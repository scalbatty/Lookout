import SwiftUI

extension View {
    /// A slow opacity pulse for loading placeholders. `wave` delays the start
    /// (0.15 s per step), so neighbouring views pulse one after another.
    /// Still when Reduce Motion is on.
    func breathing(wave: Int = 0) -> some View {
        modifier(Breathing(wave: wave))
    }
}

private struct Breathing: ViewModifier {
    let wave: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.4 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 0.9)
                        .repeatForever(autoreverses: true)
                        .delay(Double(wave) * 0.15)
                ) {
                    dimmed = true
                }
            }
    }
}

#Preview {
    HStack {
        ForEach(0..<4, id: \.self) { index in
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .frame(width: 70, height: 70)
                .breathing(wave: index)
        }
    }
}
