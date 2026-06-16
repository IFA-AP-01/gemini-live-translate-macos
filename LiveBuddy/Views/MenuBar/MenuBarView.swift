import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 12) {
                    Button {
                        appState.toggle()
                    } label: {
                        Image(systemName: appState.isRunning ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(appState.isRunning ? Color.red : Color.green)
                    .help(appState.isRunning ? "Stop Translation" : "Start Translation")
                    
                    Spacer()
                    
                    Button {
                        NotificationCenter.default.post(name: .showCaptionWindow, object: nil)
                    } label: {
                        Image(systemName: "captions.bubble")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Show Caption Window")
                    
                    Button {
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                    
                    Button {
                        Task { await appState.stop() }
                        NSApp.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Quit LiveBuddy")
                }
                
                Divider()
                
                // Audio Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Translation & Audio")
                        .font(.headline)
                        
                    Picker("Audio Source", selection: appState.binding(\.audioSource)) {
                        ForEach(AudioSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    
                    if appState.settings.audioSource == .microphone || appState.settings.audioSource == .both {
                        Picker("Microphone", selection: appState.binding(\.selectedMicrophoneDeviceUID)) {
                            Text("System Default").tag(nil as String?)
                            ForEach(appState.availableMicrophones) { device in
                                Text(device.name).tag(device.uid as String?)
                            }
                        }
                    }
                    
                    Picker("Translate to", selection: appState.binding(\.targetLanguageCode)) {
                        ForEach(TranslationLanguage.all) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                    
                    Toggle("Echo target language", isOn: appState.binding(\.echoTargetLanguage))
                }
                
                Divider()
                
                // Volume
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Captured audio playback volume")
                        Spacer()
                        Text("\(Int(appState.settings.audioPlayerVolume * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button {
                            appState.updateSetting(\.audioPlayerMuted, to: !appState.settings.audioPlayerMuted)
                        } label: {
                            Image(systemName: appState.settings.audioPlayerMuted || appState.settings.audioPlayerVolume == 0 ? "speaker.slash.fill" : (appState.settings.audioPlayerVolume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"))
                        }
                        .buttonStyle(.plain)
                        .help(appState.settings.audioPlayerMuted ? "Unmute Audio" : "Mute Audio")
                        
                        Slider(value: appState.binding(\.audioPlayerVolume), in: 0...1)
                            .disabled(appState.settings.audioPlayerMuted)
                    }
                }
                
                Divider()
                
                // Subtitle Styles
                VStack(alignment: .leading, spacing: 12) {
                    Text("Subtitle Style")
                        .font(.headline)
                        
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Subtitle font size")
                            Spacer()
                            Text("\(Int(appState.settings.subtitleFontSize))pt")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: appState.binding(\.subtitleFontSize), in: 14...60, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Black transparency")
                            Spacer()
                            Text("\(Int(appState.settings.backgroundOpacity * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: appState.binding(\.backgroundOpacity), in: 0.15...0.95)
                    }
                    
                    Picker("Font", selection: appState.binding(\.subtitleFontName)) {
                        ForEach(SubtitleFontName.allCases) { font in
                            Text(font.displayName).tag(font)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Text("Style")
                        Spacer()
                        Toggle(isOn: appState.binding(\.subtitleIsBold)) {
                            Text("B").font(.system(size: 14, weight: .bold))
                        }
                        .toggleStyle(.button)

                        Toggle(isOn: appState.binding(\.subtitleIsItalic)) {
                            Text("I").font(.system(size: 14, weight: .regular).italic())
                        }
                        .toggleStyle(.button)

                        Toggle(isOn: appState.binding(\.subtitleIsUnderline)) {
                            Text("U").font(.system(size: 14, weight: .regular)).underline()
                        }
                        .toggleStyle(.button)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Color")
                        Spacer()
                        ForEach(SubtitleColor.presets, id: \.name) { preset in
                            Button {
                                appState.updateSetting(\.subtitleColor, to: preset.color)
                            } label: {
                                Circle()
                                    .fill(preset.color.swiftUIColor)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: appState.settings.subtitleColor == preset.color ? 2 : 0)
                                            .frame(width: 20, height: 20)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(preset.name)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 350, height: 550)
        .tint(.white)
        .onAppear {
            appState.refreshAvailableMicrophones()
        }
    }
}
