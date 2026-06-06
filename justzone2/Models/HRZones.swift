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
        case .z1: return Color(red: 0.36, green: 0.66, blue: 0.86) // muted blue
        case .z2: return Color(red: 0.28, green: 0.70, blue: 0.42) // muted green
        case .z3: return Color(red: 0.86, green: 0.72, blue: 0.30) // muted gold
        case .z4: return Color(red: 0.88, green: 0.50, blue: 0.22) // muted amber-orange
        case .z5: return Color(red: 0.82, green: 0.32, blue: 0.32) // muted red
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

/// Read-only access to the persisted zone boundaries, for code outside the
/// editor (e.g. classifying a finished workout's samples at upload time).
enum HRZoneBoundaries {
    /// The 6 anchors bottom→top: [resting, d1, d2, d3, d4, maxHR].
    static func anchors() -> [Int] {
        let d = UserDefaults.standard
        if let resting = d.object(forKey: "hrZoneResting") as? Int,
           let dividers = d.array(forKey: "hrZoneDividers") as? [Int], dividers.count == 4,
           let maxHR = d.object(forKey: "hrZoneMax") as? Int {
            return [resting] + dividers + [maxHR]
        }
        // Fallback for pre-zones installs: derive from the legacy Z2 keys.
        let z2Min = d.object(forKey: "zone2Min") as? Int ?? 120
        let z2Max = d.object(forKey: "zone2Max") as? Int ?? 140
        let maxHR = max(z2Max + 20, Int((Double(z2Max) / 0.75).rounded()))
        return [60, z2Min, z2Max, z2Max + (maxHR - z2Max) * 45 / 100, z2Max + (maxHR - z2Max) * 75 / 100, maxHR]
    }

    /// Which zone a single bpm reading falls in. Below the resting floor counts
    /// as Z1; at/above max counts as Z5.
    static func zone(for bpm: Int, anchors: [Int]) -> HRZone {
        for zone in HRZone.allCases {
            let i = zone.rawValue - 1            // band i spans anchors[i]..<anchors[i+1]
            if bpm < anchors[i + 1] { return zone }
        }
        return .z5
    }

    /// The zone the workout spent the most samples in, or nil if no HR data.
    static func dominantZone(heartRates: [Int]) -> HRZone? {
        guard !heartRates.isEmpty else { return nil }
        let a = anchors()
        var counts = [Int](repeating: 0, count: HRZone.allCases.count)
        for hr in heartRates where hr > 0 {
            counts[zone(for: hr, anchors: a).rawValue - 1] += 1
        }
        guard let maxCount = counts.max(), maxCount > 0,
              let idx = counts.firstIndex(of: maxCount) else { return nil }
        return HRZone(rawValue: idx + 1)
    }
}
