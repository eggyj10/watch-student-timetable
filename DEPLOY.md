# Windows → GitHub → Mac → TestFlight

Start to finish. Written for a first time through, so it explains the bits that
are not obvious rather than assuming you already know them.

Rough timings: pushing to GitHub is 5 minutes, Mac setup is mostly waiting for
Xcode to download, and the first TestFlight upload is about an hour including
App Store Connect. Later builds take ten minutes.

---

## Before you start

You need:

- A **paid Apple Developer Program** membership (you have one). The free tier
  cannot use TestFlight.
- A **Mac** that can run Xcode 15 or later, so macOS Sonoma 14 or later.
- An **iPhone** and an **Apple Watch** already paired to it.

One thing to be upfront about: **this code has never been compiled.** It was
written on Windows, where no Swift compiler for Apple platforms exists. The
logic is covered by tests and the scheduling rules were verified separately, but
expect to fix a handful of compile errors on the first build — a wrong argument
label, a SwiftUI type inference complaint. That is normal for code that has not
met its compiler yet. Part 5 has a section on it.

---

## Part 1 — Push to GitHub (on Windows)

The repository is already initialised and committed locally, so there is nothing
to set up in `C:\dev\timetable`.

### 1.1 Make it private

Do this one as **private**. The sample data is your real timetable: your name,
your subjects, your teachers, your room numbers, and which building you are in
at 9am on a Tuesday. None of that needs to be searchable on the public internet.

### 1.2 Create the empty repo

