import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
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
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )
            .opacity(appState.settings.backgroundOpacity)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.4), location: 0),
                                .init(color: .clear, location: 0.3),
                                .init(color: .white.opacity(0.1), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)

            CaptionScrollTextView(
                text: transcript,
                settings: appState.settings
            )
            .padding(.horizontal, 18)
            .padding(.top, 38)
            .padding(.bottom, 14)

            Color.clear
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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

            Color.white.opacity(0.2)
                .frame(width: 1, height: 12)

            Button {
                appState.updateSetting(\.audioPlayerMuted, to: !appState.settings.audioPlayerMuted)
            } label: {
                Image(systemName: appState.settings.audioPlayerMuted || appState.settings.audioPlayerVolume == 0 ? "speaker.slash.fill" : (appState.settings.audioPlayerVolume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"))
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .help(appState.settings.audioPlayerMuted ? "Unmute" : "Mute")

            Slider(
                value: Binding(
                    get: { appState.settings.audioPlayerVolume },
                    set: { appState.updateSetting(\.audioPlayerVolume, to: $0) }
                ),
                in: 0...1
            )
            .disabled(appState.settings.audioPlayerMuted)
            .controlSize(.small)
            .frame(width: 60)
            .help("Volume")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.8))
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .help("Close subtitle screen and stop capture")
    }
}

struct CaptionScrollTextView: NSViewRepresentable {
    let text: String
    let settings: AppSettings

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

        let needsUpdate = context.coordinator.lastText != text
            || context.coordinator.lastSettings != settings

        if needsUpdate {
            let isNearBottom = isNearBottom(scrollView)

            if let textStorage = textView.textStorage {
                textStorage.beginEditing()
                textStorage.setAttributedString(attributedText(text))
                textStorage.endEditing()
            }

            context.coordinator.lastText = text
            context.coordinator.lastSettings = settings

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

        let font = settings.subtitleFontName.nsFont(
            size: CGFloat(settings.subtitleFontSize),
            bold: settings.subtitleIsBold,
            italic: settings.subtitleIsItalic
        )

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: settings.subtitleColor.nsColor,
            .paragraphStyle: paragraph
        ]

        if settings.subtitleIsUnderline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return NSAttributedString(string: value, attributes: attributes)
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
        var lastSettings: AppSettings?
    }
}
