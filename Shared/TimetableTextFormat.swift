import Foundation

/// A deliberately boring line-based format for bulk-entering a term without
/// tapping through a grid 25 times.
///
///     # anything after a hash is ignored
///     S SCI102B Science                 <- subject code, then its full name
///     T DAYLU Mr Day                    <- teacher code, then their name
///     MON P1 SCI102B DAYLU K34          <- day, slot, subject, teacher, room
///     A MON SB Chess Club @ Library     <- an activity, with an optional place
///     MON P3 MAX102A MURPPE T02 !10     <- trailing !N sets a reminder
///
/// Period times live in Settings, and excursions have their own screen: both
/// change far less often than the classes that sit in them.
enum TimetableTextFormat {

    struct ParseResult {
        var timetable: Timetable
        var warnings: [String]
    }

    private static let locationSeparator = " @ "

    // MARK: Export

    static func export(_ timetable: Timetable) -> String {
        var lines: [String] = []
        lines.append("# \(timetable.title)")
        if !timetable.studentName.isEmpty {
            lines.append("# \(timetable.studentName)")
        }
        lines.append("")

        lines.append("# Subjects")
        for subject in timetable.subjects.sorted(by: { $0.code < $1.code }) {
            lines.append("S \(subject.code) \(subject.name)")
        }
        lines.append("")

        lines.append("# Teachers")
        for code in timetable.teachers.keys.sorted() {
            lines.append("T \(code) \(timetable.teachers[code] ?? "")")
        }
        lines.append("")

        lines.append("# Classes and activities")
        for day in Weekday.allCases {
            for slot in timetable.slots(on: day) {
                guard let cell = timetable.cell(day: day, slotCode: slot.code) else { continue }
                lines.append(line(for: cell, day: day, slot: slot))
            }
            lines.append("")
        }

        if !timetable.excursions.isEmpty {
            lines.append("# \(timetable.excursions.count) excursion(s) are not shown here.")
            lines.append("# Edit those on the Excursions screen; they are kept as they are.")
        }

        return lines.joined(separator: "\n")
    }

    private static func line(for cell: Cell, day: Weekday, slot: Slot) -> String {
        let reminder = cell.reminderMinutes.map { " !\($0)" } ?? ""
        switch cell.kind {
        case .lesson:
            let room = cell.room.isEmpty ? "-" : cell.room
            let teacher = cell.teacherCode.isEmpty ? "-" : cell.teacherCode
            return "\(day.token) \(slot.code) \(cell.subjectCode) \(teacher) \(room)\(reminder)"
        case .activity:
            let place = cell.room.isEmpty ? "" : "\(locationSeparator)\(cell.room)"
            return "A \(day.token) \(slot.code) \(cell.title)\(place)\(reminder)"
        }
    }

    // MARK: Import

