import SwiftUI

struct DurationPicker: View {
    @Binding var selectedDuration: TimeInterval
    let options: [TimeInterval]
    let formatDuration: (TimeInterval) -> String

    var body: some View {
        Menu {
            Picker("Duration", selection: $selectedDuration) {
                ForEach(options, id: \.self) { duration in
                    Text(formatDuration(duration)).tag(duration)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                    Text("DURATION")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 0) {
                    Text(formatDuration(selectedDuration))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
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
    DurationPicker(
        selectedDuration: .constant(30 * 60),
        options: stride(from: 15 * 60, through: 180 * 60, by: 5 * 60).map { TimeInterval($0) },
        formatDuration: { duration in
            let minutes = Int(duration) / 60
            return "\(minutes) min"
        }
    )
    .padding()
}
