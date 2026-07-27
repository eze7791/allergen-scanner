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
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(LinearGradient(colors: [.teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 68, height: 68)
                                .shadow(color: .teal.opacity(0.3), radius: 12, y: 6)
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                        Text("Allergen Scanner")
                            .font(.title.bold())
                        Text("Instantly check every dish for allergens — built for the floor, trusted by the kitchen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 32)

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
                    .padding(20)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(APIClient.shared)
}
