import SwiftUI

@main
struct TimetableWatchApp: App {

    @StateObject private var store = TimetableStore.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
        }
    }
}

struct WatchRootView: View {

    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        TabView {
            NowView()
            TodayView()
            WeekView()
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            // Only asks for notification permission if something actually has a
            // reminder switched on. Pruning old excursions is left to the
            // phone, which owns the data.
            store.prepareReminders()
        }
    }
}
