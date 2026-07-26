import SwiftUI

struct CreateRestaurantView: View {
    @Environment(APIClient.self) private var api

    @State private var name = ""
    @State private var adminPin = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdSession: AuthSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set up your restaurant and become its admin. You'll get a join code to share with your staff.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Restaurant name", text: $name)
                .textFieldStyle(.roundedBorder)

            SecureField("Admin PIN (you'll use this to log in on new devices)", text: $adminPin)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

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
            .disabled(name.isEmpty || adminPin.isEmpty || isLoading)
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
            createdSession = try await api.createRestaurant(name: name, adminPin: adminPin)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CreateRestaurantView()
        .environment(APIClient.shared)
}
