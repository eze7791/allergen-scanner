import SwiftUI

struct AllergensView: View {
    @Environment(APIClient.self) private var api

    @State private var allergens: [Allergen] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false

    private var isAdmin: Bool { api.session?.role == .admin }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Allergens")
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
                    AddAllergenSheet { await load() }
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
                    if isAdmin {
                        NavigationLink {
                            EditAllergenView(allergen: allergen) { await load() }
                        } label: {
                            AllergenRow(allergen: allergen)
                        }
                    } else {
                        AllergenRow(allergen: allergen)
                    }
                }
                .onDelete(perform: isAdmin ? delete : nil)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let idsToDelete = offsets.map { allergens[$0].id }
        allergens.remove(atOffsets: offsets)
        Task {
            for id in idsToDelete {
                try? await api.deleteAllergen(id: id)
            }
        }
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
    }
}

private struct EditAllergenView: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let allergen: Allergen
    let onSaved: () async -> Void

    @State private var name: String
    @State private var description: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(allergen: Allergen, onSaved: @escaping () async -> Void) {
        self.allergen = allergen
        self.onSaved = onSaved
        _name = State(initialValue: allergen.name)
        _description = State(initialValue: allergen.description ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Description (optional)", text: $description)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("Edit Allergen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(name.isEmpty || isSaving)
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await api.updateAllergen(id: allergen.id, name: name, description: description.isEmpty ? nil : description)
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AddAllergenSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let onSaved: () async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

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
            .navigationTitle("New Allergen")
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
            _ = try await api.createAllergen(name: name, description: description.isEmpty ? nil : description)
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
