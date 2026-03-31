import SwiftUI
import MapKit

// MARK: - US State data

private struct USState: Identifiable {
    let id: String        // 2-letter abbreviation
    let name: String
    let minLat, maxLat, minLon, maxLon: Double

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta:  maxLat - minLat + 0.5,
                                   longitudeDelta: maxLon - minLon + 0.5)
        )
    }
}

private let allUSStates: [USState] = [
    USState(id: "AL", name: "Alabama",        minLat: 30.14, maxLat: 35.01, minLon: -88.47, maxLon: -84.89),
    USState(id: "AK", name: "Alaska",         minLat: 54.00, maxLat: 71.35, minLon: -168.00, maxLon: -130.00),
    USState(id: "AZ", name: "Arizona",        minLat: 31.33, maxLat: 37.00, minLon: -114.82, maxLon: -109.04),
    USState(id: "AR", name: "Arkansas",       minLat: 33.00, maxLat: 36.50, minLon: -94.62, maxLon: -89.64),
    USState(id: "CA", name: "California",     minLat: 32.53, maxLat: 42.01, minLon: -124.41, maxLon: -114.13),
    USState(id: "CO", name: "Colorado",       minLat: 36.99, maxLat: 41.00, minLon: -109.06, maxLon: -102.04),
    USState(id: "CT", name: "Connecticut",    minLat: 40.98, maxLat: 42.05, minLon: -73.73, maxLon: -71.79),
    USState(id: "DE", name: "Delaware",       minLat: 38.45, maxLat: 39.84, minLon: -75.79, maxLon: -75.05),
    USState(id: "FL", name: "Florida",        minLat: 24.54, maxLat: 31.00, minLon: -87.63, maxLon: -79.97),
    USState(id: "GA", name: "Georgia",        minLat: 30.36, maxLat: 35.00, minLon: -85.61, maxLon: -80.84),
    USState(id: "HI", name: "Hawaii",         minLat: 18.91, maxLat: 22.24, minLon: -160.25, maxLon: -154.81),
    USState(id: "ID", name: "Idaho",          minLat: 41.99, maxLat: 49.00, minLon: -117.24, maxLon: -111.04),
    USState(id: "IL", name: "Illinois",       minLat: 36.97, maxLat: 42.51, minLon: -91.51, maxLon: -87.02),
    USState(id: "IN", name: "Indiana",        minLat: 37.77, maxLat: 41.76, minLon: -88.10, maxLon: -84.78),
    USState(id: "IA", name: "Iowa",           minLat: 40.37, maxLat: 43.50, minLon: -96.64, maxLon: -90.14),
    USState(id: "KS", name: "Kansas",         minLat: 36.99, maxLat: 40.00, minLon: -102.05, maxLon: -94.59),
    USState(id: "KY", name: "Kentucky",       minLat: 36.50, maxLat: 39.15, minLon: -89.57, maxLon: -81.96),
    USState(id: "LA", name: "Louisiana",      minLat: 28.92, maxLat: 33.02, minLon: -94.04, maxLon: -88.82),
    USState(id: "ME", name: "Maine",          minLat: 43.06, maxLat: 47.46, minLon: -71.08, maxLon: -66.95),
    USState(id: "MD", name: "Maryland",       minLat: 37.91, maxLat: 39.72, minLon: -79.49, maxLon: -74.99),
    USState(id: "MA", name: "Massachusetts",  minLat: 41.24, maxLat: 42.89, minLon: -73.50, maxLon: -69.93),
    USState(id: "MI", name: "Michigan",       minLat: 41.70, maxLat: 48.31, minLon: -90.42, maxLon: -82.41),
    USState(id: "MN", name: "Minnesota",      minLat: 43.50, maxLat: 49.38, minLon: -97.24, maxLon: -89.49),
    USState(id: "MS", name: "Mississippi",    minLat: 30.17, maxLat: 35.01, minLon: -91.65, maxLon: -88.10),
    USState(id: "MO", name: "Missouri",       minLat: 35.99, maxLat: 40.61, minLon: -95.77, maxLon: -89.10),
    USState(id: "MT", name: "Montana",        minLat: 44.36, maxLat: 49.00, minLon: -116.05, maxLon: -104.04),
    USState(id: "NE", name: "Nebraska",       minLat: 40.00, maxLat: 43.00, minLon: -104.05, maxLon: -95.31),
    USState(id: "NV", name: "Nevada",         minLat: 35.00, maxLat: 42.00, minLon: -120.00, maxLon: -114.04),
    USState(id: "NH", name: "New Hampshire",  minLat: 42.70, maxLat: 45.31, minLon: -72.56, maxLon: -70.61),
    USState(id: "NJ", name: "New Jersey",     minLat: 38.93, maxLat: 41.36, minLon: -75.56, maxLon: -73.89),
    USState(id: "NM", name: "New Mexico",     minLat: 31.33, maxLat: 37.00, minLon: -109.05, maxLon: -103.00),
    USState(id: "NY", name: "New York",       minLat: 40.50, maxLat: 45.01, minLon: -79.76, maxLon: -71.86),
    USState(id: "NC", name: "North Carolina", minLat: 33.84, maxLat: 36.59, minLon: -84.32, maxLon: -75.46),
    USState(id: "ND", name: "North Dakota",   minLat: 45.94, maxLat: 49.00, minLon: -104.05, maxLon: -96.55),
    USState(id: "OH", name: "Ohio",           minLat: 38.40, maxLat: 42.32, minLon: -84.82, maxLon: -80.52),
    USState(id: "OK", name: "Oklahoma",       minLat: 33.62, maxLat: 37.00, minLon: -103.00, maxLon: -94.43),
    USState(id: "OR", name: "Oregon",         minLat: 41.99, maxLat: 46.27, minLon: -124.55, maxLon: -116.46),
    USState(id: "PA", name: "Pennsylvania",   minLat: 39.72, maxLat: 42.27, minLon: -80.52, maxLon: -74.69),
    USState(id: "RI", name: "Rhode Island",   minLat: 41.15, maxLat: 42.01, minLon: -71.86, maxLon: -71.12),
    USState(id: "SC", name: "South Carolina", minLat: 32.05, maxLat: 35.22, minLon: -83.35, maxLon: -78.54),
    USState(id: "SD", name: "South Dakota",   minLat: 42.48, maxLat: 45.94, minLon: -104.06, maxLon: -96.44),
    USState(id: "TN", name: "Tennessee",      minLat: 34.98, maxLat: 36.68, minLon: -90.31, maxLon: -81.65),
    USState(id: "TX", name: "Texas",          minLat: 25.84, maxLat: 36.50, minLon: -106.65, maxLon: -93.51),
    USState(id: "UT", name: "Utah",           minLat: 36.99, maxLat: 42.00, minLon: -114.05, maxLon: -109.04),
    USState(id: "VT", name: "Vermont",        minLat: 42.73, maxLat: 45.02, minLon: -73.44, maxLon: -71.46),
    USState(id: "VA", name: "Virginia",       minLat: 36.54, maxLat: 39.47, minLon: -83.68, maxLon: -75.24),
    USState(id: "WA", name: "Washington",     minLat: 45.54, maxLat: 49.00, minLon: -124.73, maxLon: -116.92),
    USState(id: "WV", name: "West Virginia",  minLat: 37.20, maxLat: 40.64, minLon: -82.64, maxLon: -77.72),
    USState(id: "WI", name: "Wisconsin",      minLat: 42.49, maxLat: 47.31, minLon: -92.89, maxLon: -86.25),
    USState(id: "WY", name: "Wyoming",        minLat: 40.99, maxLat: 45.01, minLon: -111.06, maxLon: -104.05),
]

