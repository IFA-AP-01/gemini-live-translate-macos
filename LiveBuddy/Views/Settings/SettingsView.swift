import SwiftUI

enum NavigationItem: Hashable {
    case provider
    case caption
    case transcripts
    case logs
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedItem: NavigationItem? = .caption
    @State private var selectedTranscript: TranscriptSession?
    @State private var isCheckingToken = false
    @State private var isTokenValid: Bool? = nil
    @State private var tokenCheckError: String? = nil

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                HStack(spacing: 8) {
                    Image(systemName: "captions.bubble.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LiveBuddy")
                            .font(.headline)
                        HStack(spacing: 5) {
                            StatusDot(level: appState.statusLevel)
                            Text(appState.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                
                Section("Settings") {
                    NavigationLink(value: NavigationItem.caption) {
                        Label("Caption", systemImage: "captions.bubble")
                    }
                    NavigationLink(value: NavigationItem.provider) {
                        Label("API Provider", systemImage: "network")
                    }
                }
                
                Section("History & Data") {
                    NavigationLink(value: NavigationItem.transcripts) {
                        Label("Transcripts", systemImage: "text.bubble")
                    }
                    
                    NavigationLink(value: NavigationItem.logs) {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch selectedItem {
                case .provider, .none:
                    providerForm
                case .caption:
                    captionForm
                case .transcripts:
                    TranscriptsView(selectedSession: $selectedTranscript)
                case .logs:
                    logsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                if selectedItem == .transcripts && selectedTranscript != nil {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTranscript = nil
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .help("Back to transcripts list")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appState.toggle()
                    } label: {
                        Label(appState.isRunning ? "Stop" : "Start", systemImage: appState.isRunning ? "stop.fill" : "play.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(appState.settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 16)
                }
            }
        }
        .sheet(isPresented: $appState.showSetupSheet) {
            ProviderSetupSheet()
        }
    }

    private var providerForm: some View {
        Form {
            Section("Active Provider") {
                Picker("Provider", selection: appState.binding(\.activeProvider)) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.menu)
            }
            
            if appState.settings.activeProvider == .gemini {
                Section("Google Gemini") {
                    HStack(spacing: 8) {
                        SecureField("API key", text: appState.binding(\.apiKey))
                        
                        if isCheckingToken {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 16, height: 16)
                        } else if let isValid = isTokenValid {
                            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(isValid ? .green : .red)
                                .imageScale(.medium)
                                .help(tokenCheckError ?? (isValid ? "Token is valid" : "Verification failed"))
                        }
                        
                        Button("Check") {
                            Task {
                                isCheckingToken = true
                                isTokenValid = nil
                                tokenCheckError = nil
                                do {
                                    try await appState.verifyGeminiToken()
                                    isTokenValid = true
                                } catch {
                                    isTokenValid = false
                                    tokenCheckError = error.localizedDescription
                                }
                                isCheckingToken = false
                            }
                        }
                        .disabled(appState.settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCheckingToken)
                    }
                    
                    if let error = tokenCheckError, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Section("Translation Prompt") {
                TextEditor(text: appState.binding(\.userPrompt))
                    .font(.body)
                    .frame(minHeight: 92)
            }
        }
        .formStyle(.grouped)
        .onChange(of: appState.settings.apiKey) { _, _ in
            isTokenValid = nil
            tokenCheckError = nil
        }
    }

    private var captionForm: some View {
        Form {
            Section("Translation & Audio") {
                Picker("Audio Source", selection: appState.binding(\.audioSource)) {
                    ForEach(AudioSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                if appState.settings.audioSource == .microphone || appState.settings.audioSource == .both {
                    Picker("Microphone", selection: appState.binding(\.selectedMicrophoneDeviceUID)) {
                        Text("System Default").tag(nil as String?)
                        ForEach(appState.availableMicrophones) { device in
                            Text(device.name).tag(device.uid as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        appState.refreshAvailableMicrophones()
                    }
                }
                
                Picker("Translate to", selection: appState.binding(\.targetLanguageCode)) {
                    ForEach(TranslationLanguage.all) { language in
                        Text("\(language.name) (\(language.id))").tag(language.id)
                    }
                }
                Toggle("Echo target language", isOn: appState.binding(\.echoTargetLanguage))
                
                HStack {
                    Text("Translation volume")
                    Spacer()
                    Button {
                        appState.updateSetting(\.audioPlayerMuted, to: !appState.settings.audioPlayerMuted)
                    } label: {
                        Image(systemName: appState.settings.audioPlayerMuted || appState.settings.audioPlayerVolume == 0 ? "speaker.slash.fill" : (appState.settings.audioPlayerVolume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"))
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                    
                    Slider(value: appState.binding(\.audioPlayerVolume), in: 0...1)
                        .disabled(appState.settings.audioPlayerMuted)
                        .frame(width: 100)
                    
                    Text("\(Int(appState.settings.audioPlayerVolume * 100))%")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }

            Section("Caption Window") {
                HStack {
                    Text("Black transparency")
                    Slider(value: appState.binding(\.backgroundOpacity), in: 0.15...0.95)
                    Text("\(Int(appState.settings.backgroundOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }

            Section("Subtitle Style") {
                HStack {
                    Text("Font size")
                    Slider(value: appState.binding(\.subtitleFontSize), in: 14...60, step: 1)
                    Text("\(Int(appState.settings.subtitleFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
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
                    .help("Bold")

                    Toggle(isOn: appState.binding(\.subtitleIsItalic)) {
                        Text("I").font(.system(size: 14, weight: .regular).italic())
                    }
                    .toggleStyle(.button)
                    .help("Italic")

                    Toggle(isOn: appState.binding(\.subtitleIsUnderline)) {
                        Text("U").font(.system(size: 14, weight: .regular)).underline()
                    }
                    .toggleStyle(.button)
                    .help("Underline")
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
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: appState.settings.subtitleColor == preset.color ? 2 : 0)
                                        .frame(width: 24, height: 24)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                    }
                }

                Text("Preview text")
                    .font(.system(size: CGFloat(appState.settings.subtitleFontSize)))
                    .bold(appState.settings.subtitleIsBold)
                    .italic(appState.settings.subtitleIsItalic)
                    .underline(appState.settings.subtitleIsUnderline)
                    .foregroundStyle(appState.settings.subtitleColor.swiftUIColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.6))
                    )
            }
        }
        .formStyle(.grouped)
    }

    private var logsView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Runtime Logs")
                    .font(.headline)
                Spacer()
                Button {
                    appState.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.logs) { entry in
                            LogRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
                .onChange(of: appState.logs.last?.id) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }
}

struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(entry.level == .error ? Color.red : Color.secondary.opacity(0.55))
                .frame(width: 7, height: 7)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.timestamp, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(entry.message)
                    .font(.callout)
                    .textSelection(.enabled)
                    .foregroundStyle(entry.level == .error ? .red : .primary)
            }
        }
    }
}

struct ProviderSetupSheet: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "captions.bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            
            Text("Welcome to LiveBuddy")
                .font(.title2)
                .bold()
            
            Text("Please configure your AI Provider to start using LiveBuddy for real-time translation.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Form {
                Picker("Provider", selection: appState.binding(\.activeProvider)) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                
                SecureField("API Key", text: appState.binding(\.apiKey))
            }
            .formStyle(.grouped)
            .frame(height: 120)
            
            HStack {
                Button("Cancel") {
                    appState.showSetupSheet = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Get Started") {
                    appState.showSetupSheet = false
                    if appState.isProviderConfigured {
                        NotificationCenter.default.post(name: .showCaptionWindow, object: nil)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!appState.isProviderConfigured)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 10)
        }
        .padding(30)
        .frame(width: 450)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
