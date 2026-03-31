import SwiftUI

extension Notification.Name {
    static let motoDeepLink = Notification.Name("motoDeepLink")
}

@main
struct MotoTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    NotificationCenter.default.post(name: .motoDeepLink, object: url)
                }
        }
    }
}
