import SwiftUI
import MapKit
import SceneKit
import UniformTypeIdentifiers

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MKMapItem needs Identifiable to be used with sheet(item:)
extension MKMapItem: @retroactive Identifiable {
    public var id: String {
        let coord = location.coordinate
        let addrStr = name ?? name ?? ""
        return "\(coord.latitude),\(coord.longitude):\(addrStr)"
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeManager = RouteManager()
    @ObservedObject private var offlineManager = OfflineMapManager.shared

    @State private var rides: [Ride] = []
    @State private var showingSaveAlert = false
    @State private var newRide: Ride?
    @State private var selectedRide: Ride?
    @State private var showRidesList = false
    @State private var pendingDestination: MKMapItem?
    @State private var showingRouteOptions = false
    @State private var showSoundControls = false
    @State private var showingRoundTrip = false
    @State private var showingGPXImport = false
    @State private var shapingMode = false
    @State private var showingViaPointSearch = false
    @State private var pendingViaPoint: MKMapItem?
    @State private var pickerCollapsed = false
    @State private var showingTripPlanner = false
    @State private var showingCommunityLibrary = false
    @State private var showingSavedRoutes = false
    @State private var showingSaveRouteAlert = false
    @State private var saveRouteName = ""
    @State private var showingPOIFilter        = false
    @State private var selectedPOI: MotoPOI?
    @StateObject private var poiManager = MotoPOIManager.shared
    @State private var showCurvinessOverlay = false
    @State private var showingSettings = false
    @State private var mapViewRef: MKMapView?
    @State private var selectedMapLayer: MapLayerStyle = .standard
    @State private var headingUpMode: Bool = false
    @State private var navAltitude: Double = 1200
    @State private var navTargetAltitude: Double = 1200

    private func startRoutePreview() {
        guard routeManager.selectedRoute != nil else { return }
        routeManager.isPreviewMode = true
        routeManager.simulationMode = true
        routeManager.simulationSpeedMultiplier = 1.0
        routeManager.startNavigation()
    }

    private func stopRoutePreview() {
        routeManager.stopNavigation()
        // After the navigation state clears, reset the map camera to show the full route
        DispatchQueue.main.async {
            guard let map = mapViewRef else { return }
            map.userTrackingMode = .none
            // Determine rect to fit
            let rect: MKMapRect?
            if let route = routeManager.selectedRoute {
                rect = route.polyline.boundingMapRect
            } else if !routeManager.routes.isEmpty {
                rect = routeManager.routes.dropFirst().reduce(routeManager.routes[0].polyline.boundingMapRect) {
                    $0.union($1.polyline.boundingMapRect)
                }
            } else {
                rect = nil
            }
            if let rect {
                map.setVisibleMapRect(
                    rect,
                    edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 300, right: 40),
                    animated: true
                )
            }
        }
    }

    // MARK: - Extracted sub-views (keeps body small for the type-checker)

