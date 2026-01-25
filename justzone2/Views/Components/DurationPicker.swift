import SwiftUI

struct DurationPicker: View {
    @Binding var selectedDuration: TimeInterval
    let options: [TimeInterval]
    let formatDuration: (TimeInterval) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.headline)

            Picker("Duration", selection: $selectedDuration) {
                ForEach(options, id: \.self) { duration in
                    Text(formatDuration(duration)).tag(duration)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)

            Text("Zone 2 sessions: 30-90 minutes recommended")
                .font(.caption)
                .foregroundColor(.secondary)
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
