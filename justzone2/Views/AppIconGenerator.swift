import SwiftUI

/// Use this view to generate an app icon
/// Run it in the preview, take a screenshot, and use an online tool to resize it for all icon sizes
struct AppIconGenerator: View {
    var body: some View {
        ZStack {
            // Solid black background
            Color.black

            // Big green "2" in Arial Rounded MT Bold
            Text("2")
                .font(.custom("ArialRoundedMTBold", size: 700))
                .foregroundColor(.green)
        }
        .frame(width: 1024, height: 1024) // App Store size
    }
}

// Alternative designs

struct AppIconGenerator_Minimal: View {
    var body: some View {
        ZStack {
            // Solid color background
            Color.green
            
            // Simple bike symbol with heart
            VStack(spacing: -10) {
                Image(systemName: "figure.indoor.cycle")
                    .font(.system(size: 140, weight: .bold))
                    .foregroundColor(.white)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.red)
            }
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .frame(width: 1024, height: 1024)
        .cornerRadius(220)
    }
}

struct AppIconGenerator_Dark: View {
    var body: some View {
        ZStack {
            // Dark gradient
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Power meter style
            ZStack {
                Circle()
                    .stroke(Color.green, lineWidth: 20)
                    .frame(width: 400, height: 400)
                
                VStack(spacing: 16) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 100, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("Z2")
                        .font(.system(size: 120, weight: .black, design: .rounded))
                        .foregroundColor(.green)
                }
            }
        }
        .frame(width: 1024, height: 1024)
        .cornerRadius(220)
    }
}

#Preview("Big Green 2") {
    AppIconGenerator()
}

#Preview("Minimal Cyclist") {
    AppIconGenerator_Minimal()
}

#Preview("Dark Power") {
    AppIconGenerator_Dark()
}

// Helper to export the icon
@MainActor
func exportAppIcon() {
    let renderer = ImageRenderer(content: AppIconGenerator())
    renderer.scale = 1.0

    if let image = renderer.uiImage,
       let data = image.pngData() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppIcon.png")
        try? data.write(to: url)
        print("Icon saved to: \(url.path)")
    }
}
