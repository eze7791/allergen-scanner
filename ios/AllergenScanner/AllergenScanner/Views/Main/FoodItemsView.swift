import SwiftUI

struct FoodItemsView: View {
    @Environment(APIClient.self) private var api

    @State private var foodItems: [FoodItem] = []
    @State private var allergens: [Allergen] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false

    private var isAdmin: Bool { api.session?.role == .admin }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Food Items")
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
                    AddFoodItemSheet(allergens: allergens) { await load() }
                }
                .task { await load() }
                .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && foodItems.isEmpty {
            ProgressView()
        } else if let errorMessage, foodItems.isEmpty {
            ContentUnavailableView("Couldn't load food items", systemImage: "wifi.slash", description: Text(errorMessage))
        } else if foodItems.isEmpty {
            ContentUnavailableView("No food items yet", systemImage: "fork.knife")
        } else {
            List {
                ForEach(foodItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.headline)
                        if let category = item.category, !category.isEmpty {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !item.allergens.isEmpty {
                            AllergenChipsRow(allergens: item.allergens)
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
            async let itemsTask = api.fetchFoodItems()
            async let allergensTask = api.fetchAllergens()
            foodItems = try await itemsTask.sorted { $0.name < $1.name }
            allergens = try await allergensTask.sorted { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        let idsToDelete = offsets.map { foodItems[$0].id }
        foodItems.remove(atOffsets: offsets)
        Task {
            for id in idsToDelete {
                try? await api.deleteFoodItem(id: id)
            }
        }
    }
}

struct AllergenChipsRow: View {
    let allergens: [Allergen]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allergens) { allergen in
                    Text(allergen.name)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct AddFoodItemSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let allergens: [Allergen]
    let onSaved: () async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var category = ""
    @State private var selectedAllergenIds: Set<Int> = []
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
                            toggle(allergen.id)
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
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("New Food Item")
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
        if selectedAllergenIds.contains(id) {
            selectedAllergenIds.remove(id)
        } else {
            selectedAllergenIds.insert(id)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await api.createFoodItem(
                name: name,
                description: description.isEmpty ? nil : description,
                category: category.isEmpty ? nil : category,
                allergenIds: Array(selectedAllergenIds)
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    FoodItemsView()
        .environment(APIClient.shared)
}
