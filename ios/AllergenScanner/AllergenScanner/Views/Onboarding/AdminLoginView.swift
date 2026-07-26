import SwiftUI

struct AdminLoginView: View {
    @Environment(APIClient.self) private var api

    @State private var joinCode = ""
    @State private var adminPin = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Already an admin on another device? Log in here with your restaurant's join code and admin PIN.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Join code (e.g. REST-1234)", text: $joinCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            SecureField("Admin PIN", text: $adminPin)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

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
            .disabled(joinCode.isEmpty || adminPin.isEmpty || isLoading)
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            api.session = try await api.adminLogin(joinCode: joinCode, adminPin: adminPin)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AdminLoginView()
        .environment(APIClient.shared)
}
