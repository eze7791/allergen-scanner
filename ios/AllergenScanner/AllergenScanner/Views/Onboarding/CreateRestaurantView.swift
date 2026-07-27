import SwiftUI

struct CreateRestaurantView: View {
    @Environment(APIClient.self) private var api

    @State private var name = ""
    @State private var adminUsername = ""
    @State private var adminPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdSession: AuthSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set up your restaurant and your personal admin login. You'll get a join code to share with your staff.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Restaurant name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Admin username", text: $adminUsername)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Admin password", text: $adminPassword)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await createRestaurant() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Restaurant")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.isEmpty || adminUsername.isEmpty || adminPassword.isEmpty || isLoading)
        }
        .alert("Restaurant created", isPresented: .constant(createdSession != nil)) {
            Button("Continue") {
                if let createdSession {
                    api.session = createdSession
                }
            }
        } message: {
            if let createdSession {
                Text("Your join code is \(createdSession.joinCode ?? "-"). Share it with your staff so they can join. You can find it again later in Settings.")
            }
        }
    }

    private func createRestaurant() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            createdSession = try await api.createRestaurant(name: name, adminUsername: adminUsername, adminPassword: adminPassword)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CreateRestaurantView()
        .environment(APIClient.shared)
}
