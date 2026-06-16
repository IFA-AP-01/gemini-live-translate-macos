import SwiftUI

@main
struct LiveBuddyApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 560, minHeight: 520)
                .onAppear {
                    appDelegate.configure(with: appState)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        MenuBarExtra("LiveBuddy", systemImage: appState.isRunning ? "captions.bubble.fill" : "captions.bubble") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

extension Notification.Name {
    static let showCaptionWindow = Notification.Name("LiveBuddyShowCaptionWindow")
}
