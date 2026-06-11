import SwiftUI
import AppKit

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

struct CaptionScrollTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.controlSize = .small

        let textView = NSTextView()
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.layoutManager?.allowsNonContiguousLayout = false

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if context.coordinator.lastText != text {
            let isNearBottom = isNearBottom(scrollView)

            if let textStorage = textView.textStorage {
                textStorage.beginEditing()
                textStorage.setAttributedString(attributedText(text))
                textStorage.endEditing()
            }

            context.coordinator.lastText = text

            if isNearBottom || text.isEmpty {
                DispatchQueue.main.async {
                    scrollSmoothlyToBottom(in: scrollView)
                }
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

    private func scrollSmoothlyToBottom(in scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }

        let documentHeight = documentView.bounds.height
        let clipHeight = scrollView.contentView.bounds.height
        let maxY = max(0, documentHeight - clipHeight)
        let targetPoint = NSPoint(x: 0, y: maxY)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scrollView.contentView.animator().setBoundsOrigin(targetPoint)
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func isNearBottom(_ scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else { return true }
        let maxY = max(0, documentView.bounds.height - scrollView.contentSize.height)
        let currentY = scrollView.contentView.bounds.origin.y
        return maxY - currentY < 50
    }

    final class Coordinator {
        var lastText = ""
    }
}
