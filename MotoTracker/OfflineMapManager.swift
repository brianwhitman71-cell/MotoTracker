import Foundation
import MapKit
import Combine

// MARK: - Download quality

enum TileQuality: String, CaseIterable, Identifiable, Codable {
    case standard = "Standard"   // zoom 10–14
    case detailed = "Detailed"   // zoom 10–15

    var id: String { rawValue }
    var minZoom: Int { 10 }
    var maxZoom: Int { self == .detailed ? 15 : 14 }

    var subtitle: String {
        switch self {
        case .standard: return "Zoom 10–14 · Great for navigation"
        case .detailed: return "Zoom 10–15 · Very sharp, larger download"
        }
    }
}

// MARK: - Offline region model

struct OfflineRegion: Identifiable, Codable {
    let id: UUID
    var name: String
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    let quality: TileQuality
    var downloadedTiles: Int
    var totalTiles: Int
    var downloadDate: Date?
    var status: DownloadStatus

    enum DownloadStatus: String, Codable {
        case pending, downloading, completed, failed, cancelled
    }

    var progress: Double { totalTiles > 0 ? Double(downloadedTiles) / Double(totalTiles) : 0 }
    var isComplete: Bool { status == .completed }

    /// Rough estimate: average tile ~15 KB
    var estimatedMB: Double { Double(totalTiles) * 15.0 / 1024.0 }
}

// MARK: - Manager

@MainActor
final class OfflineMapManager: ObservableObject {

    static let shared = OfflineMapManager()

    @Published var regions: [OfflineRegion] = []
    @Published var activeDownloadID: UUID?
    @Published var downloadProgress: Double = 0
    @Published var estimatedSecondsRemaining: Double = 0

    /// When true, the map renders OSM tiles (cached or live) instead of Apple Maps.
    @Published var useTilesForNavigation: Bool = false {
        didSet { UserDefaults.standard.set(useTilesForNavigation, forKey: "offlineTilesEnabled") }
    }

    var hasCompletedRegion: Bool { regions.contains { $0.isComplete } }

    private var downloadTask: Task<Void, Never>?
    private let tilesBase: URL
    private let persistKey = "offline_regions_v1"
    /// Hard cap: prevents accidentally queuing 100k+ tile downloads
    static let maxTiles = 20_000

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        tilesBase = docs.appendingPathComponent("OfflineTiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: tilesBase, withIntermediateDirectories: true)
        useTilesForNavigation = UserDefaults.standard.bool(forKey: "offlineTilesEnabled")
        loadPersistedRegions()
    }

    // MARK: - Public API

    func estimateTileCount(minLat: Double, maxLat: Double,
                           minLon: Double, maxLon: Double,
                           quality: TileQuality) -> Int {
        var n = 0
        for z in quality.minZoom...quality.maxZoom {
            let x0 = slippyX(lon: minLon, z: z), x1 = slippyX(lon: maxLon, z: z)
            let y0 = slippyY(lat: maxLat, z: z), y1 = slippyY(lat: minLat, z: z)
            n += (abs(x1 - x0) + 1) * (abs(y1 - y0) + 1)
        }
        return n
    }

    func addAndDownload(name: String,
                        minLat: Double, maxLat: Double,
                        minLon: Double, maxLon: Double,
                        quality: TileQuality) {
        let est = min(estimateTileCount(minLat: minLat, maxLat: maxLat,
                                        minLon: minLon, maxLon: maxLon,
                                        quality: quality), Self.maxTiles)
        let region = OfflineRegion(
            id: UUID(), name: name,
            minLat: minLat, maxLat: maxLat,
            minLon: minLon, maxLon: maxLon,
            quality: quality,
            downloadedTiles: 0, totalTiles: est,
            downloadDate: nil, status: .pending
        )
        regions.append(region)
        savePersistedRegions()
        beginDownload(id: region.id)
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        if let id = activeDownloadID, let i = regions.firstIndex(where: { $0.id == id }) {
            regions[i].status = .cancelled
        }
        activeDownloadID = nil
        downloadProgress = 0
        savePersistedRegions()
    }

