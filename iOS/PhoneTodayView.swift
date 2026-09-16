import SwiftUI

/// The same now/next answer the watch gives, on a screen big enough to also
/// show the rest of the day. Handy for checking the logic without a wrist.
struct PhoneTodayView: View {

    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let engine = store.engine
                List {
                    if let focus = engine.focus(at: context.date) {
                        Section {
                            PhoneFocusCard(focus: focus, now: context.date)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            if let then = engine.following(focus) {
                                PhoneThenRow(focus: then)
                            }
                        }
                    }

                    let rows = engine.occurrences(onDate: context.date)
                    if rows.isEmpty {
                        Section {
                            Label("Nothing on today", systemImage: "beach.umbrella")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        let current = engine.currentOccurrence(at: context.date)
                        Section(engine.weekday(of: context.date)?.fullName ?? "Today") {
                            ForEach(rows) { occurrence in
                                PhoneOccurrenceRow(occurrence: occurrence,
                                                   isCurrent: occurrence.id == current?.id)
                            }
                        }
                    }
                }
                .navigationTitle("Today")
            }
        }
    }
}

// MARK: - Focus card

struct PhoneFocusCard: View {

    let focus: Focus
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(focus.kind.label)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(focus.occurrence.color)
                if let dayNote = focus.dayNote {
                    Text(dayNote)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if focus.occurrence.reminderMinutes != nil {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(focus.occurrence.kindLabel ?? focus.occurrence.slot.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(focus.occurrence.title)
                .font(.title2.weight(.bold))

            if let detail = focus.occurrence.detailLine {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if focus.occurrence.isExcursion,
               let transport = focus.occurrence.excursion?.transport,
               transport != .unspecified {
                Label(transport.label, systemImage: transport.symbolName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(transport == .own ? Color.orange : Color.secondary)
            }

            HStack(spacing: 4) {
                Text(focus.occurrence.timeRange)
                    .font(.footnote.weight(.semibold))
                Text("·").foregroundStyle(.secondary)
                Text(focus.countdownVerb(from: now))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(focus.countdownTarget(from: now), style: .relative)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }

            if let arriveBy = focus.occurrence.arriveByNote {
                Label(arriveBy, systemImage: "exclamationmark.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            if let note = focus.occurrence.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(focus.occurrence.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(focus.occurrence.color)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Then row

struct PhoneThenRow: View {

    let focus: Focus

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(focus.occurrence.color)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("THEN")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
                Text(focus.occurrence.title)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(focus.occurrence.slot.start.display)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let detail = focus.occurrence.compactDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Row

struct PhoneOccurrenceRow: View {

    let occurrence: Occurrence
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(occurrence.slot.start.display)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                Text(occurrence.slot.code)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2)
                .fill(occurrence.isScheduled ? occurrence.color : Color.secondary.opacity(0.3))
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if occurrence.isExcursion || occurrence.isActivity {
                        Image(systemName: occurrence.symbolName)
                            .font(.caption2)
                            .foregroundStyle(occurrence.color)
                    }
                    Text(occurrence.title)
                        .font(.subheadline.weight(occurrence.isScheduled ? .semibold : .regular))
                        .foregroundStyle(occurrence.isScheduled ? .primary : .secondary)
                }
                if let detail = occurrence.detailLine {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isCurrent {
                Image(systemName: "chevron.left.circle.fill")
                    .foregroundStyle(occurrence.color)
            }
        }
        .padding(.vertical, 2)
    }
}
