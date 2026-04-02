import SwiftUI
import MapKit
import AVFoundation

// MARK: - Settings Menu (root)
struct SettingsView: View {
    @ObservedObject var routeManager: RouteManager
    var mapViewRef: MKMapView? = nil
    var currentLocation: CLLocation? = nil
    @Environment(\.dismiss) var dismiss
    @State private var showingBugReport = false

    var body: some View {
        NavigationStack {
            List {

                Section("Voice") {
                    NavigationLink {
                        VoiceSettingsView(routeManager: routeManager)
                    } label: {
                        Label("Navigation Voice", systemImage: "waveform")
                    }

                    NavigationLink {
                        SoundModeView(routeManager: routeManager)
                    } label: {
                        Label("Sound Mode", systemImage: "speaker.wave.2")
                    }

                    NavigationLink {
                        DirectionFrequencyView(routeManager: routeManager)
                    } label: {
                        Label("Direction Frequency", systemImage: "arrow.triangle.turn.up.right.road.fill")
                    }
                }

                Section("General") {
                    NavigationLink {
                        UnitsSettingsView(routeManager: routeManager)
                    } label: {
                        Label("Units of Measure", systemImage: "ruler")
                    }

                    NavigationLink {
                        WebRoutePlannerView()
                    } label: {
                        Label("Web Route Planner", systemImage: "globe")
                    }

                    Toggle(isOn: $routeManager.simulationMode) {
                        Label("Simulate Driving", systemImage: "figure.motorcycle")
                    }
                    .tint(.orange)
                }

                Section("Safety") {
                    NavigationLink {
                        CrashDetectionSettingsView()
                    } label: {
                        Label("Crash Detection", systemImage: "exclamationmark.triangle.fill")
                    }
                }

                Section("Maps") {
                    NavigationLink {
                        OfflineMapsView(manager: OfflineMapManager.shared, mapViewRef: mapViewRef,
                                        currentLocation: currentLocation)
                    } label: {
                        HStack {
                            Label("Offline Maps", systemImage: "arrow.down.circle.fill")
                            Spacer()
                            if !OfflineMapManager.shared.regions.filter(\.isComplete).isEmpty {
                                Text("\(OfflineMapManager.shared.regions.filter(\.isComplete).count) region\(OfflineMapManager.shared.regions.filter(\.isComplete).count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    Button {
                        showingBugReport = true
                    } label: {
                        Label("Report a Bug", systemImage: "ladybug")
                            .foregroundStyle(.primary)
                    }
                }

            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingBugReport) {
                BugReportView()
            }
        }
    }
}

// MARK: - Web Route Planner
private struct WebRoutePlannerView: View {
    private let plannerURL = URL(string: "https://brianwhitman71-cell.github.io/MotoTracker/WebPlanner/")!

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Plan routes on any computer or tablet using a full-screen map, then send them directly to this app with a tap.")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.top, 4)

                    Divider()

                    Text("Web Planner URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(plannerURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 6)
            } header: {
                Text("Plan on Your Computer")
            } footer: {
                Text("Open the URL above in any browser. Build your route, then tap \"Send to Phone\" — it will open automatically in 2Wheel Tracker.")
            }

            Section {
                Link(destination: plannerURL) {
                    HStack {
                        Spacer()
                        Label("Open Web Planner", systemImage: "safari")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Web Route Planner")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About
private struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }
    private var deployedAt: String {
        guard let raw = Bundle.main.infoDictionary?["DeployedAt"] as? String else { return "–" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        guard let date = formatter.date(from: raw) else { return raw }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: date)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Build", value: build)
                LabeledContent("Deployed", value: deployedAt)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Voice Settings
private struct VoiceSettingsView: View {
    @ObservedObject var routeManager: RouteManager

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tap a voice to select it. Tap the speaker icon to preview without selecting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(VoiceOption.defaults) { option in
                            VoiceOptionButton(
                                option: option,
                                isSelected: routeManager.selectedVoice == option,
                                onSelect: { routeManager.selectedVoice = option },
                                onPreview: { routeManager.previewVoice(option) }
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("Choose Voice", systemImage: "person.wave.2")
            }

        }
        .navigationTitle("Navigation Voice")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Direction Frequency
private struct DirectionFrequencyView: View {
    @ObservedObject var routeManager: RouteManager

    var body: some View {
        List {
            ForEach(DirectionFrequency.allCases) { freq in
                Button { routeManager.directionFrequency = freq } label: {
                    HStack(spacing: 14) {
                        Image(systemName: freq.icon)
                            .font(.system(size: 17))
                            .foregroundStyle(routeManager.directionFrequency == freq ? .blue : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(freq.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(freq.subtitle(imperial: routeManager.units == .imperial))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if routeManager.directionFrequency == freq {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Direction Frequency")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sound Mode
private struct SoundModeView: View {
    @ObservedObject var routeManager: RouteManager

    var body: some View {
        List {
            ForEach(VoiceMode.allCases) { mode in
                Button { routeManager.voiceMode = mode } label: {
                    HStack(spacing: 14) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 17))
                            .foregroundStyle(routeManager.voiceMode == mode ? .blue : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.label)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(soundModeSubtitle(mode))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if routeManager.voiceMode == mode {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Sound Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func soundModeSubtitle(_ mode: VoiceMode) -> String {
        switch mode {
        case .soundOn:    return "All directions and alerts spoken aloud"
        case .alertsOnly: return "Only hazard alerts, no turn directions"
        case .soundOff:   return "Silent — no voice output at all"
        }
    }
}

// MARK: - Units of Measure
private struct UnitsSettingsView: View {
    @ObservedObject var routeManager: RouteManager

    var body: some View {
        List {
            ForEach(UnitsOfMeasure.allCases) { unit in
                Button { routeManager.units = unit } label: {
                    HStack(spacing: 14) {
                        Image(systemName: unit.icon)
                            .font(.system(size: 17))
                            .foregroundStyle(routeManager.units == unit ? .blue : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(unit.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(unit.distanceUnit) · \(unit.speedUnit)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if routeManager.units == unit {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Units of Measure")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Voice Option Button
struct VoiceOptionButton: View {
    let option: VoiceOption
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                // Main tap area — selects voice
                Button(action: onSelect) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
                            .frame(height: 80)
                        VStack(spacing: 4) {
                            VoiceAvatarView(option: option, size: 48)
                            Text(option.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Play preview button — bottom-right corner
                Button(action: onPreview) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .padding(5)
                        .background(isSelected ? Color.white.opacity(0.9) : Color(.systemBackground).opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(5)
            }

            Text(option.accent)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Voice Avatar View
struct VoiceAvatarView: View {
    let option: VoiceOption
    let size: CGFloat

    private var hair:   Color { Color(hex: option.hairHex)   ?? .brown  }
    private var skin:   Color { Color(hex: option.skinHex)   ?? .orange }
    private var shirt:  Color { Color(hex: option.accentHex) ?? .blue   }
    private var isMale: Bool  { option.name == "Daniel" || option.name == "Wyatt" }

    // Face is centered slightly above mid to leave room for shirt at bottom
    private let faceOffsetY: CGFloat = -0.10

    var body: some View {
        ZStack {
            // ── Background: shirt color fills circle ──────────────────────
            Circle().fill(shirt)

            // ── Hair (drawn BEFORE face so face covers lower hair) ─────────
            hairLayer

            // ── Face / head ───────────────────────────────────────────────
            Ellipse()
                .fill(skin)
                .frame(width: size * 0.50, height: size * 0.58)
                .offset(y: size * faceOffsetY)

            // ── Eyebrows ──────────────────────────────────────────────────
            HStack(spacing: size * 0.12) {
                Capsule()
                    .fill(hair.opacity(0.85))
                    .frame(width: size * 0.12, height: size * 0.028)
                    .rotationEffect(.degrees(isMale ? -4 : -7))
                Capsule()
                    .fill(hair.opacity(0.85))
                    .frame(width: size * 0.12, height: size * 0.028)
                    .rotationEffect(.degrees(isMale ? 4 : 7))
            }
            .offset(y: size * (faceOffsetY - 0.13))

            // ── Eyes ─────────────────────────────────────────────────────
            HStack(spacing: size * 0.12) {
                AvatarEye(size: size)
                AvatarEye(size: size)
            }
            .offset(y: size * (faceOffsetY - 0.05))

            // ── Female: lash line ─────────────────────────────────────────
            if !isMale {
                HStack(spacing: size * 0.12) {
                    Capsule()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: size * 0.135, height: size * 0.016)
                    Capsule()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: size * 0.135, height: size * 0.016)
                }
                .offset(y: size * (faceOffsetY - 0.07))
            }

            // ── Nose ─────────────────────────────────────────────────────
            Capsule()
                .fill(skin.darkened(0.10))
                .frame(width: size * 0.05, height: size * 0.09)
                .offset(y: size * (faceOffsetY + 0.04))

            // ── Mouth ────────────────────────────────────────────────────
            AvatarSmile(size: size)
                .stroke(skin.darkened(0.22), lineWidth: size * 0.028)
                .frame(width: size * 0.20, height: size * 0.07)
                .offset(y: size * (faceOffsetY + 0.15))

            // ── Female: cheek blush ───────────────────────────────────────
            if !isMale {
                HStack(spacing: size * 0.20) {
                    Ellipse()
                        .fill(Color.pink.opacity(0.20))
                        .frame(width: size * 0.11, height: size * 0.07)
                    Ellipse()
                        .fill(Color.pink.opacity(0.20))
                        .frame(width: size * 0.11, height: size * 0.07)
                }
                .offset(y: size * (faceOffsetY + 0.08))
            }

            // ── Daniel: glasses ───────────────────────────────────────────
            if option.name == "Daniel" {
                AvatarGlasses(size: size)
                    .stroke(Color(hex: "#2C1A0A")!.opacity(0.65), lineWidth: size * 0.026)
                    .offset(y: size * (faceOffsetY - 0.05))
            }

            // ── Bubba: mustache + cowboy hat ──────────────────────────────
            if option.name == "Wyatt" {
                AvatarMustache(size: size)
                    .fill(hair.darkened(0.05))
                    .offset(y: size * (faceOffsetY + 0.09))

                // Hat sits at the very top of the circle (partially clipped)
                BubbaHat(size: size)
            }

            // ── Neck ─────────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 3)
                .fill(skin)
                .frame(width: size * 0.17, height: size * 0.14)
                .offset(y: size * (faceOffsetY + 0.30))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    // ── Hair Layer ────────────────────────────────────────────────────────
    @ViewBuilder private var hairLayer: some View {
        if option.name == "Wyatt" {
            // Hat covers the hair — just show dark roots at temples
            EmptyView()
        } else if isMale {
            // Short male hair: compact cap sitting above the face
            Ellipse()
                .fill(hair)
                .frame(width: size * 0.54, height: size * 0.30)
                .offset(y: size * (faceOffsetY - 0.24))
        } else {
            ZStack {
                // Top mass (wider than face → shows above and slightly over face top)
                Ellipse()
                    .fill(hair)
                    .frame(width: size * 0.66, height: size * 0.44)
                    .offset(y: size * (faceOffsetY - 0.22))
                // Left side strand (shows beside face)
                RoundedRectangle(cornerRadius: size * 0.07)
                    .fill(hair)
                    .frame(width: size * 0.16, height: size * 0.50)
                    .offset(x: -size * 0.27, y: size * (faceOffsetY + 0.04))
                // Right side strand
                RoundedRectangle(cornerRadius: size * 0.07)
                    .fill(hair)
                    .frame(width: size * 0.16, height: size * 0.50)
                    .offset(x:  size * 0.27, y: size * (faceOffsetY + 0.04))
            }
        }
    }
}

// MARK: - Sub-shapes

private struct AvatarEye: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: size * 0.11, height: size * 0.085)
            Circle()
                .fill(Color(.darkGray))
                .frame(width: size * 0.065, height: size * 0.065)
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.024)
                .offset(x: size * 0.016, y: -size * 0.016)
        }
    }
}

private struct AvatarSmile: Shape {
    let size: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: 0),
                       control: CGPoint(x: rect.midX, y: rect.height))
        return p
    }
}

// MARK: - Cowboy Hat (Bubba)
private struct BubbaHat: View {
    let size: CGFloat

    private let hatTan   = Color(red: 0.76, green: 0.60, blue: 0.36)
    private let hatDark  = Color(red: 0.52, green: 0.38, blue: 0.18)
    private let hatLight = Color(red: 0.88, green: 0.76, blue: 0.54)

    var body: some View {
        ZStack {
            CrownShape(size: size)
                .fill(hatTan)
                .frame(width: size * 0.48, height: size * 0.32)
                .offset(y: -(size * 0.50 - size * 0.16))

            CrownShape(size: size)
                .fill(hatLight.opacity(0.55))
                .frame(width: size * 0.15, height: size * 0.28)
                .offset(x: -size * 0.08, y: -(size * 0.50 - size * 0.14))

            CrownShape(size: size)
                .fill(hatDark.opacity(0.35))
                .frame(width: size * 0.12, height: size * 0.28)
                .offset(x:  size * 0.12, y: -(size * 0.50 - size * 0.14))

            Capsule()
                .fill(hatDark)
                .frame(width: size * 0.48, height: size * 0.05)
                .offset(y: -(size * 0.50 - size * 0.34))

            Ellipse()
                .fill(hatTan)
                .frame(width: size * 0.82, height: size * 0.12)
                .offset(y: -(size * 0.50 - size * 0.38))

            Ellipse()
                .fill(hatDark.opacity(0.40))
                .frame(width: size * 0.82, height: size * 0.05)
                .offset(y: -(size * 0.50 - size * 0.42))

            Ellipse()
                .fill(hatLight.opacity(0.45))
                .frame(width: size * 0.70, height: size * 0.06)
                .offset(y: -(size * 0.50 - size * 0.36))
        }
    }
}

private struct CrownShape: Shape {
    let size: CGFloat
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        p.addCurve(to: CGPoint(x: w, y: h),
                   control1: CGPoint(x: w * 0.05, y: h),
                   control2: CGPoint(x: w * 0.95, y: h))
        p.addCurve(to: CGPoint(x: w * 0.80, y: 0),
                   control1: CGPoint(x: w, y: h * 0.4),
                   control2: CGPoint(x: w * 0.90, y: 0))
        p.addQuadCurve(to: CGPoint(x: w * 0.20, y: 0),
                       control: CGPoint(x: w * 0.50, y: h * 0.08))
        p.addCurve(to: CGPoint(x: 0, y: h),
                   control1: CGPoint(x: w * 0.10, y: 0),
                   control2: CGPoint(x: 0, y: h * 0.4))
        p.closeSubpath()
        return p
    }
}

private struct AvatarMustache: Shape {
    let size: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = size / 2
        let cy = size / 2
        let hw = size * 0.10
        let ht = size * 0.055
        p.move(to:    CGPoint(x: cx - size * 0.02, y: cy))
        p.addCurve(to: CGPoint(x: cx - hw * 2,     y: cy - ht * 0.3),
                   control1: CGPoint(x: cx - hw,   y: cy + ht),
                   control2: CGPoint(x: cx - hw * 1.5, y: cy - ht * 0.1))
        p.addCurve(to: CGPoint(x: cx - size * 0.02, y: cy),
                   control1: CGPoint(x: cx - hw * 1.2, y: cy - ht * 0.8),
                   control2: CGPoint(x: cx - hw * 0.3, y: cy - ht * 0.4))
        p.move(to:    CGPoint(x: cx + size * 0.02, y: cy))
        p.addCurve(to: CGPoint(x: cx + hw * 2,     y: cy - ht * 0.3),
                   control1: CGPoint(x: cx + hw,   y: cy + ht),
                   control2: CGPoint(x: cx + hw * 1.5, y: cy - ht * 0.1))
        p.addCurve(to: CGPoint(x: cx + size * 0.02, y: cy),
                   control1: CGPoint(x: cx + hw * 1.2, y: cy - ht * 0.8),
                   control2: CGPoint(x: cx + hw * 0.3, y: cy - ht * 0.4))
        return p
    }
}

private struct AvatarGlasses: Shape {
    let size: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let lw  = size * 0.135
        let lh  = size * 0.095
        let cx  = size / 2
        let cy  = size / 2
        let gap = size * 0.035
        p.addEllipse(in: CGRect(x: cx - lw - gap / 2, y: cy - lh / 2, width: lw, height: lh))
        p.addEllipse(in: CGRect(x: cx + gap / 2,      y: cy - lh / 2, width: lw, height: lh))
        p.move(to: CGPoint(x: cx - gap / 2, y: cy))
        p.addLine(to: CGPoint(x: cx + gap / 2, y: cy))
        p.move(to: CGPoint(x: cx - lw - gap / 2, y: cy))
        p.addLine(to: CGPoint(x: cx - lw - gap / 2 - size * 0.10, y: cy - size * 0.01))
        p.move(to: CGPoint(x: cx + gap / 2 + lw, y: cy))
        p.addLine(to: CGPoint(x: cx + gap / 2 + lw + size * 0.10, y: cy - size * 0.01))
        return p
    }
}

// MARK: - Color helpers
extension Color {
    init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }

    func darkened(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: max(Double(b) - amount, 0))
    }
}

// MARK: - Crash Detection Settings

struct CrashDetectionSettingsView: View {
    @State private var contactName  = UserDefaults.standard.string(forKey: CrashDetector.contactNameKey)  ?? ""
    @State private var contactPhone = UserDefaults.standard.string(forKey: CrashDetector.contactPhoneKey) ?? ""
    @State private var saved = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("How it works", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                    Text("During navigation, 2Wheel Tracker monitors for sudden high-G impacts. If a crash is detected, a 30-second countdown begins. You can cancel it — if you don't, an SMS is sent to your emergency contact with your GPS location.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Emergency Contact") {
                HStack {
                    Label("Name", systemImage: "person")
                        .font(.subheadline)
                    Spacer()
                    TextField("Contact name", text: $contactName)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .autocorrectionDisabled()
                }

                HStack {
                    Label("Phone", systemImage: "phone")
                        .font(.subheadline)
                    Spacer()
                    TextField("+1 555 000 0000", text: $contactPhone)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .keyboardType(.phonePad)
                }
            }

            Section {
                Button {
                    UserDefaults.standard.set(contactName,  forKey: CrashDetector.contactNameKey)
                    UserDefaults.standard.set(contactPhone, forKey: CrashDetector.contactPhoneKey)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                } label: {
                    HStack {
                        Spacer()
                        if saved {
                            Label("Saved", systemImage: "checkmark")
                                .foregroundStyle(.green)
                        } else {
                            Text("Save Contact")
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                    }
                }
            }

            if contactPhone.isEmpty {
                Section {
                    Label("Add an emergency contact above to enable crash detection alerts.",
                          systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Crash Detection")
        .navigationBarTitleDisplayMode(.inline)
    }
}
