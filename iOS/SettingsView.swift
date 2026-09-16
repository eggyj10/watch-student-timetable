import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var store: TimetableStore
    @State private var showResetConfirm = false

    private var title: Binding<String> {
        Binding(get: { store.timetable.title },
                set: { new in store.update { $0.title = new } })
    }

    private var studentName: Binding<String> {
        Binding(get: { store.timetable.studentName },
                set: { new in store.update { $0.studentName = new } })
    }

    private var settleMinutes: Binding<Int> {
        Binding(get: { store.timetable.settleMinutes },
                set: { new in store.update { $0.settleMinutes = new } })
    }

    private var reminderCount: Int {
        store.timetable.remindedCells.count + store.timetable.remindedExcursions.count
    }

    /// Worked through with a real period so the number means something.
    private var settleExplanation: String {
        let minutes = store.timetable.settleMinutes
        guard let p3 = store.timetable.slot(code: "P3") else {
            return "Once a class has been running this long you already know where you are, so the watch face starts pointing at the next one instead."
        }
        let flip = p3.start.adding(minutes: minutes)
        return "Once a class has been running this long you already know where you are, "
            + "so the watch face starts pointing at the next one instead. "
            + "P3 starts at \(p3.start.display), so the face shows P3 until \(flip.display), then switches to P4."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("This timetable") {
                    TextField("Title", text: title)
                    TextField("Student", text: studentName)
                }

                Section {
                    Stepper("Switch to next after \(settleMinutes.wrappedValue) min",
                            value: settleMinutes, in: 0...60)
                } header: {
                    Text("Watch face")
                } footer: {
                    Text(settleExplanation)
                }

                Section("Content") {
                    NavigationLink { SubjectsView().environmentObject(store) } label: {
                        Label("Subjects", systemImage: "book")
                    }
                    NavigationLink { TeachersView().environmentObject(store) } label: {
                        Label("Teachers", systemImage: "person.2")
                    }
                    NavigationLink { SlotsView().environmentObject(store) } label: {
                        Label("Periods & Bells", systemImage: "bell")
                    }
                    NavigationLink { ExcursionsView().environmentObject(store) } label: {
                        HStack {
                            Label("Excursions", systemImage: "bus")
                            Spacer()
                            Text("\(store.timetable.excursions.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { BulkTextView().environmentObject(store) } label: {
                        Label("Bulk edit as text", systemImage: "text.alignleft")
                    }
                }

                Section {
                    HStack {
                        Label("Reminders set", systemImage: "bell")
                        Spacer()
                        Text("\(reminderCount)")
                            .foregroundStyle(.secondary)
                    }
                    if reminderCount > 0 {
                        Button("Turn all reminders off", role: .destructive) {
                            store.update { timetable in
                                for index in timetable.cells.indices {
                                    timetable.cells[index].reminderMinutes = nil
                                }
                                for index in timetable.excursions.indices {
                                    timetable.excursions[index].reminderMinutes = nil
                                }
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Set a reminder on an individual class, activity or excursion when you edit it. They are delivered by the Apple Watch so they still arrive with your phone out of range, and the watch asks for permission the first time you set one.")
                }

                Section {
                    HStack {
                        Label("Watch", systemImage: "applewatch")
                        Spacer()
                        Text(store.syncState.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        store.pushToCounterpart()
                    } label: {
                        Label("Send to Watch now", systemImage: "arrow.up.circle")
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text(TimetableStorage.isUsingAppGroup
                         ? "Changes are sent automatically. The watch keeps its own copy and works with the phone out of range."
                         : "App Group is not configured, so the widget will not see your data. Check the entitlement on every target.")
                }

                Section {
                    Button("Reload sample timetable") {
                        store.replace(with: .highfieldsTerm3)
                    }
                    Button("Clear all classes", role: .destructive) {
                        showResetConfirm = true
                    }
                } footer: {
                    Text("Revision \(store.timetable.revision)")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear every class?",
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible) {
                Button("Clear all classes", role: .destructive) {
                    store.replace(with: .blank)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Periods and bell times are kept. Subjects, teachers and classes are removed.")
            }
        }
    }
}

// MARK: - Bulk text editing

/// Faster than tapping through 25 cells at the start of a term.
struct BulkTextView: View {

    @EnvironmentObject private var store: TimetableStore

    @State private var text = ""
    @State private var warnings: [String] = []
    @State private var didApply = false

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 280)
            } header: {
                Text("Timetable")
            } footer: {
                Text("""
                One line per entry:
                MON P1 SCI102B DAYLU K34 — a class
                A MON SB Chess Club @ Library — an activity
                S SCI102B Science — define a subject
                T DAYLU Mr Day — define a teacher
                Add !10 to the end of a line for a reminder. Use - for a blank teacher or room, and # for a comment. Excursions are edited on their own screen and are left alone here.
                """)
            }

            if !warnings.isEmpty {
                Section("Warnings") {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                Button("Apply") { apply() }
                Button("Reload from current timetable") { load() }
            } footer: {
                if didApply {
                    Text("Applied and sent to the watch.")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Bulk edit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func load() {
        text = TimetableTextFormat.export(store.timetable)
        warnings = []
        didApply = false
    }

    private func apply() {
        let result = TimetableTextFormat.parse(text, base: store.timetable)
        warnings = result.warnings
        store.replace(with: result.timetable)
        didApply = true
    }
}
