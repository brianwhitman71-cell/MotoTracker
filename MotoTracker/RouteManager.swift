import Foundation
import SwiftUI
import MapKit
import AVFoundation
import Combine

// MARK: - Units of measure
enum UnitsOfMeasure: String, CaseIterable, Identifiable {
    case imperial = "Imperial"
    case metric   = "Metric"
    var id: String { rawValue }
    var distanceUnit: String { self == .imperial ? "mi" : "km" }
    var speedUnit: String    { self == .imperial ? "mph" : "km/h" }
    var icon: String         { self == .imperial ? "flag.fill" : "globe" }
}

// MARK: - Voice mode
enum VoiceMode: CaseIterable, Identifiable {
    case soundOn, alertsOnly, soundOff
    var id: Self { self }
    var icon: String {
        switch self {
        case .soundOn:    return "speaker.wave.2.fill"
        case .alertsOnly: return "bell.fill"
        case .soundOff:   return "speaker.slash.fill"
        }
    }
    var label: String {
        switch self {
        case .soundOn:    return "Sound"
        case .alertsOnly: return "Alerts"
        case .soundOff:   return "Mute"
        }
    }
}

// MARK: - Direction frequency
enum DirectionFrequency: String, CaseIterable, Identifiable {
    case off      = "Off"
    case minimal  = "Minimal"
    case normal   = "Normal"
    case frequent = "Frequent"
    case verbose  = "Verbose"

    var id: String { rawValue }

    func subtitle(imperial: Bool) -> String {
        switch self {
        case .off:      return "No spoken directions"
        case .minimal:  return imperial ? "Announce within 650 ft of each turn"   : "Announce within 200m of each turn"
        case .normal:   return imperial ? "Announce within 0.3 mi of each turn"   : "Announce within 500m of each turn"
        case .frequent: return imperial ? "Announce at 0.6 mi and 1,000 ft"       : "Announce at 1km and 300m"
        case .verbose:  return imperial ? "Announce at 1.2 mi, 0.5 mi, and 1,000 ft" : "Announce at 2km, 800m, and 300m"
        }
    }

    // Kept for backwards compatibility where no RouteManager context is available
    var subtitle: String { subtitle(imperial: true) }

    var icon: String {
        switch self {
        case .off:      return "speaker.slash"
        case .minimal:  return "speaker"
        case .normal:   return "speaker.wave.1"
        case .frequent: return "speaker.wave.2"
        case .verbose:  return "speaker.wave.3"
        }
    }

    // Announcement thresholds in meters, sorted largest first
    var thresholds: [Double] {
        switch self {
        case .off:      return []
        case .minimal:  return [200]
        case .normal:   return [500]
        case .frequent: return [1000, 300]
        case .verbose:  return [2000, 800, 300]
        }
    }
}

// MARK: - Voice option
struct VoiceOption: Identifiable, Equatable, Hashable {
    let id: String                    // unique identifier
    let languageCode: String          // fallback language for AVSpeechSynthesisVoice
    let voiceIdentifier: String?      // specific on-device voice ID
    let humeVoiceDescription: String? // Hume AI prompt-designed voice description
    let humeVoiceName: String?        // Hume AI named library voice
    let humeVoiceId: String?          // Hume AI voice by ID (takes priority over name/description)
    let name: String
    let accent: String
    let hairHex: String
    let skinHex: String
    let accentHex: String

    // True if this voice uses Hume AI (either named or description-based)
    var usesHume: Bool { humeVoiceId != nil || humeVoiceName != nil || humeVoiceDescription != nil }

    init(id: String, languageCode: String, voiceIdentifier: String? = nil,
         humeVoiceDescription: String? = nil, humeVoiceName: String? = nil, humeVoiceId: String? = nil,
         name: String, accent: String, hairHex: String, skinHex: String, accentHex: String) {
        self.id = id; self.languageCode = languageCode
        self.voiceIdentifier = voiceIdentifier
        self.humeVoiceDescription = humeVoiceDescription
        self.humeVoiceName = humeVoiceName
        self.humeVoiceId = humeVoiceId
        self.name = name; self.accent = accent
        self.hairHex = hairHex; self.skinHex = skinHex; self.accentHex = accentHex
    }

    static let defaults: [VoiceOption] = [
        VoiceOption(id: "samantha", languageCode: "en-US", name: "Samantha", accent: "US English",
                    hairHex: "#E8C87A", skinHex: "#FADADD", accentHex: "#2471A3"),
        VoiceOption(id: "daniel",   languageCode: "en-GB", name: "Daniel",   accent: "British English",
                    hairHex: "#3B1F0A", skinHex: "#FAE0C8", accentHex: "#7B241C"),
        VoiceOption(id: "karen",    languageCode: "en-AU", name: "Karen",    accent: "Australian English",
                    hairHex: "#F2D06B", skinHex: "#FADADD", accentHex: "#148F77"),
        VoiceOption(id: "moira",    languageCode: "en-IE", name: "Moira",    accent: "Irish English",
                    hairHex: "#A0430A", skinHex: "#FADADD", accentHex: "#1E8449"),
        VoiceOption(id: "tessa",    languageCode: "en-ZA", name: "Tessa",    accent: "South African",
                    hairHex: "#C8A040", skinHex: "#FAE0C8", accentHex: "#D35400"),
        // Wyatt — Hume AI voice by ID, else Aaron on-device fallback
        VoiceOption(id: "wyatt", languageCode: "en-US",
                    voiceIdentifier: "com.apple.voice.compact.en-US.Aaron",
                    humeVoiceId: "d8ab67c6-953d-4bd8-9370-8fa53a0f1453",
                    name: "Wyatt", accent: "Redneck",
                    hairHex: "#6B3A2A", skinHex: "#FAE0C8", accentHex: "#C0392B"),
        // Dolly — Hume AI "Charming Cowgirl" named voice, else US English fallback
        VoiceOption(id: "dolly", languageCode: "en-US",
                    humeVoiceName: "Charming Cowgirl",
                    name: "Dolly", accent: "Southern Belle",
                    hairHex: "#F2D06B", skinHex: "#FADADD", accentHex: "#C0392B"),
    ]
}

// MARK: - Hazard types
enum HazardType: Equatable {
    case police, speedCamera, construction, schoolZone, accident, roadClosed
    var announcement: String {
        switch self {
        case .police:       return "Police reported ahead"
        case .speedCamera:  return "Speed camera ahead"
        case .construction: return "Construction zone ahead"
        case .schoolZone:   return "School zone ahead"
        case .accident:     return "Accident ahead"
        case .roadClosed:   return "Road closed ahead"
        }
    }
    var icon: String {
        switch self {
        case .police:       return "shield.fill"
        case .speedCamera:  return "camera.fill"
        case .construction: return "exclamationmark.triangle.fill"
        case .schoolZone:   return "figure.walk"
        case .accident:     return "car.2.fill"
        case .roadClosed:   return "xmark.circle.fill"
        }
    }
}

struct RouteHazard {
    let id = UUID()
    let type: HazardType
    let coordinate: CLLocationCoordinate2D
    var announced = false
}

// MARK: - Weather models
struct PointWeather {
    let tempF:   Double
    let windMph: Double
    let wmoCode: Int        // WMO weather interpretation code

    var sfSymbol: String {
        switch wmoCode {
        case 0, 1:           return "sun.max.fill"
        case 2:              return "cloud.sun.fill"
        case 3:              return "cloud.fill"
        case 45, 48:         return "cloud.fog.fill"
        case 51, 53, 55:     return "cloud.drizzle.fill"
        case 56, 57, 61...67: return "cloud.rain.fill"
        case 71...77:        return "cloud.snow.fill"
        case 80...82:        return "cloud.rain.fill"
        case 85, 86:         return "cloud.snow.fill"
        case 95...99:        return "cloud.bolt.rain.fill"
        default:             return "cloud.fill"
        }
    }

    var symbolColor: Color {
        switch wmoCode {
        case 0, 1:            return .yellow
        case 2, 3:            return .gray
        case 45, 48:          return .gray
        case 71...77, 85, 86: return .cyan
        case 51...82:         return .blue
        case 95...99:         return .purple
        default:              return .gray
        }
    }

    // Any condition that significantly affects riding safety
    var isDangerous: Bool { wmoCode >= 45 }
}

struct RouteWeather {
    /// A single time-shifted forecast point along the route.
    struct Checkpoint {
        let label:   String       // "Now", "+1h30m", "Arrival"
        let weather: PointWeather
    }

    /// Four checkpoints: departure → 1/3 → 2/3 → arrival,
    /// each forecast for the time the rider will actually be there.
    let checkpoints: [Checkpoint]

    var hasDanger: Bool { checkpoints.contains { $0.weather.isDangerous } }

    var warningText: String {
        guard let first = checkpoints.first(where: { $0.weather.isDangerous }) else { return "" }
        if first.label == "Now" { return "Hazardous conditions at departure" }
        return "Weather worsens at \(first.label)"
    }
}

// MARK: - Curviness map overlay polyline
class CurvinessPolyline: MKPolyline {
    var curvinessScore: Double = 0
}

// MARK: - GraphHopper / Kurviger route model
struct GHRoute {
    let polyline: MKPolyline
    let distanceMeters: Double
    let timeMs: Double
    let instructions: [GHInstruction]
    var id: UUID = UUID()
    var elevationProfile: [Double]? = nil
    var curvinessScore: Double = 0   // degrees of direction-change per mile

    var elevationGainM: Double {
        guard let elev = elevationProfile, elev.count > 1 else { return 0 }
        var gain = 0.0
        for i in 1..<elev.count { if elev[i] > elev[i-1] { gain += elev[i] - elev[i-1] } }
        return gain
    }
    var elevationGainFt: Double { elevationGainM * 3.28084 }
    var minElevM: Double { elevationProfile?.min() ?? 0 }
    var maxElevM: Double { elevationProfile?.max() ?? 0 }

