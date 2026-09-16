import Foundation

extension Timetable {

    /// Highfields State Secondary College, 2026 Term 3, Year 10.
    /// Transcribed from the OneSchool PDF so the app is useful the moment it
    /// launches. Everything here is editable on the phone.
    static var highfieldsTerm3: Timetable {
        Timetable(
            title: "2026 Term 3",
            studentName: "Edward Jones",
            settleMinutes: 10,
            slots: standardSlots,
            subjects: standardSubjects,
            teachers: standardTeachers,
            cells: standardCells
        )
    }

    // MARK: Slots

    static var standardSlots: [Slot] {
        [
            Slot(code: "BFS", label: "Before School",
                 start: ClockTime(hour: 8, minute: 0), end: ClockTime(hour: 8, minute: 45),
                 kind: .extra, bellLead: 0, activeDays: [.thursday]),

            Slot(code: "FRM", label: "Form Class",
                 start: ClockTime(hour: 8, minute: 50), end: ClockTime(hour: 9, minute: 0),
                 kind: .pastoral, bellLead: 5),

            Slot(code: "P1", label: "Period 1",
                 start: ClockTime(hour: 9, minute: 0), end: ClockTime(hour: 10, minute: 10),
                 kind: .lesson, bellLead: 5),

            Slot(code: "FB", label: "First Break",
                 start: ClockTime(hour: 10, minute: 10), end: ClockTime(hour: 10, minute: 50),
                 kind: .recess, bellLead: 0),

            Slot(code: "P2", label: "Period 2",
                 start: ClockTime(hour: 10, minute: 50), end: ClockTime(hour: 12, minute: 0),
                 kind: .lesson, bellLead: 5),

            // The exception. The bell rings at 12:00 on the dot rather than five
            // minutes early, and everyone has until 12:05 to be in the room.
            Slot(code: "P3", label: "Period 3",
                 start: ClockTime(hour: 12, minute: 0), end: ClockTime(hour: 13, minute: 10),
                 kind: .lesson, bellLead: 0, grace: 5),

            Slot(code: "SB", label: "Second Break",
                 start: ClockTime(hour: 13, minute: 10), end: ClockTime(hour: 13, minute: 50),
                 kind: .recess, bellLead: 0),

            Slot(code: "P4", label: "Period 4",
                 start: ClockTime(hour: 13, minute: 50), end: ClockTime(hour: 15, minute: 0),
                 kind: .lesson, bellLead: 5),

            Slot(code: "AS", label: "After School",
                 start: ClockTime(hour: 15, minute: 0), end: ClockTime(hour: 16, minute: 10),
                 kind: .extra, bellLead: 0, activeDays: [.tuesday, .wednesday, .thursday]),
        ]
    }

    // MARK: Subjects

    static var standardSubjects: [Subject] {
        [
            Subject(code: "10D",     name: "Roll Class",                              colorHex: "#8E8E93"),
            Subject(code: "DIG102A", name: "Digital Technologies",                    colorHex: "#0A84FF"),
            Subject(code: "ENG102B", name: "English",                                 colorHex: "#FF375F"),
            Subject(code: "IDX102A", name: "Industrial Design & Tech Extension",      colorHex: "#FF9F0A"),
            Subject(code: "MAX102A", name: "Mathematics Extension",                   colorHex: "#30D158"),
            Subject(code: "MED102A", name: "Media Arts",                              colorHex: "#BF5AF2"),
            Subject(code: "SCI102B", name: "Science",                                 colorHex: "#64D2FF"),
            Subject(code: "STU102B", name: "Study Period",                            colorHex: "#5E5CE6"),
        ]
    }

    // MARK: Teachers

    static var standardTeachers: [String: String] {
        [
            "BARRTH": "Mrs Barr",
            "BISHMA": "Mr Bishop",
            "CADZKA": "Ms Cadzow-Smith",
            "CAMPDA": "Miss Campbell",
            "DAYLU":  "Mr Day",
            "MURPPE": "Mr Murphy",
            "NICOEM": "Miss Nicoll",
            "SANDBE": "Mrs Sanders",
            "VRIESI": "Mr Vriesema",
            "YAMATA": "Dr Yamamoto",
        ]
    }

