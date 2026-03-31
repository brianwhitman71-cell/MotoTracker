import SwiftUI
import MapKit

// MARK: - Road Type

enum CommunityRoadType: String, CaseIterable, Identifiable {
    case twisty  = "Twisty"
    case scenic  = "Scenic"
    case highway = "Highway"
    case mixed   = "Mixed"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .twisty:  return "road.lanes.curved.left"
        case .scenic:  return "mountain.2.fill"
        case .highway: return "road.lanes"
        case .mixed:   return "map.fill"
        }
    }
    var color: Color {
        switch self {
        case .twisty:  return .orange
        case .scenic:  return .green
        case .highway: return .blue
        case .mixed:   return .purple
        }
    }
}

// MARK: - Difficulty

enum CommunityDifficulty: String, CaseIterable, Identifiable {
    case easy        = "Easy"
    case moderate    = "Moderate"
    case challenging = "Challenging"
    case expert      = "Expert"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .easy:        return .green
        case .moderate:    return .yellow
        case .challenging: return .orange
        case .expert:      return .red
        }
    }
}

// MARK: - Distance Range

enum CommunityDistanceRange: String, CaseIterable, Identifiable {
    case any    = "Any Distance"
    case short  = "Under 50 mi"
    case medium = "50–150 mi"
    case long   = "150–300 mi"
    case epic   = "300+ mi"
    var id: String { rawValue }
    func matches(_ miles: Double) -> Bool {
        switch self {
        case .any:    return true
        case .short:  return miles < 50
        case .medium: return miles >= 50  && miles < 150
        case .long:   return miles >= 150 && miles < 300
        case .epic:   return miles >= 300
        }
    }
}

// MARK: - Community Route Model

struct CommunityRoute: Identifiable {
    let id = UUID()
    let name: String
    let region: String
    let state: String
    let description: String
    let distanceMiles: Double
    let elevationGainFt: Double
    let roadType: CommunityRoadType
    let difficulty: CommunityDifficulty
    let rating: Double      // 1.0–5.0
    let riderCount: Int
    let tags: [String]
    let coordinates: [CLLocationCoordinate2D]

