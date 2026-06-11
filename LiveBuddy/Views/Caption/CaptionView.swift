import SwiftUI
import AppKit
import Combine

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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Color.clear
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topLeading) {
            topControls
                .padding(.leading, 10)
                .padding(.top, 8)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.trailing, 9)
                .padding(.top, 8)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .overlay {
            SubtitleResizeOverlay()
        }
        .padding(1)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            isPlaying = appState.isRunning
        }
        .onChange(of: appState.isRunning) { newValue in
            isPlaying = newValue
        }
    }

    @State private var isHovered = false
    @State private var isPlaying = false

    private var topControls: some View {
        HStack(spacing: 9) {
            Button {
                isPlaying.toggle()
                appState.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .help(isPlaying ? "Pause" : "Play")

            StatusDot(level: appState.statusLevel)

            Text(TranslationLanguage.name(for: appState.settings.targetLanguageCode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .frame(maxWidth: 100, alignment: .leading)

            if appState.isRunning {
                WaveSoundBar(level: appState.audioLevel)
                    .transition(.opacity)
            }

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
