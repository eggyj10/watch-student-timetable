import Foundation

// Display strings shared by the watch app and the widget, so the two can never
// drift apart in how they describe the same thing.

extension Occurrence {

    /// "K34 · Mr Day" for a lesson, "Library" for a club, "School bus from Bus
    /// bay A" for an excursion. Whichever halves are missing are dropped.
    var detailLine: String? {
        if isExcursion {
            var parts: [String] = []
            if let room { parts.append(room) }
            if let transportNote { parts.append(transportNote) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        var parts: [String] = []
        if let room { parts.append(room) }
        if let teacherName, !teacherName.isEmpty { parts.append(teacherName) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The single most useful fragment, for the tightest widget families.
    var compactDetail: String? {
        return room ?? teacherName
    }

    /// A word for what this is, when the title alone is ambiguous.
    var kindLabel: String? {
        if isExcursion { return "EXCURSION" }
        if isActivity { return slot.kind == .recess ? "LUNCH" : "ACTIVITY" }
        return nil
    }

    var symbolName: String {
        if let excursion { return excursion.transport.symbolName }
        if isActivity { return "star" }
        return "book"
    }
}

extension ClockTime {

    /// Bridges to `Date` for `DatePicker`, anchored on today so only the
    /// time-of-day component is meaningful.
    var asDate: Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    static func from(_ date: Date) -> ClockTime {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}

extension Focus {

    /// "Science", or for an empty band the slot's own label.
    var headline: String { occurrence.title }

    /// "P1 · 9:00-10:10", with the day prefixed when it is not today.
    var contextLine: String {
        var parts: [String] = []
        if let dayNote { parts.append(dayNote) }
        if !occurrence.isExcursion { parts.append(occurrence.slot.code) }
        parts.append(occurrence.timeRange)
        return parts.joined(separator: " · ")
    }

    /// The instant a countdown should tick towards: when it starts if it has
    /// not yet, otherwise when it ends.
    func countdownTarget(from date: Date) -> Date {
        return date < startDate ? startDate : endDate
    }

    /// "starts" / "ends", to label that countdown.
    func countdownVerb(from date: Date) -> String {
        return date < startDate ? "starts" : "ends"
    }
}

// MARK: - Reminder offsets

enum ReminderOffset {
    /// The choices offered in the pickers. Nil means no reminder.
    static let choices: [Int] = [0, 5, 10, 15, 30, 60]

    static func label(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "At the start"
        case 60: return "1 hour before"
        default: return "\(minutes) min before"
        }
    }
}
