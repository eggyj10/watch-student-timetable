import Foundation

// MARK: - Weekday

/// School days only. Raw values 1...5 so Monday == 1.
enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday

    var id: Int { rawValue }

    /// `Calendar` uses 1 = Sunday ... 7 = Saturday.
    var calendarWeekday: Int { rawValue + 1 }

    init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday - 1)
    }

    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        }
    }

    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        }
    }

    /// Three-letter token used by the plain-text import format.
    var token: String { shortName.uppercased() }

    static func fromToken(_ token: String) -> Weekday? {
        let t = token.uppercased()
        return Weekday.allCases.first { $0.token == t || $0.fullName.uppercased() == t }
    }
}

// MARK: - ClockTime

/// A wall-clock time of day, stored as minutes since midnight.
struct ClockTime: Codable, Hashable, Comparable, Sendable {
    var minutes: Int

    init(minutes: Int) { self.minutes = minutes }
    init(hour: Int, minute: Int) { self.minutes = hour * 60 + minute }

    var hour: Int { minutes / 60 }
    var minute: Int { minutes % 60 }

    static func < (lhs: ClockTime, rhs: ClockTime) -> Bool { lhs.minutes < rhs.minutes }

    func adding(minutes delta: Int) -> ClockTime { ClockTime(minutes: minutes + delta) }

    /// Parses timetable times written without am/pm, e.g. "8:50", "12:00", "1:10".
    /// Hours 1...7 are read as afternoon, 8...12 as morning, which is how every
    /// school timetable in the world is printed.
    static func parseSchool(_ raw: String) -> ClockTime? {
        let parts = raw.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2,
              var h = Int(parts[0]),
              let m = Int(parts[1]),
              (0...23).contains(h),
              (0...59).contains(m)
        else { return nil }
        if (1...7).contains(h) { h += 12 }
        return ClockTime(hour: h, minute: m)
    }

    /// "8:50", "12:00", "1:10", matching how the printed timetable reads.
    var display: String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", h12, minute)
    }

    var displayWithMeridiem: String {
        return display + (hour < 12 ? " am" : " pm")
    }
}

// MARK: - Slot

enum SlotKind: String, Codable, Sendable {
    /// A taught period.
    case lesson
    /// Form / roll class. Short, but you still need to be somewhere.
    case pastoral
    /// Break, lunch.
    case recess
    /// Before/after school bands that may not run every day.
    case extra
    /// Synthesised at display time for an excursion. Never stored in `slots`.
    case excursion
}

/// One row of the timetable grid: a named time band shared across the week.
struct Slot: Codable, Hashable, Identifiable, Sendable {
    var code: String            // "P1", "FRM", "FB"
    var label: String           // "Period 1", "Form Class", "First Break"
    var start: ClockTime
    var end: ClockTime
    var kind: SlotKind
    /// Minutes before `start` that the bell rings for this slot.
    var bellLead: Int
    /// Minutes after `start` you are still allowed to arrive (P3's 12:05 rule).
    var grace: Int
    /// Days this row runs by default. A row also appears on any day that has
    /// something scheduled in it, so an after-school activity on a Monday makes
    /// the after-school band show up on Mondays.
    var activeDays: [Weekday]

    var id: String { code }

    var isTeaching: Bool { kind == .lesson || kind == .pastoral }
    var durationMinutes: Int { end.minutes - start.minutes }
    var arriveBy: ClockTime { start.adding(minutes: grace) }

    init(code: String,
         label: String,
         start: ClockTime,
         end: ClockTime,
         kind: SlotKind,
         bellLead: Int = 5,
         grace: Int = 0,
         activeDays: [Weekday] = Weekday.allCases) {
        self.code = code
        self.label = label
        self.start = start
        self.end = end
        self.kind = kind
        self.bellLead = bellLead
        self.grace = grace
        self.activeDays = activeDays
    }
}

// MARK: - Subject

struct Subject: Codable, Hashable, Identifiable, Sendable {
    var code: String            // "SCI102B"
    var name: String            // "Science"
    var colorHex: String        // "#3B82F6"

    var id: String { code }
}

// MARK: - Cell

/// What kind of thing is filling a square of the grid.
enum EntryKind: String, Codable, Sendable {
    /// A timetabled class, described by a subject code from the library.
    case lesson
    /// Anything else you have committed to: chess club at lunch, footy
    /// training after school, a standing appointment. Free-text, so it does not
    /// need a subject or a teacher.
    case activity
}

/// One filled square of the grid. Repeats every week.
struct Cell: Codable, Hashable, Identifiable, Sendable {

    var day: Weekday
    var slotCode: String
    var kind: EntryKind

