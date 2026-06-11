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

struct CaptionView: View {
    @EnvironmentObject private var appState: AppState
    let onClose: () -> Void

    private var transcript: String {
        appState.subtitleText
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(appState.settings.backgroundOpacity))

            CaptionScrollTextView(
                text: transcript
            )
            .padding(.horizontal, 18)
            .padding(.top, 38)
            .padding(.bottom, 14)

            Color.clear
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topLeading) {
            topControls
                .padding(.leading, 10)
                .padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.trailing, 9)
                .padding(.top, 8)
        }
        .overlay {
            SubtitleResizeOverlay()
        }
        .padding(1)
    }

    private var topControls: some View {
        HStack(spacing: 9) {
            Button {
                appState.toggle()
            } label: {
                Image(systemName: appState.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .help(appState.isRunning ? "Pause" : "Play")

            StatusDot(level: appState.statusLevel)

            Text(TranslationLanguage.name(for: appState.settings.targetLanguageCode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .leading)

            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))

            Slider(
                value: Binding(
                    get: { appState.settings.backgroundOpacity },
                    set: { appState.updateSetting(\.backgroundOpacity, to: $0) }
                ),
                in: 0.15...0.95
            )
            .controlSize(.small)
            .frame(width: 82)
            .help("Transparency")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.22), in: Capsule())
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.8))
        .background(.black.opacity(0.22), in: Circle())
        .help("Close subtitle screen and stop capture")
    }
}

struct StatusDot: View {
    let level: LiveStatusLevel

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .shadow(color: color.opacity(0.55), radius: 4)
            .help(helpText)
    }

    private var color: Color {
        switch level {
        case .running: .green
        case .connecting: .yellow
        case .error, .stopped: .red
        }
    }

    private var helpText: String {
        switch level {
        case .running: "Running"
        case .connecting: "Connecting"
        case .error: "Error"
        case .stopped: "Stopped"
        }
    }
}

struct CaptionScrollTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.controlSize = .small

        let textView = NSTextView()
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(attributedText(""))

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let targetWidth = max(1, scrollView.contentSize.width)
        if abs(textView.frame.width - targetWidth) > 0.5 {
            textView.frame.size.width = targetWidth
            updateDocumentSize(textView, in: scrollView)
        }

        if context.coordinator.lastText != text {
            let shouldFollowBottom = context.coordinator.lastText.isEmpty || isNearBottom(scrollView)
            context.coordinator.lastText = text
            textView.textStorage?.setAttributedString(attributedText(text))
            updateDocumentSize(textView, in: scrollView)
            if shouldFollowBottom {
                scroll(to: 1, in: scrollView, animated: text.containsTerminator)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func attributedText(_ value: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.alignment = .left
        return NSAttributedString(
            string: value,
            attributes: [
                .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func scroll(to position: Double, in scrollView: NSScrollView, animated: Bool) {
        guard let documentView = scrollView.documentView else { return }
        let maxY = max(0, documentView.bounds.height - scrollView.contentSize.height)
        let y = max(0, min(1, position)) * maxY
        let origin = NSPoint(x: 0, y: y)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scrollView.contentView.animator().setBoundsOrigin(origin)
            }
        } else {
            scrollView.contentView.setBoundsOrigin(origin)
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func isNearBottom(_ scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else { return true }
        let maxY = max(0, documentView.bounds.height - scrollView.contentSize.height)
        return maxY - scrollView.contentView.bounds.origin.y < 24
    }

    private func updateDocumentSize(_ textView: NSTextView, in scrollView: NSScrollView) {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }
        textContainer.containerSize = NSSize(width: max(1, scrollView.contentSize.width), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let height = ceil(usedRect.height + textView.textContainerInset.height * 2 + 16)
        textView.frame.size = NSSize(
            width: max(1, scrollView.contentSize.width),
            height: max(scrollView.contentSize.height, height)
        )
    }

    final class Coordinator {
        var lastText = ""
    }
}

private extension String {
    var containsTerminator: Bool {
        rangeOfCharacter(from: CharacterSet(charactersIn: ".?!。？！")) != nil
    }
}

struct SubtitleResizeOverlay: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeOverlayView {
        ResizeOverlayView()
    }

    func updateNSView(_ nsView: ResizeOverlayView, context: Context) {}
}

final class ResizeOverlayView: NSView {
    private let edgeSize: CGFloat = 8
    private var activeEdges: RectEdge = []
    private var initialFrame = NSRect.zero
    private var initialMouse = NSPoint.zero
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(tracking)
        self.tracking = tracking
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        edges(at: point).isEmpty ? nil : self
    }

    override func mouseMoved(with event: NSEvent) {
        cursor(for: edges(at: convert(event.locationInWindow, from: nil))).set()
    }

    override func cursorUpdate(with event: NSEvent) {
        cursor(for: edges(at: convert(event.locationInWindow, from: nil))).set()
    }

    override func mouseDown(with event: NSEvent) {
        activeEdges = edges(at: convert(event.locationInWindow, from: nil))
        initialFrame = window?.frame ?? .zero
        initialMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, !activeEdges.isEmpty else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - initialMouse.x
        let dy = current.y - initialMouse.y
        var frame = initialFrame
        let minSize = window.minSize

        if activeEdges.contains(.left) {
            frame.origin.x += dx
            frame.size.width -= dx
        }
        if activeEdges.contains(.right) {
            frame.size.width += dx
        }
        if activeEdges.contains(.bottom) {
            frame.origin.y += dy
            frame.size.height -= dy
        }
        if activeEdges.contains(.top) {
            frame.size.height += dy
        }

        if frame.size.width < minSize.width {
            if activeEdges.contains(.left) {
                frame.origin.x -= minSize.width - frame.size.width
            }
            frame.size.width = minSize.width
        }
        if frame.size.height < minSize.height {
            if activeEdges.contains(.bottom) {
                frame.origin.y -= minSize.height - frame.size.height
            }
            frame.size.height = minSize.height
        }

        window.setFrame(frame, display: true)
    }

    private func edges(at point: NSPoint) -> RectEdge {
        var edges: RectEdge = []
        if point.x <= edgeSize {
            edges.insert(.left)
        }
        if point.x >= bounds.width - edgeSize {
            edges.insert(.right)
        }
        if point.y <= edgeSize {
            edges.insert(.bottom)
        }
        if point.y >= bounds.height - edgeSize {
            edges.insert(.top)
        }
        return edges
    }

    private func cursor(for edges: RectEdge) -> NSCursor {
        if edges.contains(.left) || edges.contains(.right) {
            return .resizeLeftRight
        }
        if edges.contains(.top) || edges.contains(.bottom) {
            return .resizeUpDown
        }
        return .arrow
    }
}

struct RectEdge: OptionSet {
    let rawValue: Int

    static let top = RectEdge(rawValue: 1 << 0)
    static let right = RectEdge(rawValue: 1 << 1)
    static let bottom = RectEdge(rawValue: 1 << 2)
    static let left = RectEdge(rawValue: 1 << 3)
}
