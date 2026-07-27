import SwiftUI

struct JoinRestaurantView: View {
    @Environment(APIClient.self) private var api

    @State private var joinCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask your admin for the restaurant's join code. You'll be able to view all the food items, recipes, and allergens they've set up.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Join code (ask your admin)", text: $joinCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await join() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Join Restaurant")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(joinCode.isEmpty || isLoading)
        }
    }

    private func join() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            api.session = try await api.joinRestaurant(joinCode: joinCode)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    JoinRestaurantView()
        .environment(APIClient.shared)
}
