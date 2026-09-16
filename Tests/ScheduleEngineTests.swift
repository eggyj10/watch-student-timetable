import UserNotifications
import XCTest

/// These pin down the bell rules. If a period's times change, edit the
/// timetable; if these fail, the rules changed and that should be deliberate.
final class ScheduleEngineTests: XCTestCase {

    private var calendar: Calendar!
    private var engine: ScheduleEngine!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        // Queensland, so no daylight saving to trip over.
        calendar.timeZone = TimeZone(identifier: "Australia/Brisbane")!
        self.calendar = calendar
        self.engine = ScheduleEngine(timetable: .highfieldsTerm3, calendar: calendar)
    }

    // MARK: Helpers

    /// A date on a known Monday (2026-07-13, the date printed on the PDF).
    private func monday(_ hour: Int, _ minute: Int) -> Date {
        return date(year: 2026, month: 7, day: 13, hour: hour, minute: minute)
    }

    private func wednesday(_ hour: Int, _ minute: Int) -> Date {
        return date(year: 2026, month: 7, day: 15, hour: hour, minute: minute)
    }

    private func friday(_ hour: Int, _ minute: Int) -> Date {
        return date(year: 2026, month: 7, day: 17, hour: hour, minute: minute)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func using(_ timetable: Timetable) {
        engine = ScheduleEngine(timetable: timetable, calendar: calendar)
    }

    private func assertFocus(_ date: Date,
                             _ kind: FocusKind,
                             _ slotCode: String,
                             dayOffset: Int = 0,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        guard let focus = engine.focus(at: date) else {
            return XCTFail("no focus at \(date)", file: file, line: line)
        }
        XCTAssertEqual(focus.kind, kind, "kind", file: file, line: line)
        XCTAssertEqual(focus.occurrence.slot.code, slotCode, "slot", file: file, line: line)
        XCTAssertEqual(focus.dayOffset, dayOffset, "day offset", file: file, line: line)
    }

    // MARK: Fixture sanity

    func testMondayIsMonday() {
        XCTAssertEqual(engine.weekday(of: monday(9, 0)), .monday)
        XCTAssertEqual(engine.weekday(of: wednesday(9, 0)), .wednesday)
        XCTAssertEqual(engine.weekday(of: friday(9, 0)), .friday)
    }

    func testMondayHasFiveClasses() {
        XCTAssertEqual(engine.scheduled(on: .monday).count, 5)
    }

    // MARK: The five-minutes-early bell

    func testBellRingsFiveMinutesBeforePeriodTwo() {
        assertFocus(monday(10, 44), .next, "P2")
        assertFocus(monday(10, 45), .now, "P2")
    }

    func testBellRingsFiveMinutesBeforePeriodFour() {
        assertFocus(monday(13, 44), .next, "P4")
        assertFocus(monday(13, 45), .now, "P4")
    }

    /// Period 1's bell would nominally ring at 8:55, which is halfway through
    /// form class. It has to be held back to 9:00.
    func testEarlyBellIsClampedOutOfThePreviousClass() {
        assertFocus(monday(8, 57), .now, "FRM")
        assertFocus(monday(9, 0), .now, "P1")
    }

    // MARK: Period 3, the exception

    func testPeriodThreeGetsNoEarlyBell() {
        assertFocus(monday(11, 55), .next, "P3")
        assertFocus(monday(11, 59), .next, "P3")
    }

    func testPeriodThreeBellRingsOnTheHour() {
        assertFocus(monday(12, 0), .now, "P3")
    }

    func testPeriodThreeAtTwoMinutesPast() {
        // The case that started all this: 12:02 shows P3.
        assertFocus(monday(12, 2), .now, "P3")
    }

    func testPeriodThreeAdvertisesItsGracePeriod() {
        XCTAssertEqual(engine.focus(at: monday(12, 2))?.occurrence.arriveByNote,
                       "be there by 12:05")
    }

    func testOtherPeriodsHaveNoGraceNote() {
        XCTAssertNil(engine.focus(at: monday(10, 50))?.occurrence.arriveByNote)
    }

    // MARK: Settling

    func testSwitchesToNextOnceSettledIn() {
        // The other case that started all this: 12:10 shows what is next.
        assertFocus(monday(12, 9), .now, "P3")
        assertFocus(monday(12, 10), .next, "P4")
    }

    func testSettlingAppliesToEveryLesson() {
        assertFocus(monday(9, 9), .now, "P1")
        assertFocus(monday(9, 10), .next, "P2")
        assertFocus(monday(10, 59), .now, "P2")
        assertFocus(monday(11, 0), .next, "P3")
    }

    /// Form class is only ten minutes long, so settling must never outlast it.
    func testShortSlotSettleIsCappedAtItsEnd() {
        let form = engine.occurrences(on: .monday).first { $0.slot.code == "FRM" }!
        XCTAssertEqual(engine.settleTime(for: form), form.slot.end)
    }

    // MARK: Breaks and gaps

    func testBreaksPointAtTheNextClass() {
        assertFocus(monday(10, 20), .next, "P2")
        assertFocus(monday(13, 20), .next, "P4")
    }

    func testBeforeSchoolPointsAtFormClass() {
        assertFocus(monday(7, 30), .next, "FRM")
        assertFocus(monday(8, 44), .next, "FRM")
    }

    // MARK: Rolling over

    func testAfterTheLastClassRollsToTomorrow() {
        assertFocus(monday(15, 30), .next, "FRM", dayOffset: 1)
    }

    func testFridayAfternoonRollsToMonday() {
        assertFocus(friday(15, 30), .next, "FRM", dayOffset: 3)
    }

    func testWeekendPointsAtMonday() {
        let saturday = date(year: 2026, month: 7, day: 18, hour: 11, minute: 0)
        assertFocus(saturday, .next, "FRM", dayOffset: 2)
    }

    // MARK: Content

    func testMondayPeriodOneIsScience() {
        let focus = engine.focus(at: monday(9, 0))
        XCTAssertEqual(focus?.occurrence.title, "Science")
        XCTAssertEqual(focus?.occurrence.room, "K34")
        XCTAssertEqual(focus?.occurrence.teacherName, "Mr Day")
    }

    func testFollowingChainsForward() {
        let focus = engine.focus(at: monday(9, 0))!
        let then = engine.following(focus)
        XCTAssertEqual(then?.occurrence.slot.code, "P2")
        XCTAssertEqual(then?.occurrence.title, "Industrial Design & Tech Extension")
    }

    func testFollowingCarriesDayOffsetAcrossMidnight() {
        let focus = engine.focus(at: monday(13, 50))!
        XCTAssertEqual(focus.occurrence.slot.code, "P4")
        let then = engine.following(focus)
        XCTAssertEqual(then?.dayOffset, 1)
        XCTAssertEqual(then?.occurrence.day, .tuesday)
    }

    // MARK: - Activities

    private func timetableWithClubs() -> Timetable {
        var timetable = Timetable.highfieldsTerm3
        timetable.setCell(.activity(day: .monday, slotCode: "SB",
                                    title: "Chess Club", location: "Library"))
        // Monday is not one of the days the after-school band normally runs.
        timetable.setCell(.activity(day: .monday, slotCode: "AS",
                                    title: "Footy Training", location: "Oval"))
        return timetable
    }

    func testActivityInABreakBecomesTheFocus() {
        using(timetableWithClubs())
        assertFocus(monday(13, 10), .now, "SB")
        XCTAssertEqual(engine.focus(at: monday(13, 10))?.occurrence.title, "Chess Club")
    }

    /// The whole point of a club is that it runs for its whole slot. Only
    /// lessons get swapped out for the next thing ten minutes in.
    func testActivityDoesNotSettleEarly() {
        using(timetableWithClubs())
        assertFocus(monday(13, 30), .now, "SB")
    }

    /// A lunchtime club does not hold you the way a class does, so period 4's
    /// early bell must not be pushed back by it.
    func testActivityDoesNotClampTheNextBell() {
        using(timetableWithClubs())
        assertFocus(monday(13, 45), .now, "P4")
    }

    func testSettledInLastLessonPointsAtTheAfterSchoolActivity() {
        using(timetableWithClubs())
        assertFocus(monday(14, 0), .next, "AS")
    }

    /// The after-school band does not run on Mondays, but putting something in
    /// it should make it appear anyway.
    func testBandAppearsOnADayItDoesNotNormallyRun() {
        using(timetableWithClubs())
        assertFocus(monday(15, 0), .now, "AS")
        XCTAssertTrue(engine.occurrences(on: .monday).contains { $0.slot.code == "AS" })
        XCTAssertFalse(engine.occurrences(on: .friday).contains { $0.slot.code == "AS" })
    }

    func testActivityHasNoTeacherOrSubject() {
        using(timetableWithClubs())
        let focus = engine.focus(at: monday(13, 10))!
        XCTAssertTrue(focus.occurrence.isActivity)
        XCTAssertNil(focus.occurrence.subject)
        XCTAssertNil(focus.occurrence.teacherName)
        XCTAssertEqual(focus.occurrence.room, "Library")
    }

    func testTuesdayIsUnaffectedByMondaysClubs() {
        using(timetableWithClubs())
        let tuesday = date(year: 2026, month: 7, day: 14, hour: 13, minute: 20)
        assertFocus(tuesday, .next, "P4")
    }

    // MARK: - Excursions

    private func museumExcursion(meetingTime: ClockTime? = ClockTime(hour: 8, minute: 30),
                                 transport: TransportMode = .school) -> Excursion {
        Excursion(
            title: "Science Museum",
            date: wednesday(0, 0),
            start: ClockTime(hour: 9, minute: 0),
            end: ClockTime(hour: 15, minute: 0),
            location: "Cobb+Co Museum",
            transport: transport,
            meetingPoint: "Bus bay A",
            meetingTime: meetingTime
        )
    }

    private func timetableWithExcursion(_ excursion: Excursion? = nil) -> Timetable {
        var timetable = Timetable.highfieldsTerm3
        timetable.setExcursion(excursion ?? museumExcursion())
        return timetable
    }

    func testExcursionReplacesThePeriodsItCovers() {
        using(timetableWithExcursion())
        let codes = engine.occurrences(onDate: wednesday(12, 0)).map(\.slot.code)
        XCTAssertTrue(codes.contains("EXC"))
        for covered in ["FRM", "P1", "FB", "P2", "P3", "SB", "P4"] {
            XCTAssertFalse(codes.contains(covered), "\(covered) should be covered")
        }
    }

    func testExcursionLeavesOtherDaysAlone() {
        using(timetableWithExcursion())
        assertFocus(monday(9, 0), .now, "P1")
        XCTAssertFalse(engine.occurrences(onDate: monday(9, 0)).contains { $0.slot.code == "EXC" })
    }

    /// If you have to be at the bus bay at 8:30, the excursion owns the morning
    /// from 8:30, not from the 9:00 departure, and form class does not survive.
    func testMeetingTimePullsTheExcursionForward() {
        using(timetableWithExcursion())
        assertFocus(wednesday(8, 0), .next, "EXC")
        assertFocus(wednesday(8, 30), .now, "EXC")
        assertFocus(wednesday(8, 55), .now, "EXC")
    }

    /// Without a meeting time the excursion starts when it says it does, so
    /// form class at 8:50-9:00 survives.
    func testWithoutAMeetingTimeFormClassSurvives() {
        using(timetableWithExcursion(museumExcursion(meetingTime: nil)))
        assertFocus(wednesday(8, 55), .now, "FRM")
        assertFocus(wednesday(9, 0), .now, "EXC")
    }

    func testExcursionDoesNotSettleEarly() {
        using(timetableWithExcursion())
        assertFocus(wednesday(11, 0), .now, "EXC")
        assertFocus(wednesday(14, 59), .now, "EXC")
    }

    func testExcursionEndsIntoTheNextSchoolDay() {
        using(timetableWithExcursion())
        assertFocus(wednesday(15, 0), .next, "FRM", dayOffset: 1)
    }

    func testExcursionCarriesItsTransportDetails() {
        using(timetableWithExcursion())
        let occurrence = engine.focus(at: wednesday(10, 0))!.occurrence
        XCTAssertTrue(occurrence.isExcursion)
        XCTAssertEqual(occurrence.room, "Cobb+Co Museum")
        XCTAssertEqual(occurrence.transportNote, "School bus from Bus bay A at 8:30")
        XCTAssertEqual(occurrence.kindLabel, "EXCURSION")
    }

    func testOwnTransportIsDistinguishable() {
        using(timetableWithExcursion(museumExcursion(transport: .own)))
        let occurrence = engine.focus(at: wednesday(10, 0))!.occurrence
        XCTAssertEqual(occurrence.excursion?.transport, .own)
        XCTAssertEqual(occurrence.transportNote, "Own way from Bus bay A at 8:30")
    }

    /// A half-day excursion should leave the untouched periods running.
    func testPartialDayExcursionLeavesTheRestOfTheDay() {
        var excursion = museumExcursion(meetingTime: nil)
        excursion.start = ClockTime(hour: 9, minute: 0)
        excursion.end = ClockTime(hour: 12, minute: 0)
        using(timetableWithExcursion(excursion))

        let codes = engine.occurrences(onDate: wednesday(12, 0)).map(\.slot.code)
        XCTAssertTrue(codes.contains("EXC"))
        XCTAssertFalse(codes.contains("P1"))
        XCTAssertFalse(codes.contains("P2"))
        XCTAssertTrue(codes.contains("P3"))
        XCTAssertTrue(codes.contains("P4"))

        // Back in time for period 3, which still gets its on-the-hour bell.
        assertFocus(wednesday(12, 0), .now, "P3")
    }

    func testWeekendExcursionIsFound() {
        var excursion = museumExcursion(meetingTime: nil)
        excursion.date = date(year: 2026, month: 7, day: 18, hour: 0, minute: 0)  // Saturday
        using(timetableWithExcursion(excursion))

        let saturday = date(year: 2026, month: 7, day: 18, hour: 10, minute: 0)
        assertFocus(saturday, .now, "EXC")
        XCTAssertNil(engine.focus(at: saturday)?.occurrence.day)
    }

    func testPruningDropsOldExcursionsOnly() {
        var timetable = Timetable.highfieldsTerm3
        timetable.setExcursion(museumExcursion())
        var ancient = museumExcursion(meetingTime: nil)
        ancient.id = UUID()
        ancient.date = date(year: 2026, month: 1, day: 12, hour: 0, minute: 0)
        timetable.setExcursion(ancient)

        XCTAssertEqual(timetable.excursions.count, 2)
        timetable.pruneExcursions(before: wednesday(16, 0), calendar: calendar)
        XCTAssertEqual(timetable.excursions.count, 1)
        XCTAssertEqual(timetable.excursions.first?.title, "Science Museum")
    }

    // MARK: - Reminders

    func testNoRemindersByDefault() {
        XCTAssertTrue(engine.timetable.remindedCells.isEmpty)
        XCTAssertTrue(ReminderScheduler.shared.requests(for: engine.timetable, calendar: calendar).isEmpty)
    }

    func testClassReminderRepeatsWeekly() {
        var timetable = Timetable.highfieldsTerm3
        var cell = timetable.cell(day: .monday, slotCode: "P3")!
        cell.reminderMinutes = 15
        timetable.setCell(cell)

        let requests = ReminderScheduler.shared.requests(for: timetable, calendar: calendar)
        XCTAssertEqual(requests.count, 1)

        let request = requests[0]
        XCTAssertEqual(request.identifier, "cell-1-P3")
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.repeats, true)
        // P3 starts at 12:00, so 15 minutes before is 11:45 on a Monday.
        XCTAssertEqual(trigger?.dateComponents.weekday, Weekday.monday.calendarWeekday)
        XCTAssertEqual(trigger?.dateComponents.hour, 11)
        XCTAssertEqual(trigger?.dateComponents.minute, 45)
    }

    func testActivityReminderUsesItsOwnTitle() {
        var timetable = timetableWithClubs()
        var cell = timetable.cell(day: .monday, slotCode: "AS")!
        cell.reminderMinutes = 5
        timetable.setCell(cell)

        let request = ReminderScheduler.shared
            .requests(for: timetable, calendar: calendar)
            .first { $0.identifier == "cell-1-AS" }
        XCTAssertEqual(request?.content.title, "Footy Training")
    }

    /// Excursions happen once, so the trigger must carry a full date and not
    /// repeat.
    func testExcursionReminderIsOneShot() {
        var excursion = museumExcursion()
        excursion.date = Calendar.current.date(byAdding: .year, value: 5, to: Date())!
        excursion.reminderMinutes = 30

        var timetable = Timetable.highfieldsTerm3
        timetable.setExcursion(excursion)

        let requests = ReminderScheduler.shared.requests(for: timetable, calendar: calendar)
        XCTAssertEqual(requests.count, 1)
        let trigger = requests[0].trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.repeats, false)
        XCTAssertNotNil(trigger?.dateComponents.year)
        // Counted back from the 8:30 meeting time, not the 9:00 departure.
        XCTAssertEqual(trigger?.dateComponents.hour, 8)
        XCTAssertEqual(trigger?.dateComponents.minute, 0)
    }

    func testPastExcursionRemindersAreNotScheduled() {
        var excursion = museumExcursion()
        excursion.date = date(year: 2020, month: 3, day: 4, hour: 0, minute: 0)
        excursion.reminderMinutes = 30

        var timetable = Timetable.highfieldsTerm3
        timetable.setExcursion(excursion)
        XCTAssertTrue(ReminderScheduler.shared.requests(for: timetable, calendar: calendar).isEmpty)
    }

    // MARK: Timeline

    func testTransitionDatesAreOrderedAndInTheFuture() {
        let start = monday(7, 0)
        let dates = engine.transitionDates(from: start, days: 2)
        XCTAssertFalse(dates.isEmpty)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertTrue(dates.allSatisfy { $0 > start })
    }

    /// Two entries per scheduled thing: the bell, and the settle-over.
    func testTransitionDatesCoverEveryBell() {
        let dates = engine.transitionDates(from: monday(0, 1), days: 0)
        XCTAssertEqual(dates.count, engine.scheduled(on: .monday).count * 2)
    }

    // MARK: Parsing

    func testSchoolTimesParseWithoutMeridiem() {
        XCTAssertEqual(ClockTime.parseSchool("8:50"), ClockTime(hour: 8, minute: 50))
        XCTAssertEqual(ClockTime.parseSchool("12:00"), ClockTime(hour: 12, minute: 0))
        XCTAssertEqual(ClockTime.parseSchool("1:10"), ClockTime(hour: 13, minute: 10))
        XCTAssertEqual(ClockTime.parseSchool("3:00"), ClockTime(hour: 15, minute: 0))
        XCTAssertNil(ClockTime.parseSchool("nonsense"))
    }

    func testTextFormatRoundTrips() {
        let original = Timetable.highfieldsTerm3
        let text = TimetableTextFormat.export(original)
        let result = TimetableTextFormat.parse(text, base: .blank)

        XCTAssertEqual(result.warnings, [])
        XCTAssertEqual(result.timetable.cells.count, original.cells.count)
        XCTAssertEqual(Set(result.timetable.subjects.map(\.code)),
                       Set(original.subjects.map(\.code)))
        XCTAssertEqual(result.timetable.teachers, original.teachers)

        let rebuilt = ScheduleEngine(timetable: result.timetable, calendar: calendar)
        XCTAssertEqual(rebuilt.focus(at: monday(9, 0))?.occurrence.title, "Science")
    }

    func testTextFormatRoundTripsActivities() {
        let original = timetableWithClubs()
        let text = TimetableTextFormat.export(original)
        XCTAssertTrue(text.contains("A MON SB Chess Club @ Library"))

        let result = TimetableTextFormat.parse(text, base: .blank)
        let club = result.timetable.cell(day: .monday, slotCode: "SB")
        XCTAssertEqual(club?.kind, .activity)
        XCTAssertEqual(club?.title, "Chess Club")
        XCTAssertEqual(club?.room, "Library")
    }

    func testTextFormatCarriesRemindersThrough() {
        var original = Timetable.highfieldsTerm3
        var cell = original.cell(day: .monday, slotCode: "P1")!
        cell.reminderMinutes = 10
        original.setCell(cell)

        let text = TimetableTextFormat.export(original)
        XCTAssertTrue(text.contains("!10"))

        let result = TimetableTextFormat.parse(text, base: original)
        XCTAssertEqual(result.timetable.cell(day: .monday, slotCode: "P1")?.reminderMinutes, 10)
    }

    /// A bulk edit that does not mention reminders must not wipe them.
    func testBulkEditPreservesUnmentionedReminders() {
        var original = Timetable.highfieldsTerm3
        var cell = original.cell(day: .monday, slotCode: "P1")!
        cell.reminderMinutes = 10
        original.setCell(cell)

        let result = TimetableTextFormat.parse("MON P1 SCI102B DAYLU K34", base: original)
        XCTAssertEqual(result.timetable.cell(day: .monday, slotCode: "P1")?.reminderMinutes, 10)
    }

    func testTextFormatLeavesExcursionsAlone() {
        let original = timetableWithExcursion()
        let result = TimetableTextFormat.parse(TimetableTextFormat.export(original), base: original)
        XCTAssertEqual(result.timetable.excursions.count, 1)
    }

    func testTextFormatReportsUnknownPeriods() {
        let result = TimetableTextFormat.parse("MON P9 SCI102B DAYLU K34", base: .highfieldsTerm3)
        XCTAssertTrue(result.warnings.contains { $0.contains("P9") })
    }

    // MARK: Storage

    func testTimetableSurvivesTheWireFormat() throws {
        var original = Timetable.highfieldsTerm3
        original.setExcursion(museumExcursion())
        original.setCell(.activity(day: .monday, slotCode: "SB", title: "Chess Club"))

        let data = try XCTUnwrap(TimetableStorage.encodeForTransfer(original))
        let decoded = try XCTUnwrap(TimetableStorage.decodeFromTransfer(data))

        XCTAssertEqual(decoded.cells, original.cells)
        XCTAssertEqual(decoded.slots, original.slots)
        XCTAssertEqual(decoded.subjects, original.subjects)
        XCTAssertEqual(decoded.teachers, original.teachers)
        XCTAssertEqual(decoded.excursions.map(\.id), original.excursions.map(\.id))
        XCTAssertEqual(decoded.settleMinutes, original.settleMinutes)
        XCTAssertEqual(decoded.revision, original.revision)
    }

    /// A payload written before activities and excursions existed must still
    /// load rather than throwing the whole timetable away.
    func testOlderPayloadStillDecodes() throws {
        let json = """
        {
          "title": "Old", "studentName": "E", "settleMinutes": 10,
          "slots": [], "subjects": [], "teachers": {},
          "cells": [{"day": 1, "slotCode": "P1", "subjectCode": "SCI102B",
                     "teacherCode": "DAYLU", "room": "K34"}],
          "revision": 3, "updatedAt": "2026-07-13T08:53:06Z"
        }
        """
        let decoded = try XCTUnwrap(TimetableStorage.decodeFromTransfer(Data(json.utf8)))
        XCTAssertEqual(decoded.excursions, [])
        XCTAssertEqual(decoded.cells.first?.kind, .lesson)
        XCTAssertEqual(decoded.cells.first?.subjectCode, "SCI102B")
        XCTAssertNil(decoded.cells.first?.reminderMinutes)
    }
}
