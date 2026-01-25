import SwiftUI

struct PowerPicker: View {
    @Binding var selectedPower: Int
    let options: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Power")
                .font(.headline)

            Picker("Target Power", selection: $selectedPower) {
                ForEach(options, id: \.self) { power in
                    Text("\(power)W").tag(power)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)

            Text("Zone 2 typically: 130-170W for most riders")
                .font(.caption)
                .foregroundColor(.secondary)
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
