import SwiftUI

// MARK: - Today

/// The whole of today, so you can check something that is not the next thing.
struct TodayView: View {

    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let engine = store.engine
            let rows = engine.occurrences(onDate: context.date)
            let current = engine.currentOccurrence(at: context.date)

            ScrollView {
                if rows.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "beach.umbrella")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Nothing on")
                            .font(.headline)
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 4) {
                        ForEach(rows) { occurrence in
                            OccurrenceRow(occurrence: occurrence,
                                          isCurrent: occurrence.id == current?.id)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .navigationTitle(engine.weekday(of: context.date)?.fullName ?? "Today")
        }
    }
}

// MARK: - Week

struct WeekView: View {

    @EnvironmentObject private var store: TimetableStore

    private var upcomingExcursions: [Excursion] {
        let cutoff = Calendar.current.startOfDay(for: Date())
        return store.timetable.excursions
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Weekday.allCases) { day in
                        NavigationLink(value: day) {
                            HStack {
                                Text(day.fullName)
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text("\(store.engine.scheduled(on: day).count)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !upcomingExcursions.isEmpty {
                    Section("Excursions") {
                        ForEach(upcomingExcursions) { excursion in
                            NavigationLink {
                                ExcursionDetailView(excursion: excursion)
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(excursion.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                    Text(excursion.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        store.requestFromPhone()
                    } label: {
                        Label("Sync from iPhone", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13))
                    }
                    Text(store.syncState.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } header: {
                    Text(store.timetable.title)
                }
            }
            .navigationTitle("Week")
            .navigationDestination(for: Weekday.self) { day in
                DayDetailView(day: day)
            }
        }
    }
}

// MARK: - Day detail

/// The repeating weekly pattern for one day. Excursions are date-specific and
/// live in their own section of the week list.
struct DayDetailView: View {

    @EnvironmentObject private var store: TimetableStore
    let day: Weekday

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(store.engine.occurrences(on: day)) { occurrence in
                    OccurrenceRow(occurrence: occurrence, isCurrent: false)
                }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(day.shortName)
    }
}

// MARK: - Excursion detail

struct ExcursionDetailView: View {

    let excursion: Excursion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(excursion.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)

                DetailLine(icon: "calendar",
                           text: excursion.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                DetailLine(icon: "clock",
                           text: "\(excursion.start.display)-\(excursion.end.display)")

                if !excursion.location.isEmpty {
                    DetailLine(icon: "mappin.and.ellipse", text: excursion.location)
                }

                DetailLine(icon: excursion.transport.symbolName,
                           text: excursion.transport.label,
                           tint: excursion.transport == .own ? .orange : .primary)

                if !excursion.meetingPoint.isEmpty {
                    DetailLine(icon: "figure.stand.line.dotted.figure.stand",
                               text: "\(excursion.meetingPoint) by \(excursion.callTime.display)")
                }

                if !excursion.note.isEmpty {
                    Text(excursion.note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .navigationTitle("Excursion")
    }
}

struct DetailLine: View {

    let icon: String
    let text: String
    var tint: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Row

struct OccurrenceRow: View {

    let occurrence: Occurrence
    let isCurrent: Bool

    private var isFilled: Bool { occurrence.isScheduled }

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isFilled ? occurrence.color : Color.secondary.opacity(0.4))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    if occurrence.isExcursion || occurrence.isActivity {
                        Image(systemName: occurrence.symbolName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(occurrence.color)
                    }
                    Text(occurrence.title)
                        .font(.system(size: 13, weight: isFilled ? .semibold : .regular))
                        .foregroundStyle(isFilled ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let detail = occurrence.detailLine {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text(occurrence.slot.start.display)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                HStack(spacing: 2) {
                    if occurrence.reminderMinutes != nil {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    Text(occurrence.isExcursion ? "EXC" : occurrence.slot.code)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minHeight: 34)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isCurrent ? occurrence.color.opacity(0.28) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(isCurrent ? occurrence.color : .clear, lineWidth: 1.5)
        )
    }
}
