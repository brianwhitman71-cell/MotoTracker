import Foundation
import MapKit
import Combine
import SwiftUI

// MARK: - Category

enum MotoPOICategory: String, CaseIterable, Identifiable, Codable {
    case bikerCafe    = "Biker Café"
    case motoHotel    = "Moto Hotel"
    case mountainPass = "Mountain Pass"
    case viewpoint    = "Scenic Viewpoint"
    case motoDealer   = "Dealer & Repair"
    case fuelStop     = "Fuel Stop"
    case campground   = "Moto Campground"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .bikerCafe:    return "cup.and.saucer.fill"
        case .motoHotel:    return "bed.double.fill"
        case .mountainPass: return "mountain.2.fill"
        case .viewpoint:    return "binoculars.fill"
        case .motoDealer:   return "wrench.and.screwdriver.fill"
        case .fuelStop:     return "fuelpump.fill"
        case .campground:   return "tent.fill"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .bikerCafe:    return UIColor(red: 0.52, green: 0.32, blue: 0.14, alpha: 1)
        case .motoHotel:    return UIColor.systemBlue
        case .mountainPass: return UIColor(red: 0.18, green: 0.58, blue: 0.28, alpha: 1)
        case .viewpoint:    return UIColor(red: 0.05, green: 0.55, blue: 0.68, alpha: 1)
        case .motoDealer:   return UIColor(red: 0.94, green: 0.48, blue: 0.04, alpha: 1)
        case .fuelStop:     return UIColor.systemRed
        case .campground:   return UIColor(red: 0.42, green: 0.26, blue: 0.08, alpha: 1)
        }
    }

    var color: Color {
        switch self {
        case .bikerCafe:    return Color(red: 0.52, green: 0.32, blue: 0.14)
        case .motoHotel:    return .blue
        case .mountainPass: return Color(red: 0.18, green: 0.58, blue: 0.28)
        case .viewpoint:    return Color(red: 0.05, green: 0.55, blue: 0.68)
        case .motoDealer:   return Color(red: 0.94, green: 0.48, blue: 0.04)
        case .fuelStop:     return .red
        case .campground:   return Color(red: 0.42, green: 0.26, blue: 0.08)
        }
    }

    var description: String {
        switch self {
        case .bikerCafe:    return "Biker-friendly cafés & restaurants"
        case .motoHotel:    return "Motorcycle-friendly accommodations"
        case .mountainPass: return "Mountain passes & summits"
        case .viewpoint:    return "Scenic overlooks & photo spots"
        case .motoDealer:   return "Dealers, repair & parts shops"
        case .fuelStop:     return "Gas stations & fuel stops"
        case .campground:   return "Motorcycle-friendly campsites"
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .fuelStop: return false   // too dense, opt-in
        default: return true
        }
    }
}

// MARK: - Model

struct MotoPOI: Identifiable {
    let id: UUID
    let osmID: Int64
    let name: String
    let category: MotoPOICategory
    let latitude: Double
    let longitude: Double
    var subtitle: String?
    var phone: String?
    var website: String?
    var elevation: Int?         // metres ASL, for mountain passes
    var isMotoFriendly: Bool    // explicitly tagged motorcycle=yes
    var tags: [String: String]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Annotation

final class MotoPOIAnnotation: NSObject, MKAnnotation {
    let poi: MotoPOI
    dynamic var coordinate: CLLocationCoordinate2D { poi.coordinate }
    var title: String?    { poi.name }
    var subtitle: String? { poi.category.rawValue }
    init(_ poi: MotoPOI) { self.poi = poi }
}

// MARK: - Annotation image renderer

enum MotoPOIAnnotationRenderer {
    static func makeImage(for category: MotoPOICategory, size: CGFloat = 38) -> UIImage {
        let s = size
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { _ in
            let ctx = UIGraphicsGetCurrentContext()!

            // Shadow
            ctx.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 4,
                          color: UIColor.black.withAlphaComponent(0.38).cgColor)

            // Filled circle
            let inset: CGFloat = 2
            let circleRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
            let path = UIBezierPath(ovalIn: circleRect)
            category.uiColor.setFill()
            path.fill()

            // White border ring
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            let border = UIBezierPath(ovalIn: circleRect.insetBy(dx: 0.5, dy: 0.5))
            UIColor.white.withAlphaComponent(0.85).setStroke()
            border.lineWidth = 2
            border.stroke()

            // SF Symbol icon
            let iconSize = s * 0.44
            let cfg = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
            if let icon = UIImage(systemName: category.sfSymbol, withConfiguration: cfg)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let ix = (s - icon.size.width)  / 2
                let iy = (s - icon.size.height) / 2
                icon.draw(at: CGPoint(x: ix, y: iy))
            }
        }
    }
}