    var curvinessLabel: String {
        switch curvinessScore {
        case ..<80:  return "Straight"
        case ..<200: return "Scenic"
        case ..<450: return "Twisty"
        default:     return "Very Twisty"
        }
    }
}

// MARK: - Trip Stop
struct TripStop: Identifiable {
    let id = UUID()
    var name: String
    var mapItem: MKMapItem
    var coordinate: CLLocationCoordinate2D { mapItem.location.coordinate }
}

struct GHInstruction {
    let text: String
    let distanceMeters: Double
    let sign: Int  // direction sign: -2=left, 2=right, 0=straight, 4=arrive, etc.
    let intervalStart: Int  // index into points array where this instruction starts
}

// MARK: - Recent destination (persisted)
struct RecentDestination: Codable {
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    func toMapItem() -> MKMapItem {
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = name
        return item
    }
}

// MARK: - RouteManager
@MainActor
class RouteManager: NSObject, ObservableObject {

    // Accessible by CarPlaySceneDelegate (same module, no singleton needed)
    static weak var current: RouteManager?

    // ── API config ──────────────────────────────────────────────
    private let stadiaApiKey = Secrets.stadiaMapsKey
    private let tomTomApiKey = Secrets.tomTomKey

    // ── Search ──────────────────────────────────────────────────
    @Published var searchQuery    = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var showingRecents = false

    private static let recentsKey  = "recentDestinations"
    private static let maxRecents  = 8

    // ── Routes ──────────────────────────────────────────────────
    @Published var routes:          [GHRoute] = []
    @Published var selectedRoute:   GHRoute?
    @Published var isCalculatingRoutes = false
    @Published var isSearching      = false
    @Published var currentOptions:  RouteOptions = RouteOptions()
    @Published var waypoints:       [CLLocationCoordinate2D] = []
    @Published var isRoundTrip:     Bool = false
    @Published var segmentCurviness: [RouteOptions.Curviness] = []
    @Published var tripStops:       [TripStop] = []
    @Published var routeWeathers:      [UUID: RouteWeather] = [:]
    @Published var isRerouting         = false
    @Published var curvinessOverlays:  [CurvinessPolyline] = []
    @Published var isFetchingCurviness = false
    private(set) var currentDestination: MKMapItem?

    var userCoordinate: CLLocationCoordinate2D? { lastKnownLocation?.coordinate }

    private var offRouteCount    = 0
    private var lastRerouteTime: Date = .distantPast
    private var lastCurvinessRegion: MKCoordinateRegion?
    private var curvinessTask: Task<Void, Never>?
    private var lastRoundTripDistance: Double = 75
    private var lastRoundTripDirection: RoundTripDirection = .any
    private var lastRoundTripOptions: RouteOptions = RouteOptions()
    private var roundTripSeed: Double = 0

    // ── Errors ──────────────────────────────────────────────────
    @Published var routeError: String?

    // ── Navigation ──────────────────────────────────────────────
    @Published var isNavigating          = false
    @Published var currentInstruction    = ""
    @Published var distanceToNextTurn: Double = 0
    @Published var nextTurnCoordinate: CLLocationCoordinate2D? = nil
    @Published var voiceMode: VoiceMode              = .soundOn
    @Published var directionFrequency: DirectionFrequency = .normal
    @Published var selectedVoice: VoiceOption        = VoiceOption.defaults.first { $0.id == "dolly" } ?? VoiceOption.defaults[0]
    @Published var simulationMode: Bool              = UserDefaults.standard.bool(forKey: "simulationMode") {
        didSet { UserDefaults.standard.set(simulationMode, forKey: "simulationMode") }
    }
    @Published var isSimulationPaused: Bool          = false
    @Published var simulatedCoordinate: CLLocationCoordinate2D? = nil
    @Published var currentHeading: CLLocationDirection = 0
    @Published var simulationSpeedMultiplier: Double = 1.0
    @Published var simulationProgress: Double = 0
    var isPreviewMode = false
    private var simulationTask: Task<Void, Never>?
    private var simulationSeekFraction: Double? = nil
    @Published var units: UnitsOfMeasure             = {
        let saved = UserDefaults.standard.string(forKey: "unitsOfMeasure") ?? "Imperial"
        return UnitsOfMeasure(rawValue: saved) ?? .imperial
    }() {
        didSet { UserDefaults.standard.set(units.rawValue, forKey: "unitsOfMeasure") }
    }
    @Published var stopSearchResults: [MKMapItem]    = []
    @Published var activeHazard: RouteHazard?
    @Published var liveTrackCoords: [CLLocationCoordinate2D] = []
    @Published var currentSpeedLimit: Int? = nil

    @Published var currentStepIndex = 0
    private var announcedTiers: Set<Int> = []  // tier indices announced for current step
    private let synthesizer          = AVSpeechSynthesizer()
    private var humePlayer: AVAudioPlayer?
    private let humeAPIKey = Secrets.humeAIKey
    private var searchTask: Task<Void, Never>?
    private var lastKnownLocation: CLLocation?
    private var hazards: [RouteHazard]   = []
    private var lastSpeedLimitLocation: CLLocation?

    override init() {
        super.init()
        RouteManager.current = self
    }

    // MARK: - Search
    func showRecents() {
        let items = loadRecentDestinations().map { $0.toMapItem() }
        guard !items.isEmpty else { return }
        showingRecents = true
        searchResults  = items
    }

    func saveRecent(_ item: MKMapItem) {
        guard let name = item.name, !name.isEmpty else { return }
        let subtitle = item.name ?? ""
        let coord    = item.location.coordinate
        let recent   = RecentDestination(name: name, subtitle: subtitle,
                                         latitude: coord.latitude, longitude: coord.longitude)
        var recents  = loadRecentDestinations()
        recents.removeAll { $0.name == recent.name && $0.subtitle == recent.subtitle }
        recents.insert(recent, at: 0)
        if let data = try? JSONEncoder().encode(Array(recents.prefix(Self.maxRecents))) {
            UserDefaults.standard.set(data, forKey: Self.recentsKey)
        }
    }

    private func loadRecentDestinations() -> [RecentDestination] {
        guard let data    = UserDefaults.standard.data(forKey: Self.recentsKey),
              let recents = try? JSONDecoder().decode([RecentDestination].self, from: data)
        else { return [] }
        return recents
    }

    func search() {
        searchTask?.cancel()
        showingRecents = false
        guard !searchQuery.isEmpty else { searchResults = []; isSearching = false; return }

        let query       = searchQuery
        let userLoc     = lastKnownLocation

        // Tight region (50 km) for nearby POI queries like "gas", "coffee", "hotel"
        let nearRegion: MKCoordinateRegion? = userLoc.map {
            MKCoordinateRegion(center: $0.coordinate,
                               latitudinalMeters: 50_000,
                               longitudinalMeters: 50_000)
        }
        // Wide region (500 km) for named destinations, cities, addresses
        let wideRegion: MKCoordinateRegion? = userLoc.map {
            MKCoordinateRegion(center: $0.coordinate,
                               latitudinalMeters: 500_000,
                               longitudinalMeters: 500_000)
        }

        searchTask = Task {
            // Debounce — skip rapid keystrokes
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            isSearching = true

            // Coordinate shortcut (e.g. "45.52, -122.68")
            if let coord = Self.parseCoordinate(query) {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
                item.name = String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
                searchResults  = [item]
                isSearching    = false
                return
            }

            // Three parallel search streams — results trickle in as each completes
            var accumulated: [MKMapItem] = []
            await withTaskGroup(of: [MKMapItem].self) { group in

                // Stream 1: nearby POIs first — tight region, all categories
                // MapKit returns these distance-sorted when given a small region
                group.addTask {
                    await Self.mkSearch(query: query, region: nearRegion,
                                        resultTypes: [.pointOfInterest], filter: nil)
                }

                // Stream 2: addresses + distant named places — wide region
                group.addTask {
                    await Self.mkSearch(query: query, region: wideRegion,
                                        resultTypes: [.address], filter: nil)
                }

                // Stream 3: CLGeocoder — catches mountains, towns, named places MKLocalSearch misses
                group.addTask { await Self.geocode(query: query) }

                for await batch in group {
                    guard !Task.isCancelled else { break }
                    accumulated.append(contentsOf: batch)
                    searchResults = Self.processSearchResults(accumulated, query: query, userLocation: userLoc)
                }
            }

            guard !Task.isCancelled else { isSearching = false; return }
            searchResults = Self.processSearchResults(accumulated, query: query, userLocation: userLoc)
            isSearching   = false
        }
    }

    // Search for trip stops — same multi-source logic as search() but isolated from destination state
    func searchStops(_ query: String) async {
        guard !query.isEmpty else { stopSearchResults = []; return }
        let userLoc = lastKnownLocation
        let nearRegion: MKCoordinateRegion? = userLoc.map {
            MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
        let wideRegion: MKCoordinateRegion? = userLoc.map {
            MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 500_000, longitudinalMeters: 500_000)
        }
        var accumulated: [MKMapItem] = []
        await withTaskGroup(of: [MKMapItem].self) { group in
            group.addTask { await Self.mkSearch(query: query, region: nearRegion, resultTypes: [.pointOfInterest], filter: nil) }
            group.addTask { await Self.mkSearch(query: query, region: wideRegion, resultTypes: [.address], filter: nil) }
            group.addTask { await Self.geocode(query: query) }
            for await batch in group { accumulated.append(contentsOf: batch) }
        }
        stopSearchResults = Self.processSearchResults(accumulated, query: query, userLocation: userLoc)
    }

