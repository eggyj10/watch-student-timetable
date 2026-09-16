import SwiftUI

// MARK: - List

struct ExcursionsView: View {

    @EnvironmentObject private var store: TimetableStore
    @State private var editing: Excursion?
    @State private var isAdding = false

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private var upcoming: [Excursion] {
        store.timetable.excursions.filter { $0.date >= startOfToday }.sorted { $0.date < $1.date }
    }

    private var past: [Excursion] {
        store.timetable.excursions.filter { $0.date < startOfToday }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if upcoming.isEmpty && past.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No excursions",
                        systemImage: "bus",
                        description: Text("Add one and it will take over whatever periods it overlaps, on that date only.")
                    )
                }
            }

            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { excursion in
                        Button { editing = excursion } label: {
                            ExcursionRow(excursion: excursion)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { remove(upcoming, at: $0) }
                }
            }

            if !past.isEmpty {
                Section("Past") {
                    ForEach(past) { excursion in
                        Button { editing = excursion } label: {
                            ExcursionRow(excursion: excursion).opacity(0.55)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { remove(past, at: $0) }
                }
            }
        }
        .navigationTitle("Excursions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { excursion in
            ExcursionEditorView(excursion: excursion).environmentObject(store)
        }
        .sheet(isPresented: $isAdding) {
            ExcursionEditorView(excursion: nil).environmentObject(store)
        }
    }

    private func remove(_ list: [Excursion], at offsets: IndexSet) {
        let doomed = offsets.map { list[$0].id }
        store.update { timetable in
            for id in doomed { timetable.excursions.removeAll { $0.id == id } }
        }
    }
}

struct ExcursionRow: View {

    let excursion: Excursion

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: excursion.colorHex))
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(excursion.title)
                    .font(.subheadline.weight(.semibold))
                Text(excursion.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Label("\(excursion.start.display)-\(excursion.end.display)",
                          systemImage: "clock")
                    if excursion.transport != .unspecified {
                        Label(excursion.transport.shortLabel,
                              systemImage: excursion.transport.symbolName)
                    }
                }
                .font(.caption2)
                .foregroundStyle(excursion.transport == .own ? Color.orange : Color.secondary)
            }

            Spacer()

            if excursion.hasReminder {
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

// MARK: - Editor

struct ExcursionEditorView: View {

    @EnvironmentObject private var store: TimetableStore
    @Environment(\.dismiss) private var dismiss

    /// Nil when adding.
    let excursion: Excursion?

    @State private var title = ""
    @State private var date = Date()
    @State private var start = Date()
    @State private var end = Date()
    @State private var location = ""
    @State private var transport: TransportMode = .unspecified
    @State private var meetingPoint = ""
    @State private var hasMeetingTime = false
    @State private var meetingTime = Date()
    @State private var note = ""
    @State private var colorHex = "#FF9F0A"
    @State private var reminderOn = false
    @State private var reminderMinutes = 30

    private let colorColumns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && start < end
    }

    /// Which periods this will swallow, shown live so there are no surprises.
    private var coveredSlots: [Slot] {
        guard let day = Weekday(calendarWeekday: Calendar.current.component(.weekday, from: date)) else {
            return []
        }
        let draft = draftExcursion()
        return store.timetable.slots(on: day).filter { draft.covers($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Where are you going?", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Leaves", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Back by", selection: $end, displayedComponents: .hourAndMinute)
                } footer: {
                    if !coveredSlots.isEmpty {
                        Text("Replaces " + coveredSlots.map(\.code).joined(separator: ", ") + " on that day.")
                    } else if start >= end {
                        Text("The end time needs to be after the start.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Destination") {
                    TextField("Address or place", text: $location)
                }

                Section {
                    Picker("Getting there", selection: $transport) {
                        ForEach(TransportMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.symbolName).tag(mode)
                        }
                    }
                    TextField(transport == .own ? "Where to meet, e.g. museum steps"
                                                : "Where to meet, e.g. Bus bay A",
                              text: $meetingPoint)
                    Toggle("Be there earlier than departure", isOn: $hasMeetingTime)
                    if hasMeetingTime {
                        DatePicker("Be there by", selection: $meetingTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Transport")
                } footer: {
                    Text(transport == .own
                         ? "The watch will show this in orange, so it is obvious you are making your own way there."
                         : "If you have to be somewhere before departure, the watch switches to the excursion at that time rather than at the departure time.")
                }

                Section("Notes") {
                    TextField("Anything else, e.g. bring a hat", text: $note, axis: .vertical)
                        .lineLimit(1...4)
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
                    Text("Counted back from when you have to be there, not from departure.")
                }

                if excursion != nil {
                    Section {
                        Button("Delete excursion", role: .destructive) {
                            if let id = excursion?.id {
                                store.update { $0.removeExcursion(id: id) }
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(excursion == nil ? "New Excursion" : "Excursion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid)
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Load and save

    private func load() {
        guard let excursion else {
            // Sensible default: a whole school day, next weekday.
            start = ClockTime(hour: 9, minute: 0).asDate
            end = ClockTime(hour: 15, minute: 0).asDate
            meetingTime = ClockTime(hour: 8, minute: 30).asDate
            return
        }
        title = excursion.title
        date = excursion.date
        start = excursion.start.asDate
        end = excursion.end.asDate
        location = excursion.location
        transport = excursion.transport
        meetingPoint = excursion.meetingPoint
        if let time = excursion.meetingTime {
            hasMeetingTime = true
            meetingTime = time.asDate
        }
        note = excursion.note
        colorHex = excursion.colorHex
        if let minutes = excursion.reminderMinutes {
            reminderOn = true
            reminderMinutes = minutes
        }
    }

    private func draftExcursion() -> Excursion {
        Excursion(
            id: excursion?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            date: Calendar.current.startOfDay(for: date),
            start: .from(start),
            end: .from(end),
            location: location.trimmingCharacters(in: .whitespaces),
            transport: transport,
            meetingPoint: meetingPoint.trimmingCharacters(in: .whitespaces),
            meetingTime: hasMeetingTime ? .from(meetingTime) : nil,
            note: note.trimmingCharacters(in: .whitespaces),
            colorHex: colorHex,
            reminderMinutes: reminderOn ? reminderMinutes : nil
        )
    }

    private func save() {
        let draft = draftExcursion()
        store.update { $0.setExcursion(draft) }
        dismiss()
    }
}
