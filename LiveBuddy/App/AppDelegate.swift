import AppKit

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
