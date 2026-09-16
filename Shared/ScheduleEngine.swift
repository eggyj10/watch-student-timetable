import Foundation

// MARK: - Occurrence

/// A row of the day with its content resolved: a lesson, an activity, an
/// excursion, or an empty band like a break with nothing booked into it.
struct Occurrence: Hashable, Identifiable, Sendable {

    /// Nil only for an excursion falling on a weekend.
    var day: Weekday?
    var slot: Slot
    /// Effective bell time. Normally `slot.start - slot.bellLead`, clamped so a
    /// bell can never ring while you are still held in the previous class, and
    /// pulled forward to the meeting time for an excursion.
    var bell: ClockTime
    var cell: Cell?
    var subject: Subject?
    var teacherName: String?
    var excursion: Excursion?

    var id: String {
        if let excursion { return "exc-\(excursion.id.uuidString)" }
        return "\(day?.rawValue ?? 0)-\(slot.code)"
    }

    // MARK: Kind

    var isExcursion: Bool { excursion != nil }
    var isActivity: Bool { cell?.kind == .activity }
    var isLesson: Bool { cell?.kind == .lesson }

    /// Something is actually on. Empty breaks and free periods are not.
    var isScheduled: Bool { excursion != nil || cell != nil }

    /// Only lessons stop being interesting once you have sat down in them. An
    /// excursion or an after-school activity is the thing you are doing, so it
    /// stays on the face for its whole length.
    var settlesEarly: Bool { isLesson }

    // MARK: Content

    var title: String {
        if let excursion { return excursion.title }
        guard let cell else { return slot.label }
        if cell.kind == .activity {
            return cell.title.isEmpty ? slot.label : cell.title
        }
        return subject?.name ?? cell.subjectCode
    }

    /// The short form that fits on a watch face.
    var shortTitle: String {
        if let excursion { return excursion.title }
        guard let cell else { return slot.code }
        if cell.kind == .activity {
            return cell.title.isEmpty ? slot.code : cell.title
        }
        return cell.subjectCode
    }

    /// Room for a lesson, meeting place for an activity, destination for an
    /// excursion.
    var room: String? {
        if let excursion {
            return excursion.location.isEmpty ? nil : excursion.location
        }
        guard let room = cell?.room, !room.isEmpty else { return nil }
        return room
    }

    var note: String? {
        let raw = excursion?.note ?? cell?.note ?? ""
        return raw.isEmpty ? nil : raw
    }

    var colorHex: String {
        if let excursion { return excursion.colorHex }
        guard let cell else { return "#8E8E93" }
        if cell.kind == .activity {
            return cell.colorHex.isEmpty ? "#8E8E93" : cell.colorHex
        }
        return subject?.colorHex ?? "#8E8E93"
    }

    /// Minutes before the start to fire a reminder, if one is switched on.
    var reminderMinutes: Int? {
        return excursion?.reminderMinutes ?? cell?.reminderMinutes
    }

    var timeRange: String { "\(slot.start.display)-\(slot.end.display)" }

    /// Set only when arriving after the start is explicitly tolerated (P3's 12:05).
    var arriveByNote: String? {
        guard excursion == nil, slot.grace > 0 else { return nil }
        return "be there by \(slot.arriveBy.display)"
    }