    var centerCoordinate: CLLocationCoordinate2D {
        guard !coordinates.isEmpty else { return CLLocationCoordinate2D() }
        let lat = coordinates.map(\.latitude).reduce(0,  +) / Double(coordinates.count)
        let lon = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func toGHRoute() -> GHRoute {
        let poly = MKPolyline(coordinates: coordinates, count: coordinates.count)
        return GHRoute(polyline: poly,
                       distanceMeters: distanceMiles * 1609.34,
                       timeMs: 0,
                       instructions: [])
    }
}

// MARK: - Sample Data

extension CommunityRoute {
    static let samples: [CommunityRoute] = [
        CommunityRoute(
            name: "Tail of the Dragon",
            region: "Southeast", state: "NC/TN",
            description: "318 curves in 11 miles — arguably the most famous motorcycle road in the US. Zero stop signs, no intersecting roads, pure undiluted riding.",
            distanceMiles: 11, elevationGainFt: 940,
            roadType: .twisty, difficulty: .challenging,
            rating: 4.9, riderCount: 14200,
            tags: ["iconic", "curves", "deal's gap", "smokies"],
            coordinates: dragonCoords
        ),
        CommunityRoute(
            name: "Blue Ridge Parkway — Asheville to Grandfather Mtn",
            region: "Southeast", state: "NC",
            description: "The 100-mile stretch from Asheville north to Grandfather Mountain. Sweeping mountain vistas, minimal traffic, perfectly paved.",
            distanceMiles: 98, elevationGainFt: 6400,
            roadType: .scenic, difficulty: .moderate,
            rating: 4.8, riderCount: 9800,
            tags: ["scenic", "views", "parkway", "appalachians"],
            coordinates: blueRidgeCoords
        ),
        CommunityRoute(
            name: "Pacific Coast Highway — Big Sur",
            region: "West", state: "CA",
            description: "Cliffside roads above the Pacific. Bixby Bridge, McWay Falls, and 90 miles of the most dramatic coastline in the US.",
            distanceMiles: 91, elevationGainFt: 3200,
            roadType: .scenic, difficulty: .moderate,
            rating: 4.9, riderCount: 18600,
            tags: ["coastal", "ocean", "PCH", "California"],
            coordinates: pchCoords
        ),
        CommunityRoute(
            name: "Beartooth Highway",
            region: "Northwest", state: "MT/WY",
            description: "Charles Kuralt called it the most beautiful road in America. Switchbacks to 10,947 ft, alpine tundra, surreal high-plateau vistas.",
            distanceMiles: 68, elevationGainFt: 5200,
            roadType: .twisty, difficulty: .expert,
            rating: 4.95, riderCount: 5400,
            tags: ["alpine", "elevation", "switchbacks", "Montana"],
            coordinates: beartoothCoords
        ),
        CommunityRoute(
            name: "Cherohala Skyway",
            region: "Southeast", state: "NC/TN",
            description: "The Dragon's less-crowded sibling. Sweeping ridgeline vistas at high elevation — equally rewarding curves, a fraction of the traffic.",
            distanceMiles: 43, elevationGainFt: 3800,
            roadType: .mixed, difficulty: .moderate,
            rating: 4.7, riderCount: 6100,
            tags: ["skyway", "ridgeline", "smokies", "uncrowded"],
            coordinates: cherohalaCoords
        ),
        CommunityRoute(
            name: "Angeles Crest Highway",
            region: "West", state: "CA",
            description: "LA's backyard playground. 66 miles of canyon and mountain riding rising from Pasadena to 7,000 ft through the San Gabriel Mountains.",
            distanceMiles: 66, elevationGainFt: 5800,
            roadType: .twisty, difficulty: .challenging,
            rating: 4.6, riderCount: 11300,
            tags: ["SoCal", "canyon", "mountains", "urban escape"],
            coordinates: angelesCrestCoords
        ),
        CommunityRoute(
            name: "Going-to-the-Sun Road",
            region: "Northwest", state: "MT",
            description: "Glacier National Park's crown jewel. Only open summer months — 50 miles of raw mountain grandeur past glaciers, waterfalls, and wildlife.",
            distanceMiles: 50, elevationGainFt: 3500,
            roadType: .scenic, difficulty: .moderate,
            rating: 4.85, riderCount: 4200,
            tags: ["glacier", "national park", "alpine", "seasonal"],
            coordinates: glacierCoords
        ),
        CommunityRoute(
            name: "Natchez Trace Parkway",
            region: "Southeast", state: "MS/TN",
            description: "444 miles Natchez to Nashville. 50 mph limit, no commercial traffic, lush tunnel-of-trees canopy. The definitive cruiser route.",
            distanceMiles: 444, elevationGainFt: 2100,
            roadType: .scenic, difficulty: .easy,
            rating: 4.5, riderCount: 7800,
            tags: ["cruiser", "no trucks", "historical", "canopy"],
            coordinates: natchezCoords
        ),
        CommunityRoute(
            name: "Black Hills Loop",
            region: "Midwest", state: "SD",
            description: "The definitive rally-week route — Iron Mountain Road, Needles Highway, Custer State Park. Tunnels, pigtail bridges, and herds of bison.",
            distanceMiles: 115, elevationGainFt: 4100,
            roadType: .mixed, difficulty: .moderate,
            rating: 4.75, riderCount: 12400,
            tags: ["sturgis", "Black Hills", "tunnels", "bison"],
            coordinates: blackHillsCoords
        ),
        CommunityRoute(
            name: "San Juan Skyway",
            region: "Southwest", state: "CO",
            description: "236-mile loop through the San Juan Mountains — Ouray, Silverton, Durango. 14,000 ft peaks, red canyon walls, alpine meadows.",
            distanceMiles: 236, elevationGainFt: 14800,
            roadType: .scenic, difficulty: .challenging,
            rating: 4.85, riderCount: 8600,
            tags: ["Colorado", "14ers", "loop", "scenic byway"],
            coordinates: sanJuanCoords
        ),
        CommunityRoute(
            name: "Twisted Sisters — RR335/336/337",
            region: "Southwest", state: "TX",
            description: "Three Farm-to-Market roads in the Texas Hill Country delivering relentless back-to-back switchbacks through live oak and cedar country.",
            distanceMiles: 100, elevationGainFt: 2800,
            roadType: .twisty, difficulty: .challenging,
            rating: 4.65, riderCount: 7200,
            tags: ["Texas", "Hill Country", "switchbacks", "FM roads"],
            coordinates: twistedSistersCoords
        ),
        CommunityRoute(
            name: "Extraterrestrial Highway (SR-375)",
            region: "Southwest", state: "NV",
            description: "98 miles of desolate Nevada desert past Area 51. Minimal traffic, extreme solitude — surprisingly sweeping hills on the back half.",
            distanceMiles: 98, elevationGainFt: 1200,
            roadType: .highway, difficulty: .easy,
            rating: 4.2, riderCount: 3100,
            tags: ["desert", "Area 51", "Nevada", "solitude"],
            coordinates: etHighwayCoords
        ),
    ]

