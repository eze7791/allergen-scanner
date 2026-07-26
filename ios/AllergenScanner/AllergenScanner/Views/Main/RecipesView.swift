import SwiftUI

struct RecipesView: View {
    @Environment(APIClient.self) private var api

    @State private var recipes: [Recipe] = []
    @State private var foodItems: [FoodItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false

    private var isAdmin: Bool { api.session?.role == .admin }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Recipes")
                .toolbar {
                    if isAdmin {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingAddSheet) {
                    AddRecipeSheet(foodItems: foodItems) { await load() }
                }
                .task { await load() }
                .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && recipes.isEmpty {
            ProgressView()
        } else if let errorMessage, recipes.isEmpty {
            ContentUnavailableView("Couldn't load recipes", systemImage: "wifi.slash", description: Text(errorMessage))
        } else if recipes.isEmpty {
            ContentUnavailableView("No recipes yet", systemImage: "list.bullet.rectangle")
        } else {
            List {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(recipe.name).font(.headline)
                            Text("\(recipe.items.count) item(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !recipe.allergens.isEmpty {
                                Text(recipe.allergens.map(\.name).joined(separator: ", "))
                                    .font(.caption2.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: isAdmin ? delete : nil)
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let recipesTask = api.fetchRecipes()
            async let itemsTask = api.fetchFoodItems()
            recipes = try await recipesTask.sorted { $0.name < $1.name }
            foodItems = try await itemsTask.sorted { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        let idsToDelete = offsets.map { recipes[$0].id }
        recipes.remove(atOffsets: offsets)
        Task {
            for id in idsToDelete {
                try? await api.deleteRecipe(id: id)
            }
        }
    }
}

private struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        List {
            Section("Items") {
                ForEach(recipe.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                        if !item.allergens.isEmpty {
                            AllergenChipsRow(allergens: item.allergens)
                        }
                    }
                }
            }
            if !recipe.allergens.isEmpty {
                Section("Allergen summary") {
                    ForEach(recipe.allergens) { summary in
                        VStack(alignment: .leading) {
                            Text(summary.name).font(.headline)
                            Text("In: \(summary.items.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(recipe.name)
    }
}

private struct AddRecipeSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let foodItems: [FoodItem]
    let onSaved: () async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var selectedItemIds: Set<Int> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
                Section("Includes") {
                    ForEach(foodItems) { item in
                        Button {
                            toggle(item.id)
                        } label: {
                            HStack {
                                Text(item.name)
                                Spacer()
                                if selectedItemIds.contains(item.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("New Recipe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(name.isEmpty || isSaving)
                }
            }
        }
    }

    private func toggle(_ id: Int) {
        if selectedItemIds.contains(id) {
            selectedItemIds.remove(id)
        } else {
            selectedItemIds.insert(id)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await api.createRecipe(
                name: name,
                description: description.isEmpty ? nil : description,
                foodItemIds: Array(selectedItemIds)
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RecipesView()
        .environment(APIClient.shared)
}