    // Lesson fields.
    var subjectCode: String
    var teacherCode: String

    /// Room for a lesson, meeting place for an activity.
    var room: String

    // Activity fields.
    var title: String
    var colorHex: String
    var note: String

    /// Minutes before the start to fire a reminder, or nil for no reminder.
    var reminderMinutes: Int?

    var id: String { "\(day.rawValue)-\(slotCode)" }

    var isLesson: Bool { kind == .lesson }
    var hasReminder: Bool { reminderMinutes != nil }

    init(day: Weekday,
         slotCode: String,
         kind: EntryKind = .lesson,
         subjectCode: String = "",
         teacherCode: String = "",
         room: String = "",
         title: String = "",
         colorHex: String = "",
         note: String = "",
         reminderMinutes: Int? = nil) {
        self.day = day
        self.slotCode = slotCode
        self.kind = kind
        self.subjectCode = subjectCode
        self.teacherCode = teacherCode
        self.room = room
        self.title = title
        self.colorHex = colorHex
        self.note = note
        self.reminderMinutes = reminderMinutes
    }

    static func activity(day: Weekday,
                         slotCode: String,
                         title: String,
                         location: String = "",
                         colorHex: String = "#8E8E93",
                         note: String = "",
                         reminderMinutes: Int? = nil) -> Cell {
        Cell(day: day,
             slotCode: slotCode,
             kind: .activity,
             room: location,
             title: title,
             colorHex: colorHex,
             note: note,
             reminderMinutes: reminderMinutes)
    }

    enum CodingKeys: String, CodingKey {
        case day, slotCode, kind, subjectCode, teacherCode, room
        case title, colorHex, note, reminderMinutes
    }

    // Decoded field by field so a timetable saved before activities existed
    // still loads.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Weekday.self, forKey: .day)
        slotCode = try container.decode(String.self, forKey: .slotCode)
        kind = try container.decodeIfPresent(EntryKind.self, forKey: .kind) ?? .lesson
        subjectCode = try container.decodeIfPresent(String.self, forKey: .subjectCode) ?? ""
        teacherCode = try container.decodeIfPresent(String.self, forKey: .teacherCode) ?? ""
        room = try container.decodeIfPresent(String.self, forKey: .room) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        reminderMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderMinutes)
    }
}

// MARK: - Excursion

/// How you are getting there.
enum TransportMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case school
    case own
    case unspecified

    var id: String { rawValue }

    var label: String {
        switch self {
        case .school: return "School transport"
        case .own: return "Own transport"
        case .unspecified: return "Not specified"
        }
    }

    /// Short enough for a watch face.
    var shortLabel: String {
        switch self {
        case .school: return "School bus"
        case .own: return "Own way"
        case .unspecified: return ""
        }
    }

    var symbolName: String {
        switch self {
        case .school: return "bus"
        case .own: return "figure.walk"
        case .unspecified: return "questionmark.circle"
        }
    }
}

/// A one-off event on a specific date that takes over part of the day.
/// Any period it overlaps is replaced by the excursion.
struct Excursion: Codable, Hashable, Identifiable, Sendable {

    var id: UUID
    var title: String
    /// Any instant on the day it happens; only the calendar day is significant.
    var date: Date
    var start: ClockTime
    var end: ClockTime
    var location: String
    var transport: TransportMode
    /// Where to be before you leave, e.g. "Bus bay A" or "Museum front steps".
    var meetingPoint: String
    /// When to be at the meeting point, if that differs from `start`.
    var meetingTime: ClockTime?
    var note: String
    var colorHex: String
    var reminderMinutes: Int?

    init(id: UUID = UUID(),
         title: String,
         date: Date,
         start: ClockTime,
         end: ClockTime,
         location: String = "",
         transport: TransportMode = .unspecified,
         meetingPoint: String = "",
         meetingTime: ClockTime? = nil,
         note: String = "",
         colorHex: String = "#FF9F0A",
         reminderMinutes: Int? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.start = start
        self.end = end
        self.location = location
        self.transport = transport
        self.meetingPoint = meetingPoint
        self.meetingTime = meetingTime
        self.note = note
        self.colorHex = colorHex
        self.reminderMinutes = reminderMinutes
    }

    var hasReminder: Bool { reminderMinutes != nil }

    /// When you actually need to be somewhere: the meeting time if there is
    /// one, otherwise the start.
    var callTime: ClockTime { meetingTime ?? start }

    /// The excursion effectively owns the day from here. If you have to be at
    /// the bus bay at 8:30 for a 9:00 departure, you are not in form class at
    /// 8:50, so the span has to begin at the meeting time.
    var spanStart: ClockTime { min(callTime, start) }