    // MARK: Coordinate data

    static let dragonCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 35.4657, longitude: -83.9116),
        .init(latitude: 35.4672, longitude: -83.9198),
        .init(latitude: 35.4684, longitude: -83.9289),
        .init(latitude: 35.4691, longitude: -83.9378),
        .init(latitude: 35.4703, longitude: -83.9462),
        .init(latitude: 35.4718, longitude: -83.9548),
        .init(latitude: 35.4731, longitude: -83.9634),
        .init(latitude: 35.4756, longitude: -83.9718),
        .init(latitude: 35.4771, longitude: -83.9804),
        .init(latitude: 35.4788, longitude: -83.9891),
        .init(latitude: 35.4803, longitude: -83.9978),
        .init(latitude: 35.4812, longitude: -84.0064),
    ]

    static let blueRidgeCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 35.5781, longitude: -82.5595),
        .init(latitude: 35.7122, longitude: -82.4236),
        .init(latitude: 35.8134, longitude: -82.3187),
        .init(latitude: 35.9046, longitude: -82.2198),
        .init(latitude: 36.0215, longitude: -82.0853),
        .init(latitude: 36.1046, longitude: -81.9704),
        .init(latitude: 36.2187, longitude: -81.8532),
        .init(latitude: 36.3015, longitude: -81.7287),
    ]

    static let pchCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 36.4613, longitude: -121.9522),
        .init(latitude: 36.3738, longitude: -121.8962),
        .init(latitude: 36.2719, longitude: -121.8143),
        .init(latitude: 36.1583, longitude: -121.6731),
        .init(latitude: 35.9041, longitude: -121.4837),
        .init(latitude: 35.6894, longitude: -121.2743),
        .init(latitude: 35.5103, longitude: -121.0815),
        .init(latitude: 35.3854, longitude: -120.8591),
    ]

    static let beartoothCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 45.0239, longitude: -109.6463),
        .init(latitude: 45.0781, longitude: -109.5734),
        .init(latitude: 45.1124, longitude: -109.5028),
        .init(latitude: 45.0987, longitude: -109.4381),
        .init(latitude: 45.0634, longitude: -109.3762),
        .init(latitude: 44.9781, longitude: -109.2948),
        .init(latitude: 44.9281, longitude: -109.2236),
        .init(latitude: 44.9012, longitude: -109.1419),
    ]

    static let cherohalaCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 35.3461, longitude: -84.0237),
        .init(latitude: 35.3812, longitude: -84.1021),
        .init(latitude: 35.3918, longitude: -84.1834),
        .init(latitude: 35.3771, longitude: -84.2546),
        .init(latitude: 35.3548, longitude: -84.3234),
        .init(latitude: 35.3284, longitude: -84.3918),
        .init(latitude: 35.3047, longitude: -84.4612),
    ]

    static let angelesCrestCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 34.2016, longitude: -118.1638),
        .init(latitude: 34.2481, longitude: -118.1234),
        .init(latitude: 34.2913, longitude: -118.0721),
        .init(latitude: 34.3348, longitude: -118.0172),
        .init(latitude: 34.3671, longitude: -117.9518),
        .init(latitude: 34.3892, longitude: -117.8834),
        .init(latitude: 34.3694, longitude: -117.8072),
    ]

    static let glacierCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 48.5002, longitude: -113.9872),
        .init(latitude: 48.5288, longitude: -113.8512),
        .init(latitude: 48.5613, longitude: -113.7103),
        .init(latitude: 48.6014, longitude: -113.5872),
        .init(latitude: 48.6447, longitude: -113.4618),
        .init(latitude: 48.6978, longitude: -113.3412),
        .init(latitude: 48.7389, longitude: -113.2134),
    ]

    static let natchezCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 31.5604, longitude: -91.3871),
        .init(latitude: 32.3612, longitude: -90.8234),
        .init(latitude: 33.1234, longitude: -90.1724),
        .init(latitude: 34.1843, longitude: -89.4812),
        .init(latitude: 34.9012, longitude: -88.8134),
        .init(latitude: 35.5603, longitude: -87.8972),
        .init(latitude: 35.9781, longitude: -87.1234),
        .init(latitude: 36.1659, longitude: -86.7844),
    ]

    static let blackHillsCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 44.0805, longitude: -103.2310),
        .init(latitude: 43.9812, longitude: -103.4234),
        .init(latitude: 43.8748, longitude: -103.5618),
        .init(latitude: 43.7651, longitude: -103.5134),
        .init(latitude: 43.7013, longitude: -103.3872),
        .init(latitude: 43.7918, longitude: -103.2448),
        .init(latitude: 43.9134, longitude: -103.1234),
        .init(latitude: 44.0805, longitude: -103.2310),
    ]

    static let sanJuanCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 37.2753, longitude: -107.8801),
        .init(latitude: 37.6134, longitude: -107.6517),
        .init(latitude: 37.9712, longitude: -107.6712),
        .init(latitude: 38.0781, longitude: -107.8234),
        .init(latitude: 37.8912, longitude: -108.0134),
        .init(latitude: 37.5519, longitude: -108.0872),
        .init(latitude: 37.2753, longitude: -107.8801),
    ]

    static let twistedSistersCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 29.8134, longitude: -99.7234),
        .init(latitude: 29.8781, longitude: -99.6134),
        .init(latitude: 29.9234, longitude: -99.5012),
        .init(latitude: 29.8948, longitude: -99.3812),
        .init(latitude: 29.8534, longitude: -99.2734),
        .init(latitude: 29.7812, longitude: -99.1534),
        .init(latitude: 29.7134, longitude: -99.2834),
        .init(latitude: 29.7612, longitude: -99.4734),
        .init(latitude: 29.8134, longitude: -99.7234),
    ]

    static let etHighwayCoords: [CLLocationCoordinate2D] = [
        .init(latitude: 37.6512, longitude: -117.1234),
        .init(latitude: 37.5134, longitude: -115.8712),
        .init(latitude: 37.4012, longitude: -115.3847),
        .init(latitude: 37.3248, longitude: -115.1234),
        .init(latitude: 37.2513, longitude: -114.8134),
    ]
}