    // Deduplicate, filter empties, sort by proximity + relevance
    private static func processSearchResults(_ items: [MKMapItem], query: String, userLocation: CLLocation?) -> [MKMapItem] {
        var seen   = [String: Bool]()
        var unique = [MKMapItem]()
        for item in items {
            guard let name = item.name, !name.isEmpty else { continue }
            let c   = item.location.coordinate
            let key = "\(name.lowercased())|\(String(format: "%.3f,%.3f", c.latitude, c.longitude))"
            if seen[key] == nil { seen[key] = true; unique.append(item) }
        }

        let lq = query.lowercased()

        // Pre-compute distances once
        let distances: [ObjectIdentifier: Double] = userLocation.map { loc in
            Dictionary(uniqueKeysWithValues: unique.map { item in
                let d = loc.distance(from: CLLocation(latitude:  item.location.coordinate.latitude,
                                                      longitude: item.location.coordinate.longitude))
                return (ObjectIdentifier(item), d)
            })
        } ?? [:]

        unique.sort { a, b in
            let an = (a.name ?? "").lowercased()
            let bn = (b.name ?? "").lowercased()

            // Exact prefix match always wins regardless of distance
            let aPrefix = an.hasPrefix(lq), bPrefix = bn.hasPrefix(lq)
            if aPrefix != bPrefix { return aPrefix }

            // Sort by distance when we know the user's position
            if let dA = distances[ObjectIdentifier(a)],
               let dB = distances[ObjectIdentifier(b)] {
                // Items within 30% of each other are "the same bucket" — break ties by POI vs address
                let closer = min(dA, dB)
                if abs(dA - dB) > closer * 0.30 { return dA < dB }
                // Same distance bucket: named POI before plain address pin
                return (a.pointOfInterestCategory != nil) && (b.pointOfInterestCategory == nil)
            }

            // No location — fall back to name-contains then POI
            let aContains = an.contains(lq), bContains = bn.contains(lq)
            if aContains != bContains { return aContains }
            return (a.pointOfInterestCategory != nil) && (b.pointOfInterestCategory == nil)
        }
        return Array(unique.prefix(12))
    }

    private static func parseCoordinate(_ query: String) -> CLLocationCoordinate2D? {
        let parts = query.split(whereSeparator: { $0 == "," || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard parts.count == 2,
              let lat = Double(parts[0]), let lon = Double(parts[1]),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private static func geocode(query: String) async -> [MKMapItem] {
        guard let placemarks = try? await CLGeocoder().geocodeAddressString(query) else { return [] }
        return placemarks.prefix(3).compactMap { p -> MKMapItem? in
            guard let loc = p.location else { return nil }
            let item = MKMapItem(placemark: MKPlacemark(coordinate: loc.coordinate))
            var parts: [String] = []
            if let n = p.name                                           { parts.append(n) }
            if let city = p.locality, !parts.contains(city)            { parts.append(city) }
            if let state = p.administrativeArea                        { parts.append(state) }
            item.name = parts.isEmpty ? query : parts.joined(separator: ", ")
            return item
        }
    }

    private static func mkSearch(query: String, region: MKCoordinateRegion?,
                                 resultTypes: MKLocalSearch.ResultType,
                                 filter: MKPointOfInterestFilter?) async -> [MKMapItem] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.resultTypes          = resultTypes
        if let region { req.region = region }
        if let filter { req.pointOfInterestFilter = filter }
        return (try? await MKLocalSearch(request: req).start())?.mapItems ?? []
    }

    // MARK: - Routing via Stadia Maps / Valhalla
    func retryRoutes() async {
        guard let destination = currentDestination else { return }
        await getRoutes(to: destination, options: currentOptions)
    }

    func getRoutes(to destination: MKMapItem, options: RouteOptions = RouteOptions()) async {
        saveRecent(destination)
        currentDestination = destination
        waypoints      = []
        segmentCurviness = []
        searchResults  = []
        showingRecents = false
        searchQuery    = destination.name ?? ""
        isCalculatingRoutes = true
        routes         = []
        selectedRoute  = nil
        routeError     = nil
        currentOptions = options

        guard let userLocation = await getCurrentLocation() else {
            routeError = "Could not get your current location."
            isCalculatingRoutes = false
            return
        }

        let start: [String: Any] = ["lon": userLocation.coordinate.longitude,         "lat": userLocation.coordinate.latitude,                        "type": "break"]
        let end:   [String: Any] = ["lon": destination.location.coordinate.longitude, "lat": destination.location.coordinate.latitude, "type": "break"]
        let useTrails = options.avoidUnpaved ? 0.0 : 0.4
        let hillBias  = options.useHills

        let primaryBias:   Double
        let secondaryBias: Double
        switch options.curviness {
        case .straight:  primaryBias = 0.90; secondaryBias = 0.20
        case .curvy:     primaryBias = 0.15; secondaryBias = 0.70
        case .veryCurvy: primaryBias = 0.02; secondaryBias = 0.40
        }
        let finalPrimary   = options.avoidFreeways || options.avoidMainRoads ? 0.0 : primaryBias
        let finalSecondary = options.avoidFreeways || options.avoidMainRoads ? 0.0 : secondaryBias

        let primaryProfile:    [String: Any] = ["use_highways": finalPrimary,   "use_trails": useTrails,                "use_tolls": 0.5, "use_hills": hillBias]
        let secondaryProfile:  [String: Any] = ["use_highways": finalSecondary, "use_trails": min(useTrails + 0.2, 1.0), "use_tolls": 0.0, "use_hills": hillBias]
        let tertiaryProfile:   [String: Any] = ["use_highways": 1.0,            "use_trails": 0.0,                      "use_tolls": 1.0, "use_hills": 0.5]
        let quaternaryProfile: [String: Any] = ["use_highways": 0.0,            "use_trails": min(useTrails + 0.4, 1.0), "use_tolls": 0.0, "use_hills": hillBias]

        func makeBody(_ profile: [String: Any], alternates: Int) -> [String: Any] {
            ["locations": [start, end],
             "costing": "motorcycle",
             "costing_options": ["motorcycle": profile],
             "directions_options": ["language": "en-US"],
             "units": units == .imperial ? "miles" : "kilometers",
             "alternates": alternates]
        }

        do {
            let fetched = try await withThrowingTaskGroup(of: [GHRoute].self) { group in
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    return (try? await self.fetchValhallaRoutes(body: makeBody(primaryProfile,    alternates: 7))) ?? []
                }
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    return (try? await self.fetchValhallaRoutes(body: makeBody(secondaryProfile,  alternates: 7))) ?? []
                }
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    return (try? await self.fetchValhallaRoutes(body: makeBody(tertiaryProfile,   alternates: 7))) ?? []
                }
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    return (try? await self.fetchValhallaRoutes(body: makeBody(quaternaryProfile, alternates: 7))) ?? []
                }
                var results: [GHRoute] = []
                for try await batch in group { results.append(contentsOf: batch) }
                return results
            }

