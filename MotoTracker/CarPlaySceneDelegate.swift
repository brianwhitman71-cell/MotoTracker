// CarPlay entitlement pending Apple approval — excluded from build until approved.
#if CARPLAY_ENABLED
import CarPlay
import MapKit
import Combine

// MARK: - CarPlay Scene Delegate

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var carPlayWindow:       CPWindow?
    private var mapView:             MKMapView?
    private var mapTemplate:         CPMapTemplate?
    private var navigationSession:   CPNavigationSession?
    private var cancellables:        Set<AnyCancellable> = []

    // MARK: - Connect / Disconnect

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carPlayWindow       = window

        setupMapView(in: window)
        setupMapTemplate()
        interfaceController.setRootTemplate(mapTemplate!, animated: false, completion: nil)
        observeRouteManager()
        syncMapOverlays()
        syncNavigationState()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        cancellables.removeAll()
        navigationSession?.cancelTrip()
        navigationSession  = nil
        mapTemplate        = nil
        mapView            = nil
        carPlayWindow      = nil
        self.interfaceController = nil
    }

    // MARK: - Setup

    private func setupMapView(in window: CPWindow) {
        let mv = MKMapView(frame: window.bounds)
        mv.autoresizingMask  = [.flexibleWidth, .flexibleHeight]
        mv.showsUserLocation = true
        mv.showsTraffic      = false
        mv.isRotateEnabled   = true
        mv.delegate          = self
        let vc      = UIViewController()
        vc.view.addSubview(mv)
        window.rootViewController = vc
        mapView = mv
    }

    private func setupMapTemplate() {
        let t = CPMapTemplate()
        t.mapDelegate                    = self
        t.automaticallyHidesNavigationBar = false
        mapTemplate = t
    }

    // MARK: - Observation

    private func observeRouteManager() {
        guard let rm = RouteManager.current else { return }

        rm.$routes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncMapOverlays()
                self?.syncRoutePreviews()
            }
            .store(in: &cancellables)

        rm.$selectedRoute
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncMapOverlays() }
            .store(in: &cancellables)

        rm.$isNavigating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] navigating in
                if navigating { self?.startCarPlayNavigation() }
                else          { self?.stopCarPlayNavigation()  }
            }
            .store(in: &cancellables)

        rm.$currentInstruction
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateManeuver() }
            .store(in: &cancellables)

        rm.$distanceToNextTurn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateManeuver() }
            .store(in: &cancellables)

        rm.$currentStepIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateManeuver() }
            .store(in: &cancellables)
    }

    private func syncNavigationState() {
        guard let rm = RouteManager.current, rm.isNavigating else { return }
        startCarPlayNavigation()
    }

    // MARK: - Map overlays

    private func syncMapOverlays() {
        guard let mv = mapView else { return }
        mv.removeOverlays(mv.overlays.filter { $0 is MKPolyline })

        guard let route = activeRoute else { return }
        mv.addOverlay(route.polyline, level: .aboveRoads)

        guard RouteManager.current?.isNavigating == false else { return }
        let padded = route.polyline.boundingMapRect.insetBy(dx: -8_000, dy: -8_000)
        mv.setVisibleMapRect(padded, animated: true)
        mv.userTrackingMode = .none
    }

    // MARK: - Route preview panel

    private func syncRoutePreviews() {
        guard let rm     = RouteManager.current,
              let tmpl   = mapTemplate,
              !rm.isNavigating,
              !rm.routes.isEmpty,
              let dest   = rm.currentDestination else { return }

        let origin = MKMapItem(placemark: MKPlacemark(coordinate: rm.userCoordinate ?? .init()))
        origin.name = "Your Location"

        let choices: [CPRouteChoice] = rm.routes.prefix(3).map { route in
            let summary = "\(fmtDist(route.distanceMeters, rm)) · \(fmtTime(route.timeMs))"
            let choice  = CPRouteChoice(
                summaryVariants:          [summary],
                additionalInformationVariants: [route.curvinessLabel],
                selectionSummaryVariants: [summary]
            )
            choice.userInfo = route
            return choice
        }

        let trip = CPTrip(origin: origin, destination: dest, routeChoices: choices)
        let cfg  = CPTripPreviewTextConfiguration(
            startButtonTitle:          "Go",
            additionalRoutesButtonTitle: nil,
            overviewButtonTitle:       "Overview"
        )
        tmpl.showRouteChoicesPreview(for: trip, textConfiguration: cfg)
    }

    // MARK: - Navigation session

    private func startCarPlayNavigation() {
        guard let rm     = RouteManager.current,
              let route  = rm.selectedRoute,
              let dest   = rm.currentDestination,
              let tmpl   = mapTemplate else { return }

        // End any existing session cleanly
        navigationSession?.cancelTrip()
        navigationSession = nil

        let origin = MKMapItem(placemark: MKPlacemark(coordinate: rm.userCoordinate ?? .init()))
        origin.name = "Your Location"

        let choice = CPRouteChoice(
            summaryVariants:          ["\(fmtDist(route.distanceMeters, rm)) · \(fmtTime(route.timeMs))"],
            additionalInformationVariants: [route.curvinessLabel],
            selectionSummaryVariants: [fmtDist(route.distanceMeters, rm)]
        )
        choice.userInfo = route

        let trip    = CPTrip(origin: origin, destination: dest, routeChoices: [choice])
        let session = tmpl.startNavigationSession(for: trip)
        navigationSession = session

        mapView?.userTrackingMode = .followWithHeading
        updateManeuver()
    }

    private func stopCarPlayNavigation() {
        if let session = navigationSession {
            // If destination was reached, finish; otherwise cancel
            if RouteManager.current?.currentDestination == nil {
                session.finishTrip()
            } else {
                session.cancelTrip()
            }
            navigationSession = nil
        }
        mapTemplate?.hideTripPreviews()
        syncMapOverlays()
        syncRoutePreviews()
    }

    // MARK: - Maneuver updates

    private func updateManeuver() {
        guard let rm      = RouteManager.current,
              let session = navigationSession,
              let route   = rm.selectedRoute else { return }

        let text = rm.currentInstruction.isEmpty ? "Follow the route" : rm.currentInstruction
        let dist = rm.distanceToNextTurn

        let maneuver = CPManeuver()
        maneuver.instructionVariants    = [text]
        maneuver.symbolImage            = symbol(for: text)
        maneuver.initialTravelEstimates = estimates(distMeters: dist, timeMs: 0, rm: rm)
        session.upcomingManeuvers       = [maneuver]

        // Approximate remaining route
        let done     = Double(rm.currentStepIndex) / Double(max(route.instructions.count, 1))
        let remDist  = route.distanceMeters * max(0, 1 - done)
        let remTime  = route.timeMs         * max(0, 1 - done)
        let routeEst = estimates(distMeters: remDist, timeMs: remTime, rm: rm)
        session.updateEstimates(routeEst, for: maneuver)
    }

    // MARK: - Helpers

    private var activeRoute: GHRoute? {
        RouteManager.current?.selectedRoute ?? RouteManager.current?.routes.first
    }

    private func estimates(distMeters: Double, timeMs: Double, rm: RouteManager) -> CPTravelEstimates {
        let dist: Measurement<UnitLength> = rm.units == .imperial
            ? .init(value: distMeters / 1609.34, unit: .miles)
            : .init(value: distMeters / 1000,    unit: .kilometers)
        return CPTravelEstimates(distanceRemaining: dist, timeRemaining: timeMs / 1000)
    }

    private func fmtDist(_ meters: Double, _ rm: RouteManager) -> String {
        if rm.units == .imperial {
            let mi = meters / 1609.34
            return mi < 10 ? String(format: "%.1f mi", mi) : String(format: "%.0f mi", mi)
        }
        let km = meters / 1000
        return km < 10 ? String(format: "%.1f km", km) : String(format: "%.0f km", km)
    }

    private func fmtTime(_ ms: Double) -> String {
        let min = Int(ms / 60_000)
        guard min >= 60 else { return "\(min) min" }
        let h = min / 60, m = min % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func symbol(for instruction: String) -> UIImage? {
        let t = instruction.lowercased()
        let name: String
        if      t.contains("sharp right")                                     { name = "arrow.turn.up.right"           }
        else if t.contains("sharp left")                                      { name = "arrow.turn.up.left"            }
        else if t.contains("right")                                           { name = "arrow.turn.up.right"           }
        else if t.contains("left")                                            { name = "arrow.turn.up.left"            }
        else if t.contains("u-turn") || t.contains("uturn")                  { name = "arrow.uturn.left"              }
        else if t.contains("roundabout") || t.contains("rotary")             { name = "arrow.triangle.circlepath"     }
        else if t.contains("arrive") || t.contains("destination")            { name = "mappin.and.ellipse"            }
        else if t.contains("merge") || t.contains("ramp")                    { name = "arrow.merge"                  }
        else                                                                  { name = "arrow.up"                      }
        return UIImage(systemName: name)?
            .withTintColor(.label, renderingMode: .alwaysOriginal)
    }
}