// MARK: - Manager

@MainActor
final class MotoPOIManager: ObservableObject {
    static let shared = MotoPOIManager()

    @Published var visiblePOIs:      [MotoPOI] = []
    @Published var isFetching:       Bool = false
    @Published var enabledCategories: Set<MotoPOICategory>
    @Published var showPOIs: Bool = false {
        didSet { UserDefaults.standard.set(showPOIs, forKey: "motoPOIsEnabled") }
    }

    private var allCachedPOIs:   [MotoPOI] = []
    private var fetchedTileKeys: Set<String> = []
    private var fetchTask:       Task<Void, Never>?
    private(set) var currentRegionForRefetch: MKCoordinateRegion = MKCoordinateRegion()

    private init() {
        let saved = (UserDefaults.standard.stringArray(forKey: "motoPOICategories") ?? [])
            .compactMap { MotoPOICategory(rawValue: $0) }
        enabledCategories = saved.isEmpty
            ? Set(MotoPOICategory.allCases.filter { $0.defaultEnabled })
            : Set(saved)
        showPOIs = UserDefaults.standard.bool(forKey: "motoPOIsEnabled")
    }

    // MARK: - Public API

    func updateRegion(_ region: MKCoordinateRegion) {
        currentRegionForRefetch = region
        guard showPOIs else { return }
        // Don't bother when zoomed too far out (too many results, visually useless)
        guard region.span.latitudeDelta < 1.4 else {
            visiblePOIs = []
            return
        }
        fetchTask?.cancel()
        fetchTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            await fetchPOIs(for: region)
        }
    }

    func togglePOIs() {
        showPOIs.toggle()
        if showPOIs {
            Task { await fetchPOIs(for: currentRegionForRefetch) }
        } else {
            visiblePOIs = []
        }
    }

    func saveEnabledCategories() {
        UserDefaults.standard.set(enabledCategories.map { $0.rawValue }, forKey: "motoPOICategories")
        refilter()
    }

    func poiCount(for category: MotoPOICategory) -> Int {
        allCachedPOIs.filter { $0.category == category }.count
    }

    // MARK: - Private

    private func refilter() {
        visiblePOIs = allCachedPOIs.filter { enabledCategories.contains($0.category) }
    }

    private func tileKey(for region: MKCoordinateRegion) -> String {
        // ~0.5° grid — good enough to avoid re-fetching on small pans
        let lat = Int((region.center.latitude  / 0.5).rounded())
        let lon = Int((region.center.longitude / 0.5).rounded())
        return "\(lat),\(lon)"
    }

    private func fetchPOIs(for region: MKCoordinateRegion) async {
        let key = tileKey(for: region)
        guard !fetchedTileKeys.contains(key) else { refilter(); return }

        isFetching = true
        defer { isFetching = false }

        let c = region.center, s = region.span
        // Expand bbox slightly so POIs near the edge aren't clipped
        let pad  = 0.15
        let south = c.latitude  - s.latitudeDelta  / 2 - pad
        let north = c.latitude  + s.latitudeDelta  / 2 + pad
        let west  = c.longitude - s.longitudeDelta / 2 - pad
        let east  = c.longitude + s.longitudeDelta / 2 + pad
        let bbox  = "\(south),\(west),\(north),\(east)"

        // Overpass QL query — only motorcycle-relevant node types
        let query = """
        [out:json][timeout:25];
        (
          node["amenity"="cafe"]["motorcycle"="yes"](\(bbox));
          node["amenity"="restaurant"]["motorcycle"="yes"](\(bbox));
          node["tourism"~"hotel|motel|hostel|guest_house"]["motorcycle"="yes"](\(bbox));
          node["mountain_pass"="yes"](\(bbox));
          node["natural"="saddle"](\(bbox));
          way["mountain_pass"="yes"](\(bbox));
          node["tourism"="viewpoint"](\(bbox));
          node["shop"="motorcycle"](\(bbox));
          node["amenity"="fuel"](\(bbox));
          node["tourism"~"camp_site|caravan_site"]["motorcycle"="yes"](\(bbox));
        );
        out center body;
        """

        guard let encoded = query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encoded)")
        else { return }

        var req = URLRequest(url: url)
        req.setValue("2WheelTracker/1.0 iOS (moto POI layer)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 30

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200
        else { return }

        let newPOIs = parsePOIs(from: data)
        guard !Task.isCancelled else { return }

        fetchedTileKeys.insert(key)
        let existingOsmIDs = Set(allCachedPOIs.map { $0.osmID })
        let toAdd = newPOIs.filter { !existingOsmIDs.contains($0.osmID) }
        allCachedPOIs.append(contentsOf: toAdd)
        refilter()
    }

    private func parsePOIs(from data: Data) -> [MotoPOI] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]]
        else { return [] }

        var result: [MotoPOI] = []
        for el in elements {
            guard let osmID = el["id"] as? Int64 else { continue }

            // Nodes give lat/lon directly; ways give center
            let lat: Double
            let lon: Double
            if let l = el["lat"] as? Double, let o = el["lon"] as? Double {
                lat = l; lon = o
            } else if let center = el["center"] as? [String: Double],
                      let l = center["lat"], let o = center["lon"] {
                lat = l; lon = o
            } else { continue }

            let tags = el["tags"] as? [String: String] ?? [:]
            guard let rawName = tags["name"] ?? tags["ref"], !rawName.isEmpty else { continue }

            let category    = classifyCategory(tags: tags)
            let motoFriendly = tags["motorcycle"] == "yes"
            let elevation   = tags["ele"].flatMap { Int($0) }
            let phone       = tags["phone"] ?? tags["contact:phone"]
            let website     = tags["website"] ?? tags["contact:website"] ?? tags["url"]

            var addrParts: [String] = []
            if let city = tags["addr:city"] ?? tags["addr:town"] { addrParts.append(city) }
            if let state = tags["addr:state"] { addrParts.append(state) }

            // Append elevation to subtitle for mountain passes
            var subtitleParts = addrParts
            if category == .mountainPass, let elev = elevation {
                subtitleParts.insert(elevationString(elev), at: 0)
            }

            result.append(MotoPOI(
                id: UUID(),
                osmID: osmID,
                name: rawName,
                category: category,
                latitude: lat,
                longitude: lon,
                subtitle: subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " · "),
                phone: phone,
                website: website,
                elevation: elevation,
                isMotoFriendly: motoFriendly,
                tags: tags
            ))
        }
        return result
    }

    private func classifyCategory(tags: [String: String]) -> MotoPOICategory {
        if tags["mountain_pass"] == "yes" || tags["natural"] == "saddle" { return .mountainPass }
        if tags["tourism"] == "viewpoint"                                  { return .viewpoint }
        if tags["shop"] == "motorcycle"                                    { return .motoDealer }
        if tags["amenity"] == "fuel"                                       { return .fuelStop }
        if let t = tags["tourism"], ["hotel","motel","hostel","guest_house"].contains(t) {
            return .motoHotel
        }
        if let t = tags["tourism"], ["camp_site","caravan_site"].contains(t) {
            return .campground
        }
        return .bikerCafe
    }

    nonisolated private func elevationString(_ metres: Int) -> String {
        // Always show in feet + metres like calimoto
        let ft = Int(Double(metres) * 3.28084)
        return "\(ft) ft / \(metres) m"
    }
}