// MARK: - All regions derived from data

extension CommunityRoute {
    static var allRegions: [String] {
        let raw = samples.map(\.region)
        var seen = Set<String>()
        return raw.filter { seen.insert($0).inserted }
    }
}

// MARK: - Main View

struct CommunityLibraryView: View {
    var routeManager: RouteManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText  = ""
    @State private var selectedRegion: String? = nil
    @State private var selectedRoadType: CommunityRoadType? = nil
    @State private var selectedDifficulty: CommunityDifficulty? = nil
    @State private var selectedDistance: CommunityDistanceRange = .any
    @State private var detailRoute: CommunityRoute? = nil

    private var filtered: [CommunityRoute] {
        CommunityRoute.samples.filter { r in
            let q = searchText.lowercased()
            let matchesSearch = q.isEmpty
                || r.name.lowercased().contains(q)
                || r.state.lowercased().contains(q)
                || r.region.lowercased().contains(q)
                || r.tags.contains { $0.lowercased().contains(q) }
            let matchesRegion     = selectedRegion == nil     || r.region    == selectedRegion
            let matchesRoad       = selectedRoadType == nil   || r.roadType  == selectedRoadType
            let matchesDifficulty = selectedDifficulty == nil || r.difficulty == selectedDifficulty
            let matchesDist       = selectedDistance.matches(r.distanceMiles)
            return matchesSearch && matchesRegion && matchesRoad && matchesDifficulty && matchesDist
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider()
                routeList
            }
            .navigationTitle("Community Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    activeFilterCount > 0
                        ? Button("Clear") { clearFilters() }
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        : nil
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search routes, states, tags…")
            .sheet(item: $detailRoute) { route in
                RouteDetailSheet(route: route) {
                    loadRoute(route)
                }
            }
        }
    }

