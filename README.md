# Timetable

An iPhone app for entering a school timetable, an Apple Watch app that shows
what class you have now and next, and a watch face complication for the same.

Once the phone has sent a timetable across, the watch is fully offline: it keeps
its own copy on disk and never needs the phone again until the timetable changes.

---

## What it does

**iPhone** — enter and edit the timetable. Periods, bell times, subjects,
teachers, rooms, lunchtime and after-school activities, excursions, and opt-in
reminders. Changes are pushed to the watch automatically.

**Watch** — three pages you swipe between:

1. **Now** — one big card for the class you need, a countdown, and a "then" line.
2. **Today** — every period today, with the current one highlighted.
3. **Week** — drill into any day.

**Complication** — the next class on your watch face, in all four accessory
families (rectangular, inline, circular, corner).

---

## The bell rules

This is the part worth understanding, because it is what makes the watch face
show the right thing rather than the technically-correct thing.

A period becomes the thing on your watch face at its **bell**, which is normally
five minutes before it starts, so the walk between rooms belongs to the class you
are walking *to*.

Two adjustments:

- **Period 3 is an exception.** Its bell rings at 12:00 on the dot, not 11:55,
  and there is a five-minute grace period — the card says "be there by 12:05".
- **Bells are clamped.** A bell is never allowed to ring while you are still
  sitting in the previous class. Period 1 would nominally ring at 8:55, which is
  halfway through Form, so it is held back to 9:00.

Ten minutes after a class starts you are settled in and already know what room
you are in, so the face switches from showing that class to showing the next one.
That interval is the **Switch to next after** setting.

A Monday, minute by minute:

| Time  | Face shows | Why |
|-------|-----------|-----|
| 8:45  | `NOW FRM` | Form's bell, five minutes early |
| 8:57  | `NOW FRM` | P1's early bell is clamped out of Form |
| 9:00  | `NOW P1 Science` | P1 starts |
| 9:10  | `NEXT P2` | settled into P1 |
| 10:45 | `NOW P2` | P2's bell, five minutes early |
| 11:00 | `NEXT P3` | settled into P2 |
| 11:57 | `NEXT P3` | P3 gets no early bell |
| 12:00 | `NOW P3` | P3's bell, on the hour |
| 12:02 | `NOW P3` | |
| 12:10 | `NEXT P4` | settled into P3 |
| 13:45 | `NOW P4` | P4's bell, five minutes early |
| 14:00 | `NEXT FRM` tomorrow | last class of the day |

All of this is covered by `Tests/ScheduleEngineTests.swift`.

Bell timings are per-period and editable in **Settings → Periods & Bells**, so
if the school changes something you do not need to touch code.

---

## Activities

Any band of the day can hold an **activity** instead of a class: chess club at
lunch, training after school, a standing appointment. Open the period in the
Timetable tab and switch the type from Class to Activity. An activity has a
free-text name, a place, a colour and a note, and needs no subject or teacher.

Two rules make activities behave sensibly next to classes:

- **They do not settle early.** A lesson drops off the face ten minutes in
  because you already know what room you are in. A club is the thing you are
  doing, so it stays up for its whole length.
- **They do not hold you.** A lunchtime club never pushes back the next bell, so
  period 4 still lights up five minutes early at 1:45 even if chess runs to 1:50.

A band you put something into appears on that day even if it does not normally
run, so an after-school activity on a Monday works even though the after-school
band is only scheduled Tuesday to Thursday.

---

## Excursions

An excursion is tied to **a specific date** rather than repeating weekly, and it
takes over whatever periods it overlaps. The editor lists which periods it will
replace as you set the times, so there are no surprises.

Each one records where you are going, whether the **school is transporting you or
you are getting yourself there**, the meeting point, and an optional note. Own
transport is shown in orange on both the watch and the phone so it is obvious at
a glance.

The meeting time is the important detail. If you have to be at the bus bay at
8:30 for a 9:00 departure, set **Be there earlier than departure**, and the
watch switches to the excursion at 8:30 — which also means form class at 8:50
correctly disappears, because you are not going to be in it.

Excursions more than two weeks past are dropped automatically the next time you
open the phone app.

---

## Reminders

Off by default. Switch one on for a particular class, activity or excursion in
its editor, and choose how far ahead: at the start, 5, 10, 15, 30 minutes or an
hour.

Reminders are scheduled **on the watch**, not the phone, so they still fire with
your phone out of range — which is the point of the app. Weekly classes use a
repeating trigger, so nothing needs topping up; excursions get a one-shot trigger
tied to their date and are counted back from when you have to be there rather
than from departure.

The watch asks for notification permission the first time you set one, not at
first launch. **Settings → Reminders** on the phone shows how many are set and
can clear them all. If you would rather the phone owned reminders, the one-line
change is documented at the top of `Shared/ReminderScheduler.swift`.

---

## Building

For the full path from a Windows machine to TestFlight, see [DEPLOY.md](DEPLOY.md).
What follows is the short version.

Requires **macOS with Xcode 15 or later**. Targets iOS 17 and watchOS 10.

