import Foundation
import CoreLocation

struct SpeedSample: Codable {
    let t: Double   // seconds from ride start
    let mph: Double
}

struct ElevSample: Codable {
    let t: Double   // seconds from ride start
    let ft: Double  // elevation in feet
}

struct Ride: Identifiable, Codable {
    var id = UUID()
    var name: String
    var date: Date
    var coordinates: [CLLocationCoordinate2D]
    var distance: Double
    var durationSeconds: Double
    var maxSpeedMph: Double
    var avgSpeedMph: Double
    var elevationGainFt: Double
    var speedSamples: [SpeedSample]
    var elevSamples: [ElevSample]

    enum CodingKeys: String, CodingKey {
        case id, name, date, coordinates, distance
        case durationSeconds, maxSpeedMph, avgSpeedMph, elevationGainFt
        case speedSamples, elevSamples
    }

    init(name: String, date: Date = .now, coordinates: [CLLocationCoordinate2D] = [],
         distance: Double = 0, durationSeconds: Double = 0, maxSpeedMph: Double = 0,
         avgSpeedMph: Double = 0, elevationGainFt: Double = 0,
         speedSamples: [SpeedSample] = [], elevSamples: [ElevSample] = []) {
        self.name = name; self.date = date; self.coordinates = coordinates
        self.distance = distance; self.durationSeconds = durationSeconds
        self.maxSpeedMph = maxSpeedMph; self.avgSpeedMph = avgSpeedMph
        self.elevationGainFt = elevationGainFt
        self.speedSamples = speedSamples; self.elevSamples = elevSamples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        date = try c.decode(Date.self, forKey: .date)
        distance = try c.decode(Double.self, forKey: .distance)
        let raw = try c.decode([[String: Double]].self, forKey: .coordinates)
        coordinates = raw.map { CLLocationCoordinate2D(latitude: $0["lat"]!, longitude: $0["lon"]!) }
        durationSeconds  = (try? c.decodeIfPresent(Double.self, forKey: .durationSeconds)) ?? 0
        maxSpeedMph      = (try? c.decodeIfPresent(Double.self, forKey: .maxSpeedMph))     ?? 0
        avgSpeedMph      = (try? c.decodeIfPresent(Double.self, forKey: .avgSpeedMph))     ?? 0
        elevationGainFt  = (try? c.decodeIfPresent(Double.self, forKey: .elevationGainFt)) ?? 0
        speedSamples     = (try? c.decodeIfPresent([SpeedSample].self, forKey: .speedSamples)) ?? []
        elevSamples      = (try? c.decodeIfPresent([ElevSample].self, forKey: .elevSamples))   ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(date, forKey: .date)
        try c.encode(distance, forKey: .distance)
        try c.encode(coordinates.map { ["lat": $0.latitude, "lon": $0.longitude] }, forKey: .coordinates)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(maxSpeedMph, forKey: .maxSpeedMph)
        try c.encode(avgSpeedMph, forKey: .avgSpeedMph)
        try c.encode(elevationGainFt, forKey: .elevationGainFt)
        try c.encode(speedSamples, forKey: .speedSamples)
        try c.encode(elevSamples, forKey: .elevSamples)
    }
}
