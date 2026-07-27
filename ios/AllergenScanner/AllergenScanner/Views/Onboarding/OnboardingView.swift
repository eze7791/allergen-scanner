import SwiftUI

struct OnboardingView: View {
    private enum Mode: String, CaseIterable, Identifiable, Hashable {
        case createRestaurant = "Create"
        case joinAsStaff = "Join staff"
        case adminLogin = "Admin login"

        var id: String { rawValue }
    }

    @State private var mode: Mode = .createRestaurant
    @Namespace private var modeNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 72, height: 72)
                                    .shadow(color: .teal.opacity(0.35), radius: 16, y: 8)
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 34))
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

                        GlassChipRow(
                            items: Mode.allCases,
                            label: { $0.rawValue },
                            selected: mode,
                            onTap: { mode = $0 }
                        )
                        .padding(.horizontal)

                        Group {
                            switch mode {
                            case .createRestaurant: CreateRestaurantView()
                            case .joinAsStaff: JoinRestaurantView()
                            case .adminLogin: AdminLoginView()
                            }
                        }
                        .padding(20)
                        .glassCard(cornerRadius: 28)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

/// Soft animated-looking backdrop using a MeshGradient (iOS 18+) instead of
/// flat radial blurs, so the login screen reads as "alive" like recent
/// first-party Apple apps.
struct MeshBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .teal.opacity(0.35), .mint.opacity(0.2), .clear,
                .teal.opacity(0.15), .clear, .green.opacity(0.15),
                .clear, .green.opacity(0.2), .teal.opacity(0.25),
            ]
        )
        .background(.background)
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingView()
        .environment(APIClient.shared)
}
