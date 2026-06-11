import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            TabView {
                settingsForm
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }

                logsView
                    .tabItem {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }
            }
            .padding(.top, 8)

            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var settingsForm: some View {
        Form {
            Section("Gemini") {
                SecureField("API key", text: appState.binding(\.apiKey))
                Picker("Translate to", selection: appState.binding(\.targetLanguageCode)) {
                    ForEach(TranslationLanguage.all) { language in
                        Text("\(language.name) (\(language.id))").tag(language.id)
                    }
                }
                Toggle("Echo target language", isOn: appState.binding(\.echoTargetLanguage))
                TextEditor(text: appState.binding(\.userPrompt))
                    .font(.body)
                    .frame(minHeight: 92)
            }

            Section("Audio") {
                Picker("Source", selection: appState.binding(\.audioSource)) {
                    ForEach(AudioSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)
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

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "captions.bubble.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("LiveBuddy")
                    .font(.title2.weight(.semibold))
                HStack(spacing: 7) {
                    StatusDot(level: appState.statusLevel)
                    Text(appState.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                appState.toggle()
            } label: {
                Label(appState.isRunning ? "Stop" : "Start", systemImage: appState.isRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
    }

    private var footer: some View {
        HStack {
            Text("Model: gemini-3.5-live-translate-preview")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(appState.settings.audioSource.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
