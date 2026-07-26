import SwiftUI

struct OnboardingView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case createRestaurant = "Create Restaurant"
        case joinAsStaff = "Join as Staff"
        case adminLogin = "Admin Login"

        var id: String { rawValue }
    }

    @State private var mode: Mode = .createRestaurant

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Allergen Scanner")
                        .font(.title.bold())
                    Text("Scan ingredient labels, manage your menu, and keep every allergen documented for your team.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch mode {
                    case .createRestaurant: CreateRestaurantView()
                    case .joinAsStaff: JoinRestaurantView()
                    case .adminLogin: AdminLoginView()
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(APIClient.shared)
}
