import SwiftUI

/// The screen you get when you raise your wrist: one big card for whatever you
/// need right now, and a quieter line for what follows it.
struct NowView: View {

    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        // Re-evaluates every 30 seconds, which is enough to cross a bell on time
        // without keeping the screen busy.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    let engine = store.engine
                    if let focus = engine.focus(at: context.date) {
                        FocusCard(focus: focus, now: context.date)
                        if let then = engine.following(focus) {
                            ThenRow(focus: then)
                        }
                    } else {
                        EmptyStateView()
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .containerBackground(.blue.gradient, for: .tabView)
        .navigationTitle("Now")
    }
}

// MARK: - Focus card

struct FocusCard: View {

    let focus: Focus
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(focus.kind.label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(focus.occurrence.color)
                if let dayNote = focus.dayNote {
                    Text(dayNote)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if focus.occurrence.reminderMinutes != nil {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Text(focus.occurrence.kindLabel ?? focus.occurrence.slot.code)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(focus.occurrence.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            if let room = focus.occurrence.room {
                Label(room, systemImage: focus.occurrence.isExcursion ? "mappin.and.ellipse" : "door.left.hand.open")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let teacher = focus.occurrence.teacherName, !teacher.isEmpty {
                Text(teacher)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // For an excursion, how you are getting there matters more than
            // anything else on this card.
            if let transport = focus.occurrence.transportNote {
                Label(transport, systemImage: focus.occurrence.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(focus.occurrence.excursion?.transport == .own ? Color.orange : Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            Divider().padding(.vertical, 1)

            HStack(spacing: 4) {
                Text(focus.occurrence.timeRange)
                    .font(.system(size: 13, weight: .semibold))
                Text("·")
                    .foregroundStyle(.secondary)
                Text(focus.countdownVerb(from: now))
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                // Self-updating, so the minutes stay honest between refreshes.
                Text(focus.countdownTarget(from: now), style: .relative)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            if let arriveBy = focus.occurrence.arriveByNote {
                Text(arriveBy)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            }

            if let note = focus.occurrence.note {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(focus.occurrence.color.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(focus.occurrence.color)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}

// MARK: - Then row

struct ThenRow: View {

    let focus: Focus

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(focus.occurrence.color)
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("THEN")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.secondary)
                Text(focus.occurrence.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text(focus.occurrence.slot.start.display)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                if let room = focus.occurrence.room {
                    Text(room)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No classes found")
                .font(.headline)
            Text("Open Timetable on your iPhone to send one across.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
