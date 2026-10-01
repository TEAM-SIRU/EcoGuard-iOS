import SwiftUI

@main
struct EcoGuardApp: App {
    private let container = DIContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
