import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Scan", systemImage: "camera.viewfinder") {
                ScanView()
            }
            Tab("Allergens", systemImage: "exclamationmark.triangle") {
                AllergensView()
            }
            Tab("Food Items", systemImage: "fork.knife") {
                FoodItemsView()
            }
            Tab("Recipes", systemImage: "list.bullet.rectangle") {
                RecipesView()
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
