import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var isTracking = false
    @Published var currentCoordinates: [CLLocationCoordinate2D] = []
    @Published var distanceMiles: Double = 0
    @Published var currentSpeedMph: Double = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationUpdateCount = 0

    private(set) var currentLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var pendingStart = false
    private var rideStartTime: Date?
    private var speedSamples: [SpeedSample] = []
    private var elevSamples: [ElevSample] = []
    private var maxSpeedMph: Double = 0
    private var elevationGainFt: Double = 0
    private var lastElevFt: Double?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        authorizationStatus = manager.authorizationStatus
    }

    func startRide() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: beginTracking()
        case .notDetermined: pendingStart = true; manager.requestWhenInUseAuthorization()
        default: break
        }
    }

    func startDisplayingLocation() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: break
        }
    }

    func startLocationUpdates() { manager.startUpdatingLocation() }

    private func beginTracking() {
        currentCoordinates = []; distanceMiles = 0; lastLocation = nil
        speedSamples = []; elevSamples = []; maxSpeedMph = 0
        elevationGainFt = 0; lastElevFt = nil; rideStartTime = Date()
        isTracking = true
        manager.startUpdatingLocation()
    }

    func stopTracking() -> Ride {
        isTracking = false
        manager.stopUpdatingLocation()
        let duration = rideStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let avgSpeed = duration > 0 ? (distanceMiles / (duration / 3600)) : 0
        let formatter = DateFormatter(); formatter.dateStyle = .medium
        return Ride(
            name: "Ride on \(formatter.string(from: .now))",
            date: .now,
            coordinates: currentCoordinates,
            distance: distanceMiles,
            durationSeconds: duration,
            maxSpeedMph: maxSpeedMph,
            avgSpeedMph: avgSpeed,
            elevationGainFt: elevationGainFt,
            speedSamples: speedSamples,
            elevSamples: elevSamples
        )
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.locationUpdateCount += 1
            let speedMph = max(0, location.speed) * 2.23694
            self.currentSpeedMph = speedMph
            guard self.isTracking else { return }
            self.currentCoordinates.append(location.coordinate)
            if let last = self.lastLocation {
                self.distanceMiles += location.distance(from: last) / 1609.34
            }
            self.lastLocation = location
            let t = self.rideStartTime.map { Date().timeIntervalSince($0) } ?? 0
            if location.speed >= 0 {
                self.speedSamples.append(SpeedSample(t: t, mph: speedMph))
                if speedMph > self.maxSpeedMph { self.maxSpeedMph = speedMph }
            }
            let elevFt = location.altitude * 3.28084
            self.elevSamples.append(ElevSample(t: t, ft: elevFt))
            if let last = self.lastElevFt, elevFt > last {
                self.elevationGainFt += elevFt - last
            }
            self.lastElevFt = elevFt
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
                if self.pendingStart { self.pendingStart = false; self.beginTracking() }
            }
        }
    }
}