    /// "School bus from Bus bay A, 8:30", or nil when this is not an excursion.
    var transportNote: String? {
        guard let excursion else { return nil }
        var parts: [String] = []
        if excursion.transport != .unspecified {
            parts.append(excursion.transport.shortLabel)
        }
        if !excursion.meetingPoint.isEmpty {
            parts.append("from \(excursion.meetingPoint)")
        }
        if let meetingTime = excursion.meetingTime {
            parts.append("at \(meetingTime.display)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: - Focus

enum FocusKind: String, Sendable {
    case now
    case next

    var label: String {
        switch self {
        case .now: return "NOW"
        case .next: return "NEXT"
        }
    }
}

/// What the watch face should be showing at a given instant.
struct Focus: Hashable, Sendable {
    var kind: FocusKind
    var occurrence: Occurrence
    var startDate: Date
    var endDate: Date
    /// Day offset from the reference date: 0 = today, 1 = tomorrow.
    var dayOffset: Int

    var isToday: Bool { dayOffset == 0 }

    /// "Tomorrow" / "Mon", or nil when it is today.
    var dayNote: String? {
        switch dayOffset {
        case 0: return nil
        case 1: return "Tomorrow"
        default:
            // Built here rather than cached in a static, which would make this
            // Sendable struct carry a non-Sendable formatter. It runs only when
            // the next thing is more than a day out.
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            return formatter.string(from: startDate)
        }
    }
}

// MARK: - Engine

struct ScheduleEngine: Sendable {
    var timetable: Timetable
    var calendar: Calendar

    init(timetable: Timetable, calendar: Calendar = .current) {
        self.timetable = timetable
        self.calendar = calendar
    }

    // MARK: Building occurrences

    /// The repeating weekly pattern for `day`, with no date-specific overrides.
    /// Used by the editors, which work in weeks rather than dates.
    func occurrences(on day: Weekday) -> [Occurrence] {
        return build(slots: timetable.slots(on: day), day: day, excursions: [])
    }

    /// The actual shape of a specific date: the weekly pattern for that weekday,
    /// with any period an excursion covers replaced by the excursion.
    func occurrences(onDate date: Date) -> [Occurrence] {
        let day = weekday(of: date)
        let excursions = timetable.excursions(on: date, calendar: calendar)

        // A weekend with nothing booked has no rows at all.
        guard day != nil || !excursions.isEmpty else { return [] }

        let pattern = day.map { timetable.slots(on: $0) } ?? []
        let surviving = pattern.filter { slot in
            !excursions.contains { $0.covers(slot) }
        }
        return build(slots: surviving, day: day, excursions: excursions)
    }

    /// Merges ordinary rows and excursion rows into one ordered day, then
    /// resolves each row's bell.
    private func build(slots: [Slot], day: Weekday?, excursions: [Excursion]) -> [Occurrence] {
        // Pair each row with the excursion that produced it, if any.
        var rows: [(slot: Slot, excursion: Excursion?)] = slots.map { ($0, nil) }
        rows.append(contentsOf: excursions.map { ($0.syntheticSlot, $0) })
        rows.sort { $0.slot.start < $1.slot.start }

        var result: [Occurrence] = []
        var heldUntil: ClockTime?

        for row in rows {
            var bell: ClockTime
            if let excursion = row.excursion {
                // Turn up when you are told to, which may be before departure.
                // Never clamped: an excursion outranks whatever it displaced.
                bell = excursion.spanStart
            } else {
                bell = row.slot.start.adding(minutes: -row.slot.bellLead)
                if let heldUntil, bell < heldUntil {
                    bell = heldUntil
                }
            }

            let cell = day.flatMap { timetable.cell(day: $0, slotCode: row.slot.code) }
            // An excursion row never carries a cell, even if the codes collide.
            let resolvedCell = row.excursion == nil ? cell : nil

            let occurrence = Occurrence(
                day: day,
                slot: row.slot,
                bell: bell,
                cell: resolvedCell,
                subject: resolvedCell.flatMap {
                    $0.kind == .lesson ? timetable.subject(code: $0.subjectCode) : nil
                },
                teacherName: resolvedCell.flatMap {
                    $0.kind == .lesson ? timetable.teacherName($0.teacherCode) : nil
                },
                excursion: row.excursion
            )
            result.append(occurrence)

            // Only things that physically hold you in a room push the next bell
            // back. A lunchtime club does not stop you leaving for period 4.
            if occurrence.isLesson || occurrence.isExcursion {
                heldUntil = row.slot.end
            }
        }

        return result
    }

    /// Only the rows that actually have something in them.
    func scheduled(on day: Weekday) -> [Occurrence] {
        return occurrences(on: day).filter(\.isScheduled)
    }

    func scheduled(onDate date: Date) -> [Occurrence] {
        return occurrences(onDate: date).filter(\.isScheduled)
    }

    // MARK: Point-in-time queries

    /// The row you are "in" at `date`, counting from its bell rather than its
    /// start, so the walk between rooms belongs to the class you are walking to.
    func currentOccurrence(at date: Date) -> Occurrence? {
        let time = clockTime(of: date)
        let candidates = occurrences(onDate: date).filter { $0.bell <= time && time < $0.slot.end }
        // When a bell overlaps the tail of a break, the newer bell wins.
        return candidates.max { $0.bell < $1.bell }
    }

    /// The moment something stops being worth showing as "now".
    func settleTime(for occurrence: Occurrence) -> ClockTime {
        guard occurrence.settlesEarly else { return occurrence.slot.end }
        let settled = occurrence.slot.start.adding(minutes: timetable.settleMinutes)
        return min(settled, occurrence.slot.end)
    }

    /// What to put on the watch face at `date`.
    func focus(at date: Date) -> Focus? {
        if let current = currentOccurrence(at: date),
           current.isScheduled,
           clockTime(of: date) < settleTime(for: current) {
            return Focus(
                kind: .now,
                occurrence: current,
                startDate: absoluteDate(dayOffset: 0, time: current.slot.start, from: date),
                endDate: absoluteDate(dayOffset: 0, time: current.slot.end, from: date),
                dayOffset: 0
            )
        }
        return upcoming(after: date)
    }

    /// The next scheduled thing starting strictly after `date`, searching
    /// forward for up to 8 days.
    func upcoming(after date: Date) -> Focus? {
        let referenceTime = clockTime(of: date)

        for offset in 0...8 {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }

            for occurrence in scheduled(onDate: dayDate) {
                if offset == 0 && occurrence.slot.start <= referenceTime { continue }
                return Focus(
                    kind: .next,
                    occurrence: occurrence,
                    startDate: absoluteDate(dayOffset: offset, time: occurrence.slot.start, from: date),
                    endDate: absoluteDate(dayOffset: offset, time: occurrence.slot.end, from: date),
                    dayOffset: offset
                )
            }
        }
        return nil
    }

    /// The thing after whatever is currently in focus, for the "then" line.
    func following(_ focus: Focus) -> Focus? {
        guard var next = upcoming(after: focus.startDate) else { return nil }
        // `upcoming` counts offsets from its own reference date, so re-base them
        // onto the same origin the caller's focus used.
        next.dayOffset += focus.dayOffset
        return next
    }

    // MARK: Timeline

    /// Every instant in the next `days` days at which the watch face would
    /// change what it shows: each bell, and each settle-over moment.
    func transitionDates(from date: Date, days: Int = 3) -> [Date] {
        var dates: [Date] = []

        for offset in 0...days {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            for occurrence in scheduled(onDate: dayDate) {
                dates.append(absoluteDate(dayOffset: offset, time: occurrence.bell, from: date))
                dates.append(absoluteDate(dayOffset: offset, time: settleTime(for: occurrence), from: date))
            }
        }

        return dates.filter { $0 > date }.sorted()
    }

    // MARK: Date helpers

    func weekday(of date: Date) -> Weekday? {
        return Weekday(calendarWeekday: calendar.component(.weekday, from: date))
    }

    func clockTime(of date: Date) -> ClockTime {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// Builds an absolute `Date` from a day offset and a wall-clock time.
    /// Anchoring on midnight keeps this correct across daylight-saving shifts.
    func absoluteDate(dayOffset: Int, time: ClockTime, from reference: Date) -> Date {
        let midnight = calendar.startOfDay(for: reference)
        let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: midnight) ?? midnight
        return calendar.date(byAdding: .minute, value: time.minutes, to: dayStart) ?? dayStart
    }
}
