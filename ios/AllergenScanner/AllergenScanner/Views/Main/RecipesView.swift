import SwiftUI

struct RecipesView: View {
    @Environment(APIClient.self) private var api

    @State private var recipes: [Recipe] = []
    @State private var allergens: [Allergen] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false
    @State private var editingRecipe: Recipe?

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
                    RecipeFormSheet(allergens: allergens, existing: nil) { await load() }
                }
                .sheet(item: $editingRecipe) { recipe in
                    RecipeFormSheet(allergens: allergens, existing: recipe) { await load() }
                }
                .task { await load() }
                .refreshable { await load() }
        }
    }

    private var groupedRecipes: [(category: String, recipes: [Recipe])] {
        Dictionary(grouping: recipes) { $0.category?.isEmpty == false ? $0.category! : "Uncategorized" }
            .sorted { $0.key < $1.key }
            .map { (category: $0.key, recipes: $0.value.sorted { $0.name < $1.name }) }
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
                ForEach(groupedRecipes, id: \.category) { group in
                    Section {
                        ForEach(group.recipes) { recipe in
                            RecipeRow(recipe: recipe)
                                .contentShape(Rectangle())
                                .onTapGesture { if isAdmin { editingRecipe = recipe } }
                                .swipeActions(edge: .trailing) {
                                    if isAdmin {
                                        Button(role: .destructive) { deleteOne(recipe) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        Button { editingRecipe = recipe } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.teal)
                                    }
                                }
                        }
                    } header: {
                        Text(group.category)
                    }
                }
            }
            .listStyle(.insetGrouped)
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

    private func deleteOne(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        Task { try? await api.deleteRecipe(id: recipe.id) }
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.name).font(.headline)
            if recipe.allergens.isEmpty && recipe.mayContainAllergens.isEmpty {
                Text("No allergens on record")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                if !recipe.allergens.isEmpty {
                    AllergenChipsRow(allergens: recipe.allergens, style: .certain)
                }
                if !recipe.mayContainAllergens.isEmpty {
                    AllergenChipsRow(allergens: recipe.mayContainAllergens, style: .mayContain)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct RecipeFormSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let allergens: [Allergen]
    let existing: Recipe?
    let onSaved: () async -> Void

    @State private var name: String
    @State private var description: String
    @State private var category: String
    @State private var selectedAllergenIds: Set<Int>
    @State private var selectedMayContainIds: Set<Int>
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(allergens: [Allergen], existing: Recipe?, onSaved: @escaping () async -> Void) {
        self.allergens = allergens
        self.existing = existing
        self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "")
        _description = State(initialValue: existing?.description ?? "")
        _category = State(initialValue: existing?.category ?? "")
        _selectedAllergenIds = State(initialValue: Set(existing?.allergens.map(\.id) ?? []))
        _selectedMayContainIds = State(initialValue: Set(existing?.mayContainAllergens.map(\.id) ?? []))
    }

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
            .navigationTitle(existing == nil ? "New Dish" : "Edit Dish")
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
            if let existing {
                _ = try await api.updateRecipe(
                    id: existing.id,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    category: category.isEmpty ? nil : category,
                    allergenIds: Array(selectedAllergenIds),
                    mayContainAllergenIds: Array(selectedMayContainIds)
                )
            } else {
                _ = try await api.createRecipe(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    category: category.isEmpty ? nil : category,
                    allergenIds: Array(selectedAllergenIds),
                    mayContainAllergenIds: Array(selectedMayContainIds)
                )
            }
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