    func retryDownload(id: UUID) {
        guard let i = regions.firstIndex(where: { $0.id == id }) else { return }
        regions[i].status = .pending
        regions[i].downloadedTiles = 0
        savePersistedRegions()
        beginDownload(id: id)
    }

    func deleteRegion(id: UUID) {
        if activeDownloadID == id { cancelDownload() }
        try? FileManager.default.removeItem(at: tilesBase.appendingPathComponent(id.uuidString))
        regions.removeAll { $0.id == id }
        savePersistedRegions()
    }

    var totalDiskUsageMB: Double {
        let bytes = (try? FileManager.default.allocatedDirectorySize(at: tilesBase)) ?? 0
        return Double(bytes) / (1024 * 1024)
    }

    // MARK: - Tile lookup (nonisolated for use on background threads)

    nonisolated func cachedTile(z: Int, x: Int, y: Int) -> Data? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = docs.appendingPathComponent("OfflineTiles")
        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: base, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return nil }
        for dir in dirs {
            let tile = dir.appendingPathComponent("\(z)/\(x)/\(y).png")
            if let data = try? Data(contentsOf: tile) { return data }
        }
        return nil
    }

    // MARK: - Download engine

    private func beginDownload(id: UUID) {
        activeDownloadID = id
        downloadProgress = 0
        downloadTask = Task { await runDownload(id: id) }
    }

    private func runDownload(id: UUID) async {
        guard let region = regions.first(where: { $0.id == id }) else { return }

        let regionDir = tilesBase.appendingPathComponent(id.uuidString)
        try? FileManager.default.createDirectory(at: regionDir, withIntermediateDirectories: true)

        if let i = regions.firstIndex(where: { $0.id == id }) { regions[i].status = .downloading }

        let session: URLSession = {
            let cfg = URLSessionConfiguration.default
            cfg.httpAdditionalHeaders = ["User-Agent": "2WheelTracker/1.0 iOS (offline maps)"]
            return URLSession(configuration: cfg)
        }()

        var downloaded = 0
        let total    = region.totalTiles
        let started  = Date.now
        let subdomains = ["a", "b", "c"]
        var subIdx   = 0

        outer: for z in region.quality.minZoom...region.quality.maxZoom {
            let x0 = slippyX(lon: region.minLon, z: z), x1 = slippyX(lon: region.maxLon, z: z)
            let y0 = slippyY(lat: region.maxLat, z: z), y1 = slippyY(lat: region.minLat, z: z)

            for x in min(x0,x1)...max(x0,x1) {
                for y in min(y0,y1)...max(y0,y1) {
                    guard !Task.isCancelled, downloaded < Self.maxTiles else { break outer }

                    let tilePath = regionDir
                        .appendingPathComponent("\(z)/\(x)", isDirectory: true)
                        .appendingPathComponent("\(y).png")

                    if !FileManager.default.fileExists(atPath: tilePath.path) {
                        let sub = subdomains[subIdx % subdomains.count]
                        subIdx += 1
                        let urlStr = "https://\(sub).tile.openstreetmap.org/\(z)/\(x)/\(y).png"
                        if let url = URL(string: urlStr),
                           let (data, resp) = try? await session.data(from: url),
                           (resp as? HTTPURLResponse)?.statusCode == 200 {
                            let dir = tilePath.deletingLastPathComponent()
                            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                            try? data.write(to: tilePath, options: .atomic)
                        }
                    }

                    downloaded += 1
                    let elapsed = Date.now.timeIntervalSince(started)
                    let rate    = elapsed > 0 ? Double(downloaded) / elapsed : 1
                    let eta     = rate > 0 ? Double(total - downloaded) / rate : 0

                    if let i = regions.firstIndex(where: { $0.id == id }) {
                        regions[i].downloadedTiles = downloaded
                    }
                    downloadProgress           = Double(downloaded) / Double(max(total, 1))
                    estimatedSecondsRemaining  = eta

                    // Rate-limit: ~15 tiles/sec respects OSM fair-use policy
                    try? await Task.sleep(for: .milliseconds(65))
                }
            }
        }

        let cancelled = Task.isCancelled
        if let i = regions.firstIndex(where: { $0.id == id }) {
            regions[i].status        = cancelled ? .cancelled : .completed
            regions[i].downloadDate  = .now
        }
        activeDownloadID          = nil
        downloadProgress          = 0
        estimatedSecondsRemaining = 0
        savePersistedRegions()
    }

    // MARK: - Slippy-map tile math

    nonisolated private func slippyX(lon: Double, z: Int) -> Int {
        Int((lon + 180.0) / 360.0 * pow(2.0, Double(z)))
    }
    nonisolated private func slippyY(lat: Double, z: Int) -> Int {
        let r = lat * .pi / 180.0
        return Int((1.0 - log(tan(r) + 1.0 / cos(r)) / .pi) / 2.0 * pow(2.0, Double(z)))
    }

    // MARK: - Persistence

    private func savePersistedRegions() {
        if let data = try? JSONEncoder().encode(regions) {
            UserDefaults.standard.set(data, forKey: persistKey)
        }
    }

    private func loadPersistedRegions() {
        guard let data = UserDefaults.standard.data(forKey: persistKey),
              let saved = try? JSONDecoder().decode([OfflineRegion].self, from: data)
        else { return }
        regions = saved.map {
            var r = $0
            if r.status == .downloading { r.status = .failed }  // crashed mid-download
            return r
        }
    }
}

