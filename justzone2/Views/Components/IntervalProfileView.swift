import SwiftUI

/// The shape of an interval session: one bar per segment, width = duration,
/// height = power. During a workout, pass `elapsed` to dim what's still to
/// come and draw a "you are here" marker.
struct IntervalProfileView: View {
    let session: IntervalSession
    var elapsed: TimeInterval? = nil
    /// Nudged powers during a ride, so the bars match what the trainer holds.
    var powerFor: ((IntervalSegment) -> Int)? = nil

    static let workColor = HRZone.z4.color
    static let easyColor = HRZone.z1.color

    var body: some View {
        GeometryReader { geo in
            let segments = session.segments
            let total = max(session.totalDuration, 1)
            let powers = segments.map { powerFor?($0) ?? $0.power }
            let maxPower = Double(max(powers.max() ?? 1, 1))
            let w = geo.size.width, h = geo.size.height
            let gap: CGFloat = segments.count > 40 ? 0.5 : 1

            ZStack(alignment: .bottomLeading) {
                ForEach(Array(segments.enumerated()), id: \.offset) { i, segment in
                    let x = w * segment.start / total
                    let segW = max(w * segment.duration / total - gap, 1)
                    // Keep easy segments visible even when the work power is far higher.
                    let segH = max(h * Double(powers[i]) / maxPower, h * 0.12)
                    let color = segment.isWork ? Self.workColor : Self.easyColor
                    let done = elapsed.map { $0 >= segment.end } ?? true
                    let current = elapsed.map { $0 >= segment.start && $0 < segment.end } ?? false

                    ZStack(alignment: .leading) {
                        UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                            .fill(color.opacity(done || current ? 0.95 : 0.35))
                        // Progress through the current segment.
                        if current, let t = elapsed {
                            UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                                .fill(color.opacity(0.35))
                                .frame(width: segW * (1 - (t - segment.start) / segment.duration))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .frame(width: segW, height: segH)
                    .offset(x: x)
                }

                if let t = elapsed {
                    let x = w * min(t / total, 1)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: h + 6)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .offset(x: x - 1.5, y: 3)
                }
            }
            .frame(width: w, height: h, alignment: .bottomLeading)
        }
        .accessibilityElement()
        .accessibilityLabel("Interval profile: \(session.name)")
    }
}

#Preview {
    VStack(spacing: 30) {
        IntervalProfileView(session: .example).frame(height: 40)
        IntervalProfileView(session: .example, elapsed: 16 * 60).frame(height: 56)
    }
    .padding()
    .preferredColorScheme(.dark)
}
