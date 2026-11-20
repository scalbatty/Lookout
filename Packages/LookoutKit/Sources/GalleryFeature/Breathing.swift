import SwiftUI

extension View {
    /// A slow opacity pulse for loading placeholders. `wave` shifts the pulse
    /// (0.15 s per step), so neighbouring views pulse one after another.
    /// Still when Reduce Motion is on.
    func breathing(wave: Int = 0) -> some View {
        modifier(Breathing(wave: wave))
    }
}

private struct Breathing: ViewModifier {
    let wave: Int

    /// One full cycle, bright to dim and back.
    private static let period = 1.8
    private static let waveStep = 0.15
    private static let opacities = 0.4...1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Opacity is computed from the clock rather than animated from
    // `onAppear`: it pulses from the first frame, even when the view appears
    // during app launch (where a state-driven repeating animation can start
    // without its animation and snap), and every view of the wave shares the
    // same timeline.
    func body(content: Content) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            content.opacity(reduceMotion ? 1 : opacity(at: context.date))
        }
    }

    private func opacity(at date: Date) -> Double {
        let time = date.timeIntervalSinceReferenceDate - Double(wave) * Self.waveStep
        // Ease in and out: a cosine from 1 (bright) to 0 (dim) and back.
        let phase = (1 + cos(2 * .pi * time / Self.period)) / 2
        return Self.opacities.lowerBound + phase * (Self.opacities.upperBound - Self.opacities.lowerBound)
    }
}

#Preview {
    HStack {
        ForEach(0..<4, id: \.self) { index in
            Rectangle()
                .fill(.tertiary)
                .frame(width: 70, height: 70)
                .breathing(wave: index)
        }
    }
}
