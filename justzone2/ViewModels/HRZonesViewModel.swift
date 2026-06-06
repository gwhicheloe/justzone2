import SwiftUI
import Combine

/// Owns the six HR-zone anchors and persists them. Zone 2's bounds are mirrored
/// to the legacy `zone2Min`/`zone2Max` keys so the PID engine and all charts
/// keep reading the same source of truth.
@MainActor
final class HRZonesViewModel: ObservableObject {
    // Anchors, bottom → top. dividers[i] separates Zone (i+1) from Zone (i+2).
    @Published var restingHR: Int          // floor of Zone 1
    @Published var dividers: [Int]         // 4 values: z1/2, z2/3, z3/4, z4/5
    @Published var maxHR: Int              // ceiling of Zone 5

    /// Smallest allowed gap (bpm) between adjacent anchors.
    let minGap = 3
    /// Hard limits for the whole scale.
    let absoluteFloor = 30
    let absoluteCeiling = 230

    private let defaults = UserDefaults.standard
    private enum Key {
        static let resting = "hrZoneResting"
        static let dividers = "hrZoneDividers"   // stored as [Int]
        static let maxHR = "hrZoneMax"
        static let z2Min = "zone2Min"            // legacy — Zone 2 lower
        static let z2Max = "zone2Max"            // legacy — Zone 2 upper
    }

    init() {
        let storedMax = defaults.object(forKey: Key.maxHR) as? Int
        let storedResting = defaults.object(forKey: Key.resting) as? Int
        let storedDividers = defaults.array(forKey: Key.dividers) as? [Int]

        if let storedMax, let storedResting,
           let storedDividers, storedDividers.count == 4 {
            // Full zone config exists.
            self.maxHR = storedMax
            self.restingHR = storedResting
            self.dividers = storedDividers
        } else {
            // First run with zones: migrate. Seed from any existing Zone 2 range
            // so nothing the user already set gets reset, then derive the rest
            // from textbook %-of-max splits.
            let z2Min = defaults.object(forKey: Key.z2Min) as? Int ?? 120
            let z2Max = defaults.object(forKey: Key.z2Max) as? Int ?? 140
            // Estimate max HR so the upper zones land somewhere sensible:
            // assume the user's Z2 top ≈ 75% of max.
            let estMax = max(z2Max + 20, Int((Double(z2Max) / 0.75).rounded()))
            let computedMax = min(estMax, 230)  // absoluteCeiling
            // dividers: z1/2 = z2Min, z2/3 = z2Max, then split the remaining
            // span to max into two even steps for z3/4 and z4/5.
            let remaining = computedMax - z2Max
            let d3 = z2Max + Int(Double(remaining) * 0.45)
            let d4 = z2Max + Int(Double(remaining) * 0.75)
            self.maxHR = computedMax
            self.restingHR = 60
            self.dividers = [z2Min, z2Max, d3, d4]
        }
        normalize()
        persist()
    }

    // MARK: - Derived bands

    /// All five zone bands, bottom → top.
    var bands: [HRZoneBand] {
        let bounds = [restingHR] + dividers + [maxHR]
        return HRZone.allCases.map { zone in
            let i = zone.rawValue - 1
            return HRZoneBand(zone: zone, lower: bounds[i], upper: bounds[i + 1])
        }
    }

    var fullRange: Int { max(1, maxHR - restingHR) }

    // MARK: - Edit mode

    /// Zones can only be changed while editing — guards against accidental drags
    /// altering the Zone 2 range that drives the trainer. Edits stay in memory
    /// until Save; Discard restores the snapshot taken at Begin Edit.
    @Published private(set) var isEditing = false
    @Published private(set) var hasChanges = false
    private var snapshot: (resting: Int, dividers: [Int], maxHR: Int)?

    func beginEdit() {
        snapshot = (restingHR, dividers, maxHR)
        hasChanges = false
        isEditing = true
    }

    func save() {
        normalize()
        persist()
        snapshot = nil
        hasChanges = false
        isEditing = false
    }

    func discard() {
        if let s = snapshot {
            restingHR = s.resting
            dividers = s.dividers
            maxHR = s.maxHR
        }
        snapshot = nil
        hasChanges = false
        isEditing = false
    }

    // MARK: - Editing (in-memory only; persisted on save)

    /// Move divider `index` (0...3) to `bpm`, clamped so anchors never cross.
    func setDivider(_ index: Int, to bpm: Int) {
        guard isEditing else { return }
        let lowerBound = (index == 0 ? restingHR : dividers[index - 1]) + minGap
        let upperBound = (index == dividers.count - 1 ? maxHR : dividers[index + 1]) - minGap
        dividers[index] = min(max(bpm, lowerBound), upperBound)
        hasChanges = true
    }

    func setResting(to bpm: Int) {
        guard isEditing else { return }
        restingHR = min(max(bpm, absoluteFloor), dividers[0] - minGap)
        hasChanges = true
    }

    /// Drag the Max HR ceiling. Zones below rescale proportionally so the
    /// relative shape is preserved.
    func setMaxHR(to bpm: Int) {
        guard isEditing else { return }
        let newMax = min(max(bpm, dividers[dividers.count - 1] + minGap), absoluteCeiling)
        let oldSpan = Double(maxHR - restingHR)
        hasChanges = true
        guard oldSpan > 0 else { maxHR = newMax; return }
        let newSpan = Double(newMax - restingHR)
        dividers = dividers.map { d in
            let frac = Double(d - restingHR) / oldSpan
            return restingHR + Int((frac * newSpan).rounded())
        }
        maxHR = newMax
        normalize()
    }

    /// Reset to Strava's default %-of-max zone boundaries so the user's zones
    /// line up with what Strava shows for the same ride. Strava's bands (cycling)
    /// are Z1 ≤59%, Z2 59–78%, Z3 78–87%, Z4 87–97%, Z5 97–100% of max HR.
    func resetToDefaults() {
        guard isEditing else { return }
        let m = Double(maxHR)
        dividers = [
            Int((m * 0.59).rounded()),   // Z1 / Z2
            Int((m * 0.78).rounded()),   // Z2 / Z3
            Int((m * 0.87).rounded()),   // Z3 / Z4
            Int((m * 0.97).rounded()),   // Z4 / Z5
        ]
        normalize()
        hasChanges = true
    }

    // MARK: - Persistence

    /// Enforce ordering + min gaps across all anchors.
    private func normalize() {
        restingHR = max(absoluteFloor, min(restingHR, absoluteCeiling - minGap * 5))
        var prev = restingHR
        for i in dividers.indices {
            dividers[i] = max(dividers[i], prev + minGap)
            prev = dividers[i]
        }
        maxHR = max(maxHR, prev + minGap)
        maxHR = min(maxHR, absoluteCeiling)
    }

    private func persist() {
        defaults.set(maxHR, forKey: Key.maxHR)
        defaults.set(restingHR, forKey: Key.resting)
        defaults.set(dividers, forKey: Key.dividers)
        // Mirror Zone 2 to the legacy keys the rest of the app reads.
        defaults.set(dividers[0], forKey: Key.z2Min)
        defaults.set(dividers[1], forKey: Key.z2Max)
    }
}
