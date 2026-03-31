import SwiftUI
import CoreLocation

// MARK: - Direction model
enum RoundTripDirection: String, CaseIterable, Identifiable {
    case any       = "Any"
    case north     = "N"
    case northEast = "NE"
    case east      = "E"
    case southEast = "SE"
    case south     = "S"
    case southWest = "SW"
    case west      = "W"
    case northWest = "NW"

    var id: String { rawValue }

    var bearing: Double? {
        switch self {
        case .any:       return nil
        case .north:     return 0
        case .northEast: return 45
        case .east:      return 90
        case .southEast: return 135
        case .south:     return 180
        case .southWest: return 225
        case .west:      return 270
        case .northWest: return 315
        }
    }

    var sfSymbol: String {
        switch self {
        case .any:       return "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .north:     return "arrow.up"
        case .northEast: return "arrow.up.right"
        case .east:      return "arrow.right"
        case .southEast: return "arrow.down.right"
        case .south:     return "arrow.down"
        case .southWest: return "arrow.down.left"
        case .west:      return "arrow.left"
        case .northWest: return "arrow.up.left"
        }
    }
}

// MARK: - Round Trip Sheet
struct RoundTripView: View {
    @ObservedObject var routeManager: RouteManager
    @Environment(\.dismiss) var dismiss

    @State private var distanceMiles: Double = 75
    @State private var direction: RoundTripDirection = .any

    // 3×3 compass grid layout
    private let compassGrid: [[RoundTripDirection?]] = [
        [.northWest, .north,  .northEast],
        [.west,      .any,    .east     ],
        [.southWest, .south,  .southEast],
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // Header illustration
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 8)

                    // Distance
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Distance")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("~\(Int(distanceMiles)) miles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                        }

                        Slider(value: $distanceMiles, in: 15...250, step: 5)
                            .tint(.orange)

                        HStack {
                            Text("15 mi").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("250 mi").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Direction compass
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Direction")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(0..<compassGrid.count, id: \.self) { row in
                                HStack(spacing: 8) {
                                    ForEach(0..<compassGrid[row].count, id: \.self) { col in
                                        if let dir = compassGrid[row][col] {
                                            CompassButton(
                                                direction: dir,
                                                isSelected: direction == dir
                                            ) { direction = dir }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 100) // room for the sticky button
            }
            .navigationTitle("Round Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    Task { await routeManager.generateRoundTrip(distanceMiles: distanceMiles, direction: direction) }
                } label: {
                    Label("Generate Routes", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Compass Direction Button
struct CompassButton: View {
    let direction: RoundTripDirection
    let isSelected: Bool
    let action: () -> Void

    var isCenter: Bool { direction == .any }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: direction.sfSymbol)
                    .font(.system(size: isCenter ? 16 : 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : (isCenter ? Color.orange : .primary))
                if !isCenter {
                    Text(direction.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                } else {
                    Text("Any")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .orange)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? (isCenter ? Color.orange : Color.blue)
                          : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
