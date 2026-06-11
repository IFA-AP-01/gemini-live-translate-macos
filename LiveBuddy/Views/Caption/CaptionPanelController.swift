import AppKit
import SwiftUI

final class CaptionPanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
        let savedFrame = appState.settings.subtitleScreenFrame.map {
            NSRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
        }
        panel = NSPanel(
            contentRect: savedFrame ?? NSRect(x: 240, y: 160, width: 600, height: 150),
            styleMask: [.titled, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.title = "Subtitle Screen"
        panel.minSize = NSSize(width: 420, height: 120)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: CaptionView(onClose: { [weak panel, weak appState] in
                Task { @MainActor in
                    await appState?.stop()
                }
                panel?.orderOut(nil)
            })
            .environmentObject(appState)
        )
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    func windowWillClose(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        appState?.saveSubtitleScreenFrame(panel.frame)
    }
}
