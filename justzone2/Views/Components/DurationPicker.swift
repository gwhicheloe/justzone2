import SwiftUI

struct DurationPicker: View {
    @Binding var selectedDuration: TimeInterval
    let options: [TimeInterval]
    let formatDuration: (TimeInterval) -> String

    var body: some View {
        VStack(spacing: 4) {
            Text("Duration")
                .font(.bodyMedium)
                .foregroundColor(.secondary)

            Picker("Duration", selection: $selectedDuration) {
                ForEach(options, id: \.self) { duration in
                    Text(formatDuration(duration))
                        .font(.bodyLarge)
                        .tag(duration)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
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