            // Deduplicate: drop routes whose midpoint is within 100m of an already-kept route's midpoint
            func midpoint(_ r: GHRoute) -> CLLocationCoordinate2D {
                var coords = [CLLocationCoordinate2D](repeating: .init(), count: r.polyline.pointCount)
                r.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: r.polyline.pointCount))
                return coords[max(coords.count / 2, 0)]
            }
            var unique: [GHRoute] = []
            for route in fetched.sorted(by: { $0.distanceMeters < $1.distanceMeters }) {
                let mid = midpoint(route)
                let isDuplicate = unique.contains {
                    let m = midpoint($0)
                    let dlat = (mid.latitude  - m.latitude)  * 111_000
                    let dlon = (mid.longitude - m.longitude) * 111_000 * cos(m.latitude * .pi / 180)
                    return sqrt(dlat*dlat + dlon*dlon) < 100
                }
                if !isDuplicate { unique.append(route) }
            }

            let targetCount = options.routeCount

            routes = Array(unique.prefix(targetCount))
            selectedRoute = nil
            if routes.isEmpty { routeError = "No routes found." }
            print("Valhalla returned \(routes.count) unique route(s)")
            Task { await self.fetchElevationsForRoutes() }
            Task { await self.fetchWeatherForRoutes() }
        } catch {
            routeError = "Network error: \(error.localizedDescription)"
            print("Valhalla error: \(error)")
        }

        isCalculatingRoutes = false
    }

    // MARK: - Stadia Maps / Valhalla fetch + parse

    private func fetchValhallaRoutes(body: [String: Any]) async throws -> [GHRoute] {
        guard let url = URL(string: "https://api.stadiamaps.com/route/v1?api_key=\(stadiaApiKey)") else { return [] }
        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody   = try? JSONSerialization.data(withJSONObject: body)
        let (data, resp)   = try await URLSession.shared.data(for: request)
        let statusCode     = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                      ?? String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"
            throw NSError(domain: "Valhalla", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        var routes: [GHRoute] = []
        if let trip = json?["trip"] as? [String: Any], let r = parseValhallaTrip(trip) {
            routes.append(r)
        }
        for alt in (json?["alternates"] as? [[String: Any]] ?? []) {
            if let trip = alt["trip"] as? [String: Any], let r = parseValhallaTrip(trip) {
                routes.append(r)
            }
        }
        return routes
    }

    private func parseValhallaTrip(_ trip: [String: Any]) -> GHRoute? {
        guard let summary = trip["summary"] as? [String: Any],
              let legs    = trip["legs"]    as? [[String: Any]],
              let leg     = legs.first,
              let shape   = leg["shape"]   as? String
        else { return nil }

        let length     = summary["length"] as? Double ?? 0
        let distMeters = units == .imperial ? length * 1609.34 : length * 1000
        let timeMs     = (summary["time"] as? Double ?? 0) * 1000

        let coords = decodePolyline6(shape)
        guard coords.count > 1 else { return nil }

        let instructions: [GHInstruction] = (leg["maneuvers"] as? [[String: Any]] ?? []).compactMap { m in
            guard let text = m["instruction"] as? String else { return nil }
            let mLength = m["length"] as? Double ?? 0
            let distM   = units == .imperial ? mLength * 1609.34 : mLength * 1000
            let type    = m["type"] as? Int ?? 0
            let idx     = m["begin_shape_index"] as? Int ?? 0
            // Map Valhalla arrive types (4,5,6) to sign 4 so navigation filters work
            let sign    = (type == 4 || type == 5 || type == 6) ? 4 : 0
            return GHInstruction(text: text, distanceMeters: distM, sign: sign, intervalStart: idx)
        }

        let curviness = Self.computeCurviness(coords)
        let polyline  = MKPolyline(coordinates: coords, count: coords.count)
        return GHRoute(polyline: polyline, distanceMeters: distMeters, timeMs: timeMs,
                       instructions: instructions, curvinessScore: curviness)
    }

    // Valhalla polyline6 encoded shape (precision 1e-6)
    private func decodePolyline6(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        let bytes = Array(encoded.utf8)
        var idx = 0, lat = 0, lon = 0
        while idx < bytes.count {
            var result = 0, shift = 0, byte = 0
            repeat {
                byte = Int(bytes[idx]) - 63; idx += 1
                result |= (byte & 0x1F) << shift; shift += 5
            } while byte >= 0x20 && idx < bytes.count
            lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            result = 0; shift = 0
            repeat {
                byte = Int(bytes[idx]) - 63; idx += 1
                result |= (byte & 0x1F) << shift; shift += 5
            } while byte >= 0x20 && idx < bytes.count
            lon += (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            coords.append(CLLocationCoordinate2D(latitude:  Double(lat) / 1_000_000,
                                                 longitude: Double(lon) / 1_000_000))
        }
        return coords
    }

    // Compute direction-change degrees per mile from a coordinate array
    private static func computeCurviness(_ coords: [CLLocationCoordinate2D]) -> Double {
        guard coords.count > 2 else { return 0 }
        let step = max(1, coords.count / 300)
        let sampled = stride(from: 0, to: coords.count, by: step).map { coords[$0] }

        func bearing(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
            let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
            let dLon = (b.longitude - a.longitude) * .pi / 180
            return atan2(sin(dLon) * cos(lat2),
                         cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)) * 180 / .pi
        }

        var totalAngle = 0.0
        for i in 1..<sampled.count - 1 {
            var diff = abs(bearing(sampled[i], sampled[i+1]) - bearing(sampled[i-1], sampled[i]))
            if diff > 180 { diff = 360 - diff }
            if diff > 5 { totalAngle += diff }
        }
        var distMeters = 0.0
        for i in 1..<sampled.count {
            distMeters += CLLocation(latitude: sampled[i-1].latitude, longitude: sampled[i-1].longitude)
                .distance(from: CLLocation(latitude: sampled[i].latitude, longitude: sampled[i].longitude))
        }
        return distMeters > 0 ? totalAngle / (distMeters / 1609.34) : 0
    }

    // MARK: - Get current location (one-shot)
    private func getCurrentLocation() async -> CLLocation? {
        return await withCheckedContinuation { continuation in
            let fetcher = OneTimeLocationFetcher {
                continuation.resume(returning: $0)
            }
            fetcher.start()
            // retain the fetcher for the duration of the async call
            objc_setAssociatedObject(self, "locationFetcher", fetcher, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func cancelRoutes() {
        routes              = []
        selectedRoute       = nil
        waypoints           = []
        segmentCurviness    = []
        currentDestination  = nil
        isRoundTrip         = false
        roundTripSeed       = 0
        searchQuery         = ""
        searchResults       = []
        showingRecents      = false
        routeWeathers       = [:]
    }

    // MARK: - Trip Planner (multi-stop itinerary)
    func addTripStop(_ item: MKMapItem) {
        let stop = TripStop(name: item.name ?? "Stop \(tripStops.count + 1)", mapItem: item)
        tripStops.append(stop)
    }

    func removeTripStops(at offsets: IndexSet) {
        tripStops.remove(atOffsets: offsets)
    }

    func moveTripStops(from source: IndexSet, to destination: Int) {
        tripStops.move(fromOffsets: source, toOffset: destination)
    }

    func calculateTripRoute() async {
        guard !tripStops.isEmpty else { return }
        isCalculatingRoutes = true
        routes = []; selectedRoute = nil; routeError = nil
        isRoundTrip = false; waypoints = []; segmentCurviness = []
        searchResults = []; showingRecents = false

        guard let userLocation = await getCurrentLocation() else {
            routeError = "Could not get your current location."
            isCalculatingRoutes = false
            return
        }

        currentDestination = tripStops.last?.mapItem
        searchQuery = tripStops.map { $0.name }.joined(separator: " → ")

        var locations: [[String: Any]] = [
            ["lon": userLocation.coordinate.longitude, "lat": userLocation.coordinate.latitude, "type": "break"]
        ]
        for stop in tripStops {
            locations.append(["lon": stop.coordinate.longitude, "lat": stop.coordinate.latitude, "type": "break"])
        }

        let tripBias: Double
        switch currentOptions.curviness {
        case .straight:  tripBias = 0.90
        case .curvy:     tripBias = 0.15
        case .veryCurvy: tripBias = 0.02
        }
        let tripProfile: [String: Any] = ["use_highways": tripBias, "use_trails": currentOptions.avoidUnpaved ? 0.0 : 0.4,
                                          "use_tolls": 0.5, "use_hills": currentOptions.useHills]
        let body: [String: Any] = [
            "locations": locations, "costing": "motorcycle",
            "costing_options": ["motorcycle": tripProfile],
            "directions_options": ["language": "en-US"],
            "units": units == .imperial ? "miles" : "kilometers", "alternates": 2
        ]

        let fetched = (try? await fetchValhallaRoutes(body: body)) ?? []
        if fetched.isEmpty {
            routeError = "Could not calculate trip route. Try adjusting your stops."
        } else {
            routes = fetched
            Task { await self.fetchElevationsForRoutes() }
            Task { await self.fetchWeatherForRoutes() }
        }
        isCalculatingRoutes = false
    }

    // MARK: - Round Trip Generation
    func generateRoundTrip(distanceMiles: Double, direction: RoundTripDirection, options: RouteOptions = RouteOptions()) async {
        lastRoundTripDistance  = distanceMiles
        lastRoundTripDirection = direction
        lastRoundTripOptions   = options
        roundTripSeed          = 0
        await fetchRoundTrip(distanceMiles: distanceMiles, direction: direction, options: options, seed: 0)
    }

    func regenerateRoundTrip() async {
        roundTripSeed += 1
        await fetchRoundTrip(distanceMiles: lastRoundTripDistance,
                             direction: lastRoundTripDirection,
                             options: lastRoundTripOptions,
                             seed: roundTripSeed)
    }

    private func fetchRoundTrip(distanceMiles: Double, direction: RoundTripDirection, options: RouteOptions, seed: Double) async {
        isCalculatingRoutes = true
        isRoundTrip         = true
        routes              = []
        selectedRoute       = nil
        routeError          = nil
        waypoints           = []
        currentDestination  = nil
        searchQuery         = "Round Trip ~\(Int(distanceMiles)) mi"

        guard let userLocation = await getCurrentLocation() else {
            routeError = "Could not get your current location."
            isCalculatingRoutes = false
            return
        }

        let totalKm     = distanceMiles * 1.60934
        // Curvy roads are ~1.7–2× the crow-flies distance; use 1.8 for a nice loop feel
        let straightKm  = (totalKm / 2.0) / 1.8
        let baseBearing = direction.bearing ?? (seed * 73.1).truncatingRemainder(dividingBy: 360)

        // 5 turning-point variations spread around the chosen direction
        let offsets: [Double] = [0, 40, -40, 80, -80].map { $0 + seed * 19.7 }

        let rtUseTrails = options.avoidUnpaved ? 0.0 : 0.35
        let rtHwBias: Double
        switch options.curviness {
        case .straight:  rtHwBias = 0.5
        case .curvy:     rtHwBias = 0.05
        case .veryCurvy: rtHwBias = 0.0
        }
        let rtFinalHw = (options.avoidFreeways || options.avoidMainRoads) ? 0.0 : rtHwBias
        let rtProfile: [String: Any] = ["use_highways": rtFinalHw, "use_trails": rtUseTrails,
                                        "use_tolls": 0.3, "use_hills": options.useHills]

        var fetched: [GHRoute] = []
        await withTaskGroup(of: [GHRoute].self) { group in
            for offset in offsets {
                let bearing      = (baseBearing + offset).truncatingRemainder(dividingBy: 360)
                let turningPoint = destinationCoordinate(from: userLocation.coordinate,
                                                         distanceKm: straightKm,
                                                         bearingDeg: bearing)
                let locations: [[String: Any]] = [
                    ["lon": userLocation.coordinate.longitude, "lat": userLocation.coordinate.latitude, "type": "break"],
                    ["lon": turningPoint.longitude,            "lat": turningPoint.latitude,            "type": "through"],
                    ["lon": userLocation.coordinate.longitude, "lat": userLocation.coordinate.latitude, "type": "break"],
                ]
                let body: [String: Any] = [
                    "locations": locations, "costing": "motorcycle",
                    "costing_options": ["motorcycle": rtProfile],
                    "directions_options": ["language": "en-US"],
                    "units": "kilometers", "alternates": 1,
                ]
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    return (try? await self.fetchValhallaRoutes(body: body)) ?? []
                }
            }
            for await batch in group { fetched.append(contentsOf: batch) }
        }

        // Sort by closest match to requested distance, then deduplicate
        let targetMeters = totalKm * 1000
        let sorted = fetched.sorted { abs($0.distanceMeters - targetMeters) < abs($1.distanceMeters - targetMeters) }

        var unique: [GHRoute] = []
        for route in sorted {
            let mid = routeMidpoint(route)
            let isDup = unique.contains {
                let m = routeMidpoint($0)
                let dlat = (mid.latitude  - m.latitude)  * 111_000
                let dlon = (mid.longitude - m.longitude) * 111_000 * cos(m.latitude * .pi / 180)
                return sqrt(dlat*dlat + dlon*dlon) < 500
            }
            if !isDup { unique.append(route) }
        }

        routes = Array(unique.prefix(options.routeCount))
        if routes.isEmpty {
            routeError = "Couldn't generate a loop. Try a different distance or direction."
            isRoundTrip = false
        } else {
            Task { await self.fetchElevationsForRoutes() }
            Task { await self.fetchWeatherForRoutes() }
        }
        isCalculatingRoutes = false
    }

    // MARK: - Helpers
    private func routeMidpoint(_ r: GHRoute) -> CLLocationCoordinate2D {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: r.polyline.pointCount)
        r.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: r.polyline.pointCount))
        return coords[max(coords.count / 2, 0)]
    }

    private func destinationCoordinate(from: CLLocationCoordinate2D,
                                       distanceKm: Double,
                                       bearingDeg: Double) -> CLLocationCoordinate2D {
        let R       = 6371.0
        let d       = distanceKm / R
        let bearing = bearingDeg * .pi / 180
        let lat1    = from.latitude  * .pi / 180
        let lon1    = from.longitude * .pi / 180
        let lat2    = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(bearing))
        let lon2    = lon1 + atan2(sin(bearing) * sin(d) * cos(lat1),
                                   cos(d) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    // MARK: - Waypoint / route shaping
    func addWaypoint(_ coord: CLLocationCoordinate2D) async {
        waypoints.append(coord)
        segmentCurviness.append(currentOptions.curviness)
        let ok = await rerouteWithWaypoints()
        if !ok {
            // Revert the just-added waypoint so the map stays clean
            waypoints.removeLast()
            if !segmentCurviness.isEmpty { segmentCurviness.removeLast() }
        }
    }

    func removeWaypoint(at index: Int) async {
        guard index < waypoints.count else { return }
        waypoints.remove(at: index)
        if index < segmentCurviness.count { segmentCurviness.remove(at: index) }
        if waypoints.isEmpty {
            guard let dest = currentDestination else { return }
            await getRoutes(to: dest, options: currentOptions)
        } else {
            _ = await rerouteWithWaypoints()
            // On failure the remaining waypoints are kept and the error is shown;
            // we never silently remove extra waypoints here.
        }
    }

    func removeLastWaypoint() async {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        if !segmentCurviness.isEmpty { segmentCurviness.removeLast() }
        if waypoints.isEmpty {
            guard let dest = currentDestination else { return }
            await getRoutes(to: dest, options: currentOptions)
        } else {
            _ = await rerouteWithWaypoints()
        }
    }

    // Returns true on success, false if no route could be found.
    // Callers are responsible for reverting model state on failure if needed.
    @discardableResult
    private func rerouteWithWaypoints() async -> Bool {
        guard let destination = currentDestination else { return false }
        isCalculatingRoutes = true
        routeError = nil

        let startLoc: CLLocation?
        if let known = lastKnownLocation { startLoc = known }
        else { startLoc = await getCurrentLocation() }
        guard let startLoc else {
            routeError = "Could not get your current location."
            isCalculatingRoutes = false
            return false
        }

        var wpLocations: [[String: Any]] = [
            ["lon": startLoc.coordinate.longitude, "lat": startLoc.coordinate.latitude, "type": "break"]
        ]
        for wp in waypoints {
            wpLocations.append(["lon": wp.longitude, "lat": wp.latitude, "type": "through"])
        }
        wpLocations.append(["lon": destination.location.coordinate.longitude,
                             "lat": destination.location.coordinate.latitude, "type": "break"])

        let wpBias: Double
        switch currentOptions.curviness {
        case .straight:  wpBias = 0.90
        case .curvy:     wpBias = 0.15
        case .veryCurvy: wpBias = 0.02
        }
        let wpFinalBias = (currentOptions.avoidFreeways || currentOptions.avoidMainRoads) ? 0.0 : wpBias
        let wpProfile: [String: Any] = ["use_highways": wpFinalBias,
                                        "use_trails": currentOptions.avoidUnpaved ? 0.0 : 0.4,
                                        "use_tolls": 0.5, "use_hills": currentOptions.useHills]
        let body: [String: Any] = [
            "locations": wpLocations, "costing": "motorcycle",
            "costing_options": ["motorcycle": wpProfile],
            "directions_options": ["language": "en-US"],
            "units": units == .imperial ? "miles" : "kilometers", "alternates": 2
        ]

        let fetched = (try? await fetchValhallaRoutes(body: body)) ?? []
        isCalculatingRoutes = false
        if let best = fetched.first {
            routes = fetched
            selectedRoute = best
            Task { await self.fetchElevationsForRoutes() }
            return true
        } else {
            routeError = "Can't route through that point. Try another spot."
            return false
        }
    }

    // MARK: - Elevation Fetching
    func fetchElevationsForRoutes() async {
        for route in routes {
            let routeId = route.id
            var coords = [CLLocationCoordinate2D](repeating: .init(), count: route.polyline.pointCount)
            route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: route.polyline.pointCount))
            // Sample up to 80 evenly spaced points
            let step = max(1, coords.count / 80)
            let sampled = stride(from: 0, to: coords.count, by: step).map { coords[$0] }
            let locations = sampled.map { ["latitude": $0.latitude, "longitude": $0.longitude] }
            guard let url = URL(string: "https://api.open-elevation.com/api/v1/lookup"),
                  let body = try? JSONSerialization.data(withJSONObject: ["locations": locations]) else { continue }
            var req = URLRequest(url: url, timeoutInterval: 12)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { continue }
            let elevations = results.compactMap { $0["elevation"] as? Double }
            if let idx = routes.firstIndex(where: { $0.id == routeId }) {
                routes[idx].elevationProfile = elevations
            }
        }
    }

    // MARK: - Weather Fetching (time-shifted forecasts)

    func fetchWeatherForRoutes() async {
        guard !routes.isEmpty else { return }
        let departure = Date.now

        await withTaskGroup(of: (UUID, RouteWeather?).self) { group in
            for route in routes {
                group.addTask {
                    let count = route.polyline.pointCount
                    guard count >= 2 else { return (route.id, nil) }
                    var coords = [CLLocationCoordinate2D](repeating: .init(), count: count)
                    route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))

                    // Estimate total travel time; fall back to distance ÷ 60 km/h if unknown
                    let totalSecs = route.timeMs > 0
                        ? route.timeMs / 1000
                        : route.distanceMeters / 1000 / 60 * 3600

                    // Four evenly-spaced checkpoints: 0%, 33%, 66%, 100%
                    let offsets: [TimeInterval] = [0, totalSecs/3, 2*totalSecs/3, totalSecs]
                    let indices = [0, count/3, 2*count/3, count - 1].map { max(0, min($0, count - 1)) }

                    async let w0 = self.fetchWeather(at: coords[indices[0]], arrivalDate: departure.addingTimeInterval(offsets[0]))
                    async let w1 = self.fetchWeather(at: coords[indices[1]], arrivalDate: departure.addingTimeInterval(offsets[1]))
                    async let w2 = self.fetchWeather(at: coords[indices[2]], arrivalDate: departure.addingTimeInterval(offsets[2]))
                    async let w3 = self.fetchWeather(at: coords[indices[3]], arrivalDate: departure.addingTimeInterval(offsets[3]))

                    guard let p0 = await w0, let p1 = await w1,
                          let p2 = await w2, let p3 = await w3 else { return (route.id, nil) }

                    let checkpoints = zip(offsets, [p0, p1, p2, p3]).map {
                        RouteWeather.Checkpoint(label: self.arrivalLabel($0.0, total: totalSecs),
                                                weather: $0.1)
                    }
                    return (route.id, RouteWeather(checkpoints: checkpoints))
                }
            }
            for await (id, weather) in group {
                if let w = weather { routeWeathers[id] = w }
            }
        }
    }

    /// Format an offset as a readable label ("Now", "+1h 30m", "Arrival").
    private nonisolated func arrivalLabel(_ offset: TimeInterval, total: TimeInterval) -> String {
        if offset <= 60 { return "Now" }
        if abs(offset - total) < 120 { return "Arrival" }
        let h = Int(offset) / 3600
        let m = (Int(offset) % 3600) / 60
        if h == 0 { return "+\(m)m" }
        if m < 5  { return "+\(h)h" }
        return "+\(h)h \(m)m"
    }

    /// Fetch the hourly forecast for a specific future arrival time using Open-Meteo.
    /// Uses UTC so the hour index lookup is timezone-independent.
    private func fetchWeather(at coord: CLLocationCoordinate2D, arrivalDate: Date) async -> PointWeather? {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&hourly=temperature_2m,weathercode,windspeed_10m&wind_speed_unit=mph&temperature_unit=fahrenheit&timezone=UTC&forecast_days=3"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hourly = json["hourly"] as? [String: Any],
              let times  = hourly["time"]           as? [String],
              let temps  = hourly["temperature_2m"] as? [Double],
              let winds  = hourly["windspeed_10m"]  as? [Double],
              let codes  = hourly["weathercode"]    as? [Int]
        else { return nil }

        // Snap to nearest hour, then format as the "YYYY-MM-DDTHH:00" key Open-Meteo uses
        let snapped = Date(timeIntervalSince1970: (arrivalDate.timeIntervalSince1970 / 3600).rounded() * 3600)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let c = cal.dateComponents([.year, .month, .day, .hour], from: snapped)
        guard let year = c.year, let month = c.month, let day = c.day, let hour = c.hour else { return nil }
        let targetKey = String(format: "%04d-%02d-%02dT%02d:00", year, month, day, hour)

        guard let idx = times.firstIndex(of: targetKey),
              idx < temps.count, idx < winds.count, idx < codes.count
        else { return nil }
        return PointWeather(tempF: temps[idx], windMph: winds[idx], wmoCode: codes[idx])
    }

    // MARK: - Curviness Map Overlay

    /// Fetch OSM road geometries for the visible region and score each segment by curviness.
    /// Only roads that are meaningfully curvy are included; straight roads are filtered out.
    func fetchCurvinessOverlay(for region: MKCoordinateRegion) {
        // Too zoomed out — clear overlay and skip
        guard region.span.latitudeDelta < 0.7 else {
            curvinessOverlays = []
            lastCurvinessRegion = nil
            return
        }
        // Skip if the map hasn't moved much from the last fetch
        if let last = lastCurvinessRegion {
            let latMove = abs(last.center.latitude  - region.center.latitude)
            let lonMove = abs(last.center.longitude - region.center.longitude)
            let threshold = last.span.latitudeDelta * 0.25
            if latMove < threshold && lonMove < threshold { return }
        }
        curvinessTask?.cancel()
        curvinessTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await performCurvinessFetch(region: region)
        }
    }

    func clearCurvinessOverlay() {
        curvinessTask?.cancel()
        curvinessOverlays    = []
        lastCurvinessRegion  = nil
    }

    private func performCurvinessFetch(region: MKCoordinateRegion) async {
        let lat = region.span.latitudeDelta
        let lon = region.span.longitudeDelta
        let south = region.center.latitude  - lat / 2
        let north = region.center.latitude  + lat / 2
        let west  = region.center.longitude - lon / 2
        let east  = region.center.longitude + lon / 2

        // Include tertiary roads only when zoomed in enough
        let types = lat < 0.15
            ? "motorway|trunk|primary|secondary|tertiary"
            : "motorway|trunk|primary|secondary"

        let query = """
        [out:json][timeout:20][bbox:\(south),\(west),\(north),\(east)];
        way["highway"~"^(\(types))$"];
        out geom qt;
        """
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encoded)") else { return }

        isFetchingCurviness = true
        lastCurvinessRegion = region
        defer { isFetchingCurviness = false }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]],
              !Task.isCancelled else { return }

        var overlays: [CurvinessPolyline] = []
        for element in elements {
            guard element["type"] as? String == "way",
                  let geometry = element["geometry"] as? [[String: Any]] else { continue }
            var coords = geometry.compactMap { node -> CLLocationCoordinate2D? in
                guard let la = node["lat"] as? Double, let lo = node["lon"] as? Double else { return nil }
                return CLLocationCoordinate2D(latitude: la, longitude: lo)
            }
            guard coords.count >= 3 else { continue }
            let score = Self.computeCurviness(coords)
            guard score >= 50 else { continue }     // skip dead-straight roads
            let pl = CurvinessPolyline(coordinates: &coords, count: coords.count)
            pl.curvinessScore = score
            overlays.append(pl)
        }
        curvinessOverlays = overlays
    }

    // MARK: - Per-Segment Curviness
    func setSegmentCurviness(_ curviness: RouteOptions.Curviness, forSegment index: Int) async {
        guard index < segmentCurviness.count else { return }
        segmentCurviness[index] = curviness
        await rerouteSegmented()
    }

    private func rerouteSegmented() async {
        guard let destination = currentDestination else { return }
        isCalculatingRoutes = true
        routeError = nil
        let startLoc: CLLocation?
        if let known = lastKnownLocation { startLoc = known }
        else { startLoc = await getCurrentLocation() }
        guard let startLoc else {
            routeError = "Could not get your current location."
            isCalculatingRoutes = false
            return
        }
        var coords: [CLLocationCoordinate2D] = [startLoc.coordinate]
        coords.append(contentsOf: waypoints)
        coords.append(destination.location.coordinate)
        let segAvoidHW  = currentOptions.avoidFreeways || currentOptions.avoidMainRoads
        let segUseTrails = currentOptions.avoidUnpaved ? 0.0 : 0.4
        var segRoutes: [Int: GHRoute] = [:]
        await withTaskGroup(of: (Int, GHRoute?).self) { group in
            for i in 0..<(coords.count - 1) {
                let from = coords[i], to = coords[i + 1]
                let curv = i < segmentCurviness.count ? segmentCurviness[i] : currentOptions.curviness
                let segBias: Double
                switch curv {
                case .straight:  segBias = segAvoidHW ? 0.0 : 0.90
                case .curvy:     segBias = segAvoidHW ? 0.0 : 0.15
                case .veryCurvy: segBias = 0.0
                }
                let segProfile: [String: Any] = ["use_highways": segBias, "use_trails": segUseTrails, "use_tolls": 0.5]
                let body: [String: Any] = [
                    "locations": [
                        ["lon": from.longitude, "lat": from.latitude, "type": "break"],
                        ["lon": to.longitude,   "lat": to.latitude,   "type": "break"],
                    ],
                    "costing": "motorcycle",
                    "costing_options": ["motorcycle": segProfile],
                    "directions_options": ["language": "en-US"],
                    "units": units == .imperial ? "miles" : "kilometers",
                ]
                group.addTask { [weak self] in
                    guard let self else { return (i, nil) }
                    return (i, (try? await self.fetchValhallaRoutes(body: body))?.first)
                }
            }
            for await (idx, r) in group { segRoutes[idx] = r }
        }
        let segList = (0..<(coords.count - 1)).compactMap { segRoutes[$0] }
        guard segList.count == coords.count - 1 else {
            routeError = "Could not route one or more segments."
            isCalculatingRoutes = false
            return
        }
        // Merge segments
        var allCoords: [CLLocationCoordinate2D] = []
        var allInstructions: [GHInstruction] = []
        var totalDist = 0.0, totalTime = 0.0
        for seg in segList {
            var segCoords = [CLLocationCoordinate2D](repeating: .init(), count: seg.polyline.pointCount)
            seg.polyline.getCoordinates(&segCoords, range: NSRange(location: 0, length: seg.polyline.pointCount))
            let coords = segCoords
            let offset = allCoords.isEmpty ? 0 : allCoords.count - 1
            if !allCoords.isEmpty { allCoords.removeLast() }
            allCoords.append(contentsOf: coords)
            let adjusted = seg.instructions.map {
                GHInstruction(text: $0.text, distanceMeters: $0.distanceMeters, sign: $0.sign, intervalStart: $0.intervalStart + offset)
            }
            allInstructions.append(contentsOf: adjusted)
            totalDist += seg.distanceMeters
            totalTime += seg.timeMs
        }
        let merged = GHRoute(polyline: MKPolyline(coordinates: allCoords, count: allCoords.count),
                             distanceMeters: totalDist, timeMs: totalTime, instructions: allInstructions)
        routes = [merged]
        selectedRoute = merged
        isCalculatingRoutes = false
        Task { await self.fetchElevationsForRoutes() }
    }

    // MARK: - Navigation
    func startNavigation() {
        guard let route = selectedRoute else { return }
        isNavigating      = true
        currentStepIndex  = 0
        announcedTiers    = []
        activeHazard      = nil
        hazards           = []
        liveTrackCoords   = []
        currentSpeedLimit = nil
        lastSpeedLimitLocation = nil
        setupAudio()
        let routeToFetch  = route
        Task { await fetchLiveHazards(for: routeToFetch) }
        let steps = route.instructions.filter { !$0.text.isEmpty && $0.sign != 4 }
        if let first = steps.first {
            currentInstruction = first.text
            if !isPreviewMode { say("Starting navigation. \(first.text)", isNavigation: true) }
        }
        if simulationMode {
            simulationTask = Task { await runSimulation() }
        }
    }

    func stopNavigation() {
        isNavigating = false
        simulationTask?.cancel()
        simulationTask       = nil
        simulatedCoordinate  = nil
        isSimulationPaused   = false
        synthesizer.stopSpeaking(at: .immediate)
        if !isPreviewMode {
            cancelRoutes()
        }
        isPreviewMode            = false
        simulationSpeedMultiplier = 1.0
        simulationProgress       = 0
        simulationSeekFraction   = nil
        currentInstruction = ""
        currentStepIndex   = 0
        hazards            = []
        activeHazard       = nil
        liveTrackCoords    = []
        currentSpeedLimit  = nil
        lastSpeedLimitLocation = nil
    }

    func update(with location: CLLocation) {
        lastKnownLocation = location
        if !simulationMode, location.course >= 0 {
            currentHeading = location.course
        }
        // Fetch speed limit every ~150m regardless of navigation state
        if lastSpeedLimitLocation.map({ location.distance(from: $0) > 150 }) ?? true {
            lastSpeedLimitLocation = location
            Task { await self.fetchSpeedLimit(at: location.coordinate) }
        }
        // Append to live track during navigation — only every ≥5m to avoid 20Hz rebuilds
        if isNavigating {
            let shouldAppend: Bool
            if let last = liveTrackCoords.last {
                let prev = CLLocation(latitude: last.latitude, longitude: last.longitude)
                shouldAppend = location.distance(from: prev) >= 5
            } else {
                shouldAppend = true
            }
            if shouldAppend { liveTrackCoords.append(location.coordinate) }
        }
        guard isNavigating, let route = selectedRoute else { return }
        let steps = route.instructions.filter { !$0.text.isEmpty }
        guard currentStepIndex < steps.count else { return }

        // Get the coordinates for this step from the polyline
        let allCoords = polylineCoords(route.polyline)
        guard !allCoords.isEmpty else { return }

        // Find the next step's start point as our target
        let nextStepIndex = currentStepIndex + 1
        let isLast = nextStepIndex >= steps.count

        let targetIndex: Int
        if isLast {
            targetIndex = allCoords.count - 1
        } else {
            targetIndex = min(steps[nextStepIndex].intervalStart, allCoords.count - 1)
        }

        let targetCoord = allCoords[targetIndex]
        let targetLoc   = CLLocation(latitude: targetCoord.latitude, longitude: targetCoord.longitude)
        let dist        = location.distance(from: targetLoc)
        distanceToNextTurn    = dist
        nextTurnCoordinate    = targetCoord

        // Announce upcoming turn based on direction frequency setting
        if !isLast {
            let thresholds = directionFrequency.thresholds  // sorted largest→smallest
            for (tierIndex, threshold) in thresholds.enumerated() {
                if dist < threshold && !announcedTiers.contains(tierIndex) {
                    announcedTiers.insert(tierIndex)
                    let next   = steps[nextStepIndex].text
                    let prefix = dist > 100 ? "In \(formatDistForVoice(dist)), " : ""
                    say("\(prefix)\(next)", isNavigation: true)
                    currentInstruction = next
                    break
                }
            }
        }

        // Advance step when within 25m of waypoint
        if dist < 25 {
            if isLast {
                say("You have arrived at your destination.", isNavigation: true)
                isNavigating = false
            } else {
                currentStepIndex  += 1
                announcedTiers     = []
                currentInstruction = steps[currentStepIndex].text
            }
        }

        checkHazards(near: location)

        // Off-route detection — reroute after 3 consecutive off-route updates, max once per 30s
        if !isRerouting && !simulationMode, Date().timeIntervalSince(lastRerouteTime) > 30 {
            if isOffRoute(location: location, route: route) {
                offRouteCount += 1
                if offRouteCount >= 3 {
                    offRouteCount   = 0
                    lastRerouteTime = .now
                    isRerouting     = true
                    Task { await self.rerouteFromCurrentLocation() }
                }
            } else {
                offRouteCount = 0
            }
        }
    }

    private func isOffRoute(location: CLLocation, route: GHRoute) -> Bool {
        let coords = polylineCoords(route.polyline)
        // Sample every 3rd point — fast, and spacing is still <100m on typical routes
        for i in stride(from: 0, to: coords.count, by: 3) {
            let pt = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            if location.distance(from: pt) < 150 { return false }
        }
        return true
    }

    private func rerouteFromCurrentLocation() async {
        guard let destination = currentDestination,
              let loc = lastKnownLocation else { isRerouting = false; return }

        var rerouteLocations: [[String: Any]] = [
            ["lon": loc.coordinate.longitude, "lat": loc.coordinate.latitude, "type": "break"]
        ]
        for wp in waypoints {
            rerouteLocations.append(["lon": wp.longitude, "lat": wp.latitude, "type": "through"])
        }
        rerouteLocations.append(["lon": destination.location.coordinate.longitude,
                                  "lat": destination.location.coordinate.latitude, "type": "break"])

        let rerouteProfile: [String: Any] = ["use_highways": 0.5, "use_trails": 0.3,
                                              "use_tolls": 0.5, "use_hills": currentOptions.useHills]
        let body: [String: Any] = [
            "locations": rerouteLocations, "costing": "motorcycle",
            "costing_options": ["motorcycle": rerouteProfile],
            "directions_options": ["language": "en-US"],
            "units": units == .imperial ? "miles" : "kilometers", "alternates": 0
        ]

        if let newRoute = (try? await fetchValhallaRoutes(body: body))?.first {
            routes            = [newRoute]
            selectedRoute     = newRoute
            currentStepIndex  = 0
            announcedTiers    = []
            say("Rerouting.", isNavigation: true)
        }
        isRerouting = false
    }

    // MARK: - Simulation
    private func runSimulation() async {
        guard let route = selectedRoute else { return }
        let coords = polylineCoords(route.polyline)
        guard coords.count > 1 else { return }

        // Default simulation speed: 35 mph (≈15.6 m/s) — feels realistic for mixed roads
        let defaultSpeed: Double = 15.6  // m/s

        // Identify stop-sign waypoint indices from instructions
        let instructions = route.instructions
        let stopSignIndices: Set<Int> = Set(
            instructions.filter { $0.sign == -98 || $0.text.lowercased().contains("stop") }
                        .map { $0.intervalStart }
        )

        var coordIndex = 0

        while coordIndex < coords.count - 1 {
            guard !Task.isCancelled else { return }

            // Seek support — jump to a fractional position in the route
            if let frac = simulationSeekFraction {
                simulationSeekFraction = nil
                coordIndex = min(Int(frac * Double(coords.count - 1)), coords.count - 2)
                // Recalculate which instruction step we're at
                let steps = route.instructions.filter { !$0.text.isEmpty }
                var newStep = 0
                for (i, step) in steps.enumerated() {
                    if step.intervalStart <= coordIndex { newStep = i } else { break }
                }
                await MainActor.run {
                    currentStepIndex = newStep
                    if newStep < steps.count { currentInstruction = steps[newStep].text }
                    announcedTiers = []
                }
            }

            // Update progress
            await MainActor.run {
                simulationProgress = Double(coordIndex) / Double(max(coords.count - 2, 1))
            }

            // Pause support
            while isSimulationPaused {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(200))
            }

            let from = coords[coordIndex]
            let to   = coords[coordIndex + 1]
            let segBearing = bearing(from: from, to: to)
            let segDist = CLLocation(latitude: from.latitude, longitude: from.longitude)
                            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))

            // Speed: use current speed limit if available (scaled by multiplier), else default
            let baseSpeed = currentSpeedLimit.map { Double($0) * (units == .imperial ? 0.44704 : 0.27778) }
                            ?? defaultSpeed
            let speed = baseSpeed * simulationSpeedMultiplier

            // Time to traverse this segment
            let segTime = max(segDist / speed, 0.02)  // at least 20ms

            // Smoothly interpolate across segment in ~10 steps
            let steps = max(1, Int(segTime / 0.05))
            var seekRequested = false
            for step in 0 ... steps {
                guard !Task.isCancelled else { return }
                // Break out of inner loop immediately if a seek was requested
                if simulationSeekFraction != nil { seekRequested = true; break }
                while isSimulationPaused {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .milliseconds(200))
                }
                let t = Double(step) / Double(steps)
                let lat = from.latitude  + (to.latitude  - from.latitude)  * t
                let lon = from.longitude + (to.longitude - from.longitude) * t
                let simCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let simLocation = CLLocation(latitude: lat, longitude: lon)

                await MainActor.run {
                    simulatedCoordinate = simCoord
                    currentHeading = segBearing
                }
                update(with: simLocation)

                if step < steps {
                    let sleepMs = max(5.0, 50.0 / simulationSpeedMultiplier)
                    try? await Task.sleep(for: .milliseconds(sleepMs))
                }
            }
            if seekRequested { continue }  // jump back to top of outer loop to process seek

            coordIndex += 1

            // Stop at stop signs (scaled by speed multiplier, skipped during fast preview)
            if stopSignIndices.contains(coordIndex) && simulationSpeedMultiplier <= 1.0 {
                let stopDuration = 3.0 / simulationSpeedMultiplier
                var elapsed = 0.0
                while elapsed < stopDuration {
                    guard !Task.isCancelled else { return }
                    while isSimulationPaused {
                        guard !Task.isCancelled else { return }
                        try? await Task.sleep(for: .milliseconds(200))
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                    elapsed += 0.2
                }
            }
        }

        // Arrived
        await MainActor.run {
            simulatedCoordinate = coords.last
            isSimulationPaused  = false
            simulationProgress  = 1.0
        }
    }

    func toggleSimulationPause() {
        isSimulationPaused.toggle()
    }

    func skipSimulationForward() {
        simulationSeekFraction = min(simulationProgress + skipFraction(seconds: 5), 0.99)
    }

    func skipSimulationBackward() {
        simulationSeekFraction = max(simulationProgress - skipFraction(seconds: 5), 0.0)
    }

    /// Fraction of the route that corresponds to `seconds` of playback at current speed.
    private func skipFraction(seconds: Double) -> Double {
        guard let route = selectedRoute else { return 0.05 }
        let dist = route.distanceMeters  // total route metres
        guard dist > 0 else { return 0.05 }
        let speed = (currentSpeedLimit.map { Double($0) * (units == .imperial ? 0.44704 : 0.27778) } ?? 15.6)
                    * simulationSpeedMultiplier
        return (speed * seconds) / dist
    }

    func cycleSimulationSpeed() {
        let steps: [Double] = [0.5, 1.0, 2.0, 3.0]
        let idx = steps.firstIndex(of: simulationSpeedMultiplier) ?? 1
        simulationSpeedMultiplier = steps[(idx + 1) % steps.count]
    }

    var simulationSpeedLabel: String {
        switch simulationSpeedMultiplier {
        case 0.5: return "½×"
        case 2.0: return "2×"
        case 3.0: return "3×"
        default:  return "1×"
        }
    }

    // MARK: - Helpers
    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func polylineCoords(_ polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: polyline.pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords
    }

    func say(_ text: String, isNavigation: Bool = false) {
        guard !isPreviewMode else { return }
        guard !text.isEmpty else { return }
        guard voiceMode != .soundOff else { return }
        guard !(voiceMode == .alertsOnly && isNavigation) else { return }
        if isNavigation && directionFrequency == .off { return }

        // Route Hume AI voices when key is configured
        if selectedVoice.usesHume {
            Task { await sayWithHume(text, voice: selectedVoice) }
            return
        }

        synthesizer.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = resolveVoice(for: selectedVoice)
        u.rate  = 0.5
        synthesizer.speak(u)
    }

    /// Calls Hume AI Octave TTS and plays back the returned audio.
    private func sayWithHume(_ text: String, voice: VoiceOption) async {
        guard !humeAPIKey.isEmpty,
              let url = URL(string: "https://api.hume.ai/v0/tts") else { return }

        // Build utterance: ID > named voice > description
        var utterance: [String: Any] = ["text": text]
        if let voiceId = voice.humeVoiceId {
            utterance["voice"] = ["provider": "HUME_AI", "id": voiceId]
        } else if let voiceName = voice.humeVoiceName {
            utterance["voice"] = ["provider": "HUME_AI", "name": voiceName]
        } else if let description = voice.humeVoiceDescription {
            utterance["description"] = description
        } else {
            return
        }

        let body: [String: Any] = [
            "utterances": [utterance],
            "format": ["type": "mp3"]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(humeAPIKey, forHTTPHeaderField: "X-Hume-Api-Key")
        req.httpBody = bodyData

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }

        // Response is JSON with base64-encoded audio in generations[0].audio
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let generations = json["generations"] as? [[String: Any]],
              let audioB64 = generations.first?["audio"] as? String,
              let audioData = Data(base64Encoded: audioB64),
              !audioData.isEmpty else { return }

        humePlayer = try? AVAudioPlayer(data: audioData, fileTypeHint: "mp3")
        humePlayer?.prepareToPlay()
        humePlayer?.play()
    }

    /// Preview a voice without changing the selected voice.
    func previewVoice(_ option: VoiceOption) {
        let sample = "In \(formatDistForVoice(500)), turn right onto Main Street."
        if option.usesHume {
            Task { await sayWithHume(sample, voice: option) }
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: sample)
        u.voice = resolveVoice(for: option)
        u.rate  = 0.5
        synthesizer.speak(u)
    }

    /// Picks the best available on-device voice for a given option.
    private func resolveVoice(for option: VoiceOption) -> AVSpeechSynthesisVoice? {
        if let vid = option.voiceIdentifier {
            if let v = AVSpeechSynthesisVoice(identifier: vid) { return v }
            let lang = String(option.languageCode.prefix(2))
            if let v = AVSpeechSynthesisVoice.speechVoices().first(where: {
                $0.language.hasPrefix(lang) && $0.gender == .male
            }) { return v }
        }
        return AVSpeechSynthesisVoice(language: option.languageCode)
    }

    private func setupAudio() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .voicePrompt,
            options: [.duckOthers, .mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Formatting
    func formatTime(_ ms: Double) -> String {
        let m = Int(ms / 60000)
        return m < 60 ? "\(m) min" : "\(m/60)h \(m%60)m"
    }

    func formatDist(_ meters: Double) -> String {
        if units == .imperial {
            let feet = meters * 3.28084
            if feet < 1000 { return String(format: "%.0f ft", feet) }
            return String(format: "%.1f mi", meters / 1609.34)
        } else {
            return meters < 1000 ? "\(Int(meters)) m" : String(format: "%.1f km", meters / 1000)
        }
    }

    func formatDistForVoice(_ meters: Double) -> String {
        if units == .imperial {
            let feet = meters * 3.28084
            if feet < 1000 {
                let rounded = max(100, Int((feet / 100).rounded()) * 100)
                return "\(rounded) feet"
            }
            let miles = meters / 1609.34
            return String(format: "%.1f miles", miles)
        } else {
            if meters < 1000 {
                let rounded = max(100, Int((meters / 100).rounded()) * 100)
                return "\(rounded) meters"
            }
            return String(format: "%.1f kilometers", meters / 1000)
        }
    }

    // MARK: - Live hazard fetching
    private func fetchLiveHazards(for route: GHRoute) async {
        let bbox = routeBoundingBox(route.polyline)
        async let tomtom  = fetchTomTomIncidents(bbox: bbox)
        async let cameras = fetchSpeedCameras(bbox: bbox)
        let results = await tomtom + cameras
        hazards = results
        print("Loaded \(hazards.count) live hazard(s)")
    }

    // Bounding box from polyline with padding
    private func routeBoundingBox(_ polyline: MKPolyline, pad: Double = 0.02)
        -> (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) {
        let coords = polylineCoords(polyline)
        let lats   = coords.map { $0.latitude }
        let lons   = coords.map { $0.longitude }
        return (
            minLat: (lats.min() ?? 0) - pad,
            minLon: (lons.min() ?? 0) - pad,
            maxLat: (lats.max() ?? 0) + pad,
            maxLon: (lons.max() ?? 0) + pad
        )
    }

    // TomTom Traffic Incidents API — construction, accidents, road closures
    private func fetchTomTomIncidents(
        bbox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)
    ) async -> [RouteHazard] {
        let fields = "{incidents{type,geometry{coordinates},properties{iconCategory}}}"
        var comps  = URLComponents(string: "https://api.tomtom.com/traffic/services/5/incidentDetails")!
        comps.queryItems = [
            URLQueryItem(name: "bbox",               value: "\(bbox.minLon),\(bbox.minLat),\(bbox.maxLon),\(bbox.maxLat)"),
            URLQueryItem(name: "fields",             value: fields),
            URLQueryItem(name: "language",           value: "en-GB"),
            URLQueryItem(name: "categoryFilter",     value: "1,8,9"),   // 1=accident 8=road closed 9=road works
            URLQueryItem(name: "timeValidityFilter", value: "present"),
            URLQueryItem(name: "key",                value: tomTomApiKey),
        ]
        guard let url = comps.url else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json      = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let incidents = json?["incidents"] as? [[String: Any]] ?? []
            print("TomTom returned \(incidents.count) incident(s)")
            return incidents.compactMap { incident -> RouteHazard? in
                guard
                    let geometry = incident["geometry"] as? [String: Any],
                    let props    = incident["properties"] as? [String: Any],
                    let category = props["iconCategory"] as? Int
                else { return nil }

                // Geometry can be Point [lon,lat] or LineString [[lon,lat],...]
                let coord: CLLocationCoordinate2D
                if let pt = geometry["coordinates"] as? [Double], pt.count >= 2 {
                    coord = CLLocationCoordinate2D(latitude: pt[1], longitude: pt[0])
                } else if let line = geometry["coordinates"] as? [[Double]],
                          let mid  = line[safe: line.count / 2], mid.count >= 2 {
                    coord = CLLocationCoordinate2D(latitude: mid[1], longitude: mid[0])
                } else { return nil }

                let type: HazardType
                switch category {
                case 1:  type = .accident
                case 8:  type = .roadClosed
                case 9:  type = .construction
                default: return nil
                }
                return RouteHazard(type: type, coordinate: coord)
            }
        } catch {
            print("TomTom error: \(error)")
            return []
        }
    }

    // OpenStreetMap Overpass API — community-mapped speed cameras (free, no key)
    private func fetchSpeedCameras(
        bbox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)
    ) async -> [RouteHazard] {
        let query = "[out:json][timeout:15];node[highway=speed_camera](\(bbox.minLat),\(bbox.minLon),\(bbox.maxLat),\(bbox.maxLon));out;"
        var comps = URLComponents(string: "https://overpass-api.de/api/interpreter")!
        comps.queryItems = [URLQueryItem(name: "data", value: query)]
        guard let url = comps.url else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json      = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let elements  = json?["elements"] as? [[String: Any]] ?? []
            print("Overpass returned \(elements.count) speed camera(s)")
            return elements.compactMap { el -> RouteHazard? in
                guard let lat = el["lat"] as? Double,
                      let lon = el["lon"] as? Double else { return nil }
                return RouteHazard(type: .speedCamera,
                                   coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        } catch {
            print("Overpass error: \(error)")
            return []
        }
    }

    // MARK: - Hazard proximity check
    private func checkHazards(near location: CLLocation) {
        for i in hazards.indices {
            guard !hazards[i].announced else { continue }
            let hazardLoc = CLLocation(latitude: hazards[i].coordinate.latitude,
                                       longitude: hazards[i].coordinate.longitude)
            guard location.distance(from: hazardLoc) < 400 else { continue }
            hazards[i].announced = true
            let hazard = hazards[i]
            activeHazard = hazard
            if voiceMode != .soundOff {
                say(hazard.type.announcement)
            }
            let hazardId = hazard.id
            Task {
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                if self.activeHazard?.id == hazardId { self.activeHazard = nil }
            }
        }
    }

    // MARK: - Speed Limit
    private func fetchSpeedLimit(at coord: CLLocationCoordinate2D) async {
        let query = "[out:json];way(around:40,\(coord.latitude),\(coord.longitude))[highway][maxspeed];out 5;"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encoded)") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]] else { return }
        for el in elements {
            guard let tags = el["tags"] as? [String: String],
                  let raw = tags["maxspeed"] else { continue }
            if let limit = parseSpeedLimit(raw) {
                currentSpeedLimit = limit
                return
            }
        }
    }

    private func parseSpeedLimit(_ raw: String) -> Int? {
        let s = raw.lowercased().trimmingCharacters(in: .whitespaces)
        if s == "none" || s == "unlimited" || s == "variable" { return nil }
        if s.hasSuffix("mph") {
            return Int(s.dropLast(3).trimmingCharacters(in: .whitespaces))
        }
        // km/h or bare number (assume km/h → convert to mph)
        let numStr = s.replacingOccurrences(of: "km/h", with: "").trimmingCharacters(in: .whitespaces)
        if let kmh = Double(numStr) { return Int(kmh * 0.621371) }
        return nil
    }

}

// MARK: - Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - One-time location fetcher
// A small helper to get a single GPS fix for the routing start point
class OneTimeLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager  = CLLocationManager()
    private let callback: (CLLocation?) -> Void
    private var done     = false

    init(callback: @escaping (CLLocation?) -> Void) {
        self.callback = callback
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() { manager.startUpdatingLocation() }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !done, let loc = locations.last else { return }
        done = true
        manager.stopUpdatingLocation()
        callback(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !done else { return }
        done = true
        callback(nil)
    }
}
