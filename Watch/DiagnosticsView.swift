import SwiftUI
import WidgetKit

/// Answers "why is the complication wrong?" on the wrist, without a Mac.
///
/// This exists because the complication once sat on a stale timetable for weeks:
/// the App Group entitlement had been stripped, so the watch app and the widget
/// were reading different files, and the widget quietly rendered sample data
/// instead. Nothing on the watch could have told you that.
struct DiagnosticsView: View {

    @EnvironmentObject private var store: TimetableStore
    @State private var diagnostics = TimetableStorage.diagnostics()
    @State private var reloadedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {

                if let problem = diagnostics.problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Label("Storage healthy", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                }

                Divider()

                Row("App Group",
                    diagnostics.usingAppGroup ? "shared" : "MISSING",
                    bad: !diagnostics.usingAppGroup)
                Row("Saved file", diagnostics.fileExists ? "yes" : "no",
                    bad: !diagnostics.fileExists)
                if let bytes = diagnostics.byteCount {
                    Row("Size", "\(bytes) bytes")
                }

                Divider()

                Row("Revision", "\(store.timetable.revision)")
                Row("Title", store.timetable.title)
                Row("Classes", "\(store.timetable.cells.count)")
                Row("Updated", Self.stamp(store.timetable.updatedAt))

                if let fileRevision = diagnostics.revision,
                   fileRevision != store.timetable.revision {
                    Label("On-disk revision is \(fileRevision); the widget reads that one.",
                          systemImage: "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Button {
                    WidgetCenter.shared.reloadAllTimelines()
                    reloadedAt = Date()
                    diagnostics = TimetableStorage.diagnostics()
                } label: {
                    Label("Force widget reload", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }

                if let reloadedAt {
                    Text("Reload asked for at \(Self.stamp(reloadedAt))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Text("If App Group says MISSING, the fix is in Xcode, not here: tick App Groups on all three targets and rebuild.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Diagnostics")
        .onAppear { diagnostics = TimetableStorage.diagnostics() }
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        return formatter.string(from: date)
    }
}

private struct Row: View {

    let label: String
    let value: String
    var bad: Bool = false

    init(_ label: String, _ value: String, bad: Bool = false) {
        self.label = label
        self.value = value
        self.bad = bad
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(bad ? Color.orange : Color.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
}
