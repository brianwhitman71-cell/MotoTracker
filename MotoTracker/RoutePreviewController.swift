import SwiftUI

// MARK: - Preview Controls Overlay

struct PreviewControlsOverlay: View {
    @ObservedObject var routeManager: RouteManager
    var onStop: () -> Void

    @State private var showSpeedPicker = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.35)).frame(height: 3)
                    Capsule().fill(Color.white)
                        .frame(width: max(0, geo.size.width * routeManager.simulationProgress), height: 3)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Control bar
            HStack(spacing: 0) {
                controlBtn(icon: "backward.fill") {
                    routeManager.skipSimulationBackward()
                }
                controlBtn(icon: routeManager.isSimulationPaused ? "play.fill" : "pause.fill", size: 22) {
                    routeManager.toggleSimulationPause()
                }
                controlBtn(icon: "forward.fill") {
                    routeManager.skipSimulationForward()
                }
                // Speed button — uses confirmationDialog to avoid MKMapView gesture conflicts
                Button {
                    showSpeedPicker = true
                } label: {
                    Text(routeManager.simulationSpeedLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .confirmationDialog("Playback Speed", isPresented: $showSpeedPicker) {
                    Button("½× Slow")    { routeManager.simulationSpeedMultiplier = 0.5 }
                    Button("1× Normal")  { routeManager.simulationSpeedMultiplier = 1.0 }
                    Button("2× Fast")    { routeManager.simulationSpeedMultiplier = 2.0 }
                    Button("3× Fastest") { routeManager.simulationSpeedMultiplier = 3.0 }
                    Button("Cancel", role: .cancel) {}
                }

                Button("Stop", action: onStop)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 34)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func controlBtn(icon: String, size: CGFloat = 18, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
    }
}
