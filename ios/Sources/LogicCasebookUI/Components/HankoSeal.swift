import SwiftUI

/// A vermilion hanko (印) stamp, the app's one recurring flourish: small in
/// the case list, large on the completion screen. Perfect solves get a
/// second ring.
struct HankoSeal: View {
    let text: String
    var perfect = false
    var size: CGFloat = 120
    var animated = false
    var tint: Color = Theme.accent

    @State private var stamped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ring = max(1.5, size * 0.04)
        ZStack {
            Circle().strokeBorder(tint, lineWidth: ring * 1.2)
            if perfect {
                Circle()
                    .strokeBorder(tint, lineWidth: ring * 0.6)
                    .padding(-size * 0.11)
            }
            Text(text)
                .font(.system(size: size * 0.32, weight: .bold, design: .serif))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-9))
        .scaleEffect(animated && !stamped ? 1.7 : 1)
        .opacity(animated && !stamped ? 0 : 1)
        .onAppear {
            guard animated else { return }
            if reduceMotion {
                stamped = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { stamped = true }
            }
        }
        .accessibilityHidden(true)
    }
}
