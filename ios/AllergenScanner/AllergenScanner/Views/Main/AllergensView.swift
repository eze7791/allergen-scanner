import SwiftUI

struct AllergensView: View {
    @Environment(APIClient.self) private var api

    @State private var allergens: [Allergen] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false
    @State private var editingAllergen: Allergen?

    private var isAdmin: Bool { api.session?.role == .admin }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                MeshBackground()
                content
                if isAdmin {
                    FloatingActionButton(systemImage: "plus") { showingAddSheet = true }
                        .padding(20)
                }
            }
            .navigationTitle("Allergens")
            .sheet(isPresented: $showingAddSheet) {
                AllergenFormSheet(existing: nil) { await load() }
                    .presentationCornerRadius(32)
                    .presentationBackground(.thinMaterial)
            }
            .sheet(item: $editingAllergen) { allergen in
                AllergenFormSheet(existing: allergen) { await load() }
                    .presentationCornerRadius(32)
                    .presentationBackground(.thinMaterial)
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && allergens.isEmpty {
            ProgressView()
        } else if let errorMessage, allergens.isEmpty {
            ContentUnavailableView("Couldn't load allergens", systemImage: "wifi.slash", description: Text(errorMessage))
        } else if allergens.isEmpty {
            ContentUnavailableView("No allergens yet", systemImage: "exclamationmark.triangle")
        } else {
            List {
                ForEach(allergens) { allergen in
                    AllergenRow(allergen: allergen)
                        .glassCard(cornerRadius: 18)
                        .contentShape(Rectangle())
                        .onTapGesture { if isAdmin { editingAllergen = allergen } }
                        .swipeActions(edge: .trailing) {
                            if isAdmin {
                                Button(role: .destructive) { deleteOne(allergen) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { editingAllergen = allergen } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.teal)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func deleteOne(_ allergen: Allergen) {
        allergens.removeAll { $0.id == allergen.id }
        Task { try? await api.deleteAllergen(id: allergen.id) }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            allergens = try await api.fetchAllergens().sorted { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AllergenRow: View {
    let allergen: Allergen

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(allergen.name).font(.headline)
            if let description = allergen.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AllergenFormSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let existing: Allergen?
    let onSaved: () async -> Void

    @State private var name: String
    @State private var description: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(existing: Allergen?, onSaved: @escaping () async -> Void) {
        self.existing = existing
        self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "")
        _description = State(initialValue: existing?.description ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(existing == nil ? "New Allergen" : "Edit Allergen")
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

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let existing {
                _ = try await api.updateAllergen(id: existing.id, name: name, description: description.isEmpty ? nil : description)
            } else {
                _ = try await api.createAllergen(name: name, description: description.isEmpty ? nil : description)
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AllergensView()
        .environment(APIClient.shared)
}
