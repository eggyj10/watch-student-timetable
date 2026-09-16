import SwiftUI

// MARK: - Week editor

/// Tap a period, pick what is in it. Every change is written to disk and pushed
/// to the watch immediately.
struct WeekEditorView: View {

    @EnvironmentObject private var store: TimetableStore
    @State private var day: Weekday = Self.initialDay()
    @State private var editing: Slot?

    private static func initialDay() -> Weekday {
        Weekday(calendarWeekday: Calendar.current.component(.weekday, from: Date())) ?? .monday
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Day", selection: $day) {
                    ForEach(Weekday.allCases) { day in
                        Text(day.shortName).tag(day)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                List {
                    Section {
                        ForEach(store.timetable.slots(on: day)) { slot in
                            Button {
                                editing = slot
                            } label: {
                                SlotEditRow(day: day, slot: slot, timetable: store.timetable)
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text("Breaks and the before/after-school bands can hold activities too. A band you add something to shows up on that day even if it does not normally run.")
                    }

                    Section {
                        NavigationLink {
                            ExcursionsView().environmentObject(store)
                        } label: {
                            Label("Excursions", systemImage: "bus")
                        }
                    } footer: {
                        Text("Excursions are tied to a date and take over whatever periods they overlap.")
                    }
                }
            }
            .navigationTitle(day.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { slot in
                CellEditorView(day: day, slot: slot)
                    .environmentObject(store)
            }
        }
    }
}

struct SlotEditRow: View {

    let day: Weekday
    let slot: Slot
    let timetable: Timetable

    private var cell: Cell? { timetable.cell(day: day, slotCode: slot.code) }

    private var accent: Color {
        guard let cell else { return Color.secondary.opacity(0.25) }
        if cell.kind == .activity {
            return Color(hex: cell.colorHex.isEmpty ? "#8E8E93" : cell.colorHex)
        }
        return timetable.subject(code: cell.subjectCode).map { Color(hex: $0.colorHex) }
            ?? Color.secondary.opacity(0.25)
    }

    private var titleText: String {
        guard let cell else { return slot.kind == .lesson ? "Free" : slot.label }
        if cell.kind == .activity {
            return cell.title.isEmpty ? slot.label : cell.title
        }
        return timetable.subject(code: cell.subjectCode)?.name ?? cell.subjectCode
    }

    private var subtitleText: String? {
        guard let cell else { return nil }
        if cell.kind == .activity {
            return cell.room.isEmpty ? nil : cell.room
        }
        let teacher = timetable.teacherName(cell.teacherCode) ?? cell.teacherCode
        let parts = [cell.room, teacher].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.code)
                    .font(.footnote.weight(.bold))
                Text(slot.start.display)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(width: 44, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if cell?.kind == .activity {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(accent)
                    }
                    Text(titleText)
                        .font(.subheadline.weight(cell == nil ? .regular : .semibold))
                        .foregroundStyle(cell == nil ? .secondary : .primary)
                }
                if let subtitleText {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if cell?.hasReminder == true {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Cell editor

struct CellEditorView: View {

    @EnvironmentObject private var store: TimetableStore
    @Environment(\.dismiss) private var dismiss

    let day: Weekday
    let slot: Slot

    @State private var kind: EntryKind = .lesson
    @State private var isEmpty = true

    // Lesson
    @State private var subjectCode = ""
    @State private var teacherCode = ""

    // Activity
    @State private var title = ""
    @State private var colorHex = Palette.choices[0]
    @State private var note = ""

    // Shared
    @State private var room = ""
    @State private var reminderOn = false
    @State private var reminderMinutes = 5

    private var teacherCodes: [String] { store.timetable.teachers.keys.sorted() }
    private let colorColumns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Class").tag(EntryKind.lesson)
                        Text("Activity").tag(EntryKind.activity)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("\(slot.label) · \(slot.start.display)-\(slot.end.display)")
                } footer: {
                    Text(kind == .lesson
                         ? "A timetabled class from your subject list."
                         : "Anything else you have committed to: a club, training, a standing appointment.")
                }

                if kind == .lesson {
                    lessonSection
                } else {
                    activitySection
                }

                reminderSection

                if !isEmpty {
                    Section {
                        Button("Clear this period", role: .destructive) {
                            store.update { $0.clearCell(day: day, slotCode: slot.code) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(day.shortName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var lessonSection: some View {
        Section {
            Picker("Subject", selection: $subjectCode) {
                Text("Free").tag("")
                ForEach(store.timetable.subjects) { subject in
                    Text(subject.name).tag(subject.code)
                }
            }

            Picker("Teacher", selection: $teacherCode) {
                Text("None").tag("")
                ForEach(teacherCodes, id: \.self) { code in
                    Text(store.timetable.teachers[code] ?? code).tag(code)
                }
            }

            TextField("Room", text: $room)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        } footer: {
            if slot.grace > 0 {
                Text("Bell rings at \(slot.start.display); be in the room by \(slot.arriveBy.display).")
            } else if slot.bellLead > 0 {
                Text("Bell rings \(slot.bellLead) min early, at \(slot.start.adding(minutes: -slot.bellLead).display).")
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        Section {
            TextField("Name, e.g. Chess Club", text: $title)
            TextField("Where", text: $room)
            TextField("Note (optional)", text: $note, axis: .vertical)
                .lineLimit(1...3)
        }

        Section("Colour") {
            LazyVGrid(columns: colorColumns, spacing: 12) {
                ForEach(Palette.choices, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(Color.primary, lineWidth: hex == colorHex ? 3 : 0))
                        .onTapGesture { colorHex = hex }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var reminderSection: some View {
        Section {
            Toggle("Remind me", isOn: $reminderOn)
            if reminderOn {
                Picker("When", selection: $reminderMinutes) {
                    ForEach(ReminderOffset.choices, id: \.self) { minutes in
                        Text(ReminderOffset.label(minutes)).tag(minutes)
                    }
                }
            }
        } header: {
            Text("Reminder")
        } footer: {
            Text("Reminders are delivered by the Apple Watch, so they still arrive with your phone out of range. The watch will ask for notification permission the first time you set one.")
        }
    }

    // MARK: Load and save

    private func load() {
        guard let cell = store.timetable.cell(day: day, slotCode: slot.code) else {
            isEmpty = true
            // Breaks and the before/after-school bands are almost always
            // activities, so start there rather than on an empty subject picker.
            kind = slot.isTeaching ? .lesson : .activity
            return
        }
        isEmpty = false
        kind = cell.kind
        subjectCode = cell.subjectCode
        teacherCode = cell.teacherCode
        room = cell.room
        title = cell.title
        colorHex = cell.colorHex.isEmpty ? Palette.choices[0] : cell.colorHex
        note = cell.note
        if let minutes = cell.reminderMinutes {
            reminderOn = true
            reminderMinutes = minutes
        }
    }

    private func save() {
        let reminder = reminderOn ? reminderMinutes : nil
        let trimmedRoom = room.trimmingCharacters(in: .whitespaces)
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        store.update { timetable in
            switch kind {
            case .lesson:
                guard !subjectCode.isEmpty else {
                    timetable.clearCell(day: day, slotCode: slot.code)
                    return
                }
                timetable.setCell(Cell(day: day,
                                       slotCode: slot.code,
                                       kind: .lesson,
                                       subjectCode: subjectCode,
                                       teacherCode: teacherCode,
                                       room: trimmedRoom,
                                       reminderMinutes: reminder))
            case .activity:
                guard !trimmedTitle.isEmpty else {
                    timetable.clearCell(day: day, slotCode: slot.code)
                    return
                }
                timetable.setCell(Cell.activity(day: day,
                                                slotCode: slot.code,
                                                title: trimmedTitle,
                                                location: trimmedRoom,
                                                colorHex: colorHex,
                                                note: note.trimmingCharacters(in: .whitespaces),
                                                reminderMinutes: reminder))
            }
        }
        dismiss()
    }
}

// MARK: - Subjects

struct SubjectsView: View {

    @EnvironmentObject private var store: TimetableStore
    @State private var newCode = ""
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                ForEach(store.timetable.subjects) { subject in
                    NavigationLink {
                        SubjectDetailView(subject: subject).environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: subject.colorHex))
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subject.name).font(.subheadline.weight(.medium))
                                Text(subject.code).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    store.update { $0.subjects.remove(atOffsets: offsets) }
                }
            }

            Section("Add a subject") {
                TextField("Code, e.g. SCI102B", text: $newCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Name, e.g. Science", text: $newName)
                Button("Add") { add() }
                    .disabled(newCode.trimmingCharacters(in: .whitespaces).isEmpty
                              || newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Subjects")
    }

    private func add() {
        let code = newCode.trimmingCharacters(in: .whitespaces).uppercased()
        let name = newName.trimmingCharacters(in: .whitespaces)
        store.update { timetable in
            let used = timetable.subjects.map(\.colorHex)
            timetable.subjects.removeAll { $0.code == code }
            timetable.subjects.append(Subject(code: code,
                                              name: name,
                                              colorHex: Palette.next(avoiding: used)))
            timetable.subjects.sort { $0.code < $1.code }
        }
        newCode = ""
        newName = ""
    }
}

struct SubjectDetailView: View {

    @EnvironmentObject private var store: TimetableStore
    let subject: Subject

    @State private var name = ""
    @State private var colorHex = ""

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $name)
            }
            Section("Colour") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Palette.choices, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Color.primary, lineWidth: hex == colorHex ? 3 : 0))
                            .onTapGesture { colorHex = hex }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(subject.code)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = subject.name
            colorHex = subject.colorHex
        }
        .onDisappear(perform: commit)
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard trimmed != subject.name || colorHex != subject.colorHex else { return }
        store.update { timetable in
            guard let index = timetable.subjects.firstIndex(where: { $0.code == subject.code }) else { return }
            timetable.subjects[index].name = trimmed
            timetable.subjects[index].colorHex = colorHex
        }
    }
}

// MARK: - Teachers

struct TeachersView: View {

    @EnvironmentObject private var store: TimetableStore
    @State private var newCode = ""
    @State private var newName = ""

    private var codes: [String] { store.timetable.teachers.keys.sorted() }

    var body: some View {
        List {
            Section {
                ForEach(codes, id: \.self) { code in
                    HStack {
                        Text(store.timetable.teachers[code] ?? code)
                            .font(.subheadline)
                        Spacer()
                        Text(code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    let doomed = offsets.map { codes[$0] }
                    store.update { timetable in
                        for code in doomed { timetable.teachers.removeValue(forKey: code) }
                    }
                }
            }

            Section("Add a teacher") {
                TextField("Code, e.g. DAYLU", text: $newCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Name, e.g. Mr Day", text: $newName)
                Button("Add") { add() }
                    .disabled(newCode.trimmingCharacters(in: .whitespaces).isEmpty
                              || newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Teachers")
    }

    private func add() {
        let code = newCode.trimmingCharacters(in: .whitespaces).uppercased()
        let name = newName.trimmingCharacters(in: .whitespaces)
        store.update { $0.teachers[code] = name }
        newCode = ""
        newName = ""
    }
}

// MARK: - Periods and bells

struct SlotsView: View {

    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        List {
            ForEach(store.timetable.slots) { slot in
                NavigationLink {
                    SlotDetailView(slot: slot).environmentObject(store)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.label).font(.subheadline.weight(.medium))
                            Text("\(slot.start.display)-\(slot.end.display)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer()
                        Text(bellSummary(slot))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Periods & Bells")
    }

    private func bellSummary(_ slot: Slot) -> String {
        if slot.grace > 0 { return "bell \(slot.start.display), +\(slot.grace)m" }
        if slot.bellLead > 0 { return "bell -\(slot.bellLead)m" }
        return "bell on time"
    }
}

struct SlotDetailView: View {

    @EnvironmentObject private var store: TimetableStore
    let slot: Slot

    @State private var label = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var bellLead = 5
    @State private var grace = 0
    @State private var activeDays: Set<Weekday> = []

    var body: some View {
        Form {
            Section("Name") {
                TextField("Label", text: $label)
            }

            Section("Times") {
                DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
            }

            Section {
                Stepper("Bell rings \(bellLead) min early", value: $bellLead, in: 0...20)
                Stepper("Grace period \(grace) min", value: $grace, in: 0...20)
            } header: {
                Text("Bells")
            } footer: {
                Text("The watch starts showing this period at its bell. A bell is automatically held back if it would ring while you are still in the previous class.")
            }

            Section {
                ForEach(Weekday.allCases) { day in
                    Toggle(day.fullName, isOn: Binding(
                        get: { activeDays.contains(day) },
                        set: { isOn in
                            if isOn { activeDays.insert(day) } else { activeDays.remove(day) }
                        }
                    ))
                }
            } header: {
                Text("Runs on")
            } footer: {
                Text("A day with something scheduled in this band shows it regardless.")
            }
        }
        .navigationTitle(slot.code)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onDisappear(perform: commit)
    }

    private func load() {
        label = slot.label
        start = slot.start.asDate
        end = slot.end.asDate
        bellLead = slot.bellLead
        grace = slot.grace
        activeDays = Set(slot.activeDays)
    }

    private func commit() {
        store.update { timetable in
            guard let index = timetable.slots.firstIndex(where: { $0.code == slot.code }) else { return }
            timetable.slots[index].label = label
            timetable.slots[index].start = .from(start)
            timetable.slots[index].end = .from(end)
            timetable.slots[index].bellLead = bellLead
            timetable.slots[index].grace = grace
            timetable.slots[index].activeDays = Weekday.allCases.filter { activeDays.contains($0) }
        }
    }
}
