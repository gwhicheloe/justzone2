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
            VStack(spacing: 2) {
                Text("Target Power")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(selectedPower)W")
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
    PowerPicker(
        selectedPower: .constant(150),
        options: stride(from: 50, through: 300, by: 5).map { $0 }
    )
    .padding()
}