    // MARK: Filter bar

    private var activeFilterCount: Int {
        (selectedRegion != nil ? 1 : 0)
        + (selectedRoadType != nil ? 1 : 0)
        + (selectedDifficulty != nil ? 1 : 0)
        + (selectedDistance != .any ? 1 : 0)
    }

    private func clearFilters() {
        selectedRegion     = nil
        selectedRoadType   = nil
        selectedDifficulty = nil
        selectedDistance   = .any
    }

    @ViewBuilder private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Region
                Menu {
                    Button("Any Region") { selectedRegion = nil }
                    Divider()
                    ForEach(CommunityRoute.allRegions, id: \.self) { region in
                        Button(region) { selectedRegion = region }
                    }
                } label: {
                    FilterChip(
                        label: selectedRegion ?? "Region",
                        icon: "map",
                        active: selectedRegion != nil
                    )
                }

                // Road type
                Menu {
                    Button("Any Type") { selectedRoadType = nil }
                    Divider()
                    ForEach(CommunityRoadType.allCases) { t in
                        Button(t.rawValue) { selectedRoadType = t }
                    }
                } label: {
                    FilterChip(
                        label: selectedRoadType?.rawValue ?? "Road Type",
                        icon: selectedRoadType?.icon ?? "road.lanes",
                        active: selectedRoadType != nil,
                        color: selectedRoadType?.color
                    )
                }

                // Difficulty
                Menu {
                    Button("Any Difficulty") { selectedDifficulty = nil }
                    Divider()
                    ForEach(CommunityDifficulty.allCases) { d in
                        Button(d.rawValue) { selectedDifficulty = d }
                    }
                } label: {
                    FilterChip(
                        label: selectedDifficulty?.rawValue ?? "Difficulty",
                        icon: "gauge.with.needle",
                        active: selectedDifficulty != nil,
                        color: selectedDifficulty?.color
                    )
                }

