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
    @State private var selectedCategory: String?

    private var categories: [String] {
        let all = (foodItems.map(\.category) + recipes.map(\.category)).compactMap { $0 }
        return Array(Set(all)).sorted()
    }

    private var filteredRecipes: [Recipe] {
        if let selectedCategory { return recipes.filter { $0.category == selectedCategory } }
        guard !query.isEmpty else { return [] }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var filteredItems: [FoodItem] {
        if let selectedCategory { return foodItems.filter { $0.category == selectedCategory } }
        guard !query.isEmpty else { return [] }
        return foodItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                content
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search dishes and products")
            .onChange(of: query) { _, newValue in
                if !newValue.isEmpty { selectedCategory = nil }
            }
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
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if !categories.isEmpty {
                        GlassChipRow(
                            items: categories,
                            label: { $0 },
                            selected: selectedCategory,
                            onTap: { cat in
                                query = ""
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                            }
                        )
                    }

                    if query.isEmpty && selectedCategory == nil {
                        ContentUnavailableView(
                            "Search for a dish",
                            systemImage: "magnifyingglass",
                            description: Text("Find a dish or product, or browse by category above")
                        )
                        .padding(.top, 40)
                    } else if filteredRecipes.isEmpty && filteredItems.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .padding(.top, 40)
                    } else {
                        if !filteredRecipes.isEmpty {
                            SearchResultSection(title: "Dishes") {
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
                            SearchResultSection(title: "Products") {
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
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
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

private struct SearchResultSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(spacing: 10) {
                content
            }
        }
    }
}

private struct SearchResultRow: View {
    let name: String
    let category: String?
    let allergens: [Allergen]
    let mayContainAllergens: [Allergen]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                if let category, !category.isEmpty {
                    Text(category)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.teal.opacity(0.12), in: Capsule())
                }
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20)
    }
}

#Preview {
    SearchView()
        .environment(APIClient.shared)
}
