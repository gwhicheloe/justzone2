import SwiftUI

struct PowerPicker: View {
    @Binding var selectedPower: Int
    let options: [Int]

    var body: some View {
        VStack(spacing: 4) {
            Text("Power")
                .font(.bodyMedium)
                .foregroundColor(.secondary)

            Picker("Target Power", selection: $selectedPower) {
                ForEach(options, id: \.self) { power in
                    Text("\(power)W")
                        .font(.bodyLarge)
                        .tag(power)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
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
