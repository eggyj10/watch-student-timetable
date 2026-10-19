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
    static let appGroupIdentifier = "group.au.com.eddiej.timetable"

    static let fileName = "timetable.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// App Group container if it is configured, otherwise the app's own
    /// Documents directory.
    ///
    /// The fallback keeps the app itself working, but it is a broken state, not
    /// a supported one: each process gets its own private Documents folder, so
    /// the watch app and the widget stop seeing the same file and the
    /// complication silently freezes. Anything that renders this data is
    /// expected to check `isUsingAppGroup` and say so rather than quietly
    /// carrying on.
    static var fileURL: URL {
        if let containerURL {
            return containerURL.appendingPathComponent(fileName)
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(fileName)
    }

    static var isUsingAppGroup: Bool { containerURL != nil }

    // MARK: Diagnostics

    /// Everything needed to tell, from the watch, whether storage is healthy,
    /// without a Mac or a debugger attached.
    struct Diagnostics {
        var usingAppGroup: Bool
        var fileExists: Bool
        var byteCount: Int?
        var revision: Int?
        var updatedAt: Date?

        /// nil when everything is fine; otherwise what is wrong, in words.
        var problem: String? {
            if !usingAppGroup {
                return "App Group missing. The widget cannot see the watch app's data."
            }
            if !fileExists {
                return "No timetable saved yet. Sync from the iPhone."
            }
            return nil
        }
    }

    static func diagnostics() -> Diagnostics {
        let url = fileURL
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let stored = load()
        return Diagnostics(
            usingAppGroup: isUsingAppGroup,
            fileExists: FileManager.default.fileExists(atPath: url.path),
            byteCount: (attributes?[.size] as? NSNumber)?.intValue,
            revision: stored?.revision,
            updatedAt: stored?.updatedAt
        )
    }

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
