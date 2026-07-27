import SwiftUI

struct FoodItemsView: View {
    @Environment(APIClient.self) private var api

    @State private var foodItems: [FoodItem] = []
    @State private var allergens: [Allergen] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false
    @State private var editingItem: FoodItem?

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
                    FoodItemFormSheet(allergens: allergens, existing: nil) { await load() }
                }
                .sheet(item: $editingItem) { item in
                    FoodItemFormSheet(allergens: allergens, existing: item) { await load() }
                }
                .task { await load() }
                .refreshable { await load() }
        }
    }

    private var groupedItems: [(category: String, items: [FoodItem])] {
        Dictionary(grouping: foodItems) { $0.category?.isEmpty == false ? $0.category! : "Uncategorized" }
            .sorted { $0.key < $1.key }
            .map { (category: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
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
                ForEach(groupedItems, id: \.category) { group in
                    Section {
                        ForEach(group.items) { item in
                            FoodItemRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { if isAdmin { editingItem = item } }
                                .swipeActions(edge: .trailing) {
                                    if isAdmin {
                                        Button(role: .destructive) { deleteOne(item) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        Button { editingItem = item } label: {
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
            async let itemsTask = api.fetchFoodItems()
            async let allergensTask = api.fetchAllergens()
            foodItems = try await itemsTask.sorted { $0.name < $1.name }
            allergens = try await allergensTask.sorted { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteOne(_ item: FoodItem) {
        foodItems.removeAll { $0.id == item.id }
        Task { try? await api.deleteFoodItem(id: item.id) }
    }
}

private struct FoodItemRow: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name).font(.headline)
            if item.allergens.isEmpty && item.mayContainAllergens.isEmpty {
                Text("No allergens on record")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                if !item.allergens.isEmpty {
                    AllergenChipsRow(allergens: item.allergens, style: .certain)
                }
                if !item.mayContainAllergens.isEmpty {
                    AllergenChipsRow(allergens: item.mayContainAllergens, style: .mayContain)
                }
            }
        }
        .padding(.vertical, 6)
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

    var label: String {
        switch self {
        case .certain: return "Contains"
        case .mayContain: return "May contain"
        }
    }
}

struct AllergenChipsRow: View {
    let allergens: [Allergen]
    var style: AllergenChipStyle = .certain

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(style.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            FlowLayout(spacing: 6) {
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

/// Wraps its children onto multiple lines instead of clipping or scrolling,
/// so a long allergen list is always fully visible at a glance.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct FoodItemFormSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let allergens: [Allergen]
    let existing: FoodItem?
    let onSaved: () async -> Void

    @State private var name: String
    @State private var description: String
    @State private var category: String
    @State private var selectedAllergenIds: Set<Int>
    @State private var selectedMayContainIds: Set<Int>
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(allergens: [Allergen], existing: FoodItem?, onSaved: @escaping () async -> Void) {
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
                } footer: {
                    Text("Use this for cross-contamination risk, e.g. a supplier that doesn't guarantee an ingredient is allergen-free.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(existing == nil ? "New Food Item" : "Edit Food Item")
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
                _ = try await api.updateFoodItem(
                    id: existing.id,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    category: category.isEmpty ? nil : category,
                    allergenIds: Array(selectedAllergenIds),
                    mayContainAllergenIds: Array(selectedMayContainIds)
                )
            } else {
                _ = try await api.createFoodItem(
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
    FoodItemsView()
        .environment(APIClient.shared)
}