                // Distance
                Menu {
                    ForEach(CommunityDistanceRange.allCases) { d in
                        Button(d.rawValue) { selectedDistance = d }
                    }
                } label: {
                    FilterChip(
                        label: selectedDistance.rawValue,
                        icon: "ruler",
                        active: selectedDistance != .any
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Route list

    @ViewBuilder private var routeList: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            List(filtered) { route in
                Button { detailRoute = route } label: {
                    RouteCard(route: route)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No routes match your filters")
                .font(.headline)
            Text("Try removing some filters or searching by state.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Clear Filters") { clearFilters() }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }

    // MARK: Load action

    private func loadRoute(_ route: CommunityRoute) {
        let ghRoute = route.toGHRoute()
        routeManager.routes       = [ghRoute]
        routeManager.selectedRoute = ghRoute
        dismiss()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let icon: String
    var active: Bool  = false
    var color: Color? = nil

    private var tint: Color { color ?? .blue }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
            if active {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(active ? tint.opacity(0.15) : Color(.secondarySystemGroupedBackground))
        .foregroundStyle(active ? tint : .secondary)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(active ? tint.opacity(0.4) : Color.clear, lineWidth: 1))
    }
}

// MARK: - Route Card

struct RouteCard: View {
    let route: CommunityRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .top, spacing: 10) {
                roadTypeIcon
                VStack(alignment: .leading, spacing: 3) {
                    Text(route.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(route.state) · \(route.region)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ratingBadge
            }
            .padding(.bottom, 8)

            // Description
            Text(route.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.bottom, 10)

            // Stats row
            HStack(spacing: 6) {
                statPill(value: distanceLabel, icon: "arrow.left.and.right", color: .blue)
                statPill(value: elevLabel, icon: "arrow.up.right", color: .teal)
                Spacer()
                difficultyPill
                roadTypePill
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var roadTypeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(route.roadType.color.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: route.roadType.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(route.roadType.color)
        }
    }

    private var ratingBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", route.rating))
                .font(.caption.weight(.semibold))
            Text("(\(riderCountLabel))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var distanceLabel: String {
        route.distanceMiles >= 100
            ? String(format: "%.0f mi", route.distanceMiles)
            : String(format: "%.0f mi", route.distanceMiles)
    }

    private var elevLabel: String {
        route.elevationGainFt >= 1000
            ? String(format: "%.1fk ft gain", route.elevationGainFt / 1000)
            : String(format: "%.0f ft gain", route.elevationGainFt)
    }

    private var riderCountLabel: String {
        route.riderCount >= 1000
            ? String(format: "%.1fk", Double(route.riderCount) / 1000)
            : "\(route.riderCount)"
    }

    private func statPill(value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text(value).font(.caption2.weight(.medium)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var difficultyPill: some View {
        Text(route.difficulty.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(route.difficulty.color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(route.difficulty.color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var roadTypePill: some View {
        Text(route.roadType.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(route.roadType.color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(route.roadType.color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Route Detail Sheet

struct RouteDetailSheet: View {
    let route: CommunityRoute
    let onLoad: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mapPreview
                    detailBody
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .safeAreaInset(edge: .bottom) {
                loadButton
            }
        }
    }

    // MARK: Map preview

    private var mapPreview: some View {
        RouteMapPreview(coordinates: route.coordinates)
            .frame(height: 260)
    }

    // MARK: Detail body

    private var detailBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title block
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    roadTypeBadge
                    difficultyBadge
                    Spacer()
                    ratingRow
                }
                Text(route.name)
                    .font(.title2.weight(.bold))
                Text("\(route.state) · \(route.region)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Stats grid
            statsGrid

            // Description
            VStack(alignment: .leading, spacing: 6) {
                Text("About This Route")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(route.description)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Tags
            if !route.tags.isEmpty {
                tagsRow
            }
        }
        .padding(20)
    }

    private var roadTypeBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: route.roadType.icon).font(.system(size: 11, weight: .bold))
            Text(route.roadType.rawValue).font(.caption.weight(.semibold))
        }
        .foregroundStyle(route.roadType.color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(route.roadType.color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var difficultyBadge: some View {
        Text(route.difficulty.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(route.difficulty.color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(route.difficulty.color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var ratingRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                Image(systemName: Double(i) < route.rating ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
            }
            Text(String(format: "%.1f", route.rating))
                .font(.caption.weight(.semibold))
            Text("· \(riderCountStr) riders")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var riderCountStr: String {
        route.riderCount >= 1000
            ? String(format: "%.1fk", Double(route.riderCount) / 1000)
            : "\(route.riderCount)"
    }

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statCell(value: distanceStr, label: "Distance", icon: "arrow.left.and.right", color: .blue)
            Divider().frame(height: 44)
            statCell(value: elevStr, label: "Elev Gain", icon: "arrow.up.right", color: .teal)
            Divider().frame(height: 44)
            statCell(value: durationStr, label: "Est. Time", icon: "clock", color: .orange)
        }
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            Text(value).font(.subheadline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var distanceStr: String {
        String(format: "%.0f mi", route.distanceMiles)
    }

    private var elevStr: String {
        route.elevationGainFt >= 1000
            ? String(format: "%.1fk ft", route.elevationGainFt / 1000)
            : String(format: "%.0f ft", route.elevationGainFt)
    }

    private var durationStr: String {
        let hours = route.distanceMiles / 40   // ~40 mph avg on scenic/twisty roads
        if hours < 1 { return String(format: "%.0f min", hours * 60) }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    @ViewBuilder private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            FlowLayout(spacing: 6) {
                ForEach(route.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var loadButton: some View {
        Button {
            onLoad()
            dismiss()
        } label: {
            Label("Load Route on Map", systemImage: "map.fill")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Map Preview (MKMapSnapshot)

struct RouteMapPreview: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isUserInteractionEnabled = false
        map.isScrollEnabled   = false
        map.isZoomEnabled     = false
        map.mapType           = .standard
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        guard coordinates.count > 1 else { return }
        let poly = MKPolyline(coordinates: coordinates, count: coordinates.count)
        map.addOverlay(poly)
        map.setVisibleMapRect(
            poly.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32),
            animated: false
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: poly)
            r.strokeColor = UIColor.systemBlue
            r.lineWidth   = 3
            r.lineCap     = .round
            return r
        }
    }
}

// MARK: - Simple flow layout for tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
