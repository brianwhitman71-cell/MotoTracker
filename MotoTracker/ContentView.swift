import SwiftUI
import MapKit

// MARK: - Main View
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeManager = RouteManager()

    @State private var rides: [Ride] = []
    @State private var showingSaveAlert = false
    @State private var newRide: Ride?
    @State private var selectedRide: Ride?
    @State private var showRidesList = false

    var body: some View {
        ZStack(alignment: .top) {

            // Fullscreen map
            MapView(
                trackingCoordinates: locationManager.currentCoordinates,
                routes: routeManager.routes,
                selectedRoute: routeManager.selectedRoute
            )
            .ignoresSafeArea()

            // Overlay
            VStack(spacing: 8) {

                // Top: navigation banner OR search bar
                if routeManager.isNavigating {
                    NavBanner(routeManager: routeManager)
                } else {
                    SearchBarView(routeManager: routeManager)
                    if !routeManager.searchResults.isEmpty {
                        SearchResultsView(routeManager: routeManager)
                    }
                }

                Spacer()

                // Bottom panel
                VStack(spacing: 10) {
                    if routeManager.isCalculatingRoutes {
                        ProgressView("Calculating routes...")
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !routeManager.routes.isEmpty && !routeManager.isNavigating {
                        RoutePicker(routeManager: routeManager, locationManager: locationManager)
                    }

                    BottomControls(
                        locationManager: locationManager,
                        routeManager: routeManager,
                        rides: rides,
                        showRidesList: $showRidesList,
                        onStop: {
                            newRide = locationManager.stopTracking()
                            showingSaveAlert = true
                        }
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        // Pass every GPS update to the route manager for navigation
        .onChange(of: locationManager.locationUpdateCount) {
            if let loc = locationManager.currentLocation {
                routeManager.update(with: loc)
            }
        }
        .alert("Save Ride?", isPresented: $showingSaveAlert, presenting: newRide) { ride in
            Button("Save") { rides.append(ride) }
            Button("Discard", role: .destructive) { }
        } message: { ride in
            Text(String(format: "You rode %.2f miles.", ride.distance))
        }
        .sheet(item: $selectedRide) { ride in
            RideDetailView(ride: ride)
        }
        .sheet(isPresented: $showRidesList) {
            RidesListView(rides: $rides, selectedRide: $selectedRide)
        }
    }
}

// MARK: - Search Bar
struct SearchBarView: View {
    @ObservedObject var routeManager: RouteManager

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search for a destination...", text: $routeManager.searchQuery)
                .onChange(of: routeManager.searchQuery) { routeManager.search() }
                .submitLabel(.search)
                .onSubmit { routeManager.search() }
            if !routeManager.searchQuery.isEmpty {
                Button {
                    routeManager.cancelRoutes()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Search Results
struct SearchResultsView: View {
    @ObservedObject var routeManager: RouteManager

    var body: some View {
        VStack(spacing: 0) {
            ForEach(routeManager.searchResults.indices, id: \.self) { i in
                let item = routeManager.searchResults[i]
                Button {
                    Task { await routeManager.getRoutes(to: item) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Unknown")
                                .font(.subheadline).bold()
                                .foregroundStyle(.primary)
                            Text(item.placemark.title ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                if i < routeManager.searchResults.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Navigation Banner
struct NavBanner: View {
    @ObservedObject var routeManager: RouteManager

    var arrowIcon: String {
        let t = routeManager.currentInstruction.lowercased()
        if t.contains("left") { return "arrow.turn.up.left" }
        if t.contains("right") { return "arrow.turn.up.right" }
        if t.contains("arrive") || t.contains("destination") { return "mappin.circle.fill" }
        return "arrow.up"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.blue).frame(width: 50, height: 50)
                Image(systemName: arrowIcon).font(.title2.bold()).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(routeManager.currentInstruction.isEmpty ? "Follow the route" : routeManager.currentInstruction)
                    .font(.headline)
                    .lineLimit(2)
                if routeManager.distanceToNextTurn > 0 {
                    Text(routeManager.formatDist(routeManager.distanceToNextTurn))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                routeManager.stopNavigation()
            } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.gray)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Route Picker
struct RoutePicker: View {
    @ObservedObject var routeManager: RouteManager
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose Route").font(.headline)
                Spacer()
                Button("Cancel") { routeManager.cancelRoutes() }.foregroundStyle(.red)
            }

            ForEach(routeManager.routes.indices, id: \.self) { i in
                let route = routeManager.routes[i]
                let isSelected = routeManager.selectedRoute === route
                Button { routeManager.selectedRoute = route } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(i == 0 ? "Fastest" : "Alternate \(i)")
                                .font(.subheadline).bold()
                                .foregroundStyle(isSelected ? .white : .primary)
                            Text("\(routeManager.formatTime(route.expectedTravelTime))  ·  \(routeManager.formatDist(route.distance))")
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                        }
                    }
                    .padding(10)
                    .background(isSelected ? Color.blue : Color(.secondarySystemBackground).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Button("Start Navigation") {
                locationManager.startRide()
                routeManager.startNavigation()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Bottom Controls
struct BottomControls: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var routeManager: RouteManager
    var rides: [Ride]
    @Binding var showRidesList: Bool
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if locationManager.isTracking {
                HStack {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text(String(format: "%.2f miles", locationManager.distanceMiles)).font(.headline)
                    Spacer()
                    Button("Stop Ride", role: .destructive) {
                        if routeManager.isNavigating { routeManager.stopNavigation() }
                        onStop()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if !routeManager.isNavigating && routeManager.routes.isEmpty {
                Button("Start Ride") { locationManager.startRide() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                if !rides.isEmpty {
                    Button("My Rides (\(rides.count))") { showRidesList = true }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Rides List
struct RidesListView: View {
    @Binding var rides: [Ride]
    @Binding var selectedRide: Ride?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(rides) { ride in
                    Button {
                        selectedRide = ride
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ride.name).font(.headline).foregroundStyle(.primary)
                            HStack {
                                Text(ride.date.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                Text(String(format: "%.2f miles", ride.distance))
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { rides.remove(atOffsets: $0) }
            }
            .navigationTitle("My Rides")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
    }
}

// MARK: - Map View
struct MapView: UIViewRepresentable {
    var trackingCoordinates: [CLLocationCoordinate2D]
    var routes: [MKRoute]
    var selectedRoute: MKRoute?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .follow
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.routes = routes
        context.coordinator.selectedRoute = selectedRoute
        map.removeOverlays(map.overlays)

        // Alternate routes (gray, drawn first/underneath)
        for route in routes where route !== selectedRoute {
            map.addOverlay(route.polyline, level: .aboveRoads)
        }

        // Selected route (blue)
        if let selected = selectedRoute {
            map.addOverlay(selected.polyline, level: .aboveRoads)
            if !routes.isEmpty {
                map.setVisibleMapRect(
                    selected.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 300, right: 40),
                    animated: true
                )
            }
        }

        // Tracked path (orange, drawn on top)
        if trackingCoordinates.count > 1 {
            let poly = MKPolyline(coordinates: trackingCoordinates, count: trackingCoordinates.count)
            map.addOverlay(poly, level: .aboveRoads)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        var routes: [MKRoute] = []
        var selectedRoute: MKRoute?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            if let selected = selectedRoute, polyline === selected.polyline {
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 6
            } else if routes.contains(where: { $0.polyline === polyline }) {
                renderer.strokeColor = .systemGray
                renderer.lineWidth = 4
                renderer.alpha = 0.6
            } else {
                renderer.strokeColor = .systemOrange
                renderer.lineWidth = 5
            }
            return renderer
        }
    }
}

// MARK: - Ride Detail View
struct RideDetailView: View {
    let ride: Ride
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                MapView(trackingCoordinates: ride.coordinates, routes: [], selectedRoute: nil)
                    .ignoresSafeArea(edges: .top)
                    .frame(maxHeight: .infinity)
                VStack(spacing: 12) {
                    Text(ride.name).font(.title2).bold()
                    HStack(spacing: 30) {
                        StatView(label: "Distance", value: String(format: "%.2f mi", ride.distance))
                        StatView(label: "Date", value: ride.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Stat View
struct StatView: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).bold()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
