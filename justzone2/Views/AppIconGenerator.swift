import SwiftUI

/// Use this view to generate an app icon
/// Run it in the preview, take a screenshot, and use an online tool to resize it for all icon sizes
struct AppIconGenerator: View {
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.green, Color.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                // Cycling/power symbol
                Image(systemName: "bolt.fill")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Heart rate line
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
            }
        }
        .frame(width: 1024, height: 1024) // App Store size
        .cornerRadius(220) // iOS app icon corner radius ratio
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

#Preview("Green Gradient") {
    AppIconGenerator()
}

#Preview("Minimal Cyclist") {
    AppIconGenerator_Minimal()
}

#Preview("Dark Power") {
    AppIconGenerator_Dark()
}
