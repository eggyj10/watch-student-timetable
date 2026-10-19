import SwiftUI
import WidgetKit

// MARK: - Entry

/// Why the widget has nothing real to show. Rendering sample data instead of
/// saying this is what let a missing App Group masquerade as a working
/// complication for weeks.
enum WidgetProblem {
    case appGroupMissing
    case noTimetable

    var short: String {
        switch self {
        case .appGroupMissing: return "Setup"
        case .noTimetable: return "Sync"
        }
    }

    var message: String {
        switch self {
        case .appGroupMissing: return "App Group missing"
        case .noTimetable: return "Open app to sync"
        }
    }
}

struct ClassEntry: TimelineEntry {
    let date: Date
    let focus: Focus?
    var problem: WidgetProblem?
}

// MARK: - Provider

struct NextClassProvider: TimelineProvider {

    /// The widget runs in its own process, so it reads the App Group file
    /// directly rather than touching `TimetableStore` — no point spinning up a
    /// WatchConnectivity session just to draw a complication.
    /// Returns the real engine, or the reason there isn't one. Never falls back
    /// to sample data outside the gallery placeholder: a complication showing a
    /// plausible but wrong timetable is worse than one admitting it is broken.
    private func loadEngine() -> Result<ScheduleEngine, WidgetProblem> {
        guard TimetableStorage.isUsingAppGroup else { return .failure(.appGroupMissing) }
        guard let timetable = TimetableStorage.load() else { return .failure(.noTimetable) }
        return .success(ScheduleEngine(timetable: timetable))
    }

    /// The gallery preview, where sample data is the point.
    func placeholder(in context: Context) -> ClassEntry {
        let engine = ScheduleEngine(timetable: .highfieldsTerm3)
        return ClassEntry(date: Date(), focus: engine.focus(at: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (ClassEntry) -> Void) {
        let now = Date()
        switch loadEngine() {
        case .success(let engine):
            completion(ClassEntry(date: now, focus: engine.focus(at: now)))
        case .failure(let problem):
            completion(ClassEntry(date: now, focus: nil, problem: problem))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassEntry>) -> Void) {
        let now = Date()

        let engine: ScheduleEngine
        switch loadEngine() {
        case .success(let loaded):
            engine = loaded
        case .failure(let problem):
            // Retry in an hour: the fix is a rebuild or a sync, either of which
            // also triggers an explicit reload.
            let retry = now.addingTimeInterval(3600)
            completion(Timeline(entries: [ClassEntry(date: now, focus: nil, problem: problem)],
                                policy: .after(retry)))
            return
        }

        // One entry per moment the answer changes: every bell, and every
        // settle-over. Between those, the only thing moving is the relative
        // countdown, which SwiftUI updates on its own.
        var dates = [now]
        dates.append(contentsOf: engine.transitionDates(from: now, days: 3))
        dates = Array(dates.prefix(100))

        let entries = dates.map { ClassEntry(date: $0, focus: engine.focus(at: $0)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget

struct NextClassWidget: Widget {

    let kind = "NextClassWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextClassProvider()) { entry in
            NextClassWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Class")
        .description("What you have now, and what is next.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
            .accessoryCorner,
        ])
    }
}

// MARK: - View routing

struct NextClassWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: ClassEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                InlineView(entry: entry)
            case .accessoryCircular:
                CircularView(entry: entry)
            case .accessoryCorner:
                CornerView(entry: entry)
            default:
                RectangularView(entry: entry)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Rectangular

struct RectangularView: View {

    let entry: ClassEntry

    var body: some View {
        if let focus = entry.focus {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text(focus.kind.label)
                        .font(.system(size: 11, weight: .heavy))
                        .widgetAccentable()
                    if let dayNote = focus.dayNote {
                        Text(dayNote)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Spacer(minLength: 0)
                    Text(focus.occurrence.kindLabel ?? focus.occurrence.slot.code)
                        .font(.system(size: 11, weight: .semibold))
                }

                Text(focus.occurrence.title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 3) {
                    if let detail = focus.occurrence.compactDetail {
                        Text(detail)
                            .font(.system(size: 12, weight: .medium))
                    }
                    Text(focus.occurrence.slot.start.display)
                        .font(.system(size: 12))
                        .monospacedDigit()
                    Text(focus.countdownTarget(from: entry.date), style: .relative)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Timetable")
                    .font(.system(size: 11, weight: .heavy))
                    .widgetAccentable()
                Text(entry.problem?.message ?? "No classes")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Inline

struct InlineView: View {

    let entry: ClassEntry

    var body: some View {
        if let focus = entry.focus {
            // Inline is a single run of text, so lead with the room. That is
            // the bit you actually need while walking.
            let room = focus.occurrence.room.map { " \($0)" } ?? ""
            Text("\(focus.occurrence.shortTitle)\(room) \(focus.occurrence.slot.start.display)")
        } else {
            Text(entry.problem?.message ?? "No classes")
        }
    }
}

// MARK: - Circular

struct CircularView: View {

    let entry: ClassEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let focus = entry.focus {
                VStack(spacing: -1) {
                    Text(focus.occurrence.slot.code)
                        .font(.system(size: 13, weight: .bold))
                        .widgetAccentable()
                    Text(focus.occurrence.room ?? focus.occurrence.shortTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(focus.occurrence.slot.start.display)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(2)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: entry.problem == nil ? "graduationcap" : "exclamationmark.triangle")
                        .font(.system(size: 14))
                    if let problem = entry.problem {
                        Text(problem.short)
                            .font(.system(size: 10, weight: .semibold))
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
    }
}

// MARK: - Corner

struct CornerView: View {

    let entry: ClassEntry

    var body: some View {
        if let focus = entry.focus {
            Text(focus.occurrence.room ?? focus.occurrence.shortTitle)
                .font(.system(size: 15, weight: .bold))
                .widgetLabel {
                    Text("\(focus.kind.label) \(focus.occurrence.title)")
                }
        } else {
            Image(systemName: entry.problem == nil ? "graduationcap" : "exclamationmark.triangle")
                .widgetLabel { Text(entry.problem?.message ?? "No classes") }
        }
    }
}

// MARK: - Bundle

@main
struct TimetableWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextClassWidget()
    }
}
