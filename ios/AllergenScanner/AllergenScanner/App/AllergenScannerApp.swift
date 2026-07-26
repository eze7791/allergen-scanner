import SwiftUI

@main
struct AllergenScannerApp: App {
    @State private var api = APIClient.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(api)
        }
    }
}

struct RootView: View {
    @Environment(APIClient.self) private var api

    var body: some View {
        if api.session != nil {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}
