import SwiftUI

/// Shared "Liquid Glass" building blocks. Uses the real iOS 26 `glassEffect`
/// API when available and falls back to translucent Material + a soft
/// shadow on older iOS so the app still looks intentional everywhere.
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                tint.map { Glass.regular.tint($0) } ?? .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }
}

/// A floating circular action button, glass on iOS 26+ with a gradient
/// fallback below that, matching Apple's "Compose" style FABs.
struct FloatingActionButton: View {
    let systemImage: String
    var tint: Color = .teal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
        }
        .background {
            if #available(iOS 26.0, *) {
                Circle().fill(tint).glassEffect(.regular.tint(tint).interactive(), in: Circle())
            } else {
                Circle().fill(
                    LinearGradient(colors: [tint, tint.mix(with: .green, by: 0.4, in: .perceptual)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
        }
        .clipShape(Circle())
        .shadow(color: tint.opacity(0.4), radius: 14, y: 6)
    }
}

/// A row of chips with a glass pill that slides between selections via
/// `matchedGeometryEffect`, instead of each chip re-drawing its own background.
struct GlassChipRow<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    let selected: Item?
    let onTap: (Item) -> Void

    @Namespace private var namespace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let isSelected = item == selected
                    Text(label(item))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.teal)
                                    .matchedGeometryEffect(id: "chip-highlight", in: namespace)
                            } else {
                                Capsule().fill(.ultraThinMaterial)
                            }
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                onTap(item)
                            }
                        }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }
}
