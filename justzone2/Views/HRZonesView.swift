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

                Text("Drag the dividers to set your zones. Zone 2 drives your workouts.")
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
        VStack(spacing: 8) {
            pickerRow(binding: restingBinding, range: Array(30...120), label: "Min HR")
            pickerRow(binding: maxBinding, range: Array(120...230), label: "Max HR")
        }
        .padding(12)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func pickerRow(binding: Binding<Int>, range: [Int], label: String) -> some View {
        HStack(spacing: 12) {
            Picker("", selection: binding) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .clipped()

            Text(label)
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Zone stack

    private func zoneStack(in size: CGSize) -> some View {
        // Map a bpm value to a y-offset (top = maxHR, bottom = restingHR).
        let h = size.height
        let range = CGFloat(viewModel.fullRange)
        func y(for bpm: Int) -> CGFloat {
            let frac = CGFloat(bpm - viewModel.restingHR) / range
            return h - frac * h
        }

        return ZStack(alignment: .topLeading) {
            // Zone bands (top zone first so it draws downward).
            ForEach(viewModel.bands.reversed()) { band in
                let top = y(for: band.upper)
                let bottom = y(for: band.lower)
                bandView(band, top: top, height: max(0, bottom - top), width: size.width)
            }

            // Draggable dividers (between zones). Top/bottom edges are fixed —
            // set by the Min/Max HR pickers above.
            ForEach(0..<viewModel.dividers.count, id: \.self) { i in
                handle(
                    bpm: viewModel.dividers[i],
                    y: y(for: viewModel.dividers[i]),
                    width: size.width
                ) { newBpm in viewModel.setDivider(i, to: newBpm) }
            }

            // Live HR marker (BLE strap only — the only live source outside a workout).
            if heartRateService.isConnected, heartRateService.currentHeartRate > 0 {
                liveHRMarker(bpm: heartRateService.currentHeartRate, y: y(for: heartRateService.currentHeartRate), width: size.width)
            }
        }
        .coordinateSpace(name: "stack")
    }

    private func bandView(_ band: HRZoneBand, top: CGFloat, height: CGFloat, width: CGFloat) -> some View {
        let isZ2 = band.zone == .z2
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(band.zone.color.opacity(isZ2 ? 0.30 : 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(band.zone.color.opacity(isZ2 ? 0.9 : 0.4),
                                      lineWidth: isZ2 ? 2 : 1)
                )
                .shadow(color: isZ2 ? band.zone.color.opacity(0.5) : .clear,
                        radius: isZ2 ? 10 : 0)

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(band.zone.label)
                            .font(.subheadline.bold())
                        if isZ2 {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(band.zone.color)
                        }
                    }
                    Text(band.zone.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(band.lower)–\(band.upper)")
                        .font(.caption.monospacedDigit().bold())
                    Text("\(pctOfMax(band.lower))–\(pctOfMax(band.upper))% max")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            // Left inset clears the divider grip tab that sits at the band's top edge.
            .padding(.leading, 52)
            .padding(.trailing, 14)
            .opacity(height > 30 ? 1 : 0)  // hide labels in very thin bands
        }
        .frame(width: width, height: height)
        .offset(y: top)
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

            // Grip tab on the left — signals the line is draggable.
            HStack(spacing: 1.5) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(Color.secondary)
                        .frame(width: 9, height: 1.5)
                }
            }
            .padding(.horizontal, 7).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(lineColor, lineWidth: 1.5))
            )
            .position(x: 22, y: 0)

            // bpm pill on the right.
            Text("\(bpm)")
                .font(.system(size: 14, weight: .bold)).monospacedDigit()
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color(.systemBackground)))
                .overlay(Capsule().strokeBorder(lineColor, lineWidth: 1.5))
                .frame(width: pillWidth)
                .position(x: width - pillWidth / 2, y: 0)
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
                // Convert the drag's y position to bpm using the live geometry
                // captured via the closure's reference frame.
                let start = dragStartBpm ?? currentBpm
                if dragStartBpm == nil { dragStartBpm = currentBpm }
                // translation in points → bpm delta (computed against full range
                // and the stack height held in lastStackHeight).
                let bpmPerPoint = CGFloat(viewModel.fullRange) / max(1, lastStackHeight)
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
            Button {
                viewModel.resetToDefaults()
                Haptics.impact()
            } label: {
                Label("Reset to % of max", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
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
