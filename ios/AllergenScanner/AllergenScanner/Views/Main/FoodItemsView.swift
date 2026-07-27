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
                            AllergenChipsRow(allergens: item.allergens, style: .certain)
                        }
                        if !item.mayContainAllergens.isEmpty {
                            AllergenChipsRow(allergens: item.mayContainAllergens, style: .mayContain)
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

enum AllergenChipStyle {
    case certain
    case mayContain

    var color: Color {
        switch self {
        case .certain: return .red
        case .mayContain: return .orange
        }
    }

    var prefix: String? {
        switch self {
        case .certain: return nil
        case .mayContain: return "May contain: "
        }
    }
}

struct AllergenChipsRow: View {
    let allergens: [Allergen]
    var style: AllergenChipStyle = .certain

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let prefix = style.prefix {
                    Text(prefix)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(allergens) { allergen in
                    Text(allergen.name)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(style.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(style.color)
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
                } footer: {
                    Text("Use this for cross-contamination risk, e.g. a supplier that doesn't guarantee an ingredient is allergen-free.")
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
            _ = try await api.createFoodItem(
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
    FoodItemsView()
        .environment(APIClient.shared)
}
