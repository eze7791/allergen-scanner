import SwiftUI

struct SettingsView: View {
    @Environment(APIClient.self) private var api

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        if let session = api.session {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Restaurant")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                SettingsRow(label: "Name", value: session.restaurantName)
                                SettingsRow(label: "Role", value: session.role.rawValue.capitalized)
                                if session.role == .admin, let joinCode = session.joinCode {
                                    SettingsRow(label: "Join code", value: joinCode)
                                }
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(cornerRadius: 24)
                        }

                        Button(role: .destructive) {
                            api.logOut()
                        } label: {
                            Text("Log Out")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .glassCard(cornerRadius: 24, tint: .red)
                        .foregroundStyle(.red)
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    SettingsView()
        .environment(APIClient.shared)
}
