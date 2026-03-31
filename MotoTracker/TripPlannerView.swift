import SwiftUI
import MapKit

struct TripPlannerView: View {
    @ObservedObject var routeManager: RouteManager
    @Environment(\.dismiss) var dismiss

    @State private var searchQuery = ""
    @State private var isAddingStop = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                // Start — always your location
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.green).frame(width: 22, height: 22)
                            Image(systemName: "location.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("Your Location")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Start")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }

                // Stops list
                Section {
                    ForEach(routeManager.tripStops) { stop in
                        HStack(spacing: 14) {
                            let idx = routeManager.tripStops.firstIndex(where: { $0.id == stop.id }) ?? 0
                            ZStack {
                                Circle().fill(Color.red.opacity(0.15)).frame(width: 22, height: 22)
                                Text("\(idx + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.red)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stop.name)
                                    .font(.subheadline.weight(.medium))
                                let coord = stop.coordinate
                                Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if stop.id == routeManager.tripStops.last?.id {
                                Text("End")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { routeManager.removeTripStops(at: $0) }
                    .onMove  { routeManager.moveTripStops(from: $0, to: $1) }

                    // Add stop inline search
                    if isAddingStop {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: routeManager.isSearching ? "arrow.2.circlepath" : "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search for a stop…", text: $searchQuery)
                                    .autocorrectionDisabled()
                                    .onChange(of: searchQuery) { _, newValue in
                                        searchTask?.cancel()
                                        guard !newValue.isEmpty else {
                                            routeManager.stopSearchResults = []
                                            return
                                        }
                                        searchTask = Task {
                                            try? await Task.sleep(for: .milliseconds(280))
                                            guard !Task.isCancelled else { return }
                                            await routeManager.searchStops(newValue)
                                        }
                                    }
                                if !searchQuery.isEmpty {
                                    Button {
                                        searchQuery = ""
                                        routeManager.stopSearchResults = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                    }
                                } else {
                                    Button("Cancel") {
                                        isAddingStop = false
                                        searchQuery = ""
                                        routeManager.stopSearchResults = []
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 4)

                            ForEach(routeManager.stopSearchResults, id: \.self) { item in
                                Button {
                                    routeManager.addTripStop(item)
                                    searchQuery = ""
                                    routeManager.stopSearchResults = []
                                    isAddingStop = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.name ?? "")
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            if let subtitle = item.placemark.title, !subtitle.isEmpty,
                                               subtitle != item.name {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        Button {
                            isAddingStop = true
                        } label: {
                            Label("Add Stop", systemImage: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    if routeManager.tripStops.isEmpty {
                        Text("No stops added yet")
                    } else {
                        Text("\(routeManager.tripStops.count) stop\(routeManager.tripStops.count == 1 ? "" : "s")")
                    }
                }

                // Tip
                if routeManager.tripStops.isEmpty {
                    Section {
                        Label("Add at least one destination to calculate a multi-stop route.",
                              systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Plan Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .disabled(routeManager.tripStops.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    Task { await routeManager.calculateTripRoute() }
                } label: {
                    Text("Calculate Route")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(routeManager.tripStops.isEmpty ? Color.gray.opacity(0.4) : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .disabled(routeManager.tripStops.isEmpty)
                .background(.ultraThinMaterial)
            }
        }
    }
}