// MARK: - Main Offline Maps View

struct OfflineMapsView: View {
    @ObservedObject var manager: OfflineMapManager
    var mapViewRef: MKMapView?
    var currentLocation: CLLocation? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showingAddRegion = false
    @State private var selectMode       = false
    @State private var selectedIDs:     Set<UUID> = []
    @State private var showDeleteAllConfirm = false

    var body: some View {
        NavigationStack {
            List {
                regionsSection
                storageSection
            }
            .navigationTitle("Offline Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                if selectMode { deleteSelectionBar }
            }
            .sheet(isPresented: $showingAddRegion) {
                AddRegionView(manager: manager, mapViewRef: mapViewRef,
                              currentLocation: currentLocation)
            }
            .confirmationDialog(
                "Delete \(selectedIDs.count) region\(selectedIDs.count == 1 ? "" : "s")?",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteSelected() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Tile data will be removed from your device.")
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if selectMode {
                Button("Cancel") { exitSelectMode() }
            } else {
                Button("Done") { dismiss() }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if selectMode {
                // "Select All" / "Deselect All" toggle
                Button(selectedIDs.count == manager.regions.count ? "Deselect All" : "Select All") {
                    if selectedIDs.count == manager.regions.count {
                        selectedIDs = []
                    } else {
                        selectedIDs = Set(manager.regions.map { $0.id })
                    }
                }
                .font(.subheadline)
            } else {
                HStack(spacing: 16) {
                    if !manager.regions.isEmpty {
                        Button("Select") { selectMode = true }
                            .font(.subheadline)
                    }
                    Button { showingAddRegion = true } label: { Image(systemName: "plus") }
                        .disabled(manager.activeDownloadID != nil)
                }
            }
        }
    }

    // MARK: Status section

    @ViewBuilder private var statusSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(manager.useTilesForNavigation ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: manager.useTilesForNavigation ? "map.fill" : "map")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(manager.useTilesForNavigation ? .blue : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Offline Tiles")
                        .font(.subheadline.weight(.medium))
                    Text(manager.useTilesForNavigation
                         ? "Using OSM tiles — works without cell service"
                         : "Using Apple Maps — requires data connection")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $manager.useTilesForNavigation).labelsHidden()
            }
            .padding(.vertical, 4)
        } header: { Text("Navigation Tiles") }
          footer: { Text("When enabled, the map uses OpenStreetMap tiles cached locally — available offline for downloaded regions.") }
    }

    // MARK: Regions section

    @ViewBuilder private var regionsSection: some View {
        Section {
            if manager.regions.isEmpty {
                Label("No regions downloaded yet. Tap + to add one.", systemImage: "arrow.down.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(manager.regions) { region in
                    let isSelected = selectedIDs.contains(region.id)
                    Button {
                        if selectMode {
                            if isSelected { selectedIDs.remove(region.id) }
                            else          { selectedIDs.insert(region.id) }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Checkbox — only shown in select mode
                            if selectMode {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(isSelected ? .red : Color.secondary.opacity(0.5))
                                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                            }
                            RegionRow(region: region, manager: manager)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        isSelected && selectMode
                            ? Color.red.opacity(0.06)
                            : Color.clear
                    )
                }
                .onDelete { idxs in
                    guard !selectMode else { return }
                    idxs.forEach { manager.deleteRegion(id: manager.regions[$0].id) }
                }
            }
        } header: {
            HStack {
                Text("Downloaded Regions")
                if selectMode && !selectedIDs.isEmpty {
                    Spacer()
                    Text("\(selectedIDs.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Storage section

    @ViewBuilder private var storageSection: some View {
        Section("Storage") {
            HStack {
                Label("Tiles on Disk", systemImage: "internaldrive")
                Spacer()
                Text(String(format: "%.1f MB", manager.totalDiskUsageMB))
                    .foregroundStyle(.secondary)
            }
            if !manager.regions.isEmpty && !selectMode {
                Button(role: .destructive) {
                    manager.regions.forEach { manager.deleteRegion(id: $0.id) }
                } label: {
                    Label("Delete All Downloaded Maps", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Bottom delete bar (select mode)

    private var deleteSelectionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                if selectedIDs.isEmpty {
                    Text("Tap maps to select")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    Button(role: .destructive) {
                        showDeleteAllConfirm = true
                    } label: {
                        Label(
                            "Delete \(selectedIDs.count) Map\(selectedIDs.count == 1 ? "" : "s")",
                            systemImage: "trash"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Helpers

    private func deleteSelected() {
        selectedIDs.forEach { manager.deleteRegion(id: $0) }
        exitSelectMode()
    }

    private func exitSelectMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectMode  = false
            selectedIDs = []
        }
    }
}

// MARK: - Region Row

private struct RegionRow: View {
    let region: OfflineRegion
    @ObservedObject var manager: OfflineMapManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(region.name).font(.subheadline.weight(.medium))
                    subtitleText
                }
                Spacer()
                statusBadge
            }
            if region.status == .downloading {
                VStack(spacing: 3) {
                    ProgressView(value: region.progress).tint(.blue)
                    HStack {
                        Text(String(format: "%.0f%%  ·  %d / %d tiles",
                                    region.progress * 100,
                                    region.downloadedTiles, region.totalTiles))
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        if manager.estimatedSecondsRemaining > 0 {
                            Text(etaText(manager.estimatedSecondsRemaining) + " left")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Button(role: .destructive) { manager.cancelDownload() } label: {
                    Label("Cancel Download", systemImage: "xmark.circle")
                        .font(.caption).foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else if region.status == .failed || region.status == .cancelled {
                Button { manager.retryDownload(id: region.id) } label: {
                    Label("Retry Download", systemImage: "arrow.clockwise")
                        .font(.caption).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitleText: some View {
        Group {
            if region.isComplete, let d = region.downloadDate {
                Text("\(region.quality.rawValue) · \(region.totalTiles) tiles · \(d.formatted(.relative(presentation: .named)))")
            } else {
                Text("\(region.quality.rawValue) · ~\(String(format: "%.0f", region.estimatedMB)) MB")
            }
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder private var statusBadge: some View {
        switch region.status {
        case .completed:   Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .downloading: ProgressView().scaleEffect(0.8)
        case .failed:      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .cancelled:   Image(systemName: "minus.circle").foregroundStyle(.secondary)
        case .pending:     Image(systemName: "clock").foregroundStyle(.secondary)
        }
    }

    private func etaText(_ s: Double) -> String {
        let n = Int(s)
        if n < 60   { return "\(n)s" }
        if n < 3600 { return "\(n / 60)m" }
        return "\(n / 3600)h \((n % 3600) / 60)m"
    }
}

// MARK: - Add Region View

struct AddRegionView: View {
    @ObservedObject var manager: OfflineMapManager
    var mapViewRef: MKMapView?
    var currentLocation: CLLocation? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var searchText     = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching    = false
    @State private var searchTask: Task<Void, Never>?

    @State private var selectedRegion: MKCoordinateRegion?
    @State private var selectedName   = ""
    @State private var isStatePack    = false       // true when a whole state is selected
    @State private var quality        = TileQuality.standard
    @State private var tileEstimate   = 0
    @State private var sizeMB         = 0.0

    private var filteredStates: [USState] {
        guard !searchText.isEmpty else { return allUSStates }
        let q = searchText.lowercased()
        return allUSStates.filter { $0.name.lowercased().contains(q) || $0.id.lowercased() == q }
    }

    var body: some View {
        NavigationStack {
            List {
                if !searchResults.isEmpty  { searchResultsSection }
                if searchText.isEmpty      { nearbySection }
                if searchText.isEmpty, mapViewRef != nil { currentViewSection }
                statesSection
                if selectedRegion != nil   { configSection }
            }
            .navigationTitle("Download Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "City, state, or region name…")
            .overlay {
                if isSearching { ProgressView().padding(.top, 120) }
            }
            .safeAreaInset(edge: .bottom) {
                if selectedRegion != nil { downloadBar }
            }
            .onChange(of: searchText) { _, q in
                searchTask?.cancel()
                guard !q.isEmpty else { searchResults = []; return }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(280))
                    guard !Task.isCancelled else { return }
                    await performSearch(q)
                }
            }
            .onChange(of: quality) { _, _ in recompute() }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var searchResultsSection: some View {
        Section("Places") {
            ForEach(searchResults, id: \.self) { item in
                Button { selectItem(item) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.red).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "").font(.subheadline).foregroundStyle(.primary)
                            if let sub = item.placemark.title, sub != item.name, !sub.isEmpty {
                                Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var nearbySection: some View {
        Section {
            if let loc = currentLocation {
                ForEach([("Nearby (~35 mi)", 0.5), ("Local region (~75 mi)", 1.1), ("Extended (~150 mi)", 2.2)], id: \.0) { label, deg in
                    Button { selectNearby(loc.coordinate, degrees: deg, label: label) } label: {
                        nearbyRow(label: label, coord: loc.coordinate, degrees: deg)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Label("GPS unavailable — search by name above", systemImage: "location.slash")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } header: { Text("Nearby Your Location") }
    }

    private func nearbyRow(label: String, coord: CLLocationCoordinate2D, degrees: Double) -> some View {
        let h  = degrees / 2
        let n  = manager.estimateTileCount(minLat: coord.latitude - h, maxLat: coord.latitude + h,
                                            minLon: coord.longitude - h, maxLon: coord.longitude + h,
                                            quality: quality)
        let mb = Double(n) * 15 / 1024
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: "location.fill").font(.system(size: 14)).foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.medium))
                Text("~\(String(format: "%.0f", mb)) MB").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder private var currentViewSection: some View {
        Section {
            Button {
                guard let r = mapViewRef?.region else { return }
                selectedRegion = r
                selectedName   = "Current Map View"
                isStatePack    = false
                recompute()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.12)).frame(width: 36, height: 36)
                        Image(systemName: "crop").font(.system(size: 14)).foregroundStyle(.purple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Current Map View").font(.subheadline.weight(.medium))
                        Text("Exact area visible on screen").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var statesSection: some View {
        Section {
            ForEach(filteredStates) { state in
                Button { selectState(state) } label: {
                    HStack(spacing: 12) {
                        Text(state.id)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.orange.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.name).font(.subheadline.weight(.medium))
                            Text(stateEstimateLabel(state)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedName == state.name {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        } else {
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("US States")
        } footer: {
            Text("Large states hit the \(OfflineMapManager.maxTiles / 1000)k tile cap. Use Standard quality for full coverage.")
        }
    }

    @ViewBuilder private var configSection: some View {
        if let r = selectedRegion {
            Section {
                RegionMapPreview(region: r)
                    .frame(height: 150)
                    .listRowInsets(EdgeInsets())

                Picker("Quality", selection: $quality) {
                    ForEach(TileQuality.allCases) { q in
                        VStack(alignment: .leading) {
                            Text(q.rawValue)
                            Text(q.subtitle).font(.caption2).foregroundStyle(.secondary)
                        }
                        .tag(q)
                    }
                }
                .pickerStyle(.inline)

            } header: {
                HStack {
                    Text(selectedName)
                    Spacer()
                    Button("Change") { selectedRegion = nil; selectedName = "" }
                        .font(.caption).foregroundStyle(.blue)
                }
            } footer: {
                sizeFooter
            }
        }
    }

    @ViewBuilder private var sizeFooter: some View {
        if tileEstimate > 0 {
            if tileEstimate >= OfflineMapManager.maxTiles {
                Label("Capped at \(OfflineMapManager.maxTiles / 1000)k tiles (~\(String(format: "%.0f", sizeMB)) MB). Lower zoom levels downloaded first.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.caption)
            } else {
                Text("\(tileEstimate) tiles · ~\(String(format: "%.0f", sizeMB)) MB")
                    .font(.caption)
            }
        }
    }

    // MARK: - Bottom download bar

    private var downloadBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                guard let r = selectedRegion else { return }
                let minLat = r.center.latitude  - r.span.latitudeDelta  / 2
                let maxLat = r.center.latitude  + r.span.latitudeDelta  / 2
                let minLon = r.center.longitude - r.span.longitudeDelta / 2
                let maxLon = r.center.longitude + r.span.longitudeDelta / 2
                manager.addAndDownload(
                    name: selectedName.isEmpty ? "Downloaded Region" : selectedName,
                    minLat: minLat, maxLat: maxLat,
                    minLon: minLon, maxLon: maxLon,
                    quality: quality
                )
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Download \(selectedName)")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1).minimumScaleFactor(0.75)
                        if tileEstimate > 0 {
                            Text("~\(String(format: "%.0f", sizeMB)) MB · \(min(tileEstimate, OfflineMapManager.maxTiles)) tiles")
                                .font(.caption).opacity(0.85)
                        }
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func selectState(_ state: USState) {
        selectedRegion = state.region
        selectedName   = state.name
        isStatePack    = true
        recompute()
    }

    private func selectNearby(_ coord: CLLocationCoordinate2D, degrees: Double, label: String) {
        selectedRegion = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: degrees, longitudeDelta: degrees)
        )
        selectedName = label
        isStatePack  = false
        recompute()
    }

    private func selectItem(_ item: MKMapItem) {
        selectedRegion = MKCoordinateRegion(
            center: item.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 1.1, longitudeDelta: 1.1)
        )
        selectedName  = item.name ?? item.placemark.locality ?? "Selected Area"
        isStatePack   = false
        searchResults = []
        searchText    = ""
        recompute()
    }

    private func recompute() {
        guard let r = selectedRegion else { return }
        let minLat = r.center.latitude  - r.span.latitudeDelta  / 2
        let maxLat = r.center.latitude  + r.span.latitudeDelta  / 2
        let minLon = r.center.longitude - r.span.longitudeDelta / 2
        let maxLon = r.center.longitude + r.span.longitudeDelta / 2
        tileEstimate = manager.estimateTileCount(minLat: minLat, maxLat: maxLat,
                                                  minLon: minLon, maxLon: maxLon, quality: quality)
        sizeMB = Double(min(tileEstimate, OfflineMapManager.maxTiles)) * 15 / 1024
    }

    private func stateEstimateLabel(_ state: USState) -> String {
        let n = manager.estimateTileCount(minLat: state.minLat, maxLat: state.maxLat,
                                           minLon: state.minLon, maxLon: state.maxLon,
                                           quality: .standard)
        let capped = min(n, OfflineMapManager.maxTiles)
        let mb = Double(capped) * 15 / 1024
        return n > OfflineMapManager.maxTiles
            ? "Capped ~\(String(format: "%.0f", mb)) MB (20k tile limit)"
            : "~\(String(format: "%.0f", mb)) MB"
    }

    private func performSearch(_ query: String) async {
        isSearching = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.resultTypes          = [.address, .pointOfInterest]
        if let loc = currentLocation {
            req.region = MKCoordinateRegion(center: loc.coordinate,
                                             latitudinalMeters: 1_000_000,
                                             longitudinalMeters: 1_000_000)
        }
        searchResults = Array(((try? await MKLocalSearch(request: req).start())?.mapItems ?? []).prefix(6))
        isSearching   = false
    }
}

// MARK: - Region map preview

private struct RegionMapPreview: UIViewRepresentable {
    let region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isUserInteractionEnabled = false
        map.isScrollEnabled = false
        map.isZoomEnabled   = false
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.setRegion(region, animated: false)
        map.removeOverlays(map.overlays)
        let c = region.center, s = region.span
        let box: [CLLocationCoordinate2D] = [
            .init(latitude: c.latitude - s.latitudeDelta/2, longitude: c.longitude - s.longitudeDelta/2),
            .init(latitude: c.latitude + s.latitudeDelta/2, longitude: c.longitude - s.longitudeDelta/2),
            .init(latitude: c.latitude + s.latitudeDelta/2, longitude: c.longitude + s.longitudeDelta/2),
            .init(latitude: c.latitude - s.latitudeDelta/2, longitude: c.longitude + s.longitudeDelta/2),
            .init(latitude: c.latitude - s.latitudeDelta/2, longitude: c.longitude - s.longitudeDelta/2),
        ]
        map.addOverlay(MKPolyline(coordinates: box, count: box.count))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let p = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: p)
            r.strokeColor = UIColor.systemBlue
            r.lineWidth   = 2
            r.lineDashPattern = [6, 4]
            return r
        }
    }
}