Go to [github.com/new](https://github.com/new) and set:

- **Repository name**: `timetable`
- **Visibility**: **Private**
- **Do not** tick "Add a README", ".gitignore" or "license". The repo must be
  completely empty or the first push will be rejected for having diverged.

Click **Create repository**.

### 1.3 Push

In the Claude Code terminal, or any terminal at `C:\dev\timetable`, replacing
`YOUR-USERNAME`:

```bash
git remote add origin https://github.com/YOUR-USERNAME/timetable.git
```

```bash
git branch -M main && git push -u origin main
```

Git will open a browser window to authenticate the first time. If it instead
asks for a username and password in the terminal, the password field wants a
[personal access token](https://github.com/settings/tokens), not your account
password — GitHub stopped accepting passwords for git operations in 2021.

### 1.4 Check it

Reload the repo page. You should see 34 files and one commit. Confirm the
padlock icon next to the repo name says **Private**.

---

## Part 1.5 — The app icon (optional, on the Mac)

The build ships a flat `AppIcon.appiconset`, which works everywhere and needs no
attention. There is also a hand-authored Icon Composer bundle at
`Icon/AppIcon.icon` for the iOS 26 Liquid Glass treatment — deliberately not
wired into the build until you have opened it once on the Mac and confirmed it.
See [Icon/README.md](Icon/README.md). Skip this entirely if you just want a
build on your phone.

---

## Part 2 — Set up the Mac

### 2.1 Xcode

Install **Xcode** from the Mac App Store. It is about 8 GB, so start it now and
read the rest while it downloads.

Open it once when it finishes, accept the licence, and let it install the
additional components it asks for. Then:

```bash
xcode-select --install
```

If that says the tools are already installed, good.

### 2.2 Homebrew and XcodeGen

This project has no `.xcodeproj` checked in. That is deliberate: Xcode project
files are enormous, unreadable, and produce horrible merge conflicts. Instead
`project.yml` describes the project and **XcodeGen** builds the `.xcodeproj`
from it. You regenerate it any time the file list changes.

If you do not have Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then:

```bash
brew install xcodegen
```

### 2.3 Clone

```bash
git clone https://github.com/YOUR-USERNAME/timetable.git ~/Developer/timetable && cd ~/Developer/timetable
```

### 2.4 Sign in to Xcode

**Xcode → Settings → Accounts → +** → Apple ID, and sign in with the Apple ID
that holds your developer membership. Once it appears, select it and confirm
your team is listed.

---

## Part 3 — Your identifiers

Three placeholder values need to become yours. A script does all of it, but here
is what they are first.

### 3.1 Find your Team ID

Go to [developer.apple.com/account](https://developer.apple.com/account) →
**Membership details**. The **Team ID** is a 10-character string like
`A1B2C3D4E5`. Copy it.

### 3.2 Choose a bundle prefix

A reverse-domain string that is yours: `com.edwardjones`, `au.com.ejones`,
whatever. It does not need to be a domain you own, but it does need to be
globally unique on the App Store, so avoid `com.example` or `com.test`.

From this the project derives:

| Identifier | What it is |
|---|---|
| `PREFIX.timetable` | the iPhone app |
| `PREFIX.timetable.watchkitapp` | the Watch app |
| `PREFIX.timetable.watchkitapp.widget` | the complication |
| `group.PREFIX.timetable` | the App Group |

The `.watchkitapp` suffix is not a style choice — App Store Connect requires the
watch app's identifier to be exactly the iPhone app's identifier plus
`.watchkitapp`, or the upload is rejected.

### 3.3 Apply them

```bash
./Scripts/configure.sh com.edwardjones A1B2C3D4E5
```

Use your own two values. It rewrites six files and prints what it changed.
Verify nothing was missed:

```bash
grep -rn "com.ejones\|CHANGEME99" . --exclude-dir=.git --exclude-dir=Scripts
```

That should print nothing.

### 3.4 Register the App Group

The App Group is the shared container that lets the complication read what the
watch app wrote. Without it the watch works but the complication stays blank.

Xcode can usually create it for you when you add the capability, but it is more
reliable to make it first. At
[developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers):

1. **+** → **App Groups** → Continue
2. **Description**: `Timetable`
3. **Identifier**: `group.PREFIX.timetable` — exactly what the script printed
4. Continue → Register

You do not need to create the three App IDs by hand. Xcode registers those
automatically the first time it signs the app.

### 3.5 Commit

```bash
git add -A && git commit -m "Configure bundle identifiers and team" && git push
```

---

## Part 4 — Generate and open

```bash
xcodegen generate && open Timetable.xcodeproj
```

You should get four targets in the sidebar: `Timetable`, `TimetableWatch`,
`TimetableWidget`, `TimetableTests`.

### 4.1 Check signing

For each of the three app targets — `Timetable`, `TimetableWatch`,
`TimetableWidget` — click the target, go to **Signing & Capabilities**, and
confirm:

- **Automatically manage signing** is ticked
- **Team** shows your team
- **App Groups** appears in the capability list with your group ticked

If App Groups is missing on any target, click **+ Capability**, add **App
Groups**, and tick your group. If the group is not in the list, hit the refresh
button below it.

A yellow warning triangle here usually resolves itself once Xcode finishes
registering the App IDs. Wait a few seconds and look again.

---

## Part 5 — Build it

### 5.1 Run the tests first

Before worrying about devices, check the logic compiles and passes:

```bash
xcodebuild test -scheme Timetable -destination 'platform=iOS Simulator,name=iPhone 15' -quiet
```

If your Xcode has no iPhone 15 simulator, list what you do have with
`xcrun simctl list devices available` and substitute a name.

### 5.2 About the compile errors

This is the step where the never-been-compiled caveat bites. Work through them
top to bottom — fix the first error, rebuild, repeat, because one error in
SwiftUI often cascades into several misleading ones below it.

The likely kinds, in rough order of probability:

- **"Type of expression is ambiguous"** in a SwiftUI view body. Almost always a
  modifier being handed two different types, e.g. a ternary choosing between a
  `Color` and a `.secondary` hierarchical style. Fix by naming the type on both
  sides: `cond ? Color.orange : Color.secondary`.
- **A wrong argument label or a renamed property.** The fix is whatever Xcode
  suggests.
- **"Unable to type-check this expression in reasonable time"** on a long view
  body. Split the offending `VStack` into a separate `private var` returning
  `some View`.

If you hit one you cannot place, paste the error and the surrounding lines back
into Claude Code and it can fix it against the rest of the codebase.

### 5.3 Run on your devices

Plug the iPhone in. First time, you will need to enable Developer Mode:
**Settings → Privacy & Security → Developer Mode → On**, then restart the phone.

Pick your iPhone from the device menu at the top of Xcode and press ▶.

Then select the **TimetableWatch** scheme and your watch as the destination, and
press ▶ again. The first watch install is slow — several minutes, sometimes with
no visible progress. Leave it on the charger and be patient.

Add the complication: long-press the watch face → **Edit** → swipe to
**Complications** → tap a slot → **Timetable → Next Class**.

---

## Part 6 — App Store Connect

### 6.1 Pick a name

App Store app names must be unique across the entire store, and "Timetable" is
long gone. This name is only what appears in App Store Connect and TestFlight,
so pick something specific: **"Highfields Timetable"**, **"Bell — Class
Timetable"**, whatever is free.

This is separate from the name under the icon on your home screen, which stays
"Timetable" and is set by `INFOPLIST_KEY_CFBundleDisplayName` in `project.yml`.

### 6.2 Create the app record

At [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps),
**+** → **New App**:

- **Platforms**: iOS
- **Name**: the name from 6.1
- **Primary Language**: English (Australia)
- **Bundle ID**: pick `PREFIX.timetable` from the dropdown. If it is not there,
  you have not built and signed on a device yet — go back and do Part 5.3, which
  is what registers the App ID.
- **SKU**: any internal string, `timetable-001` is fine. Never shown to anyone.
- **User Access**: Full Access

Create.

You do **not** need screenshots, a description, a privacy policy or an age
rating to use TestFlight with internal testers. Those are only required for
external testers and App Store review.

---

## Part 7 — Archive and upload

### 7.1 Set the build number

Every upload needs a build number higher than the last, or App Store Connect
rejects it. In `project.yml`:

```yaml
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
```

`MARKETING_VERSION` is the version humans see (1.0, 1.1). `CURRENT_PROJECT_VERSION`
is the build number and must go up every single upload, even for the same
version. Bump it, then `xcodegen generate` again.

### 7.2 Archive

In Xcode:

1. Select the **Timetable** scheme (the iOS one — it embeds the watch app and
   the complication, so you archive this and only this).
2. From the device menu, choose **Any iOS Device (arm64)**. Archive is greyed
   out while a simulator is selected, which is the usual reason people think it
   is broken.
3. **Product → Archive**.

The Organizer opens when it finishes.

### 7.3 Upload

In the Organizer, with the new archive selected:

1. **Distribute App**
2. **TestFlight & App Store** → Next
3. **Upload** → Next
4. Leave the defaults ticked — symbols on, and let Xcode manage signing
5. **Upload**

It takes a few minutes. Then the build sits in App Store Connect **Processing**
for anywhere from five minutes to an hour. You get an email when it is done.

Because `ITSAppUsesNonExemptEncryption` is already set to `NO` in
`project.yml`, you will not be asked the export compliance question. That is the
correct answer here — the app does no encryption of its own, and HTTPS through
the system frameworks is exempt.

### 7.4 CLI alternative

Once you have done it through the GUI a few times, this does the same thing:

```bash
xcodebuild -scheme Timetable -destination 'generic/platform=iOS' -archivePath build/Timetable.xcarchive archive
```

```bash
xcodebuild -exportArchive -archivePath build/Timetable.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

with an `ExportOptions.plist` of:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>          <string>app-store-connect</string>
    <key>destination</key>     <string>upload</string>
    <key>teamID</key>          <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>   <true/>
</dict>
</plist>
```

`build/` and `ExportOptions.local.plist` are already gitignored.

---

## Part 8 — TestFlight

### 8.1 Add yourself as an internal tester

In App Store Connect, open your app → **TestFlight** tab.

Internal testers are people on your App Store Connect team, up to 100, and **do
not need Beta App Review**. Builds are available to them within minutes. This is
what you want.

1. **Users and Access** → make sure your Apple ID is on the team
2. Back in **TestFlight** → **Internal Testing** → **+** next to Testers
3. Name the group `Me`, tick yourself, and attach the processed build

### 8.2 Install

On the iPhone, install **TestFlight** from the App Store, sign in with the same
Apple ID, and your app is waiting. Install it.

### 8.3 Get it onto the watch

The watch app ships **inside** the iPhone app, so there is nothing separate to
install from TestFlight. After installing on the phone:

1. Open the **Watch** app on your iPhone
2. Scroll to **Available Apps**
3. Find Timetable → **Install**

If it does not appear, give it a minute and pull to refresh. If it still does
not, the usual cause is the watch app's bundle identifier not being exactly the
iPhone app's plus `.watchkitapp` — check `project.yml`.

Then add the complication as in 5.3.

---

## Part 9 — Shipping an update

```bash
# on the Mac
git pull
# bump CURRENT_PROJECT_VERSION in project.yml
xcodegen generate
```

Then Part 7.2 onwards. Internal testers get the new build within minutes of it
finishing processing.

To go the other way, working on Windows and building on the Mac:

```bash
# Windows
git add -A && git commit -m "..." && git push
```

```bash
# Mac
git pull && xcodegen generate
```

---

## When something goes wrong

**"No account for team" / "Failed to register bundle identifier"**
Xcode is not signed in, or the bundle prefix is already taken by someone else.
Change the prefix in `Scripts/configure.sh` terms and run it again with a new
one.

**"Provisioning profile doesn't include the com.apple.security.application-groups entitlement"**
The App Group in Part 3.4 was not created, or its identifier does not exactly
match. They have to be character-for-character identical, `group.` prefix
included.

**Complication stays blank, watch app works fine**
Always the App Group. The complication is a separate process and the shared
container is the only way it can see the data. Check the capability is ticked on
the **TimetableWidget** target specifically, not just the other two.

**"Invalid bundle. The WatchKit app has an invalid bundle identifier"**
The watch bundle ID is not `<iOS bundle ID>.watchkitapp`.

**Build rejected: "The provided entity includes an attribute with an invalid value" on upload**
Nearly always a build number that is not higher than a previous one. Bump
`CURRENT_PROJECT_VERSION`.

**Archive is greyed out**
A simulator is selected. Switch to **Any iOS Device (arm64)**.

**Watch app will not install and shows no error**
Restart both devices. This is genuinely the fix more often than it should be.

---

## What the repo does and does not carry

Committed: all source, `project.yml`, the entitlements, the app icon, the tests.

Gitignored: `Timetable.xcodeproj/` (regenerate it with `xcodegen`), build output,
archives, and — importantly — `*.p8`, `*.p12`, `*.cer` and `*.mobileprovision`.
If you ever set up an App Store Connect API key for automated uploads, that `.p8`
file is a credential that can publish apps as you. It must never be committed,
even to a private repo.