// MARK: - MKMapViewDelegate

extension CarPlaySceneDelegate: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let r         = MKPolylineRenderer(polyline: polyline)
        r.strokeColor = UIColor.systemBlue
        r.lineWidth   = 7
        r.lineCap     = .round
        r.lineJoin    = .round
        return r
    }
}

// MARK: - CPMapTemplateDelegate

extension CarPlaySceneDelegate: CPMapTemplateDelegate {

    // User selected a route in the preview panel
    func mapTemplate(_ mapTemplate: CPMapTemplate,
                     selectedPreviewFor trip: CPTrip,
                     using routeChoice: CPRouteChoice) {
        guard let route = routeChoice.userInfo as? GHRoute,
              let rm    = RouteManager.current else { return }
        rm.selectedRoute = route
        syncMapOverlays()
    }

    // User tapped "Go" in the preview panel — start navigation
    func mapTemplate(_ mapTemplate: CPMapTemplate,
                     startedTrip trip: CPTrip,
                     using routeChoice: CPRouteChoice) {
        if let route = routeChoice.userInfo as? GHRoute {
            RouteManager.current?.selectedRoute = route
        }
        RouteManager.current?.startNavigation()
    }

    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        RouteManager.current?.stopNavigation()
    }

    // Pan/zoom requests from CarPlay hardware controls
    func mapTemplate(_ mapTemplate: CPMapTemplate,
                     panWith direction: CPMapTemplate.PanDirection) {
        guard let mv = mapView else { return }
        let delta: Double = 30_000  // metres
        var region = mv.region
        switch direction {
        case .up:    region.center.latitude  += region.span.latitudeDelta  * 0.3
        case .down:  region.center.latitude  -= region.span.latitudeDelta  * 0.3
        case .left:  region.center.longitude -= region.span.longitudeDelta * 0.3
        case .right: region.center.longitude += region.span.longitudeDelta * 0.3
        default: break
        }
        _ = delta  // silence warning
        mv.setRegion(region, animated: true)
    }
}
#endif // CARPLAY_ENABLED
