import SwiftUI
import WidgetKit

// MARK: - Entry

struct ClassEntry: TimelineEntry {
    let date: Date
    let focus: Focus?
}

// MARK: - Provider

struct NextClassProvider: TimelineProvider {

    /// The widget runs in its own process, so it reads the App Group file
    /// directly rather than touching `TimetableStore` — no point spinning up a
    /// WatchConnectivity session just to draw a complication.
    private func loadEngine() -> ScheduleEngine {
        let timetable = TimetableStorage.load() ?? .highfieldsTerm3
        return ScheduleEngine(timetable: timetable)
    }

    func placeholder(in context: Context) -> ClassEntry {
        let engine = ScheduleEngine(timetable: .highfieldsTerm3)
        return ClassEntry(date: Date(), focus: engine.focus(at: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (ClassEntry) -> Void) {
        let now = Date()
        completion(ClassEntry(date: now, focus: loadEngine().focus(at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassEntry>) -> Void) {
        let engine = loadEngine()
        let now = Date()

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
            Text("No classes")
                .font(.system(size: 14, weight: .semibold))
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
            Text("No classes")
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
                Image(systemName: "graduationcap")
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
            Image(systemName: "graduationcap")
                .widgetLabel { Text("No classes") }
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
