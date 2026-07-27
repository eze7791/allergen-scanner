import SwiftUI

struct RecipesView: View {
    @Environment(APIClient.self) private var api

    @State private var recipes: [Recipe] = []
    @State private var allergens: [Allergen] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false

    private var isAdmin: Bool { api.session?.role == .admin }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Dishes")
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
                    AddRecipeSheet(allergens: allergens) { await load() }
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
            ContentUnavailableView("Couldn't load dishes", systemImage: "wifi.slash", description: Text(errorMessage))
        } else if recipes.isEmpty {
            ContentUnavailableView("No dishes yet", systemImage: "list.bullet.rectangle")
        } else {
            List {
                ForEach(recipes) { recipe in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.name).font(.headline)
                        if let category = recipe.category, !category.isEmpty {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !recipe.allergens.isEmpty {
                            AllergenChipsRow(allergens: recipe.allergens, style: .certain)
                        }
                        if !recipe.mayContainAllergens.isEmpty {
                            AllergenChipsRow(allergens: recipe.mayContainAllergens, style: .mayContain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: isAdmin ? delete : nil)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let recipesTask = api.fetchRecipes()
            async let allergensTask = api.fetchAllergens()
            recipes = try await recipesTask.sorted { $0.name < $1.name }
            allergens = try await allergensTask.sorted { $0.name < $1.name }
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

private struct AddRecipeSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let allergens: [Allergen]
    let onSaved: () async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var category = ""
    @State private var selectedAllergenIds: Set<Int> = []
    @State private var selectedMayContainIds: Set<Int> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)
                    TextField("Category (optional)", text: $category)
                }
                Section("Contains") {
                    ForEach(allergens) { allergen in
                        Button {
                            toggle(allergen.id, in: &selectedAllergenIds, removingFrom: &selectedMayContainIds)
                        } label: {
                            HStack {
                                Text(allergen.name)
                                Spacer()
                                if selectedAllergenIds.contains(allergen.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
                Section {
                    ForEach(allergens) { allergen in
                        Button {
                            toggle(allergen.id, in: &selectedMayContainIds, removingFrom: &selectedAllergenIds)
                        } label: {
                            HStack {
                                Text(allergen.name)
                                Spacer()
                                if selectedMayContainIds.contains(allergen.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text("May contain")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("New Dish")
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

    private func toggle(_ id: Int, in set: inout Set<Int>, removingFrom other: inout Set<Int>) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
            other.remove(id)
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
                category: category.isEmpty ? nil : category,
                allergenIds: Array(selectedAllergenIds),
                mayContainAllergenIds: Array(selectedMayContainIds)
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
