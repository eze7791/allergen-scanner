import SwiftUI

struct MainTabView: View {
    @Environment(APIClient.self) private var api

    private var isAdmin: Bool { api.session?.role == .admin }

    var body: some View {
        TabView {
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }
            Tab("Dishes", systemImage: "list.bullet.rectangle") {
                RecipesView()
            }
            if isAdmin {
                Tab("Scan", systemImage: "camera.viewfinder") {
                    ScanView()
                }
            }
            Tab("Food Items", systemImage: "fork.knife") {
                FoodItemsView()
            }
            Tab("Allergens", systemImage: "exclamationmark.triangle") {
                AllergensView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(APIClient.shared)
}
