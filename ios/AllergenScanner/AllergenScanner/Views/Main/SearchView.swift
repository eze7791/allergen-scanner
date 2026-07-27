import SwiftUI

/// The floor-staff landing screen: search a dish or product by name and see
/// its allergens immediately. Filters client-side against data already
/// fetched on load, rather than round-tripping per keystroke, since speed
/// matters more here than anywhere else in the app.
struct SearchView: View {
    @Environment(APIClient.self) private var api

    @State private var foodItems: [FoodItem] = []
    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var query = ""

    private var filteredRecipes: [Recipe] {
        guard !query.isEmpty else { return [] }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var filteredItems: [FoodItem] {
        guard !query.isEmpty else { return [] }
        return foodItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .searchable(text: $query, prompt: "Search dishes and products")
                .task { await load() }
                .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && foodItems.isEmpty && recipes.isEmpty {
            ProgressView()
        } else if let errorMessage, foodItems.isEmpty && recipes.isEmpty {
            ContentUnavailableView("Couldn't load the menu", systemImage: "wifi.slash", description: Text(errorMessage))
        } else if query.isEmpty {
            ContentUnavailableView(
                "Search for a dish",
                systemImage: "magnifyingglass",
                description: Text("Find a dish or product to see its allergens")
            )
        } else if filteredRecipes.isEmpty && filteredItems.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                if !filteredRecipes.isEmpty {
                    Section("Dishes") {
                        ForEach(filteredRecipes) { recipe in
                            SearchResultRow(
                                name: recipe.name,
                                category: recipe.category,
                                allergens: recipe.allergens,
                                mayContainAllergens: recipe.mayContainAllergens
                            )
                        }
                    }
                }
                if !filteredItems.isEmpty {
                    Section("Products") {
                        ForEach(filteredItems) { item in
                            SearchResultRow(
                                name: item.name,
                                category: item.category,
                                allergens: item.allergens,
                                mayContainAllergens: item.mayContainAllergens
                            )
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let itemsTask = api.fetchFoodItems()
            async let recipesTask = api.fetchRecipes()
            foodItems = try await itemsTask
            recipes = try await recipesTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SearchResultRow: View {
    let name: String
    let category: String?
    let allergens: [Allergen]
    let mayContainAllergens: [Allergen]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.headline)
            if let category, !category.isEmpty {
                Text(category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if allergens.isEmpty && mayContainAllergens.isEmpty {
                Text("No allergens on record")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                if !allergens.isEmpty {
                    AllergenChipsRow(allergens: allergens, style: .certain)
                }
                if !mayContainAllergens.isEmpty {
                    AllergenChipsRow(allergens: mayContainAllergens, style: .mayContain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchView()
        .environment(APIClient.shared)
}
