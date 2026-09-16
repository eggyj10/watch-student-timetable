import Foundation

/// Where the timetable JSON lives.
///
/// On watchOS this has to be the App Group container, because the widget
/// extension is a separate process and can only see the app's data through the
/// shared group. iOS uses the same code path even though nothing else reads it
/// there, so there is only one thing to debug.
enum TimetableStorage {

    /// Must match the App Group capability on every target.
    /// Change this if you change your bundle prefix.
    static let appGroupIdentifier = "group.com.ejones.timetable"

    static let fileName = "timetable.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// App Group container if it is configured, otherwise the app's own
    /// Documents directory. The fallback keeps the app usable if the entitlement
    /// is missing, though the widget will not see data in that case.
    static var fileURL: URL {
        if let containerURL {
            return containerURL.appendingPathComponent(fileName)
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(fileName)
    }

    static var isUsingAppGroup: Bool { containerURL != nil }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: Disk

    static func load() -> Timetable? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(Timetable.self, from: data)
    }

    @discardableResult
    static func save(_ timetable: Timetable) -> Bool {
        guard let data = try? encoder.encode(timetable) else { return false }
        do {
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: Wire format

    /// Compact JSON for the WatchConnectivity payload. Application context is
    /// capped at roughly 256 KB; a full timetable is a couple of kilobytes.
    static func encodeForTransfer(_ timetable: Timetable) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(timetable)
    }

    static func decodeFromTransfer(_ data: Data) -> Timetable? {
        return try? decoder.decode(Timetable.self, from: data)
    }
}