    @ViewBuilder private var shapingBanner: some View {
        if shapingMode && routeManager.selectedRoute != nil {
            VStack(spacing: 0) {
                // Top control bar
                HStack(spacing: 10) {
                    Image(systemName: showingViaPointSearch ? "magnifyingglass" : "mappin.and.ellipse")
                        .foregroundStyle(.white)
                    Text(showingViaPointSearch ? "Search for a via-point" : "Tap map to add a via-point")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    if !showingViaPointSearch {
                        Button {
                            // Clear searchQuery so the inline search starts fresh (empty field).
                            // Safe to do here because showingViaPointSearch = true removes the
                            // topOverlay SearchBarView from the hierarchy before SwiftUI fires
                            // any onChange, so handleQueryChange cannot trigger showRecents().
                            routeManager.searchQuery = ""
                            routeManager.searchResults = []
                            routeManager.showingRecents = false
                            showingViaPointSearch = true
                        } label: {
                            Label("Search", systemImage: "magnifyingglass")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Color.white.opacity(0.22))
                                .clipShape(Capsule())
                        }
                    } else {
                        Button("Cancel") {
                            showingViaPointSearch = false
                            routeManager.searchQuery = ""
                            routeManager.searchResults = []
                        }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    }
                    Button("Done") {
                        shapingMode = false
                        showingViaPointSearch = false
                        routeManager.searchQuery = ""
                        routeManager.searchResults = []
                    }
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.purple.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal).padding(.top, 8)

                // Inline search UI — shown when user taps "Search"
                if showingViaPointSearch {
                    VStack(spacing: 6) {
                        SearchBarView(routeManager: routeManager, autoFocus: true, clearQueryOnly: true)
                        if !routeManager.searchResults.isEmpty {
                            SearchResultsView(routeManager: routeManager,
                                             pendingDestination: $pendingViaPoint)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                Spacer()
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: shapingMode)
            .zIndex(10)
        }
    }


    @ViewBuilder private var topOverlay: some View {
        if routeManager.isNavigating {
            NavBanner(routeManager: routeManager)
            if let hazard = routeManager.activeHazard {
                HazardBanner(hazard: hazard)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: routeManager.activeHazard?.id)
            }
        } else if !showingViaPointSearch {
            HStack(spacing: 8) {
                Button { showingSettings = true } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                SearchBarView(routeManager: routeManager)
            }
            .padding(.horizontal)
            if !routeManager.searchResults.isEmpty && routeManager.routes.isEmpty {
                SearchResultsView(routeManager: routeManager, pendingDestination: $pendingDestination)
            }
            if routeManager.routes.isEmpty && routeManager.searchResults.isEmpty {
                searchShortcuts
            }
        }
    }

    @ViewBuilder private var searchShortcuts: some View {
        HStack(spacing: 8) {
            Button { showingRoundTrip = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Round Trip")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button { showingTripPlanner = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map")
                    Text("Plan Trip")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
        HStack(spacing: 8) {
            Button { showingGPXImport = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc").font(.subheadline.weight(.semibold))
                    Text("Import GPX").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button { showingCommunityLibrary = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill").font(.subheadline.weight(.semibold))
                    Text("Community").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
        HStack(spacing: 8) {
            Button { showingSavedRoutes = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill").font(.subheadline.weight(.semibold))
                    Text("Saved Routes").font(.subheadline.weight(.semibold))
                    if !routeManager.savedRoutes.isEmpty {
                        Text("\(routeManager.savedRoutes.count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder private var bottomPanel: some View {
        VStack(spacing: 10) {
            if routeManager.isCalculatingRoutes {
                ProgressView("Calculating routes...")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if let error = routeManager.routeError {
                Text(error)
                    .font(.subheadline).foregroundStyle(.white)
                    .padding(10)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if !routeManager.routes.isEmpty && !routeManager.isNavigating && !shapingMode {
                routePickerPanel
                if routeManager.selectedRoute != nil {
                    Button {
                        saveRouteName = ""
                        showingSaveRouteAlert = true
                    } label: {
                        Label("Save Route", systemImage: "bookmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
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

    @ViewBuilder private var routePickerPanel: some View {
        RoutePickerPanel(
            routeManager: routeManager,
            locationManager: locationManager,
            shapingMode: $shapingMode,
            pickerCollapsed: $pickerCollapsed,
            pendingDestination: $pendingDestination,
            onPreview: startRoutePreview
        )
    }

    @ViewBuilder private var mapLeftControls: some View {
        MapControlsView(
            mapViewRef: mapViewRef,
            headingUpMode: $headingUpMode,
            simulatedCoordinate: routeManager.simulatedCoordinate,
            currentLocation: locationManager.currentLocation,
            selectedRoute: routeManager.selectedRoute
        )
    }

    @ViewBuilder private var navRightControls: some View {
        NavControlsView(routeManager: routeManager, showSoundControls: $showSoundControls)
    }

    @ViewBuilder private var speedLimitBadge: some View {
        SpeedLimitBadge(limit: routeManager.currentSpeedLimit)
    }

    @ViewBuilder private var curvinessToggle: some View {
        CurvinessToggleView(
            showOverlay: $showCurvinessOverlay,
            isFetching: routeManager.isFetchingCurviness,
            onToggle: { routeManager.clearCurvinessOverlay() }
        )
    }

    var body: some View {
        mapStackWithSheets2
            .fileImporter(isPresented: $showingGPXImport, allowedContentTypes: [.xml], allowsMultipleSelection: false) { result in
                handleGPXImport(result)
            }
            .onReceive(NotificationCenter.default.publisher(for: .motoDeepLink)) { notif in
                guard let url = notif.object as? URL else { return }
                Task { await routeManager.handleDeepLink(url) }
            }
    }

    private func saveAlertMessage(for ride: Ride) -> String {
        routeManager.units == .imperial
            ? String(format: "You rode %.2f miles.", ride.distance)
            : String(format: "You rode %.2f km.", ride.distance * 1.60934)
    }

    private var mapStackWithSheets2: some View {
        mapStackWithSheets1
            .alert("Save Ride?", isPresented: $showingSaveAlert, presenting: newRide) { ride in
                Button("Save") { rides.append(ride) }
                Button("Discard", role: .destructive) { }
            } message: { ride in
                Text(saveAlertMessage(for: ride))
            }
            .sheet(isPresented: $showingRoundTrip) { RoundTripView(routeManager: routeManager) }
            .sheet(isPresented: $showingTripPlanner) { TripPlannerView(routeManager: routeManager) }
            .sheet(isPresented: $showingSettings) { SettingsView(routeManager: routeManager, mapViewRef: mapViewRef, currentLocation: locationManager.currentLocation) }
            .sheet(isPresented: $showingCommunityLibrary) { CommunityLibraryView(routeManager: routeManager) }
            .sheet(isPresented: $showingSavedRoutes) { SavedRoutesView(routeManager: routeManager) }
            .alert("Save Route", isPresented: $showingSaveRouteAlert) {
                TextField("Route name", text: $saveRouteName)
                Button("Save") { routeManager.saveCurrentRoute(name: saveRouteName) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Give this route a name to find it later.")
            }
            .sheet(isPresented: $showingPOIFilter) { MotoPOIFilterView(manager: poiManager) }
            .sheet(item: $selectedPOI) { poi in
                MotoPOIDetailView(poi: poi) { navPOI in
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: navPOI.coordinate))
                    item.name = navPOI.name
                    Task { await routeManager.getRoutes(to: item, options: routeManager.currentOptions) }
                }
            }
    }

    private var mapStackWithSheets1: some View {
        mapStackWithObservers
            .sheet(item: $selectedRide) { ride in RideDetailView(ride: ride) }
            .sheet(isPresented: $showRidesList) { RidesListView(rides: $rides, selectedRide: $selectedRide) }
            .sheet(item: $pendingDestination) { dest in
                RouteOptionsView(destination: dest) { options in
                    Task { await routeManager.getRoutes(to: dest, options: options) }
                }
            }
    }

    private var mapStackWithObserversA: some View {
        mapStackWithBaseObservers
            .onChange(of: pendingViaPoint) { _, item in
                guard let item else { return }
                let coord = item.placemark.coordinate
                pendingViaPoint = nil
                showingViaPointSearch = false
                // Don't mutate routeManager.searchQuery here – touching it while the
                // SearchBarView may still be in the hierarchy triggers showRecents() and
                // can interfere with the addWaypoint Task.
                routeManager.searchResults = []
                routeManager.showingRecents = false
                Task { await routeManager.addWaypoint(coord) }
            }
            .onChange(of: shapingMode) { _, active in
                if !active {
                    showingViaPointSearch = false
                    routeManager.searchResults = []
                    routeManager.showingRecents = false
                }
            }
            .onChange(of: routeManager.simulatedCoordinate) { _, coord in handleSimCoordChange(coord) }
    }

    private var mapStackWithObservers: some View {
        mapStackWithObserversA
            .onChange(of: routeManager.distanceToNextTurn) { _, dist in
                guard routeManager.isNavigating, dist > 0 else { return }
                navTargetAltitude = dist < 250 ? 380 : 1200
            }
            .onChange(of: routeManager.currentStepIndex) { navTargetAltitude = 1200 }
            .onChange(of: routeManager.isNavigating) { _, navigating in
                if !navigating {
                    showSoundControls = false
                    navAltitude = 1200
                    navTargetAltitude = 1200
                    // If simulation ended naturally during preview, clean up preview state
                    if routeManager.isPreviewMode {
                        routeManager.isPreviewMode = false
                        routeManager.simulationMode = false
                        routeManager.simulationSpeedMultiplier = 1.0
                    }
                }
            }
    }

    private var mapStackWithBaseObservers: some View {
        mapStack
            .onAppear { locationManager.startDisplayingLocation() }
            .onChange(of: locationManager.locationUpdateCount) { handleGPSUpdate() }
            .onChange(of: showCurvinessOverlay) {
                if !showCurvinessOverlay { routeManager.clearCurvinessOverlay() }
            }
            .onChange(of: routeManager.routes.isEmpty) {
                // Only reset when routes are truly gone (user cancelled / no results),
                // NOT during a recalculation where isCalculatingRoutes is still true.
                // Without this guard, deleting a via-point triggers getRoutes which
                // sets routes=[] briefly while loading, incorrectly resetting shapingMode.
                if routeManager.routes.isEmpty && !routeManager.isCalculatingRoutes {
                    pickerCollapsed = false
                    shapingMode = false
                    stopRoutePreview()
                }
            }
            // When a recalculation finishes while shaping mode is active (e.g. after
            // a via-point is deleted and routes reload), handle the two outcomes:
            //  • Routes loaded  → auto-select first so the shaping banner reappears.
            //  • No routes back → exit shaping mode (nothing to shape).
            .onChange(of: routeManager.isCalculatingRoutes) { _, calculating in
                guard !calculating, shapingMode else { return }
                if !routeManager.routes.isEmpty && routeManager.selectedRoute == nil {
                    routeManager.selectedRoute = routeManager.routes.first
                } else if routeManager.routes.isEmpty {
                    pickerCollapsed = false
                    shapingMode = false
                }
            }
    }

    private var mapView: some View {
        MapView(
            trackingCoordinates: locationManager.currentCoordinates,
            routes: routeManager.routes,
            selectedRoute: routeManager.selectedRoute,
            waypoints: routeManager.waypoints,
            shapingMode: shapingMode,
            liveTrackCoords: routeManager.liveTrackCoords,
            userCoordinate: routeManager.simulatedCoordinate ?? locationManager.currentLocation?.coordinate,
            previewActive: routeManager.isPreviewMode,
            curvinessOverlays: showCurvinessOverlay ? routeManager.curvinessOverlays : [],
            showOfflineTiles: true,
            motoPOIs: poiManager.showPOIs ? poiManager.visiblePOIs : [],
            onRouteSelected: { route in
                routeManager.selectedRoute = route
                shapingMode = false
                withAnimation(.easeInOut(duration: 0.25)) { pickerCollapsed = true }
            },
            onWaypointAdded: { coord in Task { await routeManager.addWaypoint(coord) } },
            onWaypointRemoved: { idx in Task { await routeManager.removeWaypoint(at: idx) } },
            onRegionChange: { region in
                if showCurvinessOverlay { routeManager.fetchCurvinessOverlay(for: region) }
                poiManager.updateRegion(region)
            },
            onMapCreated: { mapViewRef = $0 },
            onPOISelected: { poi in selectedPOI = poi },
            isShapingMode: { shapingMode },
            mapLayer: selectedMapLayer
        )
        .ignoresSafeArea()
    }

    private var mapStack: some View {
        ZStack(alignment: .top) {
            mapView
            shapingBanner
            if routeManager.isPreviewMode {
                PreviewControlsOverlay(routeManager: routeManager, onStop: stopRoutePreview)
                    .transition(.opacity)
                    .zIndex(12)
            }
            if showSoundControls {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring()) { showSoundControls = false } }
                VStack {
                    Spacer()
                    SoundControlSheet(routeManager: routeManager) {
                        withAnimation(.spring()) { showSoundControls = false }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.opacity)
            }
            speedLimitBadge
            curvinessToggle
            mapLeftControls
            navRightControls
            MapLayerButton(selectedLayer: $selectedMapLayer, isNavigating: routeManager.isNavigating)
            if !routeManager.isNavigating {
                MotoPOIMapButton(manager: poiManager) { showingPOIFilter = true }
            }
            VStack(spacing: 8) {
                topOverlay
                Spacer()
                bottomPanel
            }
        }
    }

    private func handleSimCoordChange(_ coord: CLLocationCoordinate2D?) {
        guard routeManager.isNavigating, let coord, let map = mapViewRef else { return }
        navAltitude += (navTargetAltitude - navAltitude) * 0.12
        var center = coord
        if navAltitude < 900, let turn = routeManager.nextTurnCoordinate {
            let t = 0.30
            center = CLLocationCoordinate2D(
                latitude:  coord.latitude  * (1 - t) + turn.latitude  * t,
                longitude: coord.longitude * (1 - t) + turn.longitude * t
            )
        }
        map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: navAltitude,
                                  pitch: map.camera.pitch, heading: map.camera.heading), animated: false)
        // During preview, updateUIView returns early so we must move the annotation here
        if let moto = map.annotations.first(where: { $0 is MotorcycleAnnotation }) as? MotorcycleAnnotation {
            moto.coordinate = coord
        }
        rotateMotorcycleAnnotation(on: map, heading: routeManager.currentHeading)
    }

    private func handleGPSUpdate() {
        if let loc = locationManager.currentLocation { routeManager.update(with: loc) }
        guard routeManager.isNavigating, !routeManager.simulationMode,
              let coord = locationManager.currentLocation?.coordinate,
              let map = mapViewRef else { return }
        navAltitude += (navTargetAltitude - navAltitude) * 0.12
        var center = coord
        if navAltitude < 900, let turn = routeManager.nextTurnCoordinate {
            let t = 0.30
            center = CLLocationCoordinate2D(
                latitude:  coord.latitude  * (1 - t) + turn.latitude  * t,
                longitude: coord.longitude * (1 - t) + turn.longitude * t
            )
        }
        map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: navAltitude,
                                  pitch: map.camera.pitch, heading: map.camera.heading), animated: false)
        rotateMotorcycleAnnotation(on: map, heading: routeManager.currentHeading)
    }

    private func rotateMotorcycleAnnotation(on map: MKMapView, heading: CLLocationDirection) {
        guard let moto = map.annotations.first(where: { $0 is MotorcycleAnnotation }) as? MotorcycleAnnotation,
              let view = map.view(for: moto) as? MotorcycleAnnotationView else { return }
        moto.heading = heading
        view.updateHeading(heading, mapHeading: map.camera.heading)
    }

    private func handleGPXImport(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first,
              url.startAccessingSecurityScopedResource(),
              let data = try? Data(contentsOf: url) else { return }
        url.stopAccessingSecurityScopedResource()
        let gpxList = GPXParser.parse(data)
        for gpx in gpxList {
            if gpx.isTrack {
                var dist = 0.0
                for i in 1..<gpx.coordinates.count {
                    let a = CLLocation(latitude: gpx.coordinates[i-1].latitude, longitude: gpx.coordinates[i-1].longitude)
                    let b = CLLocation(latitude: gpx.coordinates[i].latitude, longitude: gpx.coordinates[i].longitude)
                    dist += a.distance(from: b) / 1609.34
                }
                rides.append(Ride(name: gpx.name ?? "Imported Ride", date: .now, coordinates: gpx.coordinates, distance: dist))
            } else {
                let poly = MKPolyline(coordinates: gpx.coordinates, count: gpx.coordinates.count)
                let route = GHRoute(polyline: poly, distanceMeters: 0, timeMs: 0, instructions: [])
                routeManager.routes = [route]
                routeManager.selectedRoute = route
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBarView: View {
    @ObservedObject var routeManager: RouteManager
    /// When true, the field auto-focuses on appear (used for the via-point inline search).
    var autoFocus: Bool = false
    /// When true the X button only clears the query instead of calling cancelRoutes()
    /// (used in via-point search context where we don't want to wipe the destination).
    var clearQueryOnly: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            if routeManager.isSearching {
                ProgressView().controlSize(.small).padding(.leading, 2)
            } else {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            }
            searchField
            if !routeManager.searchQuery.isEmpty {
                Button {
                    if clearQueryOnly {
                        routeManager.searchQuery = ""
                        routeManager.searchResults = []
                    } else {
                        routeManager.cancelRoutes()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { if autoFocus { isFocused = true } }
    }

    private var searchField: some View {
        TextField("Search destination, address, or place…", text: $routeManager.searchQuery)
            .focused($isFocused)
            .submitLabel(.search)
            .onSubmit { routeManager.search() }
            .onChange(of: routeManager.searchQuery) { handleQueryChange() }
            .onChange(of: isFocused) { handleFocusChange() }
    }

    private func handleQueryChange() {
        if routeManager.searchQuery.isEmpty && isFocused {
            routeManager.showRecents()
        } else {
            routeManager.search()
        }
    }

    private func handleFocusChange() {
        if isFocused && routeManager.searchQuery.isEmpty {
            routeManager.showRecents()
        }
    }
}

// MARK: - Search Results
struct SearchResultsView: View {
    @ObservedObject var routeManager: RouteManager
    @Binding var pendingDestination: MKMapItem?

    var body: some View {
        VStack(spacing: 0) {
            if routeManager.showingRecents {
                HStack {
                    Image(systemName: "clock").font(.caption).foregroundStyle(.secondary)
                    Text("Recents").font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
            }

            ForEach(Array(routeManager.searchResults.enumerated()), id: \.offset) { i, item in
                Button {
                    routeManager.searchResults = []
                    pendingDestination = item
                } label: {
                    HStack(spacing: 12) {
                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(routeManager.showingRecents
                                      ? Color.secondary.opacity(0.15)
                                      : iconColor(for: item).opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: routeManager.showingRecents ? "clock" : icon(for: item))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(routeManager.showingRecents ? .secondary : iconColor(for: item))
                        }

                        // Name + subtitle
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Unknown")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            let sub = subtitle(for: item, isRecent: routeManager.showingRecents)
                            if !sub.isEmpty {
                                Text(sub)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // Distance
                        if let dist = distance(to: item) {
                            Text(dist)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if i < routeManager.searchResults.count - 1 {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: Result helpers

    private func icon(for item: MKMapItem) -> String {
        switch item.pointOfInterestCategory {
        case .gasStation:                   return "fuelpump.fill"
        case .evCharger:                    return "bolt.car.fill"
        case .parking:                      return "parkingsign.circle.fill"
        case .restaurant:                   return "fork.knife"
        case .cafe:                         return "cup.and.saucer.fill"
        case .bakery:                       return "birthday.cake.fill"
        case .brewery, .winery, .distillery: return "wineglass.fill"
        case .nightlife:                    return "music.note"
        case .foodMarket:                   return "cart.fill"
        case .hotel:                        return "bed.double.fill"
        case .campground:                   return "tent.fill"
        case .nationalPark:                 return "mountain.2.fill"
        case .park:                         return "leaf.fill"
        case .beach:                        return "sun.horizon.fill"
        case .marina:                       return "sailboat.fill"
        case .museum:                       return "building.columns.fill"
        case .theater, .movieTheater:       return "theatermasks.fill"
        case .stadium:                      return "sportscourt.fill"
        case .amusementPark:                return "ferriswheel"
        case .zoo:                          return "pawprint.fill"
        case .aquarium:                     return "drop.fill"
        case .hospital:                     return "cross.fill"
        case .pharmacy:                     return "pills.fill"
        case .bank, .atm:                   return "banknote.fill"
        case .store:                        return "bag.fill"
        case .fitnessCenter:                return "figure.run"
        case .spa:                          return "sparkles"
        default:                            return "mappin.circle.fill"
        }
    }

    private func iconColor(for item: MKMapItem) -> Color {
        switch item.pointOfInterestCategory {
        case .gasStation, .evCharger, .parking:
            return .orange
        case .restaurant, .cafe, .bakery, .brewery, .winery, .distillery, .nightlife, .foodMarket:
            return Color(red: 0.9, green: 0.45, blue: 0.1)
        case .hotel:
            return .blue
        case .campground:
            return Color(red: 0.55, green: 0.35, blue: 0.1)
        case .nationalPark, .park, .beach:
            return .green
        case .marina:
            return .cyan
        case .museum, .theater, .movieTheater, .amusementPark, .zoo, .aquarium, .stadium:
            return .purple
        case .hospital, .pharmacy:
            return .red
        case .bank, .atm:
            return Color(red: 0.1, green: 0.6, blue: 0.3)
        case .store, .fitnessCenter, .spa:
            return .teal
        default:
            return .red
        }
    }

    private func subtitle(for item: MKMapItem, isRecent: Bool) -> String {
        if isRecent { return "Recent destination" }

        let p = item.placemark
        if let cat = item.pointOfInterestCategory {
            let label = categoryLabel(for: cat)
            let location = [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            return [label, location].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        // Address result
        var parts: [String] = []
        if let num = p.subThoroughfare, let street = p.thoroughfare {
            parts.append("\(num) \(street)")
        } else if let street = p.thoroughfare {
            parts.append(street)
        }
        if let city = p.locality { parts.append(city) }
        if let state = p.administrativeArea { parts.append(state) }
        return parts.joined(separator: ", ")
    }

    private func categoryLabel(for cat: MKPointOfInterestCategory) -> String {
        switch cat {
        case .gasStation:    return "Gas Station"
        case .evCharger:     return "EV Charger"
        case .parking:       return "Parking"
        case .restaurant:    return "Restaurant"
        case .cafe:          return "Café"
        case .bakery:        return "Bakery"
        case .brewery:       return "Brewery"
        case .winery:        return "Winery"
        case .distillery:    return "Distillery"
        case .nightlife:     return "Nightlife"
        case .foodMarket:    return "Food Market"
        case .hotel:         return "Hotel"
        case .campground:    return "Campground"
        case .nationalPark:  return "National Park"
        case .park:          return "Park"
        case .beach:         return "Beach"
        case .marina:        return "Marina"
        case .museum:        return "Museum"
        case .theater:       return "Theater"
        case .movieTheater:  return "Cinema"
        case .stadium:       return "Stadium"
        case .amusementPark: return "Amusement Park"
        case .zoo:           return "Zoo"
        case .aquarium:      return "Aquarium"
        case .hospital:      return "Hospital"
        case .pharmacy:      return "Pharmacy"
        case .bank:          return "Bank"
        case .atm:           return "ATM"
        case .store:         return "Store"
        case .fitnessCenter: return "Gym"
        case .spa:           return "Spa"
        default:             return "Point of Interest"
        }
    }

    private func distance(to item: MKMapItem) -> String? {
        guard let uc = routeManager.userCoordinate else { return nil }
        let meters = CLLocation(latitude: uc.latitude, longitude: uc.longitude)
            .distance(from: CLLocation(latitude: item.location.coordinate.latitude,
                                       longitude: item.location.coordinate.longitude))
        guard meters > 200 else { return nil }
        return routeManager.formatDist(meters)
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(routeManager.isRerouting ? Color.orange : Color.blue)
                    .frame(width: 50, height: 50)
                if routeManager.isRerouting {
                    ProgressView().tint(.white).scaleEffect(1.2)
                } else {
                    Image(systemName: arrowIcon).font(.title2.bold()).foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(routeManager.isRerouting ? "Rerouting…" :
                     (routeManager.currentInstruction.isEmpty ? "Follow the route" : routeManager.currentInstruction))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if !routeManager.isRerouting && routeManager.distanceToNextTurn > 0 {
                    Text(routeManager.formatDist(routeManager.distanceToNextTurn))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let limit = routeManager.currentSpeedLimit {
                ZStack {
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 3)
                        .background(Circle().fill(.white))
                        .frame(width: 44, height: 44)
                    Text("\(limit)")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.black)
                }
            }
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

// MARK: - Elevation Mini Chart
struct ElevationMiniChart: View {
    let elevations: [Double]
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let mn = elevations.min() ?? 0
            let mx = elevations.max() ?? 1
            let range = mx - mn > 0 ? mx - mn : 1
            let w = geo.size.width, h = geo.size.height
            let step = w / Double(max(elevations.count - 1, 1))
            let pts = elevations.enumerated().map { (i, e) in
                CGPoint(x: Double(i) * step, y: h - (e - mn) / range * h)
            }
            ZStack {
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: first)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }.fill(color.opacity(0.18))
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }.stroke(color, lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Weather Row (shown in route cards)
struct WeatherRow: View {
    let weather: RouteWeather

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header label explaining the feature
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 9, weight: .semibold))
                Text("Forecast when you arrive at each point")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.secondary)

            if weather.hasDanger {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                    Text(weather.warningText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 0) {
                ForEach(Array(weather.checkpoints.enumerated()), id: \.offset) { i, cp in
                    if i > 0 {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                        Spacer()
                    }
                    WeatherPointView(label: cp.label, point: cp.weather)
                }
            }
        }
    }
}

struct WeatherPointView: View {
    let label: String
    let point: PointWeather

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: point.sfSymbol)
                .font(.system(size: 16))
                .foregroundStyle(point.symbolColor)
            Text(String(format: "%.0f°", point.tempF))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            if point.windMph >= 20 {
                HStack(spacing: 2) {
                    Image(systemName: "wind").font(.system(size: 8))
                    Text(String(format: "%.0f", point.windMph))
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Route Picker
struct RoutePicker: View {
    @ObservedObject var routeManager: RouteManager
    @ObservedObject var locationManager: LocationManager
    @Binding var shapingMode: Bool
    @Binding var pickerCollapsed: Bool
    var onPreview: (() -> Void)?
    var onRouteOptions: (() -> Void)?
    @State private var showingSegmentEditor = false

    @ViewBuilder
    private func routeRow(route: GHRoute, index: Int) -> some View {
        let isSelected = routeManager.selectedRoute?.polyline === route.polyline
        let label = routeLabel(for: index)
        VStack(spacing: 0) {
            Button { routeManager.selectedRoute = route; shapingMode = false } label: {
                HStack(spacing: 14) {
                    Image(systemName: isSelected ? "record.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if route.curvinessScore > 0 {
                            let badgeColor = curvinessBadgeColor(for: route.curvinessScore)
                            HStack(spacing: 3) {
                                Image(systemName: "road.lanes.curved.right")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(route.curvinessLabel)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(badgeColor.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(routeManager.formatDist(route.distanceMeters))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isSelected ? .blue : .primary)
                        Text(routeManager.formatTime(route.timeMs))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            }
            .buttonStyle(.plain)

            if let elev = route.elevationProfile, elev.count > 2 {
                VStack(alignment: .leading, spacing: 2) {
                    ElevationMiniChart(elevations: elev, color: isSelected ? .blue : .secondary)
                        .frame(height: 30)
                        .padding(.horizontal, 2)
                    HStack {
                        Image(systemName: "arrow.up.right").font(.system(size: 9))
                        Text(String(format: "+%.0f ft", route.elevationGainFt))
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            if let weather = routeManager.routeWeathers[route.id] {
                WeatherRow(weather: weather)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
    }

    private func curvinessBadgeColor(for score: Double) -> Color {
        switch score {
        case ..<80:  return .secondary
        case ..<200: return .green
        case ..<450: return .orange
        default:     return .red
        }
    }

    private func routeLabel(for index: Int) -> String {
        if index == 0 {
            switch routeManager.currentOptions.curviness {
            case .straight:  return "Fastest"
            case .curvy:     return "Most Scenic"
            case .veryCurvy: return "Curviest"
            }
        }
        return "Option \(index + 1)"
    }

    var body: some View {
        VStack(spacing: 0) {

            // Drag handle + collapse button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { pickerCollapsed = true }
            } label: {
                VStack(spacing: 4) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 4)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { v in
                        if v.translation.height > 30 {
                            withAnimation(.easeInOut(duration: 0.25)) { pickerCollapsed = true }
                        }
                    }
            )

            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { pickerCollapsed = true }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if routeManager.isRoundTrip {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                }
                Text(routeManager.isRoundTrip ? "Round Trip Options" : "Choose a Route")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Spacer()
                if routeManager.isRoundTrip {
                    Button {
                        Task { await routeManager.regenerateRoundTrip() }
                    } label: {
                        Label("Try Another", systemImage: "dice")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                } else {
                    Button {
                        onRouteOptions?()
                    } label: {
                        Label("Options", systemImage: "slider.horizontal.3")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Button {
                        Task { await routeManager.retryRoutes() }
                    } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Button { routeManager.cancelRoutes() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Route rows
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(routeManager.routes.enumerated()), id: \.offset) { i, route in
                        routeRow(route: route, index: i)
                        if i < routeManager.routes.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)

            // Route tools — shown when routes are available
            if !routeManager.routes.isEmpty {
                Divider().padding(.top, 4)

                HStack(spacing: 8) {
                    // Preview button — shown when a route is selected
                    if routeManager.selectedRoute != nil {
                        Button { onPreview?() } label: {
                            Label("Preview", systemImage: "play.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.indigo)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.indigo.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    // Shape Route toggle — auto-selects first route if none selected.
                    // No withAnimation: the RoutePicker UIKit views must be removed
                    // immediately so they don't block map taps in shaping mode.
                    Button {
                        if routeManager.selectedRoute == nil {
                            routeManager.selectedRoute = routeManager.routes.first
                        }
                        shapingMode = true
                        pickerCollapsed = true
                    } label: {
                        Label("Shape Route", systemImage: "skew")
                            .font(.caption.bold())
                            .foregroundStyle(shapingMode ? .white : .purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(shapingMode ? Color.purple : Color.purple.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if !routeManager.waypoints.isEmpty {
                        Button {
                            Task { await routeManager.removeLastWaypoint() }
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        Button { showingSegmentEditor = true } label: {
                            Label("Segments", systemImage: "slider.horizontal.3")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Button {
                    if routeManager.selectedRoute == nil {
                        routeManager.selectedRoute = routeManager.routes.first
                    }
                    locationManager.startLocationUpdates()
                    routeManager.startNavigation()
                } label: {
                    Label("Start Navigation", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $showingSegmentEditor) {
            SegmentEditorView(routeManager: routeManager)
        }
    }
}

// MARK: - Segment Editor View
struct SegmentEditorView: View {
    @ObservedObject var routeManager: RouteManager
    @Environment(\.dismiss) var dismiss

    private func segmentName(_ index: Int) -> String {
        if index == 0 { return "Start" }
        return "Via \(index)"
    }
    private func segmentEndName(_ index: Int) -> String {
        if index < routeManager.waypoints.count { return "Via \(index + 1)" }
        return routeManager.searchQuery.isEmpty ? "Destination" : routeManager.searchQuery
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<routeManager.segmentCurviness.count, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill").foregroundStyle(.blue).font(.caption)
                            Text("\(segmentName(i)) → \(segmentEndName(i))")
                                .font(.subheadline.weight(.semibold))
                        }
                        HStack(spacing: 8) {
                            ForEach(RouteOptions.Curviness.allCases) { curv in
                                let sel = routeManager.segmentCurviness[i] == curv
                                Button {
                                    Task { await routeManager.setSegmentCurviness(curv, forSegment: i) }
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: curv.icon)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(sel ? .white : .primary)
                                        Text(curv.rawValue)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(sel ? .white : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(sel ? Color.blue : Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Segment Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
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
                    Text(String(format: "%.2f miles", locationManager.distanceMiles))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
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

// Custom annotation for the motorcycle icon
class MotorcycleAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var heading: CLLocationDirection = 0
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

// MARK: - 3-D motorcycle annotation view (SceneKit)
final class MotorcycleAnnotationView: MKAnnotationView {

    private let scnView  = SCNView()
    private let bikeNode = SCNNode()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupScene()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Scene

    private func setupScene() {
        frame           = CGRect(x: 0, y: 0, width: 110, height: 110)
        backgroundColor = .clear
        canShowCallout  = false
        centerOffset    = .zero

        scnView.frame               = bounds
        scnView.backgroundColor     = .clear
        scnView.antialiasingMode    = .multisampling4X
        scnView.rendersContinuously = false
        addSubview(scnView)

        let scene = SCNScene()
        scnView.scene = scene

        // Camera — behind & above the bike (front of bike faces –Z)
        let camNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.zNear       = 0.05
        camNode.camera = camera
        camNode.position = SCNVector3(3.2, 3.5, 2.0)
        camNode.look(at: SCNVector3(0, 0.50, 0))
        scene.rootNode.addChildNode(camNode)

        // Key light (sun, upper-left-front)
        let key = SCNNode()
        let keyLight = SCNLight()
        keyLight.type      = .directional
        keyLight.intensity = 950
        keyLight.color     = UIColor(white: 1.0, alpha: 1)
        key.light = keyLight
        key.position = SCNVector3(-2, 7, -3)
        key.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(key)

        // Fill light (right-rear, cooler tone)
        let fill = SCNNode()
        let fillLight = SCNLight()
        fillLight.type      = .directional
        fillLight.intensity = 380
        fillLight.color     = UIColor(red: 0.82, green: 0.88, blue: 1.0, alpha: 1)
        fill.light = fillLight
        fill.position = SCNVector3(4, 3, 4)
        fill.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fill)

        // Ambient
        let amb = SCNNode()
        let ambLight = SCNLight()
        ambLight.type      = .ambient
        ambLight.intensity = 380
        ambLight.color     = UIColor(white: 0.78, alpha: 1)
        amb.light = ambLight
        scene.rootNode.addChildNode(amb)

        buildBike()
        scene.rootNode.addChildNode(bikeNode)
    }

    // MARK: - Material & geometry helpers

    private func mat(_ c: UIColor, m: CGFloat = 0.55, r: CGFloat = 0.40) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents   = c
        mat.metalness.contents = m
        mat.roughness.contents = r
        mat.lightingModel      = .physicallyBased
        return mat
    }

    private func glassMat(_ c: UIColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents      = c
        mat.isDoubleSided         = true
        mat.transparency          = 0.50
        mat.blendMode             = .alpha
        mat.writesToDepthBuffer   = false
        mat.lightingModel         = .physicallyBased
        mat.metalness.contents    = 0.05
        mat.roughness.contents    = 0.08
        return mat
    }

    @discardableResult
    private func add(_ n: SCNNode) -> SCNNode { bikeNode.addChildNode(n); return n }

    private func box(_ w: Float, _ h: Float, _ d: Float,
                     x: Float = 0, y: Float = 0, z: Float = 0,
                     c: UIColor, ch: CGFloat = 0.05,
                     m: CGFloat = 0.55, r: CGFloat = 0.40) -> SCNNode {
        let g = SCNBox(width: CGFloat(w), height: CGFloat(h),
                       length: CGFloat(d), chamferRadius: ch)
        g.materials = [mat(c, m: m, r: r)]
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(x, y, z)
        return n
    }

    /// Cylinder. Default rx = π/2 so height axis points along bike's Z (length).
    private func cyl(_ radius: Float, _ height: Float,
                     x: Float = 0, y: Float = 0, z: Float = 0,
                     c: UIColor, rx: Float = Float.pi / 2,
                     m: CGFloat = 0.68, r: CGFloat = 0.28) -> SCNNode {
        let g = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        g.materials = [mat(c, m: m, r: r)]
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(x, y, z)
        n.eulerAngles.x = rx
        return n
    }

    // Torus tyre — looks like a real tyre in cross-section
    private func addTyre(outerR: Float, section: Float, z: Float, c: UIColor) {
        let g = SCNTorus(ringRadius: CGFloat(outerR - section),
                         pipeRadius: CGFloat(section))
        g.ringSegmentCount = 56
        g.pipeSegmentCount = 22
        g.materials = [mat(c, m: 0.0, r: 0.96)]
        let n = SCNNode(geometry: g)
        n.position    = SCNVector3(0, 0, z)
        n.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        bikeNode.addChildNode(n)
    }

    // 5-spoke cast alloy rim
    private func addRim(outerR: Float, innerR: Float, depth: Float, z: Float,
                        rc: UIColor, sc: UIColor) {
        // Outer band (SCNTube = hollow cylinder) — axis along X (wheel axle)
        let band = SCNTube(innerRadius: CGFloat(outerR - 0.048),
                           outerRadius: CGFloat(outerR),
                           height: CGFloat(depth))
        band.materials = [mat(rc, m: 0.70, r: 0.32)]
        let bandN = SCNNode(geometry: band)
        bandN.position    = SCNVector3(0, 0, z)
        bandN.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        bikeNode.addChildNode(bandN)

        // Hub
        let hub = SCNCylinder(radius: CGFloat(innerR),
                              height: CGFloat(depth * 1.15))
        hub.materials = [mat(rc, m: 0.78, r: 0.22)]
        let hubN = SCNNode(geometry: hub)
        hubN.position    = SCNVector3(0, 0, z)
        hubN.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        bikeNode.addChildNode(hubN)

        // 5 spokes — radiate in Y-Z plane (wheel disc is in Y-Z, axle along X)
        let spokeLen   = outerR - innerR - 0.065
        let spokeMidR  = (outerR + innerR) / 2 + 0.012
        for i in 0..<5 {
            let angle = Float(i) / 5.0 * 2 * Float.pi
            let sy = cos(angle) * spokeMidR
            let sz = sin(angle) * spokeMidR
            let sg = SCNBox(width: 0.038, height: CGFloat(spokeLen),
                            length: CGFloat(depth * 0.52), chamferRadius: 0.007)
            sg.materials = [mat(sc, m: 0.68, r: 0.32)]
            let sn = SCNNode(geometry: sg)
            sn.position    = SCNVector3(0, sy, z + sz)
            sn.eulerAngles = SCNVector3(angle, 0, 0)
            bikeNode.addChildNode(sn)
        }
    }

    // MARK: - BMW M1000 XR

    private func buildBike() {
        // ── Colour palette (M Motorsport livery) ──────────────────────────────
        let mBlue   = UIColor(red: 0.00, green: 0.31, blue: 0.63, alpha: 1) // BMW blue
        let mRed    = UIColor(red: 0.87, green: 0.08, blue: 0.12, alpha: 1) // M red
        let mPurp   = UIColor(red: 0.37, green: 0.15, blue: 0.48, alpha: 1) // M purple
        let carbon  = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1) // carbon black
        let matte   = UIColor(white: 0.11, alpha: 1)
        let engCol  = UIColor(white: 0.20, alpha: 1)
        let darkMet = UIColor(white: 0.26, alpha: 1)
        let chrome  = UIColor(white: 0.74, alpha: 1)
        let gold    = UIColor(red: 0.74, green: 0.57, blue: 0.10, alpha: 1) // Brembo gold
        let glass   = UIColor(red: 0.58, green: 0.78, blue: 0.97, alpha: 0.6)
        let led     = UIColor(red: 0.93, green: 0.96, blue: 1.00, alpha: 1)
        let drl     = UIColor(red: 1.00, green: 0.88, blue: 0.32, alpha: 1) // amber DRL
        let brakeL  = UIColor(red: 0.90, green: 0.10, blue: 0.10, alpha: 1)
        let rubber  = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
        let rimC    = UIColor(white: 0.28, alpha: 1)
        let spokeC  = UIColor(white: 0.48, alpha: 1)

        // ── Tyres (SCNTorus — true tyre cross-section) ─────────────────────
        addTyre(outerR: 0.328, section: 0.092, z:  0.895, c: rubber)
        addTyre(outerR: 0.288, section: 0.078, z: -0.895, c: rubber)

        // ── 5-spoke alloy rims ─────────────────────────────────────────────
        addRim(outerR: 0.286, innerR: 0.088, depth: 0.172, z:  0.895, rc: rimC, sc: spokeC)
        addRim(outerR: 0.248, innerR: 0.074, depth: 0.142, z: -0.895, rc: rimC, sc: spokeC)

        // ── Front forks (silver stanchions) ───────────────────────────────
        for s: Float in [-1, 1] {
            // Upper stanchion
            let st = box(0.048, 0.535, 0.048, x: s*0.142, y: 0.362, z: -0.642,
                         c: chrome, ch: 0.012, m: 0.88, r: 0.12)
            st.eulerAngles.x = 0.16    // slight rake
            add(st)
            // Lower slider
            add(box(0.058, 0.272, 0.058, x: s*0.142, y: 0.038, z: -0.798,
                    c: darkMet, ch: 0.010))
        }
        // Axle (thin horizontal rod)
        add(box(0.380, 0.030, 0.030, y: 0, z: -0.895, c: chrome, ch: 0.008, m: 0.85, r: 0.12))
        // Triple clamp / yoke
        add(box(0.038, 0.268, 0.038, y: 0.428, z: -0.498, c: matte, ch: 0.008))
        // Brake rotors (front, two discs)
        for s: Float in [-1, 1] {
            let rot = cyl(0.192, 0.009, x: s*0.092, y: 0, z: -0.895, c: darkMet, rx: 0, m: 0.82, r: 0.28)
            add(rot)
        }

        // ── Rear axle ──────────────────────────────────────────────────────
        add(box(0.425, 0.030, 0.030, y: 0, z: 0.895, c: chrome, ch: 0.008, m: 0.85, r: 0.12))
        // Rear brake disc
        add(cyl(0.158, 0.009, x: -0.102, y: 0, z: 0.895, c: darkMet, rx: 0, m: 0.82, r: 0.28))

        // ── Frame (trellis, visible through fairing gaps) ─────────────────
        add(box(0.048, 0.048, 0.972, y: 0.532, z: -0.018, c: carbon, ch: 0.008))
        for s: Float in [-1, 1] {
            add(box(0.030, 0.030, 0.542, x: s*0.088, y: 0.288, z: -0.182, c: matte, ch: 0.006))
        }
        add(box(0.272, 0.055, 0.062, y: 0.498, z: 0.442, c: matte, ch: 0.010))  // swingarm pivot

        // ── Swingarm ──────────────────────────────────────────────────────
        for s: Float in [-1, 1] {
            add(box(0.040, 0.046, 0.498, x: s*0.108, y: 0.188, z: 0.648, c: matte, ch: 0.006))
        }
        // Shock / spring (right side)
        add(cyl(0.022, 0.368, x: 0.068, y: 0.338, z: 0.548, c: chrome, rx: -0.48, m: 0.82, r: 0.18))
        add(cyl(0.038, 0.168, x: 0.068, y: 0.428, z: 0.408, c: chrome, rx: -0.48, m: 0.65, r: 0.35)) // spring

        // ── Engine block ──────────────────────────────────────────────────
        add(box(0.438, 0.318, 0.692, y: 0.198, z: 0.012, c: engCol, ch: 0.058))
        add(box(0.398, 0.076, 0.518, y: 0.398, z: 0.012, c: darkMet, ch: 0.038))  // head
        add(box(0.376, 0.092, 0.552, y: 0.022, z: 0.068, c: carbon, ch: 0.028))    // sump
        add(box(0.052, 0.208, 0.252, x:  0.252, y: 0.172, z: -0.048, c: engCol, ch: 0.018)) // clutch R
        add(box(0.052, 0.172, 0.228, x: -0.252, y: 0.172, z:  0.022, c: engCol, ch: 0.018)) // alt L
        add(box(0.052, 0.112, 0.168, x:  0.252, y: 0.078, z:  0.198, c: darkMet, ch: 0.010)) // sprocket

        // ── Fuel tank ─────────────────────────────────────────────────────
        add(box(0.522, 0.228, 0.668, y: 0.622, z: -0.142, c: mBlue, ch: 0.082))
        add(box(0.438, 0.112, 0.552, y: 0.782, z: -0.122, c: mBlue, ch: 0.062))
        // Knee recesses
        for s: Float in [-1, 1] {
            add(box(0.065, 0.192, 0.442, x: s*0.240, y: 0.602, z: -0.118, c: carbon, ch: 0.010))
        }
        // Filler cap
        add(box(0.098, 0.018, 0.098, y: 0.848, z: -0.158, c: chrome, ch: 0.018, m: 0.88, r: 0.12))

        // ── Upper fairing (main blue body) ────────────────────────────────
        add(box(0.522, 0.358, 0.498, y: 0.602, z: -0.578, c: mBlue, ch: 0.088))
        add(box(0.378, 0.238, 0.358, y: 0.822, z: -0.718, c: mBlue, ch: 0.062))
        add(box(0.298, 0.252, 0.172, y: 0.522, z: -0.948, c: mBlue, ch: 0.062)) // nose
        add(box(0.418, 0.192, 0.418, y: 0.138, z: -0.678, c: carbon, ch: 0.052)) // chin
        add(box(0.368, 0.072, 0.592, y: 0.028, z: -0.518, c: carbon, ch: 0.010)) // belly pan

        // ── M Motorsport colour stripes (3 horizontal bands on fairing) ───
        add(box(0.530, 0.046, 0.498, y: 0.618, z: -0.548, c: mBlue,  ch: 0.008))
        add(box(0.530, 0.036, 0.498, y: 0.571, z: -0.548, c: mPurp,  ch: 0.008))
        add(box(0.530, 0.036, 0.498, y: 0.534, z: -0.548, c: mRed,   ch: 0.008))

        // ── BMW split LED headlights ───────────────────────────────────────
        // Upper lens
        add(box(0.412, 0.086, 0.048, y: 0.652, z: -1.002, c: led, ch: 0.008, m: 0.08, r: 0.05))
        // Lower lens
        add(box(0.358, 0.082, 0.048, y: 0.498, z: -1.000, c: led, ch: 0.008, m: 0.08, r: 0.05))
        // Amber DRL strips (horizontal signature lines)
        add(box(0.430, 0.020, 0.048, y: 0.716, z: -0.982, c: drl, ch: 0.004))
        add(box(0.430, 0.020, 0.048, y: 0.440, z: -0.982, c: drl, ch: 0.004))
        // Centre nose divider (vertical split)
        add(box(0.055, 0.155, 0.048, y: 0.575, z: -1.010, c: carbon, ch: 0.006))
        // Corner DRL position lights
        for s: Float in [-1, 1] {
            add(box(0.038, 0.038, 0.048, x: s*0.212, y: 0.578, z: -0.998, c: drl, ch: 0.006))
        }

        // ── Windscreen (transparent) ───────────────────────────────────────
        let wg = SCNBox(width: 0.375, height: 0.312, length: 0.046, chamferRadius: 0.022)
        wg.materials = [glassMat(glass)]
        let ws = SCNNode(geometry: wg)
        ws.position = SCNVector3(0, 1.062, -0.742)
        ws.eulerAngles.x = 0.592
        add(ws)
        // Side wind deflectors
        for s: Float in [-1, 1] {
            let dg = SCNBox(width: 0.062, height: 0.152, length: 0.038, chamferRadius: 0.008)
            dg.materials = [glassMat(glass)]
            let dn = SCNNode(geometry: dg)
            dn.position    = SCNVector3(s * 0.232, 0.998, -0.782)
            dn.eulerAngles = SCNVector3(0.448, 0, 0)
            add(dn)
        }

        // ── Aerodynamic winglets (defining M1000 XR feature) ──────────────
        for s: Float in [-1, 1] {
            // Main lower blade
            let w1 = box(0.218, 0.052, 0.292, x: s*0.368, y: 0.495, z: -0.612,
                         c: carbon, ch: 0.012)
            w1.eulerAngles = SCNVector3(0, 0, s * 0.282)
            add(w1)
            // End-plate (vertical fin)
            add(box(0.046, 0.095, 0.270, x: s*0.498, y: 0.475, z: -0.612,
                    c: carbon, ch: 0.008))
            // Upper element (double-element wing)
            let w3 = box(0.152, 0.036, 0.208, x: s*0.332, y: 0.595, z: -0.602,
                         c: carbon, ch: 0.012)
            w3.eulerAngles = SCNVector3(0, 0, s * 0.172)
            add(w3)
        }

        // ── Seat ──────────────────────────────────────────────────────────
        add(box(0.332, 0.066, 0.508, y: 0.840, z: 0.278, c: matte, ch: 0.040))
        add(box(0.272, 0.056, 0.192, y: 0.818, z: 0.678, c: matte, ch: 0.036))  // pillion

        // ── Tail section ──────────────────────────────────────────────────
        add(box(0.355, 0.275, 0.552, y: 0.618, z: 0.718, c: mBlue, ch: 0.078))
        add(box(0.275, 0.175, 0.272, y: 0.602, z: 0.998, c: mBlue, ch: 0.058))  // taper
        // Tail light LED strip
        add(box(0.332, 0.046, 0.046, y: 0.682, z: 1.118, c: brakeL, ch: 0.008))
        add(box(0.242, 0.016, 0.046, y: 0.642, z: 1.128, c: brakeL, ch: 0.004))
        // Rear turn signals
        for s: Float in [-1, 1] {
            add(box(0.036, 0.036, 0.036, x: s*0.155, y: 0.668, z: 1.128, c: drl, ch: 0.006))
        }
        // Undertail / exhaust heat shield
        add(box(0.275, 0.092, 0.292, y: 0.358, z: 0.842, c: carbon, ch: 0.028))
        // Number plate holder / rear hugger
        add(box(0.225, 0.145, 0.035, y: 0.188, z: 1.042, c: matte, ch: 0.012))

        // ── Exhaust system ────────────────────────────────────────────────
        // Left header pipes (inline-4 exits left then crosses)
        add(box(0.065, 0.065, 0.582, x: -0.195, y: 0.085, z: 0.092, c: darkMet, ch: 0.022))
        // Right header bank
        add(box(0.065, 0.065, 0.538, x:  0.195, y: 0.085, z: 0.092, c: darkMet, ch: 0.022))
        // Collector
        add(box(0.075, 0.075, 0.292, x: 0.195, y: 0.175, z: 0.492, c: darkMet, ch: 0.015))
        // Under-seat muffler (BMW style)
        add(box(0.115, 0.115, 0.368, x: 0.235, y: 0.392, z: 0.718, c: chrome, ch: 0.035, m: 0.75, r: 0.22))
        // Carbon heat shield on muffler
        add(box(0.082, 0.082, 0.298, x: 0.235, y: 0.392, z: 0.692, c: carbon, ch: 0.012))
        // Tip
        add(cyl(0.048, 0.075, x: 0.235, y: 0.392, z: 0.918, c: darkMet, rx: 0, m: 0.72, r: 0.28))

        // ── Handlebars (clip-on / low sport bars) ─────────────────────────
        add(box(0.588, 0.036, 0.036, y: 0.965, z: -0.395, c: matte, ch: 0.008))
        for s: Float in [-1, 1] {
            // Bar end / perch
            add(box(0.036, 0.036, 0.135, x: s*0.295, y: 0.945, z: -0.375,
                    c: chrome, ch: 0.008, m: 0.82, r: 0.15))
            // Mirror stalk
            add(box(0.075, 0.055, 0.055, x: s*0.275, y: 0.965, z: -0.512, c: matte, ch: 0.010))
            // Mirror glass (slightly dark for realism)
            add(box(0.115, 0.072, 0.055, x: s*0.275, y: 0.965, z: -0.592,
                    c: UIColor(white: 0.32, alpha: 1), ch: 0.008, m: 0.55, r: 0.08))
        }

        // ── Brembo brake calipers (gold) ──────────────────────────────────
        for s: Float in [-1, 1] {
            add(box(0.046, 0.115, 0.095, x: s*0.170, y: 0.040, z: -0.815,
                    c: gold, ch: 0.010, m: 0.28, r: 0.32))
        }
        add(box(0.046, 0.115, 0.095, x: 0.205, y: 0.016, z: 0.815,
                c: gold, ch: 0.010, m: 0.28, r: 0.32))

        // ── Footpegs ──────────────────────────────────────────────────────
        for s: Float in [-1, 1] {
            add(box(0.208, 0.020, 0.030, x: s*0.332, y: 0.115, z: 0.215,
                    c: matte, ch: 0.004, m: 0.28, r: 0.72))
            add(box(0.172, 0.018, 0.026, x: s*0.292, y: 0.115, z: 0.615,
                    c: matte, ch: 0.004, m: 0.28, r: 0.72))
        }

        // ── Radiator (front, just behind chin fairing) ────────────────────
        add(box(0.395, 0.292, 0.055, y: 0.215, z: -0.672, c: darkMet, ch: 0.016))

        // ── Rear suspension linkage ────────────────────────────────────────
        add(box(0.185, 0.038, 0.038, y: 0.135, z: 0.445, c: darkMet, ch: 0.008))
    }

    // MARK: - Heading update

    func updateHeading(_ heading: Double, mapHeading: Double) {
        // Camera azimuth from the bike's front axis (+Z = behind, rotating toward +X = right side).
        // atan2(camX, camZ) gives the offset angle so the heading formula remains correct
        // regardless of where the SceneKit camera sits horizontally.
        let camAzimuth = atan2(Double(3.2), Double(2.0))  // matches cam position (3.2, 3.5, 2.0)
        let angle = Float(camAzimuth - (heading - mapHeading) * .pi / 180)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.10
        bikeNode.eulerAngles.y = angle
        SCNTransaction.commit()
    }
}

// Via-point annotation
class WaypointAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let index: Int
    var title: String? { "Via \(index + 1)" }
    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate
        self.index = index
    }
}

// MARK: - Hazard Banner
struct HazardBanner: View {
    let hazard: RouteHazard

    var color: Color {
        switch hazard.type {
        case .police:       return .blue
        case .speedCamera:  return .orange
        case .construction: return Color(red: 0.95, green: 0.55, blue: 0.0)
        case .schoolZone:   return .red
        case .accident:     return .red
        case .roadClosed:   return Color(red: 0.6, green: 0.0, blue: 0.0)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hazard.type.icon)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(hazard.type.announcement)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

// MARK: - Sound Control Sheet
struct SoundControlSheet: View {
    @ObservedObject var routeManager: RouteManager
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            HStack(spacing: 12) {
                ForEach(VoiceMode.allCases) { mode in
                    let selected = routeManager.voiceMode == mode
                    Button {
                        routeManager.voiceMode = mode
                        onDismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(selected ? .white : .primary)
                                .frame(width: 56, height: 56)
                                .background(selected ? Color.blue : Color(.secondarySystemBackground))
                                .clipShape(Circle())
                            Text(mode.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(selected ? .blue : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Map View
// MARK: - Live track overlay (never removed, updated in-place — zero flash)
class LiveTrackOverlay: NSObject, MKOverlay {
    var coordinates: [CLLocationCoordinate2D] = []
    var coordinate: CLLocationCoordinate2D { coordinates.first ?? CLLocationCoordinate2D() }
    var boundingMapRect: MKMapRect { .world }
}

class LiveTrackRenderer: MKOverlayRenderer {
    var coordinates: [CLLocationCoordinate2D] = [] {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard coordinates.count > 1 else { return }
        let pts = coordinates.map { point(for: MKMapPoint($0)) }
        context.setStrokeColor(UIColor.systemPurple.cgColor)
        context.setLineWidth(5 / zoomScale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: pts[0])
        for pt in pts.dropFirst() { context.addLine(to: pt) }
        context.strokePath()
    }
}

// Keep for any legacy references — no longer used for live track
class LiveTrackPolyline: MKPolyline {}

// MARK: - Map Layer Style

enum MapLayerStyle: String, CaseIterable, Equatable {
    case standard        = "Standard"
    case muted           = "Muted"
    case satellite       = "Satellite"
    case hybrid          = "Hybrid"
    case trafficStandard = "Traffic"
    case trafficHybrid   = "Satellite + Traffic"

    var icon: String {
        switch self {
        case .standard:        return "map"
        case .muted:           return "map.fill"
        case .satellite:       return "globe.americas.fill"
        case .hybrid:          return "globe.americas"
        case .trafficStandard: return "car.fill"
        case .trafficHybrid:   return "car.circle.fill"
        }
    }

    var configuration: MKMapConfiguration {
        switch self {
        case .standard:
            return MKStandardMapConfiguration(elevationStyle: .realistic)
        case .muted:
            let cfg = MKStandardMapConfiguration(elevationStyle: .flat)
            cfg.emphasisStyle = .muted
            return cfg
        case .satellite:
            return MKImageryMapConfiguration(elevationStyle: .realistic)
        case .hybrid:
            return MKHybridMapConfiguration(elevationStyle: .realistic)
        case .trafficStandard:
            let cfg = MKStandardMapConfiguration(elevationStyle: .realistic)
            cfg.showsTraffic = true
            return cfg
        case .trafficHybrid:
            let cfg = MKHybridMapConfiguration(elevationStyle: .realistic)
            cfg.showsTraffic = true
            return cfg
        }
    }
}

// MARK: - Map Layer Button

struct MapLayerButton: View {
    @Binding var selectedLayer: MapLayerStyle
    var isNavigating: Bool
    @State private var showingPicker = false

    var body: some View {
        if isNavigating {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { showingPicker = true } label: {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 3, y: 1)
                    }
                    .confirmationDialog("Map Layer", isPresented: $showingPicker) {
                        ForEach(MapLayerStyle.allCases, id: \.self) { layer in
                            Button {
                                selectedLayer = layer
                            } label: {
                                Label(layer.rawValue, systemImage: layer.icon)
                            }
                            .disabled(selectedLayer == layer)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Current: \(selectedLayer.rawValue)")
                    }
                    .padding(.trailing, 14)
                }
                .padding(.bottom, 180)
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: isNavigating)
        }
    }
}

struct MapView: UIViewRepresentable {
    var trackingCoordinates: [CLLocationCoordinate2D]
    var routes: [GHRoute]
    var selectedRoute: GHRoute?
    var waypoints: [CLLocationCoordinate2D] = []
    var shapingMode: Bool = false
    var liveTrackCoords: [CLLocationCoordinate2D] = []
    var userCoordinate: CLLocationCoordinate2D?
    var previewActive: Bool = false
    var curvinessOverlays: [CurvinessPolyline] = []
    var showOfflineTiles: Bool = false
    var motoPOIs: [MotoPOI] = []
    var onRouteSelected: (GHRoute) -> Void = { _ in }
    var onWaypointAdded: ((CLLocationCoordinate2D) -> Void)?
    var onWaypointRemoved: ((Int) -> Void)?
    var onRegionChange: ((MKCoordinateRegion) -> Void)?
    var onMapCreated: ((MKMapView) -> Void)?
    var onPOISelected: ((MotoPOI) -> Void)?
    var isShapingMode: (() -> Bool)?       // live closure passed from ContentView @State
    var mapLayer: MapLayerStyle = .standard

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = false  // we draw our own motorcycle annotation
        map.userTrackingMode = .none
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        // Must be false so callout accessory buttons (e.g. delete) can receive their touches
        tap.cancelsTouchesInView = false
        // Allow simultaneous recognition with MKMapView's internal gesture recognizers
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        let cb = onMapCreated
        DispatchQueue.main.async { cb?(map) }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Apply map layer configuration only when it changes to avoid flicker
        if context.coordinator.lastMapLayer != mapLayer {
            context.coordinator.lastMapLayer = mapLayer
            map.preferredConfiguration = mapLayer.configuration
        }

        context.coordinator.routes = routes
        context.coordinator.selectedPolyline = selectedRoute?.polyline
        context.coordinator.onRouteSelected = onRouteSelected
        context.coordinator.shapingMode = shapingMode
        context.coordinator.isShapingMode = isShapingMode
        context.coordinator.onWaypointAdded = onWaypointAdded
        context.coordinator.onWaypointRemoved = onWaypointRemoved
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.onPOISelected = onPOISelected

        // During preview the camera and motorcycle annotation are driven directly
        // on the MKMapView reference — returning here prevents any overlay
        // re-syncing that would cause flashes on every previewProgress tick.
        if previewActive {
            // Ensure the motorcycle annotation exists so handleSimCoordChange can move it
            if let coord = userCoordinate,
               !map.annotations.contains(where: { $0 is MotorcycleAnnotation }) {
                map.addAnnotation(MotorcycleAnnotation(coordinate: coord))
            }
            return
        }

        // Offline tile overlay — added once as the base layer, removed when disabled
        let hasOfflineOverlay = map.overlays.contains { $0 is OfflineTileOverlay }
        if showOfflineTiles && !hasOfflineOverlay {
            let overlay = OfflineTileOverlay(manager: OfflineMapManager.shared)
            // Insert at index 0 so it sits below all route overlays
            map.insertOverlay(overlay, at: 0, level: .aboveRoads)
        } else if !showOfflineTiles && hasOfflineOverlay {
            map.removeOverlays(map.overlays.filter { $0 is OfflineTileOverlay })
        }

        // Sync Moto POI annotations — diff by osmID to avoid full remove/re-add flicker
        let existingPOIAnns = map.annotations.compactMap { $0 as? MotoPOIAnnotation }
        let existingOsmIDs  = Set(existingPOIAnns.map { $0.poi.osmID })
        let newOsmIDs       = Set(motoPOIs.map { $0.osmID })
        let annToRemove     = existingPOIAnns.filter { !newOsmIDs.contains($0.poi.osmID) }
        let poisToAdd       = motoPOIs.filter      { !existingOsmIDs.contains($0.osmID) }
        if !annToRemove.isEmpty { map.removeAnnotations(annToRemove) }
        if !poisToAdd.isEmpty   { map.addAnnotations(poisToAdd.map { MotoPOIAnnotation($0) }) }

        // Sync curviness overlays independently — don't blow them away when routes change
        let existingCurviness = map.overlays.compactMap { $0 as? CurvinessPolyline }
        if existingCurviness.count != curvinessOverlays.count ||
           zip(existingCurviness, curvinessOverlays).contains(where: { ObjectIdentifier($0) != ObjectIdentifier($1) }) {
            map.removeOverlays(existingCurviness)
            if !curvinessOverlays.isEmpty {
                // Draw curviness below route overlays (add first so routes render on top)
                for overlay in curvinessOverlays {
                    map.addOverlay(overlay, level: .aboveRoads)
                }
            }
        }

        // Sync waypoint annotations
        let existing = map.annotations.compactMap { $0 as? WaypointAnnotation }
        map.removeAnnotations(existing)
        for (i, coord) in waypoints.enumerated() {
            map.addAnnotation(WaypointAnnotation(coordinate: coord, index: i))
        }

        // Update or add motorcycle annotation
        if let coord = userCoordinate {
            if let existing = map.annotations.first(where: { $0 is MotorcycleAnnotation }) as? MotorcycleAnnotation {
                existing.coordinate = coord
            } else {
                let annotation = MotorcycleAnnotation(coordinate: coord)
                map.addAnnotation(annotation)
                let region = MKCoordinateRegion(center: coord,
                                               latitudinalMeters: 1000,
                                               longitudinalMeters: 1000)
                map.setRegion(region, animated: true)
            }
        }

        // Only update route overlays when routes or selection actually changes
        let currentRouteIDs = routes.map { ObjectIdentifier($0.polyline) }
        let currentSelectedID = selectedRoute.map { ObjectIdentifier($0.polyline) }
        let routesChanged = currentRouteIDs != context.coordinator.lastRoutePolylineIDs
            || currentSelectedID != context.coordinator.lastSelectedPolylineID
        if routesChanged {
            context.coordinator.lastRoutePolylineIDs = currentRouteIDs
            context.coordinator.lastSelectedPolylineID = currentSelectedID

            let toRemove = map.overlays.filter { !($0 is CurvinessPolyline) && !($0 is LiveTrackPolyline) && !($0 is LiveTrackOverlay) }
            map.removeOverlays(toRemove)

            for route in routes where route.polyline !== selectedRoute?.polyline {
                map.addOverlay(route.polyline, level: .aboveRoads)
            }
            if let selected = selectedRoute {
                map.addOverlay(selected.polyline, level: .aboveRoads)
            }
        }

        // Viewport fit (only when selection/routes change)
        if routesChanged {
        if let selected = selectedRoute {
            if !shapingMode {
                map.setVisibleMapRect(
                    selected.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 300, right: 40),
                    animated: true
                )
            }
        } else if !routes.isEmpty {
            // Zoom to fit all routes, but only once per route set load
            let firstPolylineID = ObjectIdentifier(routes[0].polyline)
            if context.coordinator.fittedRouteSetID != firstPolylineID {
                context.coordinator.fittedRouteSetID = firstPolylineID
                let boundingRect = routes.dropFirst().reduce(routes[0].polyline.boundingMapRect) {
                    $0.union($1.polyline.boundingMapRect)
                }
                map.setVisibleMapRect(
                    boundingRect,
                    edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 300, right: 40),
                    animated: true
                )
            }
        }
        } // end routesChanged

        // Tracked path (orange, drawn on top)
        if trackingCoordinates.count > 1 {
            let poly = MKPolyline(coordinates: trackingCoordinates, count: trackingCoordinates.count)
            map.addOverlay(poly, level: .aboveRoads)
        }

        // Live navigation track — add overlay once, update renderer in-place (zero flash)
        if liveTrackCoords.isEmpty {
            // Navigation ended/reset — remove overlay so it's recreated fresh next time
            if let old = context.coordinator.liveTrackOverlay {
                map.removeOverlay(old)
                context.coordinator.liveTrackOverlay = nil
                context.coordinator.liveTrackRenderer = nil
                context.coordinator.lastLiveTrackCount = 0
            }
        } else {
            if context.coordinator.liveTrackOverlay == nil {
                let overlay = LiveTrackOverlay()
                context.coordinator.liveTrackOverlay = overlay
                map.addOverlay(overlay, level: .aboveRoads)
            }
            if liveTrackCoords.count != context.coordinator.lastLiveTrackCount {
                context.coordinator.lastLiveTrackCount = liveTrackCoords.count
                context.coordinator.liveTrackOverlay?.coordinates = liveTrackCoords
                context.coordinator.liveTrackRenderer?.coordinates = liveTrackCoords
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var routes: [GHRoute] = []
        var selectedPolyline: MKPolyline?
        var shapingMode = false
        var isShapingMode: (() -> Bool)?   // live closure — always reads current SwiftUI state
        var onRouteSelected: (GHRoute) -> Void = { _ in }
        var onWaypointAdded: ((CLLocationCoordinate2D) -> Void)?
        var onWaypointRemoved: ((Int) -> Void)?
        var onRegionChange: ((MKCoordinateRegion) -> Void)?
        var onPOISelected: ((MotoPOI) -> Void)?
        var fittedRouteSetID: ObjectIdentifier?
        var lastLiveTrackCount: Int = 0
        var liveTrackOverlay: LiveTrackOverlay?
        var liveTrackRenderer: LiveTrackRenderer?
        var lastRoutePolylineIDs: [ObjectIdentifier] = []
        var lastSelectedPolylineID: ObjectIdentifier?
        var lastMapLayer: MapLayerStyle = .standard

        // Allow our tap to fire alongside MKMapView's own recognizers (label taps, etc.)
        // so the shaping-mode tap always reaches handleTap regardless of map state.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            onRegionChange?(mapView.region)
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView = recognizer.view as? MKMapView else { return }
            let tapPt = recognizer.location(in: mapView)

            // In shaping mode any tap adds a via-point; skip route-selection hit test.
            // Guard: don't add a waypoint if the tap landed on an annotation view (pin tap to
            // open callout) or if a callout is already showing (button tap inside callout).
            if isShapingMode?() ?? shapingMode {
                // Walk the hit-test view hierarchy to detect annotation views and callout views
                let hitView = mapView.hitTest(tapPt, with: nil)
                var ancestor: UIView? = hitView
                var hitAnnotationOrCallout = false
                while let v = ancestor {
                    if v is MKAnnotationView { hitAnnotationOrCallout = true; break }
                    let cls = String(describing: type(of: v))
                    if cls.contains("Callout") { hitAnnotationOrCallout = true; break }
                    ancestor = v.superview
                }
                if !hitAnnotationOrCallout {
                    // Dismiss any selected annotation (e.g. motorcycle icon) before adding waypoint
                    for ann in mapView.selectedAnnotations { mapView.deselectAnnotation(ann, animated: false) }
                    let coord = mapView.convert(tapPt, toCoordinateFrom: mapView)
                    onWaypointAdded?(coord)
                }
                return
            }

            let tapMapPt = MKMapPoint(mapView.convert(tapPt, toCoordinateFrom: mapView))
            let pxScale  = mapView.visibleMapRect.size.width / Double(mapView.bounds.width)
            let threshold = 22.0 * pxScale
            var closest: GHRoute?
            var minDist  = Double.infinity
            for route in routes {
                let pts = route.polyline.points()
                for i in 0..<(route.polyline.pointCount - 1) {
                    let d = ptSegDist(tapMapPt, pts[i], pts[i + 1])
                    if d < minDist { minDist = d; closest = route }
                }
            }
            if minDist < threshold, let r = closest {
                onRouteSelected(r)
            }
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                     calloutAccessoryControlTapped control: UIControl) {
            if let poiAnn = view.annotation as? MotoPOIAnnotation {
                mapView.deselectAnnotation(poiAnn, animated: true)
                onPOISelected?(poiAnn.poi)
                return
            }
            guard let wp = view.annotation as? WaypointAnnotation else { return }
            mapView.deselectAnnotation(wp, animated: true)
            onWaypointRemoved?(wp.index)
        }

        private func ptSegDist(_ p: MKMapPoint, _ a: MKMapPoint, _ b: MKMapPoint) -> Double {
            let dx = b.x - a.x, dy = b.y - a.y
            if dx == 0 && dy == 0 { return hypot(p.x - a.x, p.y - a.y) }
            let t = max(0, min(1, ((p.x - a.x)*dx + (p.y - a.y)*dy) / (dx*dx + dy*dy)))
            return hypot(p.x - (a.x + t*dx), p.y - (a.y + t*dy))
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let poiAnn = annotation as? MotoPOIAnnotation {
                let id = "motopoi_\(poiAnn.poi.category.rawValue)"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation    = poiAnn
                view.image         = MotoPOIAnnotationRenderer.makeImage(for: poiAnn.poi.category)
                view.centerOffset  = .zero
                view.canShowCallout = true
                // "i" info button opens the detail sheet
                let infoBtn = UIButton(type: .detailDisclosure)
                infoBtn.tintColor = poiAnn.poi.category.uiColor
                view.rightCalloutAccessoryView = infoBtn
                // Moto-friendly badge in left callout
                if poiAnn.poi.isMotoFriendly {
                    let badge = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
                    badge.tintColor = .systemGreen
                    badge.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                    view.leftCalloutAccessoryView = badge
                }
                view.displayPriority = .defaultHigh
                return view
            }
            if let wp = annotation as? WaypointAnnotation {
                let id = "waypoint"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = wp
                view.markerTintColor = .systemPurple
                view.glyphImage = UIImage(systemName: "smallcircle.filled.circle")
                view.canShowCallout = true
                view.titleVisibility = .adaptive
                // Delete button as right accessory
                let deleteBtn = UIButton(type: .system)
                deleteBtn.setImage(UIImage(systemName: "trash.circle.fill"), for: .normal)
                deleteBtn.tintColor = .systemRed
                deleteBtn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                view.rightCalloutAccessoryView = deleteBtn
                return view
            }
            guard let moto = annotation as? MotorcycleAnnotation else { return nil }
            let id = "motorcycle3d"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MotorcycleAnnotationView)
                ?? MotorcycleAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = moto
            view.updateHeading(moto.heading, mapHeading: mapView.camera.heading)
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let curvy = overlay as? CurvinessPolyline {
                let r = MKPolylineRenderer(polyline: curvy)
                switch curvy.curvinessScore {
                case ..<150:
                    r.strokeColor = UIColor.systemYellow.withAlphaComponent(0.65)
                    r.lineWidth = 2.5
                case ..<350:
                    r.strokeColor = UIColor.systemGreen.withAlphaComponent(0.75)
                    r.lineWidth = 3
                case ..<650:
                    r.strokeColor = UIColor.systemOrange.withAlphaComponent(0.85)
                    r.lineWidth = 3.5
                default:
                    r.strokeColor = UIColor.systemRed.withAlphaComponent(0.9)
                    r.lineWidth = 4
                }
                return r
            }
            if let liveOverlay = overlay as? LiveTrackOverlay {
                let renderer = LiveTrackRenderer(overlay: liveOverlay)
                renderer.coordinates = liveOverlay.coordinates
                liveTrackRenderer = renderer
                return renderer
            }
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            if let selected = selectedPolyline, polyline === selected {
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 3
            } else if routes.contains(where: { $0.polyline === polyline }) {
                renderer.strokeColor = .systemGray
                renderer.lineWidth = 2
                renderer.alpha = 0.6
            } else {
                renderer.strokeColor = .systemOrange
                renderer.lineWidth = 2.5
            }
            return renderer
        }
    }
}

// MARK: - Ride Detail View
struct RideDetailView: View {
    let ride: Ride
    @Environment(\.dismiss) var dismiss

    private var durationStr: String {
        let m = Int(ride.durationSeconds) / 60
        return m < 60 ? "\(m) min" : "\(m/60)h \(m%60)m"
    }
    private var elevMinFt: Double { ride.elevSamples.map { $0.ft }.min() ?? 0 }
    private var elevMaxFt: Double { ride.elevSamples.map { $0.ft }.max() ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    MapView(trackingCoordinates: ride.coordinates, routes: [], selectedRoute: nil)
                        .frame(height: 260)
                    rideCharts
                        .padding(.vertical, 16)
                }
            }
            .navigationTitle(ride.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    @ViewBuilder private var rideCharts: some View {
        VStack(spacing: 20) {
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                StatView(label: "Distance",   value: String(format: "%.2f mi",  ride.distance))
                StatView(label: "Duration",   value: durationStr)
                StatView(label: "Max Speed",  value: ride.maxSpeedMph > 0 ? String(format: "%.0f mph", ride.maxSpeedMph) : "—")
                StatView(label: "Avg Speed",  value: ride.avgSpeedMph > 0 ? String(format: "%.0f mph", ride.avgSpeedMph) : "—")
                StatView(label: "Elev. Gain", value: ride.elevationGainFt > 0 ? String(format: "+%.0f ft", ride.elevationGainFt) : "—")
                StatView(label: "Date",       value: ride.date.formatted(date: .abbreviated, time: .omitted))
            }
            .padding(.horizontal)

            // Speed chart
            if ride.speedSamples.count > 3 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Speed").font(.headline).padding(.horizontal)
                    ElevationMiniChart(elevations: ride.speedSamples.map { $0.mph }, color: .blue)
                        .frame(height: 80).padding(.horizontal)
                    HStack {
                        Text("0 min").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(durationStr).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }

            // Elevation chart
            if ride.elevSamples.count > 3 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Elevation").font(.headline).padding(.horizontal)
                    ElevationMiniChart(elevations: ride.elevSamples.map { $0.ft }, color: .orange)
                        .frame(height: 80).padding(.horizontal)
                    HStack {
                        Text(String(format: "%.0f ft", elevMinFt)).font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f ft", elevMaxFt)).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }

            if ride.speedSamples.count > 6 {
                segmentBreakdown
            }
        }
    }

    @ViewBuilder private var segmentBreakdown: some View {
        let segments = segmentize(ride)
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 4)
            Text("Segment Breakdown")
                .font(.subheadline.weight(.semibold))
                .padding(.bottom, 4)
            ForEach(Array(segments.enumerated()), id: \.offset) { i, seg in
                HStack {
                    Text(seg.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "avg %.0f mph", seg.avgSpeed))
                            .font(.caption.weight(.medium))
                        Text(String(format: "max %.0f mph", seg.maxSpeed))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "+%.0f ft", seg.elevGain))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 2)
                if i < segments.count - 1 { Divider() }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    struct RideSeg { let label: String; let avgSpeed: Double; let maxSpeed: Double; let elevGain: Double }

    private func segmentize(_ ride: Ride) -> [RideSeg] {
        let labels = ["First ⅓", "Middle ⅓", "Last ⅓"]
        let n = ride.speedSamples.count
        let size = max(1, n / 3)
        return (0..<3).map { i in
            let start = i * size
            let end = i == 2 ? n : min(start + size, n)
            let slice = Array(ride.speedSamples[start..<end])
            let avg = slice.isEmpty ? 0 : slice.map(\.mph).reduce(0, +) / Double(slice.count)
            let mx  = slice.map(\.mph).max() ?? 0

            let eStart = i * max(1, ride.elevSamples.count / 3)
            let eEnd = i == 2 ? ride.elevSamples.count : min(eStart + max(1, ride.elevSamples.count / 3), ride.elevSamples.count)
            let eSlice = ride.elevSamples.count > 0 ? Array(ride.elevSamples[eStart..<eEnd]) : []
            var gain = 0.0
            for j in 1..<eSlice.count { if eSlice[j].ft > eSlice[j-1].ft { gain += eSlice[j].ft - eSlice[j-1].ft } }

            return RideSeg(label: labels[i], avgSpeed: avg, maxSpeed: mx, elevGain: gain)
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

// MARK: - Map overlay controls (separate structs for faster type-checking)

struct MapControlsView: View {
    var mapViewRef: MKMapView?
    @Binding var headingUpMode: Bool
    var simulatedCoordinate: CLLocationCoordinate2D?
    var currentLocation: CLLocation?
    var selectedRoute: GHRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoomPill
            locHeadingPill
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 14)
        .padding(.bottom, 64)
    }

    private var zoomPill: some View {
        VStack(spacing: 0) {
            Button { zoom(by: 0.5) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            Divider().frame(width: 44)
            Button { zoom(by: 2) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 3, y: 1)
    }

    private var locHeadingPill: some View {
        VStack(spacing: 0) {
            Button { recenter() } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
            }
            Divider().frame(width: 44)
            Button { toggleHeading() } label: {
                Image(systemName: headingUpMode ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(headingUpMode ? .orange : .primary)
                    .frame(width: 44, height: 44)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 3, y: 1)
    }

    private func zoom(by factor: Double) {
        guard let map = mapViewRef else { return }
        var region = map.region
        region.span.latitudeDelta  = min(max(region.span.latitudeDelta  * factor, 0.0005), 150)
        region.span.longitudeDelta = min(max(region.span.longitudeDelta * factor, 0.0005), 150)
        map.setRegion(region, animated: true)
    }

    private func recenter() {
        let coord = simulatedCoordinate ?? currentLocation?.coordinate
        guard let coord, let map = mapViewRef else { return }
        map.setRegion(MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800), animated: true)
    }

    private func toggleHeading() {
        headingUpMode.toggle()
        guard let map = mapViewRef else { return }
        let center = map.camera.centerCoordinate
        let altitude = map.camera.altitude
        if headingUpMode {
            var bearing: Double = 0
            if let course = currentLocation?.course, course >= 0 {
                bearing = course
            } else if let route = selectedRoute {
                var coords = [CLLocationCoordinate2D](repeating: .init(), count: route.polyline.pointCount)
                route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: route.polyline.pointCount))
                if coords.count > 1 {
                    let a = coords[0], b = coords[1]
                    let dLon = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)
                    let dLat = b.latitude - a.latitude
                    bearing = (atan2(dLon, dLat) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
                }
            }
            map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: altitude, pitch: 45, heading: bearing), animated: true)
        } else {
            map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: altitude, pitch: 0, heading: 0), animated: true)
        }
    }
}

struct NavControlsView: View {
    @ObservedObject var routeManager: RouteManager
    @Binding var showSoundControls: Bool

    var body: some View {
        if routeManager.isNavigating {
            VStack(spacing: 12) {
                Button { withAnimation(.spring()) { showSoundControls.toggle() } } label: {
                    Image(systemName: routeManager.voiceMode.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 3, y: 1)
                }
                if routeManager.simulationMode {
                    Button { routeManager.toggleSimulationPause() } label: {
                        Image(systemName: routeManager.isSimulationPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(routeManager.isSimulationPaused ? .green : .orange)
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 3, y: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 14)
        }
    }
}

struct SpeedLimitBadge: View {
    var limit: Int?
    var body: some View {
        if let limit {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Circle().fill(.white).frame(width: 56, height: 56).shadow(radius: 3, y: 1)
                        Circle().strokeBorder(Color.red, lineWidth: 4).frame(width: 56, height: 56)
                        Text("\(limit)").font(.system(size: 18, weight: .black)).foregroundStyle(.black)
                    }
                    .padding(.trailing, 14).padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: limit)
        }
    }
}

private struct CurvinessDot: View {
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.primary)
        }
    }
}

struct RoutePickerPanel: View {
    @ObservedObject var routeManager: RouteManager
    var locationManager: LocationManager
    @Binding var shapingMode: Bool
    @Binding var pickerCollapsed: Bool
    @Binding var pendingDestination: MKMapItem?
    var onPreview: () -> Void

    var body: some View {
        if pickerCollapsed {
            collapsedBar
        } else {
            RoutePicker(routeManager: routeManager, locationManager: locationManager,
                        shapingMode: $shapingMode, pickerCollapsed: $pickerCollapsed,
                        onPreview: onPreview,
                        onRouteOptions: { pendingDestination = routeManager.currentDestination })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onChange(of: routeManager.selectedRoute?.polyline) { pickerCollapsed = false }
        }
    }

    @ViewBuilder private var collapsedBar: some View {
        if let route = routeManager.selectedRoute {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(routeManager.formatDist(route.distanceMeters))  ·  \(routeManager.formatTime(route.timeMs))")
                        .font(.subheadline.weight(.semibold))
                    Text("Route selected").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { shapingMode.toggle() }
                } label: {
                    Image(systemName: "skew").font(.title3)
                        .foregroundStyle(shapingMode ? .white : .purple)
                        .frame(width: 36, height: 36)
                        .background(shapingMode ? Color.purple : Color.purple.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { pickerCollapsed = false }
                } label: {
                    Image(systemName: "chevron.up.circle.fill").font(.title2).foregroundStyle(.blue)
                }
                Button {
                    locationManager.startLocationUpdates()
                    routeManager.startNavigation()
                } label: {
                    Text("Go").font(.headline).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(Color.blue).clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill").foregroundStyle(.blue).font(.subheadline)
                Text("\(routeManager.routes.count) route\(routeManager.routes.count == 1 ? "" : "s") · tap one on the map")
                    .font(.subheadline).foregroundStyle(.primary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { pickerCollapsed = false }
                } label: {
                    Image(systemName: "chevron.up.circle.fill").font(.title2).foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct CurvinessToggleView: View {
    @Binding var showOverlay: Bool
    var isFetching: Bool
    var onToggle: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    if showOverlay {
                        HStack(spacing: 8) {
                            CurvinessDot(label: "Mild",    color: .yellow)
                            CurvinessDot(label: "Curvy",   color: .green)
                            CurvinessDot(label: "Twisty",  color: .orange)
                            CurvinessDot(label: "Extreme", color: .red)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.regularMaterial).clipShape(Capsule())
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showOverlay.toggle() }
                        onToggle()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(showOverlay ? Color.green : Color(.systemBackground).opacity(0.9))
                                .frame(width: 44, height: 44).shadow(radius: 3, y: 1)
                            Image(systemName: "road.lanes.curved.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(showOverlay ? .white : .primary)
                            if isFetching {
                                Circle().stroke(Color.green.opacity(0.5), lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                    .rotationEffect(.degrees(isFetching ? 360 : 0))
                                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isFetching)
                            }
                        }
                    }
                }
                .padding(.leading, 14).padding(.bottom, 110)
                Spacer()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
