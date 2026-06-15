import SwiftUI

struct PowerPicker: View {
    @Binding var selectedPower: Int
    let options: [Int]

    var body: some View {
        Menu {
            Picker("Target Power", selection: $selectedPower) {
                ForEach(options, id: \.self) { power in
                    Text("\(power)W").tag(power)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.yellow)
                    Text("POWER")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(selectedPower)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("W")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }
}

#Preview {
    PowerPicker(
        selectedPower: .constant(150),
        options: stride(from: 50, through: 300, by: 5).map { $0 }
    )
    .padding()
}
