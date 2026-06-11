import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            appState.toggle()
        } label: {
            Label(appState.isRunning ? "Stop Live Translate" : "Start Live Translate",
                  systemImage: appState.isRunning ? "stop.fill" : "play.fill")
        }

        Divider()

        Picker("Language", selection: appState.binding(\.targetLanguageCode)) {
            ForEach(TranslationLanguage.all) { language in
                Text(language.name).tag(language.id)
            }
        }

        Picker("Audio Source", selection: appState.binding(\.audioSource)) {
            ForEach(AudioSource.allCases) { source in
                Text(source.title).tag(source)
            }
        }

        Divider()

        Button {
            NotificationCenter.default.post(name: .showCaptionWindow, object: nil)
        } label: {
            Label("Show Caption Window", systemImage: "captions.bubble")
        }

        Button {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Settings", systemImage: "gearshape")
        }

        Button {
            Task { await appState.stop() }
            NSApp.terminate(nil)
        } label: {
            Label("Quit", systemImage: "power")
        }
    }
}