### Before you build, set your identifiers

The repo ships with a placeholder bundle prefix and Team ID. One script replaces
both everywhere they appear, across six files:

```bash
./Scripts/configure.sh com.yourname A1B2C3D4E5
```

The first argument is any reverse-domain prefix that is yours; the second is the
10-character Team ID from **Membership details** at developer.apple.com/account.

You also need to register the **App Group** it prints (`group.<prefix>.timetable`)
under Certificates, Identifiers & Profiles → Identifiers → App Groups, and tick
it on all three app targets. That shared container is the only way the
complication can read what the watch app wrote — if it is missing, the watch app
works but the complication stays blank.

### Option A: XcodeGen

```bash
brew install xcodegen
xcodegen generate
open Timetable.xcodeproj
```

### Option B: by hand

1. **New Project** → iOS → App. Name it `Timetable`, interface SwiftUI.
2. **File → New → Target** → watchOS → App. Name it `TimetableWatch`. When Xcode
   offers to embed it in the iOS app, accept.
3. **File → New → Target** → watchOS → Widget Extension. Name it
   `TimetableWidget`, uncheck "Include Configuration App Intent", and embed it in
   the **watch** app.
4. Delete the generated `.swift` files from all three targets.
5. Drag in `Shared/`, `iOS/`, `Watch/`, `Widget/` and `Tests/` as folder
   references with "Copy items if needed" checked.
6. Set **Target Membership** in the file inspector:

   | Folder | Timetable | TimetableWatch | TimetableWidget | TimetableTests |
   |--------|:---------:|:--------------:|:---------------:|:--------------:|
   | `Shared/` | ✓ | ✓ | ✓ | ✓ |
   | `iOS/` | ✓ | | | |
   | `Watch/` | | ✓ | | |
   | `Widget/` | | | ✓ | |
   | `Tests/` | | | | ✓ |

7. For each of the three app targets: **Signing & Capabilities → + Capability →
   App Groups**, and tick the same group.

### Running it

Build the `Timetable` scheme to your iPhone first, then the `TimetableWatch`
scheme to the watch. With a paid developer account the install lasts a year.

To add the complication: long-press the watch face → **Edit** → swipe to
**Complications** → tap a slot → pick **Timetable → Next Class**.

---

## Entering a timetable

The app ships with the 2026 Term 3 timetable already in it, so there is nothing
to do on first launch. To change it:

- **Timetable tab** — pick a day, tap a period, choose subject, teacher and room.
- **Settings → Bulk edit as text** — much faster at the start of a term:

```
# Subjects
S SCI102B Science
S MAX102A Mathematics Extension

# Teachers
T DAYLU Mr Day
T MURPPE Mr Murphy

# Classes: DAY SLOT SUBJECT TEACHER ROOM
MON P1 SCI102B DAYLU K34
MON P2 IDX102A BISHMA K08
FRI P1 MAX102A MURPPE T02 !10

# Activities: A DAY SLOT Name @ Place
A MON SB Chess Club @ Library
A MON AS Footy Training @ Oval
```

Use `-` for a blank teacher or room, and `#` for a comment. A trailing `!10` sets
a reminder ten minutes before; leaving it off keeps whatever reminder you already
had, so a bulk edit never silently wipes one.

Excursions are not part of this format — they have their own screen and are left
untouched by a bulk edit. The current timetable is pre-filled in the editor, so it
doubles as an export.

Anything that does not parse is reported as a warning rather than silently
dropped.

---

## Sync

The phone owns the data. Every edit bumps a revision number, writes to disk and
calls `updateApplicationContext`, which is latest-value-wins and gets delivered
even if the watch is asleep or out of range at the time.

The watch writes whatever arrives into the App Group container. The watch app and
the widget both read from there, so neither needs the phone to be present. The
watch ignores any payload that is not newer than what it already holds.

**Week** page on the watch has a **Sync from iPhone** button for when you want to
force it.

---

## Layout

```
Shared/      Models, schedule engine, storage, sync, formatting
  Models.swift              Weekday, ClockTime, Slot, Subject, Cell, Excursion, Timetable
  ScheduleEngine.swift      Bell clamping, excursion overrides, now/next, timeline
  SampleTimetable.swift     2026 Term 3, transcribed from the OneSchool PDF
  TimetableStorage.swift    App Group file, JSON wire format
  TimetableStore.swift      Observable store, WatchConnectivity
  TimetableTextFormat.swift Bulk text import/export
  ReminderScheduler.swift   Opt-in local notifications
  Presentation.swift        Display strings shared by watch and widget
  Theme.swift               Colours

iOS/         Phone app: today view, grid editor, excursions, settings
Watch/       Watch app: now, today, week, excursion detail
Widget/      Complication: provider, four accessory layouts
Tests/       Bell rules, activities, excursions, reminders, text and wire formats
Config/      App Group entitlements
```

`ScheduleEngine` has no UI and no platform dependencies. It resolves the weekly
pattern for a weekday, applies any excursion covering that date, then answers
"what now, what next" — which is why every rule above can be tested directly.
