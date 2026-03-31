import SwiftUI
import MapKit

// MARK: - Route Options Model
struct RouteOptions {

    enum Curviness: String, CaseIterable, Identifiable {
        case straight  = "Straight"
        case curvy     = "Curvy"
        case veryCurvy = "Very Curvy"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .straight:  return "arrow.right"
            case .curvy:     return "road.lanes.curved.right"
            case .veryCurvy: return "waveform.path"
            }
        }

        var description: String {
            switch self {
            case .straight:  return "Fastest path"
            case .curvy:     return "Scenic & twisty"
            case .veryCurvy: return "Max curves & mountain roads"
            }
        }

        // Maps to GraphHopper weighting parameter
        // NOTE: "curvature" only works with motorcycle/bike profiles.
        // Using "fastest" for car (placeholder) until Kurviger profile is enabled.
        var weighting: String {
            switch self {
            case .straight:  return "fastest"
            case .curvy:     return "fastest"
            case .veryCurvy: return "fastest"
            }
        }
    }

    var curviness:      Curviness = .curvy
    var avoidFreeways:  Bool      = false
    var avoidMainRoads: Bool      = false
    var avoidUnpaved:   Bool      = false
    var useHills:       Double    = 0.5  // 0.0 = avoid hills, 1.0 = seek hills
    var routeCount:     Int       = 5    // number of route options to return (1-10)
}

// MARK: - Route Options View
struct RouteOptionsView: View {
    let destination: MKMapItem
    @State private var options = RouteOptions()
    @Environment(\.dismiss) var dismiss

    var onFindRoutes: (RouteOptions) -> Void

    private func hillLabel(_ v: Double) -> String {
        switch v {
        case ..<0.2: return "Avoid hills"
        case ..<0.4: return "Prefer flat"
        case ..<0.6: return "Neutral"
        case ..<0.8: return "Prefer hills"
        default:     return "Seek hills"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Destination header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.red.opacity(0.15)).frame(width: 44, height: 44)
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2).foregroundStyle(.red)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(destination.name ?? "Destination").font(.headline)
                            Text(destination.name ?? "")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding([.horizontal, .top])

                    // Route Style
                    OptionsSection(title: "Route Style") {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                ForEach(RouteOptions.Curviness.allCases) { option in
                                    CurvinessButton(
                                        option: option,
                                        isSelected: options.curviness == option
                                    ) { options.curviness = option }
                                }
                            }
                            Text(options.curviness.description)
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    // Avoid
                    OptionsSection(title: "Avoid") {
                        VStack(spacing: 0) {
                            ToggleRow(label: "Freeways & Motorways", icon: "road.lanes",        isOn: $options.avoidFreeways)
                            Divider().padding(.leading, 36)
                            ToggleRow(label: "Main Roads",           icon: "car.2",             isOn: $options.avoidMainRoads)
                            Divider().padding(.leading, 36)
                            ToggleRow(label: "Unpaved Roads",        icon: "road.lanes.curved.left", isOn: $options.avoidUnpaved)
                        }
                    }

                    // Elevation — slider outside List to avoid gesture conflicts
                    OptionsSection(title: "Elevation") {
                        VStack(spacing: 10) {
                            HStack {
                                Label("Hill Preference", systemImage: "mountain.2")
                                    .font(.subheadline)
                                Spacer()
                                Text(hillLabel(options.useHills))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            TappableSlider(value: $options.useHills, tint: .green)
                            HStack {
                                Text("Flat").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("Hilly").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Route count
                    OptionsSection(title: "Results") {
                        Stepper(value: $options.routeCount, in: 1...10) {
                            HStack {
                                Label("Number of Routes", systemImage: "list.number")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(options.routeCount)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.blue)
                                    .frame(minWidth: 24)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Route Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onFindRoutes(options)
                    dismiss()
                } label: {
                    Label("Find Routes", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
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

// MARK: - Curviness Button
struct CurvinessButton: View {
    let option: RouteOptions.Curviness
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
                        .frame(height: 56)
                    Image(systemName: option.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                Text(option.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? .blue : .primary)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}

// MARK: - Options Section wrapper
struct OptionsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            content()
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
}

// MARK: - Tappable Slider (tap anywhere on track to jump)
struct TappableSlider: View {
    @Binding var value: Double
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            let thumbSize: CGFloat = 24
            let trackWidth = geo.size.width - thumbSize
            let fraction = CGFloat(max(0, min(1, value)))
            let thumbX    = thumbSize / 2 + fraction * trackWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(height: 4)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, thumbX), height: 4)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX - thumbSize / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let frac = Double((drag.location.x - thumbSize / 2) / trackWidth)
                        value = max(0, min(1, frac))
                    }
            )
        }
        .frame(height: 24)
    }
}

// MARK: - Toggle Row
struct ToggleRow: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

