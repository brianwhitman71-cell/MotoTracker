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

    private var lastLocation: CLLocation?
    private var pendingStart = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        authorizationStatus = manager.authorizationStatus
        print("LocationManager init — auth status: \(manager.authorizationStatus.rawValue)")
    }

    func startRide() {
        print("startRide called — auth status: \(manager.authorizationStatus.rawValue)")
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startTracking()
        case .notDetermined:
            pendingStart = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("Location permission denied — user needs to enable in Settings")
        @unknown default:
            break
        }
    }

    func startTracking() {
        print("startTracking called")
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
            print("Auth changed to: \(manager.authorizationStatus.rawValue)")
            if self.pendingStart && (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) {
                self.pendingStart = false
                self.startTracking()
            }
        }
    }
}
