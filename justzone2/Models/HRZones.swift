import SwiftUI

/// The five standard heart-rate training zones. Zone 2 is the namesake zone
/// that drives the app's ERG/PID engine; its boundaries are persisted to the
/// existing `zone2Min` / `zone2Max` UserDefaults keys so all the existing
/// consumers (PID, charts, Strava description) keep working unchanged.
enum HRZone: Int, CaseIterable, Identifiable {
    case z1 = 1, z2, z3, z4, z5

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .z1: return "Recovery"
        case .z2: return "Endurance"
        case .z3: return "Tempo"
        case .z4: return "Threshold"
        case .z5: return "VO₂ Max"
        }
    }

    var label: String { "Zone \(rawValue)" }

    var color: Color {
        switch self {
        case .z1: return Color(red: 0.31, green: 0.76, blue: 0.97) // blue
        case .z2: return Color(red: 0.20, green: 0.78, blue: 0.35) // green
        case .z3: return Color(red: 1.00, green: 0.84, blue: 0.20) // yellow
        case .z4: return Color(red: 1.00, green: 0.58, blue: 0.00) // orange
        case .z5: return Color(red: 1.00, green: 0.27, blue: 0.23) // red
        }
    }

    /// One-line description shown under the zone name.
    var blurb: String {
        switch self {
        case .z1: return "Active recovery"
        case .z2: return "Aerobic base — the JustZone2 zone"
        case .z3: return "Aerobic endurance"
        case .z4: return "Lactate threshold"
        case .z5: return "Maximal effort"
        }
    }
}

/// A computed zone band: which zone, and its inclusive bpm bounds.
struct HRZoneBand: Identifiable {
    let zone: HRZone
    let lower: Int
    let upper: Int
    var id: Int { zone.rawValue }
    var span: Int { max(1, upper - lower) }
}
