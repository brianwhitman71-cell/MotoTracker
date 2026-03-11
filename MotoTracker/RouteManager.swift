import Foundation
import MapKit
import AVFoundation
import Combine

@MainActor
class RouteManager: NSObject, ObservableObject {

    // Search
    @Published var searchQuery = ""
    @Published var searchResults: [MKMapItem] = []

    // Routes
    @Published var routes: [MKRoute] = []
    @Published var selectedRoute: MKRoute?
    @Published var isCalculatingRoutes = false

    // Navigation
    @Published var isNavigating = false
    @Published var currentInstruction = ""
    @Published var distanceToNextTurn: Double = 0

    private var currentStepIndex = 0
    private var lastAnnouncedStep = -1
    private let synthesizer = AVSpeechSynthesizer()
    private var searchTask: Task<Void, Never>?

    // MARK: - Search
    func search() {
        searchTask?.cancel()
        guard !searchQuery.isEmpty else { searchResults = []; return }
        searchTask = Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchQuery
            let response = try? await MKLocalSearch(request: request).start()
            if !Task.isCancelled {
                searchResults = Array((response?.mapItems ?? []).prefix(5))
            }
        }
    }

    // MARK: - Routing
    func getRoutes(to destination: MKMapItem) async {
        searchResults = []
        searchQuery = destination.name ?? ""
        isCalculatingRoutes = true
        routes = []
        selectedRoute = nil

        let request = MKDirections.Request()
        request.source = .forCurrentLocation()
        request.destination = destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        let response = try? await MKDirections(request: request).calculate()
        routes = (response?.routes ?? []).sorted { $0.expectedTravelTime < $1.expectedTravelTime }
        selectedRoute = routes.first
        isCalculatingRoutes = false
    }

    func cancelRoutes() {
        routes = []
        selectedRoute = nil
        searchQuery = ""
        searchResults = []
    }

    // MARK: - Navigation
    func startNavigation() {
        guard let route = selectedRoute else { return }
        isNavigating = true
        currentStepIndex = 0
        lastAnnouncedStep = -1
        setupAudio()
        let steps = route.steps.filter { !$0.instructions.isEmpty }
        if let first = steps.first {
            currentInstruction = first.instructions
            say("Starting navigation. \(first.instructions)")
        }
    }

    func stopNavigation() {
        isNavigating = false
        synthesizer.stopSpeaking(at: .immediate)
        cancelRoutes()
        currentInstruction = ""
        currentStepIndex = 0
    }

    func update(with location: CLLocation) {
        guard isNavigating, let route = selectedRoute else { return }
        let steps = route.steps.filter { !$0.instructions.isEmpty }
        guard currentStepIndex < steps.count else { return }

        let step = steps[currentStepIndex]
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: step.polyline.pointCount)
        step.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: step.polyline.pointCount))
        guard let endCoord = coords.last else { return }

        let dist = location.distance(from: CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude))
        distanceToNextTurn = dist
        let isLast = currentStepIndex >= steps.count - 1

        // Announce upcoming turn at 300 meters
        if dist < 300 && !isLast && lastAnnouncedStep != currentStepIndex {
            lastAnnouncedStep = currentStepIndex
            let next = steps[currentStepIndex + 1].instructions
            let prefix = dist > 50 ? "In \(Int(dist)) meters, " : ""
            say("\(prefix)\(next)")
            currentInstruction = next
        }

        // Advance to next step at 25 meters
        if dist < 25 {
            if isLast {
                say("You have arrived at your destination.")
                isNavigating = false
            } else {
                currentStepIndex += 1
                currentInstruction = steps[currentStepIndex].instructions
            }
        }
    }

    // MARK: - Helpers
    func say(_ text: String) {
        guard !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = 0.5
        synthesizer.speak(u)
    }

    private func setupAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        return m < 60 ? "\(m) min" : "\(m/60)h \(m%60)m"
    }

    func formatDist(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters)) m" : String(format: "%.1f km", meters / 1000)
    }
}
