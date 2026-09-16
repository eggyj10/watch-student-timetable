import Combine
import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Sync state

enum SyncState: Equatable {
    case idle
    case unsupported
    case sending
    case sent(Date)
    case received(Date)
    case failed(String)

    var description: String {
        switch self {
        case .idle: return "Not synced yet"
        case .unsupported: return "Watch sync unavailable"
        case .sending: return "Sending..."
        case .sent(let date): return "Sent \(Self.relative(date))"
        case .received(let date): return "Updated \(Self.relative(date))"
        case .failed(let message): return "Failed: \(message)"
        }
    }

    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Store

/// Single source of truth for the timetable on both platforms.
///
/// The phone owns the data and pushes it to the watch through
/// `updateApplicationContext`, which is latest-value-wins and gets delivered
/// even when the watch app is not running. Once the watch has written the
/// payload into its App Group container it is fully offline: the watch app and
/// the widget both read from disk and never need the phone again.
final class TimetableStore: NSObject, ObservableObject {

    static let shared = TimetableStore()

    @Published private(set) var timetable: Timetable
    @Published private(set) var syncState: SyncState = .idle
    /// False until the watch has received at least one payload from the phone.
    @Published private(set) var hasSyncedFromPhone: Bool

    private let syncedFlagKey = "au.com.eddiej.timetable.hasSyncedFromPhone"

    private override init() {
        self.timetable = TimetableStorage.load() ?? .highfieldsTerm3
        self.hasSyncedFromPhone = UserDefaults.standard.bool(forKey: syncedFlagKey)
        super.init()

        // Make sure the widget has something to read on very first launch.
        TimetableStorage.save(timetable)
        activateSession()
    }

    // MARK: Engine

    var engine: ScheduleEngine { ScheduleEngine(timetable: timetable) }

    // MARK: Mutation

    /// Edit the timetable. Bumps the revision, writes to disk, refreshes any
    /// widgets and pushes to the watch.
    func update(_ transform: (inout Timetable) -> Void) {
        var copy = timetable
        transform(&copy)
        copy.touch()
        commit(copy, pushToWatch: true)
    }

    /// Wholesale replacement, for imports and resets.
    func replace(with newTimetable: Timetable) {
        var copy = newTimetable
        copy.revision = max(newTimetable.revision, timetable.revision + 1)
        copy.updatedAt = Date()
        commit(copy, pushToWatch: true)
    }

    private func commit(_ newTimetable: Timetable, pushToWatch: Bool) {
        timetable = newTimetable
        TimetableStorage.save(newTimetable)
        reloadWidgets()
        refreshReminders()
        if pushToWatch { pushToCounterpart() }
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Reminders live on the watch so they still fire with the phone out of
    /// range. See the note at the top of `ReminderScheduler`.
    private func refreshReminders() {
        #if os(watchOS)
        ReminderScheduler.shared.reschedule(for: timetable)
        #endif
    }

    /// Called when the watch app appears, so the permission prompt only shows
    /// up once something is actually asking for it.
    func prepareReminders() {
        #if os(watchOS)
        ReminderScheduler.shared.requestAuthorizationIfNeeded(for: timetable) { [weak self] in
            guard let self else { return }
            ReminderScheduler.shared.reschedule(for: self.timetable)
        }
        #endif
    }

    /// Drops excursions that are well past, so the list and the payload do not
    /// grow without bound.
    func pruneOldExcursions() {
        var copy = timetable
        let before = copy.excursions.count
        copy.pruneExcursions(before: Date())
        guard copy.excursions.count != before else { return }
        commit(copy, pushToWatch: true)
    }

    // MARK: Incoming

    /// Applies a payload that arrived from the counterpart device. Never echoes
    /// back, and ignores anything not newer than what we already hold.
    private func applyIncoming(_ incoming: Timetable) {
        guard incoming.revision > timetable.revision || incoming.updatedAt > timetable.updatedAt else {
            return
        }
        timetable = incoming
        TimetableStorage.save(incoming)
        reloadWidgets()
        refreshReminders()
        syncState = .received(Date())
        if !hasSyncedFromPhone {
            hasSyncedFromPhone = true
            UserDefaults.standard.set(true, forKey: syncedFlagKey)
        }
    }
}

// MARK: - WatchConnectivity

#if canImport(WatchConnectivity)

extension TimetableStore: WCSessionDelegate {

    private var session: WCSession? {
        guard WCSession.isSupported() else { return nil }
        return WCSession.default
    }

    fileprivate func activateSession() {
        guard let session else {
            syncState = .unsupported
            return
        }
        session.delegate = self
        session.activate()
    }

    /// Push the current timetable to the other device.
    func pushToCounterpart() {
        guard let session, session.activationState == .activated else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        guard let data = TimetableStorage.encodeForTransfer(timetable) else { return }

        DispatchQueue.main.async { self.syncState = .sending }
        do {
            // Latest-value-wins, and survives the watch being asleep.
            try session.updateApplicationContext(["timetable": data, "revision": timetable.revision])
            DispatchQueue.main.async { self.syncState = .sent(Date()) }
        } catch {
            DispatchQueue.main.async { self.syncState = .failed(error.localizedDescription) }
        }
    }

    /// Watch-side pull, for the refresh button.
    func requestFromPhone() {
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["request": "timetable"], replyHandler: { [weak self] reply in
            guard let data = reply["timetable"] as? Data,
                  let incoming = TimetableStorage.decodeFromTransfer(data) else { return }
            DispatchQueue.main.async { self?.applyIncoming(incoming) }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async { self?.syncState = .failed(error.localizedDescription) }
        })
    }

    private func handle(context: [String: Any]) {
        guard let data = context["timetable"] as? Data,
              let incoming = TimetableStorage.decodeFromTransfer(data) else { return }
        DispatchQueue.main.async { self.applyIncoming(incoming) }
    }

    // MARK: Delegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            DispatchQueue.main.async { self.syncState = .failed(error.localizedDescription) }
            return
        }
        guard activationState == .activated else { return }

        // Pick up anything that arrived while we were not running.
        if !session.receivedApplicationContext.isEmpty {
            handle(context: session.receivedApplicationContext)
        }

        #if os(iOS)
        // Make sure a freshly installed watch app gets the current data.
        pushToCounterpart()
        #endif
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(context: applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["request"] as? String == "timetable" else {
            replyHandler([:])
            return
        }
        DispatchQueue.main.async {
            if let data = TimetableStorage.encodeForTransfer(self.timetable) {
                replyHandler(["timetable": data])
            } else {
                replyHandler([:])
            }
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Required on iOS so the session re-activates after a watch swap.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        pushToCounterpart()
    }
    #endif
}

#else

extension TimetableStore {
    fileprivate func activateSession() { syncState = .unsupported }
    func pushToCounterpart() {}
    func requestFromPhone() {}
}

#endif
