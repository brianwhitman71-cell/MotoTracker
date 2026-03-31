import SwiftUI
import MapKit

// MARK: - POI Layer Filter Sheet
// (opened by the POI button on the map — same pattern as calimoto's layer panel)

struct MotoPOIFilterView: View {
    @ObservedObject var manager: MotoPOIManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                masterToggleSection
                categorySection
                hintSection
            }
            .navigationTitle("Moto Points of Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    @ViewBuilder private var masterToggleSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(manager.showPOIs ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(manager.showPOIs ? .orange : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show on Map")
                        .font(.subheadline.weight(.medium))
                    Text(manager.showPOIs
                         ? "Moto POIs visible — zoom in to load"
                         : "Tap to show motorcycle-specific places")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $manager.showPOIs)
                    .labelsHidden()
                    .onChange(of: manager.showPOIs) { _, on in
                        if on { manager.updateRegion(manager.currentRegionForRefetch) }
                        else  { manager.visiblePOIs = [] }
                    }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private var categorySection: some View {
        Section {
            ForEach(MotoPOICategory.allCases) { category in
                let enabled = manager.enabledCategories.contains(category)
                Button {
                    if enabled {
                        manager.enabledCategories.remove(category)
                    } else {
                        manager.enabledCategories.insert(category)
                    }
                    manager.saveEnabledCategories()
                } label: {
                    HStack(spacing: 14) {
                        // Category badge
                        ZStack {
                            Circle()
                                .fill(enabled ? category.color : Color.secondary.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: category.sfSymbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(enabled ? .white : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(category.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(enabled ? category.color : Color.secondary.opacity(0.4))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!manager.showPOIs)
                .opacity(manager.showPOIs ? 1 : 0.45)
            }
        } header: {
            Text("Categories")
        }
    }

    @ViewBuilder private var hintSection: some View {
        Section {
            Label("POIs load from OpenStreetMap as you browse. Zoom in to \(String(format: "~%.0f", 100))+ mi view for results.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }
}

// MARK: - POI Detail Sheet

struct MotoPOIDetailView: View {
    let poi: MotoPOI
    var onNavigate: ((MotoPOI) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero header
                    heroHeader
                        .padding(.bottom, 20)

                    VStack(spacing: 12) {
                        infoCards
                        if poi.phone != nil || poi.website != nil {
                            contactCard
                        }
                        navigateButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Hero

    private var heroHeader: some View {
        VStack(spacing: 14) {
            // Large category icon
            ZStack {
                Circle()
                    .fill(poi.category.color.opacity(0.12))
                    .frame(width: 80, height: 80)
                Circle()
                    .strokeBorder(poi.category.color.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                Image(systemName: poi.category.sfSymbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(poi.category.color)
            }
            .padding(.top, 24)

            VStack(spacing: 6) {
                Text(poi.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                // Category pill
                HStack(spacing: 5) {
                    Image(systemName: poi.category.sfSymbol)
                        .font(.system(size: 11, weight: .semibold))
                    Text(poi.category.rawValue)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(poi.category.color)
                .clipShape(Capsule())

                // Moto-friendly badge
                if poi.isMotoFriendly {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                        Text("Motorcycle Friendly")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: Info cards

    @ViewBuilder private var infoCards: some View {
        VStack(spacing: 10) {
            // Elevation for mountain passes
            if poi.category == .mountainPass, let elev = poi.elevation {
                infoRow(icon: "arrow.up.and.line.horizontal.and.arrow.down",
                        label: "Elevation",
                        value: "\(Int(Double(elev) * 3.28084)) ft  /  \(elev) m",
                        color: poi.category.color)
            }

            // Subtitle / location
            if let sub = poi.subtitle {
                infoRow(icon: "mappin.circle.fill",
                        label: "Location",
                        value: sub,
                        color: .secondary)
            }

            // Coordinates
            let lat = poi.latitude
            let lon = poi.longitude
            infoRow(icon: "globe",
                    label: "Coordinates",
                    value: String(format: "%.5f, %.5f", lat, lon),
                    color: .secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
        }
    }

    // MARK: Contact card

    @ViewBuilder private var contactCard: some View {
        VStack(spacing: 0) {
            if let phone = poi.phone {
                Link(destination: URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.green)
                            .frame(width: 22)
                        Text(phone)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }
                if poi.website != nil { Divider().padding(.leading, 48) }
            }

            if let site = poi.website, let url = URL(string: site) {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.blue)
                            .frame(width: 22)
                        Text(site
                            .replacingOccurrences(of: "https://", with: "")
                            .replacingOccurrences(of: "http://",  with: ""))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Navigate button

    private var navigateButton: some View {
        Button {
            onNavigate?(poi)
            dismiss()
        } label: {
            Label("Navigate Here", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }
    }
}

// MARK: - Map POI button (right-side floating button, calimoto style)

struct MotoPOIMapButton: View {
    @ObservedObject var manager: MotoPOIManager
    var onTap: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack(alignment: .topTrailing) {
                    Button { onTap() } label: {
                        ZStack {
                            Circle()
                                .fill(manager.showPOIs
                                      ? Color.orange
                                      : Color(.systemBackground).opacity(0.92))
                                .frame(width: 44, height: 44)
                                .shadow(radius: 3, y: 1)
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(manager.showPOIs ? .white : .primary)
                            // Spinning fetch ring
                            if manager.isFetching {
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(Color.orange, lineWidth: 2.5)
                                    .frame(width: 44, height: 44)
                                    .rotationEffect(.degrees(manager.isFetching ? 360 : 0))
                                    .animation(
                                        .linear(duration: 0.9).repeatForever(autoreverses: false),
                                        value: manager.isFetching
                                    )
                            }
                        }
                    }

                    // Active-category count badge
                    if manager.showPOIs {
                        Text("\(manager.enabledCategories.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.trailing, 14)
            .padding(.bottom, 110)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
