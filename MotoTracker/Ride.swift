//
//  Ride.swift
//  MotoTracker
//
//  Created by Brian Whitman on 3/11/26.
//

import Foundation
  import CoreLocation

  struct Ride: Identifiable, Codable {
      var id = UUID()
      var name: String
      var date: Date
      var coordinates: [CLLocationCoordinate2D]
      var distance: Double // in miles

      enum CodingKeys: String, CodingKey {
          case id, name, date, coordinates, distance
      }

      init(name: String, date: Date = .now, coordinates: [CLLocationCoordinate2D] = [], distance:
  Double = 0) {
          self.name = name
          self.date = date
          self.coordinates = coordinates
          self.distance = distance
      }

      // CLLocationCoordinate2D needs manual Codable support
      init(from decoder: Decoder) throws {
          let c = try decoder.container(keyedBy: CodingKeys.self)
          id = try c.decode(UUID.self, forKey: .id)
          name = try c.decode(String.self, forKey: .name)
          date = try c.decode(Date.self, forKey: .date)
          distance = try c.decode(Double.self, forKey: .distance)
          let raw = try c.decode([[String: Double]].self, forKey: .coordinates)
          coordinates = raw.map { CLLocationCoordinate2D(latitude: $0["lat"]!, longitude: $0["lon"]!)
  }
      }

      func encode(to encoder: Encoder) throws {
          var c = encoder.container(keyedBy: CodingKeys.self)
          try c.encode(id, forKey: .id)
          try c.encode(name, forKey: .name)
          try c.encode(date, forKey: .date)
          try c.encode(distance, forKey: .distance)
          let raw = coordinates.map { ["lat": $0.latitude, "lon": $0.longitude] }
          try c.encode(raw, forKey: .coordinates)
      }
  }
