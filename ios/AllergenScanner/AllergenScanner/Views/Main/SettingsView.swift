import SwiftUI

struct SettingsView: View {
    @Environment(APIClient.self) private var api

    var body: some View {
        NavigationStack {
            Form {
                if let session = api.session {
                    Section("Restaurant") {
                        LabeledContent("Name", value: session.restaurantName)
                        LabeledContent("Role", value: session.role.rawValue.capitalized)
                        if session.role == .admin, let joinCode = session.joinCode {
                            LabeledContent("Join code", value: joinCode)
                        }
                    }
                }
                Section {
                    Button("Log Out", role: .destructive) {
                        api.logOut()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environment(APIClient.shared)
}
