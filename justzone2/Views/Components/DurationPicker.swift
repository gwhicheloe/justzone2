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
            VStack(spacing: 2) {
                Text("Duration")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(formatDuration(selectedDuration))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
