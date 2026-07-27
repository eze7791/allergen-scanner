import SwiftUI

struct AdminLoginView: View {
    @Environment(APIClient.self) private var api

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Already an admin on another device? Log in here with your personal admin username and password.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Admin username", text: $username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Admin password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await login() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty || isLoading)
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            api.session = try await api.adminLogin(username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AdminLoginView()
        .environment(APIClient.shared)
}
