import SwiftUI

struct SavedRoutesView: View {
    @ObservedObject var routeManager: RouteManager
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if routeManager.savedRoutes.isEmpty {
                    ContentUnavailableView(
                        "No Saved Routes",
                        systemImage: "bookmark.slash",
                        description: Text("Plan a route and tap Save to keep it here.")
                    )
                } else {
                    List {
                        ForEach(routeManager.savedRoutes) { route in
                            Button {
                                dismiss()
                                Task { await routeManager.loadSavedRoute(route) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(route.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(Self.dateFormatter.string(from: route.date))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { routeManager.savedRoutes[$0] }.forEach {
                                routeManager.deleteSavedRoute($0)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
