import SwiftUI

@main
struct LiveBuddyApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 560, minHeight: 520)
                .onAppear {
                    appDelegate.configure(with: appState)
                }
        }
        .windowResizability(.contentSize)

        MenuBarExtra("LiveBuddy", systemImage: appState.isRunning ? "captions.bubble.fill" : "captions.bubble") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var captionPanel: CaptionPanelController?
    private weak var appState: AppState?
    private var showCaptionObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func configure(with appState: AppState) {
        guard self.appState !== appState else { return }
        self.appState = appState
        let panel = CaptionPanelController(appState: appState)
        captionPanel = panel
        panel.show()
        showCaptionObserver = NotificationCenter.default.addObserver(
            forName: .showCaptionWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.captionPanel?.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { await appState?.stop() }
        if let showCaptionObserver {
            NotificationCenter.default.removeObserver(showCaptionObserver)
        }
    }
}

extension Notification.Name {
    static let showCaptionWindow = Notification.Name("LiveBuddyShowCaptionWindow")
}
