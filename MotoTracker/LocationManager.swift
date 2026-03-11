import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var isTracking = false
    @Published var currentCoordinates: [CLLocationCoordinate2D] = []
    @Published var distanceMiles: Double = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationUpdateCount = 0  // increments every GPS update

    private(set) var currentLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var pendingStart = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        authorizationStatus = manager.authorizationStatus
    }

    // Start recording a ride (also starts GPS)
    func startRide() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginTracking()
        case .notDetermined:
            pendingStart = true
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    // Start GPS without recording — used for navigation-only mode
    func startLocationUpdates() {
        manager.startUpdatingLocation()
    }

    private func beginTracking() {
        currentCoordinates = []
        distanceMiles = 0
        lastLocation = nil
        isTracking = true
        manager.startUpdatingLocation()
    }

    func stopTracking() -> Ride {
        isTracking = false
        manager.stopUpdatingLocation()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let name = "Ride on \(formatter.string(from: .now))"
        return Ride(name: name, date: .now, coordinates: currentCoordinates, distance: distanceMiles)
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.locationUpdateCount += 1
            guard self.isTracking else { return }
            self.currentCoordinates.append(location.coordinate)
            if let last = self.lastLocation {
                self.distanceMiles += location.distance(from: last) / 1609.34
            }
            self.lastLocation = location
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if self.pendingStart && (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) {
                self.pendingStart = false
                self.beginTracking()
            }
        }
    }
}
