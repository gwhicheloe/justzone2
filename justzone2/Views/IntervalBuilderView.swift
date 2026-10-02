import SwiftUI

/// Saved interval sessions: tap to edit, swipe to delete, + to add.
/// Reached from Settings and from the Setup screen's interval picker.
struct IntervalSessionListView: View {
    @ObservedObject private var store = IntervalSessionStore.shared
    @State private var editing: IntervalSession?

    var body: some View {
        List {
            if store.sessions.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No interval sessions yet")
                            .font(.subheadline.weight(.semibold))
                        Text("Build one: how many intervals, how long, how hard, and the power to recover at in between.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                ForEach(store.sessions) { session in
                    Button { editing = session } label: {
                        IntervalSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for i in offsets { store.delete(id: store.sessions[i].id) }
                }
            }
        }
        .navigationTitle("Interval Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = IntervalSession.newTemplate } label: {
                    Label("New Session", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { session in
            IntervalSessionEditor(session: session) { saved in
                store.save(saved)
            }
        }
    }
}

struct IntervalSessionRow: View {
    let session: IntervalSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(IntervalSession.formatDuration(session.totalDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            IntervalProfileView(session: session)
                .frame(height: 26)
            HStack {
                Text(session.recoverySummary)
                Spacer()
                Text("Weighted avg \(session.weightedAveragePower) W")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Create or edit one session. The name defaults to a description of the
/// session ("5 × 4 min @ 220 W") and updates as the numbers change, until the
/// rider types their own.
struct IntervalSessionEditor: View {
    @State private var session: IntervalSession
    @State private var name: String
    let onSave: (IntervalSession) -> Void
    @Environment(\.dismiss) private var dismiss

    init(session: IntervalSession, onSave: @escaping (IntervalSession) -> Void) {
        _session = State(initialValue: session)
        _name = State(initialValue: session.customName ?? "")
        self.onSave = onSave
    }

    private static let workDurations: [TimeInterval] =
        [15, 20, 30, 40, 45, 60, 90, 120, 150, 180, 240, 300, 360, 420, 480, 600, 720, 900, 1200, 1500, 1800]
    private static let restDurations: [TimeInterval] =
        [10, 15, 20, 30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 480, 600]
    private static let setRecoveryDurations: [TimeInterval] =
        [60, 90, 120, 150, 180, 240, 300, 360, 480, 600]
    private static let easyDurations: [TimeInterval] =
        [0, 180, 300, 420, 600, 720, 900, 1200, 1800]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        IntervalProfileView(session: session)
                            .frame(height: 54)
                        HStack {
                            Label(IntervalSession.formatDuration(session.totalDuration), systemImage: "timer")
                            Spacer()
                            Label("\(session.totalIntervals) intervals", systemImage: "bolt.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        // Recalculated live as the numbers change.
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Weighted average power")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(session.weightedAveragePower)")
                                .font(.title3.weight(.bold).monospacedDigit())
                                .contentTransition(.numericText())
                            Text("W")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Intervals") {
                    Stepper(value: $session.intervalCount, in: 1...30) {
                        LabeledContent(session.setsEnabled ? "Number per set" : "Number", value: "\(session.intervalCount)")
                    }
                    durationPicker("Duration", selection: $session.workDuration, options: Self.workDurations)
                    powerRow("Power", value: $session.workPower)
                }

                Section {
                    durationPicker("Duration", selection: $session.restDuration, options: Self.restDurations)
                    powerRow("Power", value: $session.restPower)
                } header: {
                    Text("Recovery between intervals")
                }

                Section {
                    Toggle("Ride in sets", isOn: $session.setsEnabled.animation())
                    if session.setsEnabled {
                        Stepper(value: $session.setCount, in: 2...10) {
                            LabeledContent("Number of sets", value: "\(session.setCount)")
                        }
                        durationPicker("Recovery between sets", selection: $session.setRecoveryDuration, options: Self.setRecoveryDurations)
                    }
                } header: {
                    Text("Sets")
                } footer: {
                    Text(session.setsEnabled
                         ? "\(session.setCount) sets of \(session.intervalCount), with a longer recovery between sets at the recovery power."
                         : "Repeat the intervals in sets with a longer recovery between them, like Rønnestad's 3 × 13 × 30/15s.")
                }

                Section {
                    durationPicker("Warm-up", selection: $session.warmUpDuration, options: Self.easyDurations)
                    durationPicker("Cool-down", selection: $session.coolDownDuration, options: Self.easyDurations)
                } header: {
                    Text("Warm-up & cool-down")
                } footer: {
                    Text("Ridden at the recovery power.")
                }

                Section {
                    TextField(session.defaultName, text: $name)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Leave blank to use \"\(session.defaultName)\".")
                }
            }
            .navigationTitle(IntervalSessionStore.shared.session(id: session.id) == nil ? "New Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = session
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        saved.customName = trimmed.isEmpty ? nil : trimmed
                        onSave(saved)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func durationPicker(_ title: String, selection: Binding<TimeInterval>, options: [TimeInterval]) -> some View {
        // Keep an edited value that isn't in the preset list selectable.
        let all = options.contains(selection.wrappedValue) ? options : (options + [selection.wrappedValue]).sorted()
        return Picker(title, selection: selection) {
            ForEach(all, id: \.self) { d in
                Text(d == 0 ? "None" : IntervalSession.formatDuration(d)).tag(d)
            }
        }
    }

    private func powerRow(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("W", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .onChange(of: value.wrappedValue) { _, new in
                    let clamped = min(max(new, 30), 1500)
                    if clamped != new { value.wrappedValue = clamped }
                }
            Text("W").foregroundStyle(.secondary)
            Stepper("", value: value, in: 30...1500, step: 5)
                .labelsHidden()
        }
    }
}

#Preview {
    NavigationStack { IntervalSessionListView() }
}