    /// Parses `text` onto a copy of `base`, which supplies the slot structure
    /// and anything the text does not mention. Excursions are never touched.
    static func parse(_ text: String, base: Timetable) -> ParseResult {
        var timetable = base
        var subjects: [Subject] = []
        var teachers: [String: String] = [:]
        var cells: [Cell] = []
        var warnings: [String] = []
        var sawAnyCell = false

        for (index, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            var line = rawLine
            if let hash = line.firstIndex(of: "#") {
                line = String(line[line.startIndex..<hash])
            }
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Pull a trailing "!15" off before anything else looks at the line.
            var reminderMinutes: Int?
            if let bang = trimmed.lastIndex(of: "!") {
                let suffix = trimmed[trimmed.index(after: bang)...]
                if let minutes = Int(suffix), minutes >= 0, minutes <= 24 * 60 {
                    reminderMinutes = minutes
                    trimmed = String(trimmed[trimmed.startIndex..<bang])
                        .trimmingCharacters(in: .whitespaces)
                }
            }

            let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let first = tokens.first else { continue }

            switch first.uppercased() {
            case "S":
                guard tokens.count >= 3 else {
                    warnings.append("Line \(lineNumber): subject needs a code and a name")
                    continue
                }
                let code = tokens[1].uppercased()
                let name = tokens.dropFirst(2).joined(separator: " ")
                let used = subjects.map(\.colorHex)
                let existing = base.subject(code: code)
                subjects.removeAll { $0.code == code }
                subjects.append(Subject(code: code,
                                        name: name,
                                        colorHex: existing?.colorHex ?? Palette.next(avoiding: used)))

            case "T":
                guard tokens.count >= 3 else {
                    warnings.append("Line \(lineNumber): teacher needs a code and a name")
                    continue
                }
                teachers[tokens[1].uppercased()] = tokens.dropFirst(2).joined(separator: " ")

            case "A":
                guard tokens.count >= 4,
                      let day = Weekday.fromToken(tokens[1]) else {
                    warnings.append("Line \(lineNumber): activity needs a day, a period and a name")
                    continue
                }
                let slotCode = tokens[2].uppercased()
                guard timetable.slot(code: slotCode) != nil else {
                    warnings.append("Line \(lineNumber): no period called '\(slotCode)'")
                    continue
                }
                let rest = tokens.dropFirst(3).joined(separator: " ")
                let parts = rest.components(separatedBy: locationSeparator)
                let title = parts[0].trimmingCharacters(in: .whitespaces)
                let place = parts.count > 1
                    ? parts.dropFirst().joined(separator: locationSeparator)
                        .trimmingCharacters(in: .whitespaces)
                    : ""
                guard !title.isEmpty else {
                    warnings.append("Line \(lineNumber): activity has no name")
                    continue
                }

                let previous = base.cell(day: day, slotCode: slotCode)
                let keptColor = previous.flatMap { $0.colorHex.isEmpty ? nil : $0.colorHex }

                sawAnyCell = true
                cells.removeAll { $0.day == day && $0.slotCode == slotCode }
                cells.append(Cell.activity(
                    day: day,
                    slotCode: slotCode,
                    title: title,
                    location: place,
                    colorHex: keptColor ?? Palette.next(avoiding: cells.map(\.colorHex)),
                    note: previous?.note ?? "",
                    // Keep a reminder that was set in the app if the text does
                    // not mention one, so a bulk edit never silently drops it.
                    reminderMinutes: reminderMinutes ?? previous?.reminderMinutes
                ))

            default:
                guard let day = Weekday.fromToken(first) else {
                    warnings.append("Line \(lineNumber): '\(first)' is not a day, subject (S), teacher (T) or activity (A)")
                    continue
                }
                guard tokens.count >= 3 else {
                    warnings.append("Line \(lineNumber): needs at least a day, period and subject")
                    continue
                }
                let slotCode = tokens[1].uppercased()
                guard timetable.slot(code: slotCode) != nil else {
                    warnings.append("Line \(lineNumber): no period called '\(slotCode)'")
                    continue
                }
                let teacher = tokens.count > 3 && tokens[3] != "-" ? tokens[3].uppercased() : ""
                let room = tokens.count > 4 && tokens[4] != "-" ? tokens[4] : ""
                let previous = base.cell(day: day, slotCode: slotCode)

                sawAnyCell = true
                cells.removeAll { $0.day == day && $0.slotCode == slotCode }
                cells.append(Cell(day: day,
                                  slotCode: slotCode,
                                  kind: .lesson,
                                  subjectCode: tokens[2].uppercased(),
                                  teacherCode: teacher,
                                  room: room,
                                  reminderMinutes: reminderMinutes
                                    ?? (previous?.kind == .lesson ? previous?.reminderMinutes : nil)))
            }
        }

        // Flag classes that reference something the text never defined, so a
        // typo shows up as a warning rather than a blank card on the watch.
        for cell in cells where cell.kind == .lesson {
            let known = subjects.contains { $0.code == cell.subjectCode }
                || base.subject(code: cell.subjectCode) != nil
            if !known {
                warnings.append("\(cell.day.token) \(cell.slotCode): subject '\(cell.subjectCode)' has no S line")
            }
        }

        if !subjects.isEmpty {
            // Keep any pre-existing subjects that the text did not redefine.
            var merged = subjects
            for subject in base.subjects where !merged.contains(where: { $0.code == subject.code }) {
                merged.append(subject)
            }
            timetable.subjects = merged.sorted { $0.code < $1.code }
        }
        if !teachers.isEmpty {
            timetable.teachers = base.teachers.merging(teachers) { _, new in new }
        }
        if sawAnyCell {
            timetable.cells = cells
        }
        timetable.touch()

        return ParseResult(timetable: timetable, warnings: warnings)
    }
}
