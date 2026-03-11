import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var rides: [Ride] = []
    @State private var showingSaveAlert = false
    @State private var newRide: Ride?
    @State private var selectedRide: Ride?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Map
                MapView(coordinates: locationManager.currentCoordinates)
                    .frame(height: 300)
                    .ignoresSafeArea(edges: .horizontal)

                // Tracking controls
                if locationManager.isTracking {
                    HStack {
                        Image(systemName: "figure.outdoor.cycle")
                        Text(String(format: "%.2f miles", locationManager.distanceMiles))
                        Spacer()
                        Button("Stop Ride", role: .destructive) {
                            newRide = locationManager.stopTracking()
                            showingSaveAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                } else {
                    Button("Start Ride") {
                        locationManager.startRide()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                }

                Divider()

                // Saved rides list
                if rides.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No rides yet")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(rides) { ride in
                            Button {
                                selectedRide = ride
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ride.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    HStack {
                                        Text(ride.date.formatted(date: .abbreviated, time: .shortened))
                                        Spacer()
                                        Text(String(format: "%.2f miles", ride.distance))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteRide)
                    }
                }
            }
            .navigationTitle("MotoTracker")
            .toolbar {
                EditButton()
            }
            .alert("Save Ride?", isPresented: $showingSaveAlert, presenting: newRide) { ride in
                Button("Save") { rides.append(ride) }
                Button("Discard", role: .destructive) { }
            } message: { ride in
                Text(String(format: "You rode %.2f miles.", ride.distance))
            }
            .sheet(item: $selectedRide) { ride in
                RideDetailView(ride: ride)
            }
        }
    }

    func deleteRide(at offsets: IndexSet) {
        rides.remove(atOffsets: offsets)
    }
}

// MARK: - Map View
struct MapView: UIViewRepresentable {
    var coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .follow
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        guard coordinates.count > 1 else { return }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        map.addOverlay(polyline)
        map.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
            animated: true
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .systemOrange
            renderer.lineWidth = 4
            return renderer
        }
    }
}

// MARK: - Ride Detail View
struct RideDetailView: View {
    let ride: Ride
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                MapView(coordinates: ride.coordinates)
                    .ignoresSafeArea(edges: .top)
                    .frame(maxHeight: .infinity)

                VStack(spacing: 12) {
                    Text(ride.name)
                        .font(.title2).bold()
                    HStack(spacing: 30) {
                        StatView(label: "Distance", value: String(format: "%.2f mi", ride.distance))
                        StatView(label: "Date", value: ride.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Stat View
struct StatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).bold()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
