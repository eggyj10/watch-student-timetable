import Foundation
import UserNotifications

/// Schedules the opt-in reminders.
///
/// These are scheduled **on the watch**, not the phone. The watch is the device
/// on your wrist and the one that keeps working with the phone out of range,
/// which is the whole point of the app. Scheduling in both places would double
/// every alert, so if you would rather the phone owned them, move the
/// `reschedule` call in `TimetableStore` across and flip the `#if os(watchOS)`
/// below.
final class ReminderScheduler {

    static let shared = ReminderScheduler()

    private let center = UNUserNotificationCenter.current()
    private let cellPrefix = "cell-"
    private let excursionPrefix = "exc-"

    private init() {}

    // MARK: Authorization

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    /// Asks for permission the first time something actually wants it, rather
    /// than throwing a prompt at first launch.
    func requestAuthorizationIfNeeded(for timetable: Timetable,
                                      then completion: (() -> Void)? = nil) {
        guard !timetable.remindedCells.isEmpty || !timetable.remindedExcursions.isEmpty else {
            completion?()
            return
        }
        authorizationStatus { [weak self] status in
            guard status == .notDetermined else {
                completion?()
                return
            }
            self?.requestAuthorization { _ in completion?() }
        }
    }

    // MARK: Scheduling

    /// Clears everything this app scheduled and lays it out again. Cheap enough
    /// to call on every edit, and it avoids any drift between the timetable and
    /// what is pending.
    func reschedule(for timetable: Timetable, calendar: Calendar = .current) {
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let ours = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(self.cellPrefix) || $0.hasPrefix(self.excursionPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)

            for request in self.requests(for: timetable, calendar: calendar) {
                self.center.add(request, withCompletionHandler: nil)
            }
        }
    }

    func cancelAll() {
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let ours = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(self.cellPrefix) || $0.hasPrefix(self.excursionPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }

    // MARK: Building requests

    /// Exposed for testing: the requests that `reschedule` would install.
    func requests(for timetable: Timetable, calendar: Calendar = .current) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []
        let engine = ScheduleEngine(timetable: timetable, calendar: calendar)

        // Weekly classes and activities repeat forever, so one repeating
        // trigger each is enough and nothing needs periodic topping up.
        for cell in timetable.remindedCells {
            guard let lead = cell.reminderMinutes,
                  let occurrence = engine.occurrences(on: cell.day)
                      .first(where: { $0.slot.code == cell.slotCode })
            else { continue }

            let fire = occurrence.slot.start.adding(minutes: -lead)
            guard fire.minutes >= 0 else { continue }

            var components = DateComponents()
            components.weekday = cell.day.calendarWeekday
            components.hour = fire.hour
            components.minute = fire.minute

            let content = UNMutableNotificationContent()
            content.title = occurrence.title
            content.body = body(for: occurrence, lead: lead)
            content.sound = .default

            requests.append(UNNotificationRequest(
                identifier: "\(cellPrefix)\(cell.day.rawValue)-\(cell.slotCode)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            ))
        }

        // Excursions happen once, so they need the full date and get dropped
        // once they are in the past.
        for excursion in timetable.remindedExcursions {
            guard let lead = excursion.reminderMinutes else { continue }

            let dayStart = calendar.startOfDay(for: excursion.date)
            let fireMinutes = excursion.spanStart.minutes - lead
            guard fireMinutes >= 0,
                  let fireDate = calendar.date(byAdding: .minute, value: fireMinutes, to: dayStart),
                  fireDate > Date()
            else { continue }

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate)

            let content = UNMutableNotificationContent()
            content.title = excursion.title
            content.body = excursionBody(for: excursion, lead: lead)
            content.sound = .default

            requests.append(UNNotificationRequest(
                identifier: "\(excursionPrefix)\(excursion.id.uuidString)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }

        return requests
    }

    private func body(for occurrence: Occurrence, lead: Int) -> String {
        var parts: [String] = []
        parts.append(lead == 0 ? "Starting now" : "In \(lead) min")
        if let detail = occurrence.detailLine { parts.append(detail) }
        parts.append(occurrence.slot.start.display)
        return parts.joined(separator: " · ")
    }

    private func excursionBody(for excursion: Excursion, lead: Int) -> String {
        var parts: [String] = []
        parts.append(lead == 0 ? "Starting now" : "In \(lead) min")
        if !excursion.meetingPoint.isEmpty {
            parts.append("Meet at \(excursion.meetingPoint) by \(excursion.callTime.display)")
        } else if !excursion.location.isEmpty {
            parts.append(excursion.location)
        }
        if excursion.transport != .unspecified {
            parts.append(excursion.transport.label)
        }
        return parts.joined(separator: " · ")
    }
}