    // MARK: Cells

    static var standardCells: [Cell] {
        [
            // Monday
            Cell(day: .monday,    slotCode: "FRM", subjectCode: "10D",     teacherCode: "NICOEM", room: "E02"),
            Cell(day: .monday,    slotCode: "P1",  subjectCode: "SCI102B", teacherCode: "DAYLU",  room: "K34"),
            Cell(day: .monday,    slotCode: "P2",  subjectCode: "IDX102A", teacherCode: "BISHMA", room: "K08"),
            Cell(day: .monday,    slotCode: "P3",  subjectCode: "STU102B", teacherCode: "YAMATA", room: "K17"),
            Cell(day: .monday,    slotCode: "P4",  subjectCode: "STU102B", teacherCode: "YAMATA", room: "K17"),

            // Tuesday
            Cell(day: .tuesday,   slotCode: "FRM", subjectCode: "10D",     teacherCode: "BARRTH", room: "E02"),
            Cell(day: .tuesday,   slotCode: "P1",  subjectCode: "MED102A", teacherCode: "CADZKA", room: "P33"),
            Cell(day: .tuesday,   slotCode: "P2",  subjectCode: "ENG102B", teacherCode: "CAMPDA", room: "T03"),
            Cell(day: .tuesday,   slotCode: "P3",  subjectCode: "MAX102A", teacherCode: "MURPPE", room: "T02"),
            Cell(day: .tuesday,   slotCode: "P4",  subjectCode: "DIG102A", teacherCode: "VRIESI", room: "B10"),

            // Wednesday
            Cell(day: .wednesday, slotCode: "FRM", subjectCode: "10D",     teacherCode: "BARRTH", room: "E02"),
            Cell(day: .wednesday, slotCode: "P1",  subjectCode: "IDX102A", teacherCode: "BISHMA", room: "K08"),
            Cell(day: .wednesday, slotCode: "P2",  subjectCode: "SCI102B", teacherCode: "DAYLU",  room: "K34"),
            Cell(day: .wednesday, slotCode: "P3",  subjectCode: "MED102A", teacherCode: "SANDBE", room: "P33"),
            Cell(day: .wednesday, slotCode: "P4",  subjectCode: "ENG102B", teacherCode: "CAMPDA", room: "T03"),

            // Thursday
            Cell(day: .thursday,  slotCode: "FRM", subjectCode: "10D",     teacherCode: "BARRTH", room: "E02"),
            Cell(day: .thursday,  slotCode: "P1",  subjectCode: "DIG102A", teacherCode: "VRIESI", room: "B10"),
            Cell(day: .thursday,  slotCode: "P2",  subjectCode: "MAX102A", teacherCode: "MURPPE", room: "T02"),
            Cell(day: .thursday,  slotCode: "P3",  subjectCode: "SCI102B", teacherCode: "DAYLU",  room: "K34"),
            Cell(day: .thursday,  slotCode: "P4",  subjectCode: "MED102A", teacherCode: "SANDBE", room: "P33"),

            // Friday
            Cell(day: .friday,    slotCode: "FRM", subjectCode: "10D",     teacherCode: "BARRTH", room: "E02"),
            Cell(day: .friday,    slotCode: "P1",  subjectCode: "MAX102A", teacherCode: "MURPPE", room: "T02"),
            Cell(day: .friday,    slotCode: "P2",  subjectCode: "DIG102A", teacherCode: "VRIESI", room: "B10"),
            Cell(day: .friday,    slotCode: "P3",  subjectCode: "ENG102B", teacherCode: "CAMPDA", room: "T03"),
            Cell(day: .friday,    slotCode: "P4",  subjectCode: "IDX102A", teacherCode: "BISHMA", room: "K08"),
        ]
    }

    /// An empty timetable that still has the standard bell structure, for
    /// starting a new term from scratch.
    static var blank: Timetable {
        Timetable(
            title: "New Timetable",
            studentName: "",
            settleMinutes: 10,
            slots: standardSlots,
            subjects: [],
            teachers: [:],
            cells: []
        )
    }
}