// MARK: - FileManager helper

extension FileManager {
    func allocatedDirectorySize(at url: URL) throws -> UInt64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey]
        guard let e = enumerator(at: url, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total: UInt64 = 0
        for case let f as URL in e {
            let v = try f.resourceValues(forKeys: keys)
            if v.isRegularFile == true { total += UInt64(v.fileAllocatedSize ?? 0) }
        }
        return total
    }
}

// MARK: - Offline tile overlay

/// An MKTileOverlay that checks the local tile cache before going to the network.
/// Set canReplaceMapContent = true so it replaces Apple Maps entirely — providing
/// a consistent OSM-based view that works whether the device is online or offline.
class OfflineTileOverlay: MKTileOverlay {
    private let manager: OfflineMapManager

    init(manager: OfflineMapManager) {
        self.manager = manager
        super.init(urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png")
        canReplaceMapContent = true
        tileSize = CGSize(width: 256, height: 256)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let subs = ["a", "b", "c"]
        let s    = subs[(path.x + path.y) % subs.count]
        return URL(string: "https://\(s).tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        if let cached = manager.cachedTile(z: path.z, x: path.x, y: path.y) {
            result(cached, nil)
            return
        }
        // Online fallback: fetch from OSM and cache for next time
        var req = URLRequest(url: url(forTilePath: path))
        req.setValue("2WheelTracker/1.0 iOS", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, error in
            if let data, (resp as? HTTPURLResponse)?.statusCode == 200 {
                self?.cacheTile(data, z: path.z, x: path.x, y: path.y)
                result(data, nil)
            } else {
                result(nil, error)
            }
        }.resume()
    }

    private func cacheTile(_ data: Data, z: Int, x: Int, y: Int) {
        // Find the first completed region that covers this tile and cache it there
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = docs.appendingPathComponent("OfflineTiles")
        // Stash in a shared "live-cache" bucket that isn't tied to a specific download region
        let dest = base
            .appendingPathComponent("live_cache/\(z)/\(x)", isDirectory: true)
            .appendingPathComponent("\(y).png")
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: dest, options: .atomic)
    }
}
