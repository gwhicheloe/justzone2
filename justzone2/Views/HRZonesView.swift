import SwiftUI

struct HRZonesView: View {
    @StateObject private var viewModel = HRZonesViewModel()
    @ObservedObject var heartRateService: HeartRateService

    // Layout constants for the zone stack.
    private let handleHeight: CGFloat = 2
    private let pillWidth: CGFloat = 58

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                hrPickers
                    .disabled(!viewModel.isEditing)
                    .opacity(viewModel.isEditing ? 1 : 0.55)

                Text(viewModel.isEditing
                     ? "Drag the dividers to set your zones. Zone 2 drives your workouts."
                     : "Tap Edit to change your zones. Zone 2 drives your workouts.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)

                GeometryReader { geo in
                    zoneStack(in: geo.size)
                        .onAppear { lastStackHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, h in lastStackHeight = h }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)

                footer
            }
            .navigationTitle("Heart Rate Zones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("Heart Rate Zones")
                            .font(.headline)
                            .foregroundColor(.green)
                        DemoTitleTag()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isEditing {
                        Button("Save") { viewModel.save(); Haptics.impact() }
                            .fontWeight(.bold)
                            .disabled(!viewModel.hasChanges)
                    } else {
                        Button("Edit") { viewModel.beginEdit() }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.isEditing {
                        Button("Discard", role: .cancel) { viewModel.discard() }
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    // MARK: - Min / Max HR pickers

    private var restingBinding: Binding<Int> {
        Binding(get: { viewModel.restingHR }, set: { viewModel.setResting(to: $0) })
    }
    private var maxBinding: Binding<Int> {
        Binding(get: { viewModel.maxHR }, set: { viewModel.setMaxHR(to: $0) })
    }

    private var hrPickers: some View {
        HStack(spacing: 12) {
            pickerBox(binding: restingBinding, range: Array(30...120), label: "Min HR")
            pickerBox(binding: maxBinding, range: Array(120...230), label: "Max HR")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private func pickerBox(binding: Binding<Int>, range: [Int], label: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold)).tracking(0.6)
                .foregroundColor(.primary.opacity(0.85))
            Menu {
                Picker("", selection: binding) {
                    ForEach(range, id: \.self) { Text("\($0)").tag($0) }
                }
            } label: {
                HStack {
                    Text("\(binding.wrappedValue)")
                        .font(.title3.bold()).monospacedDigit()
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Zone stack

    private func zoneStack(in size: CGSize) -> some View {
        // Map a bpm value to a y-offset (top = maxHR, bottom = display floor).
        // The axis bottom is the display floor (≈50% max HR) rather than resting
        // HR, so the very wide Zone 1 doesn't dominate; values below the floor
        // (Zone 1's lower edge, a low live HR) pin to the bottom.
        let h = size.height
        let floor = viewModel.displayFloor
        let range = CGFloat(viewModel.displayRange)
        func y(for bpm: Int) -> CGFloat {
            let frac = CGFloat(max(bpm, floor) - floor) / range
            return h - frac * h
        }

        // The coloured bars occupy a narrow column on the left; zone text sits
        // to the right of the column, vertically centred on each band.
        let barWidth = min(160, size.width * 0.55)

        return ZStack(alignment: .topLeading) {
            // Zone bars (top zone first so it draws downward).
            ForEach(viewModel.bands.reversed()) { band in
                let top = y(for: band.upper)
                let bottom = y(for: band.lower)
                bandBar(band, top: top, height: max(0, bottom - top), width: barWidth)
            }

            // Zone text labels to the right of the bars.
            ForEach(viewModel.bands) { band in
                let top = y(for: band.upper)
                let bottom = y(for: band.lower)
                bandLabel(band, top: top, height: max(0, bottom - top), barWidth: barWidth, totalWidth: size.width)
            }

            // Draggable dividers (between zones), confined to the bar column.
            ForEach(0..<viewModel.dividers.count, id: \.self) { i in
                handle(
                    bpm: viewModel.dividers[i],
                    y: y(for: viewModel.dividers[i]),
                    width: barWidth
                ) { newBpm in viewModel.setDivider(i, to: newBpm) }
            }

            // Live HR marker (BLE strap only — the only live source outside a workout).
            if heartRateService.isConnected, heartRateService.currentHeartRate > 0 {
                liveHRMarker(bpm: heartRateService.currentHeartRate, y: y(for: heartRateService.currentHeartRate), width: barWidth)
            }
        }
        .coordinateSpace(name: "stack")
    }

    /// The coloured bar for a zone (no text inside). The colour is composited
    /// over a near-black base with a subtle top→bottom gradient so it reads as a
    /// rich, muted tone with depth — never a flat saturated block.
    private func bandBar(_ band: HRZoneBand, top: CGFloat, height: CGFloat, width: CGFloat) -> some View {
        let isZ2 = band.zone == .z2
        let c = band.zone.color
        let base = Color(red: 0.07, green: 0.07, blue: 0.09)  // panel charcoal
        let fill = LinearGradient(
            colors: [
                base.blended(with: c, amount: isZ2 ? 0.62 : 0.46),
                base.blended(with: c, amount: isZ2 ? 0.48 : 0.32),
            ],
            startPoint: .top, endPoint: .bottom
        )
        return RoundedRectangle(cornerRadius: 10)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(c.opacity(isZ2 ? 0.85 : 0.45),
                                  lineWidth: isZ2 ? 1.5 : 1)
            )
            .shadow(color: isZ2 ? c.opacity(0.35) : .clear,
                    radius: isZ2 ? 8 : 0)
            .frame(width: width, height: height)
            .offset(y: top)
    }

    /// Zone name + range text, placed to the right of the bar column.
    private func bandLabel(_ band: HRZoneBand, top: CGFloat, height: CGFloat, barWidth: CGFloat, totalWidth: CGFloat) -> some View {
        let isZ2 = band.zone == .z2
        let textWidth = totalWidth - barWidth - 16
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(band.zone.label)
                    .font(.subheadline.bold())
                    .foregroundColor(band.zone.color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(band.zone.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    if isZ2 {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(band.zone.color)
                    }
                    Text("\(band.lower)–\(band.upper)")
                        .font(.caption.monospacedDigit().bold())
                }
                Text("\(pctOfMax(band.lower))–\(pctOfMax(band.upper))% max")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(width: textWidth, height: max(height, 16), alignment: .leading)
        .offset(x: barWidth + 16, y: top)
        .opacity(height > 22 ? 1 : 0)
    }

    // MARK: - Handles

    private func handle(
        bpm: Int,
        y: CGFloat,
        width: CGFloat,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        let lineColor: Color = .white.opacity(0.9)
        return ZStack {
            // The grab line.
            Rectangle()
                .fill(lineColor)
                .frame(width: width, height: handleHeight)

            // bpm pill on the right, nudged down to sit just above the divider
            // line (the frame is 44pt tall and the line sits at its centre, y=22).
            Text("\(bpm)")
                .font(.system(size: 14, weight: .bold)).monospacedDigit()
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color(.systemBackground)))
                .overlay(Capsule().strokeBorder(lineColor, lineWidth: 1.5))
                .frame(width: pillWidth)
                .position(x: width - pillWidth / 2, y: 7)
        }
        .frame(width: width, height: 44)         // generous touch target
        .contentShape(Rectangle())
        .offset(y: y - 22)
        .gesture(dragGesture(currentBpm: bpm, onChange: onChange))
    }

    @State private var dragStartBpm: Int?

    private func dragGesture(currentBpm: Int, onChange: @escaping (Int) -> Void) -> some Gesture {
        DragGesture(coordinateSpace: .named("stack"))
            .onChanged { value in
                // Dividers are only adjustable while editing — outside edit mode a
                // drag must do nothing (no value change, and crucially no haptic).
                guard viewModel.isEditing else { return }
                // Convert the drag's y position to bpm using the live geometry
                // captured via the closure's reference frame.
                let start = dragStartBpm ?? currentBpm
                if dragStartBpm == nil { dragStartBpm = currentBpm }
                // translation in points → bpm delta (computed against full range
                // and the stack height held in lastStackHeight).
                let bpmPerPoint = CGFloat(viewModel.displayRange) / max(1, lastStackHeight)
                let delta = Int((-value.translation.height * bpmPerPoint).rounded())
                let newBpm = start + delta
                if newBpm != currentBpm {
                    onChange(newBpm)
                    Haptics.tick()
                }
            }
            .onEnded { _ in dragStartBpm = nil }
    }

    // Captured each layout pass so the drag math knows the pixel height.
    @State private var lastStackHeight: CGFloat = 1

    // MARK: - Live HR marker

    private func liveHRMarker(bpm: Int, y: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
                .frame(width: width, height: 2)
                .opacity(0.9)
            HStack(spacing: 3) {
                Image(systemName: "heart.fill").font(.system(size: 10))
                Text("\(bpm)").font(.system(size: 13, weight: .heavy)).monospacedDigit()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(Color.red))
            .position(x: 30, y: 0)
        }
        .frame(width: width, height: 24)
        .offset(y: y - 12)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.4), value: bpm)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if viewModel.isEditing {
                Button {
                    viewModel.resetToDefaults()
                    Haptics.impact()
                } label: {
                    Label("Reset to % of max", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
            }
            Spacer()
            if heartRateService.isConnected {
                Label("Live", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption).foregroundColor(.red)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func pctOfMax(_ bpm: Int) -> Int {
        guard viewModel.maxHR > 0 else { return 0 }
        return Int((Double(bpm) / Double(viewModel.maxHR) * 100).rounded())
    }
}

extension Color {
    /// Linear RGB blend toward `other` by `amount` (0 = self, 1 = other).
    func blended(with other: Color, amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t)
        )
    }
}

/// Lightweight haptics wrapper.
enum Haptics {
    static func tick() {
        let g = UISelectionFeedbackGenerator()
        g.selectionChanged()
    }
    static func impact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