    /// Renders as a slot so the rest of the app can treat it like any other row.
    var syntheticSlot: Slot {
        Slot(code: "EXC",
             label: title,
             start: start,
             end: end,
             kind: .excursion,
             bellLead: 0,
             grace: 0)
    }

    func covers(_ slot: Slot) -> Bool {
        return slot.start < end && spanStart < slot.end
    }
}

// MARK: - Timetable

struct Timetable: Codable, Hashable, Sendable {
    var title: String
    var studentName: String
    /// How long after something starts before the watch face stops showing it
    /// as "now" and starts pointing at the next thing.
    var settleMinutes: Int
    var slots: [Slot]
    var subjects: [Subject]
    var teachers: [String: String]
    var cells: [Cell]
    var excursions: [Excursion]

    /// Bumped whenever the phone edits the timetable, so the watch can tell
    /// whether an incoming payload is newer than what it already has.
    var revision: Int
    var updatedAt: Date

    init(title: String = "Timetable",
         studentName: String = "",
         settleMinutes: Int = 10,
         slots: [Slot] = [],
         subjects: [Subject] = [],
         teachers: [String: String] = [:],
         cells: [Cell] = [],
         excursions: [Excursion] = [],
         revision: Int = 1,
         updatedAt: Date = Date()) {
        self.title = title
        self.studentName = studentName
        self.settleMinutes = settleMinutes
        self.slots = slots
        self.subjects = subjects
        self.teachers = teachers
        self.cells = cells
        self.excursions = excursions
        self.revision = revision
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case title, studentName, settleMinutes, slots, subjects, teachers
        case cells, excursions, revision, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        studentName = try container.decode(String.self, forKey: .studentName)
        settleMinutes = try container.decode(Int.self, forKey: .settleMinutes)
        slots = try container.decode([Slot].self, forKey: .slots)
        subjects = try container.decode([Subject].self, forKey: .subjects)
        teachers = try container.decode([String: String].self, forKey: .teachers)
        cells = try container.decode([Cell].self, forKey: .cells)
        excursions = try container.decodeIfPresent([Excursion].self, forKey: .excursions) ?? []
        revision = try container.decode(Int.self, forKey: .revision)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Lookups

extension Timetable {
    func slot(code: String) -> Slot? { slots.first { $0.code == code } }
    func subject(code: String) -> Subject? { subjects.first { $0.code == code } }
    func teacherName(_ code: String) -> String? { teachers[code] }

    func cell(day: Weekday, slotCode: String) -> Cell? {
        cells.first { $0.day == day && $0.slotCode == slotCode }
    }

    /// Rows that run on `day`, in chronological order. A row with something
    /// scheduled in it is included even on a day it does not normally run.
    func slots(on day: Weekday) -> [Slot] {
        return slots
            .filter { $0.activeDays.contains(day) || cell(day: day, slotCode: $0.code) != nil }
            .sorted { $0.start < $1.start }
    }

    /// Excursions falling on the calendar day containing `date`.
    func excursions(on date: Date, calendar: Calendar = .current) -> [Excursion] {
        return excursions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }

    /// Everything with a reminder switched on.
    var remindedCells: [Cell] { cells.filter(\.hasReminder) }
    var remindedExcursions: [Excursion] { excursions.filter(\.hasReminder) }
}

// MARK: - Mutation

extension Timetable {
    mutating func setCell(_ cell: Cell) {
        cells.removeAll { $0.day == cell.day && $0.slotCode == cell.slotCode }
        cells.append(cell)
        touch()
    }

    mutating func clearCell(day: Weekday, slotCode: String) {
        cells.removeAll { $0.day == day && $0.slotCode == slotCode }
        touch()
    }

    mutating func setExcursion(_ excursion: Excursion) {
        excursions.removeAll { $0.id == excursion.id }
        excursions.append(excursion)
        excursions.sort { $0.date < $1.date }
        touch()
    }

    mutating func removeExcursion(id: UUID) {
        excursions.removeAll { $0.id == id }
        touch()
    }

    /// Drops excursions whose day is well behind us, so the list does not grow
    /// forever and the watch is not carrying dead weight.
    mutating func pruneExcursions(before date: Date, calendar: Calendar = .current) {
        let cutoff = calendar.date(byAdding: .day, value: -14, to: date) ?? date
        let before = excursions.count
        excursions.removeAll { $0.date < calendar.startOfDay(for: cutoff) }
        if excursions.count != before { touch() }
    }

    mutating func touch() {
        revision += 1
        updatedAt = Date()
    }
}
