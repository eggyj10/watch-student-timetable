import SwiftUI

@main
struct TimetableApp: App {

    @StateObject private var store = TimetableStore.shared

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environmentObject(store)
        }
    }
}

struct PhoneRootView: View {

    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        TabView {
            PhoneTodayView()
                .tabItem { Label("Today", systemImage: "clock") }

            WeekEditorView()
                .tabItem { Label("Timetable", systemImage: "square.grid.3x3") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear {
            // The phone owns the data, so it is the one that tidies up.
            store.pruneOldExcursions()
        }
    }
}
