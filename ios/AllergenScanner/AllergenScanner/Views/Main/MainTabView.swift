import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }
            Tab("Dishes", systemImage: "list.bullet.rectangle") {
                RecipesView()
            }
            Tab("Scan", systemImage: "camera.viewfinder") {
                ScanView()
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
