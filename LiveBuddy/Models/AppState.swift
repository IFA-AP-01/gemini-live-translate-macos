import Foundation
import Combine
import SwiftUI
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var settings: AppSettings {
        didSet {
            saveSettings()
            rebuildRunningSessionIfNeeded(oldValue: oldValue)
        }
    }
    @Published private(set) var captions: [CaptionLine] = []
    @Published private(set) var captionDraft = ""
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var statusLevel: LiveStatusLevel = .stopped
    @Published private(set) var logs: [LogEntry] = []
    @Published private(set) var transcriptSessions: [TranscriptSession] = []

    private let settingsURL: URL
    private let transcriptsURL: URL
    private var client: GeminiLiveTranslateClient?
    private var microphoneCapture: MicrophoneCapture?
    private var screenCapture: ScreenAudioCapture?
    private let audioPlayer = PCM16AudioPlayer()
    private var restartTask: Task<Void, Never>?
    private var currentSessionID: UUID?
    private var micChunkCount = 0
    private var screenChunkCount = 0
    private var sentChunkCount = 0
    private var lastAudioStatusAt = Date.distantPast

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LiveBuddy", isDirectory: true)
        settingsURL = support.appendingPathComponent("settings.json")
        transcriptsURL = support.appendingPathComponent("transcripts.json")
        if let data = try? Data(contentsOf: settingsURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
        loadTranscriptSessions()
        appendLog("App ready", level: .info)
    }

    func start() async {
        NotificationCenter.default.post(name: .showCaptionWindow, object: nil)
        guard !isRunning else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            updateStatus("Add Gemini API key in Settings", level: .error, log: true)
            return
        }

        captions.removeAll()
        captionDraft = ""
        resetAudioCounters()
        beginTranscriptSession()
        updateStatus("Connecting", level: .connecting, log: true)

        let client = GeminiLiveTranslateClient(settings: settings)
        client.onInputTranscript = { [weak self] text, language in
            Task { @MainActor [weak self] in
                self?.appendLog("Input\(language.map { " [\($0)]" } ?? ""): \(text)", level: .info)
            }
        }
        client.onOutputTranscript = { [weak self] text, language in
            Task { @MainActor [weak self] in
                self?.appendCaption(text, language: language, kind: .output)
            }
        }
        client.onAudioChunk = { [weak self] data in
            self?.audioPlayer.playPCM16(data, sampleRate: 24_000)
        }
        client.onStatus = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleClientStatus(message)
            }
        }

        do {
            try await client.connect()
            self.client = client
            try await startCapture()
            isRunning = true
            updateStatus("Listening", level: .running, log: true)
        } catch {
            await stop()
            updateStatus(error.localizedDescription, level: .error, log: true)
        }
    }

    func stop() async {
        restartTask?.cancel()
        restartTask = nil
        microphoneCapture?.stop()
        microphoneCapture = nil
        await screenCapture?.stop()
        screenCapture = nil
        client?.close()
        client = nil
        audioPlayer.stop()
        finishTranscriptSession()
        isRunning = false
        updateStatus("Stopped", level: .stopped, log: true)
    }

    func toggle() {
        Task {
            isRunning ? await stop() : await start()
        }
    }

    func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { [weak self] value in
                DispatchQueue.main.async {
                    self?.updateSetting(keyPath, to: value)
                }
            }
        )
    }

    func updateSetting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>, to value: Value) {
        settings[keyPath: keyPath] = value
    }

    func clearLogs() {
        logs.removeAll()
        appendLog("Logs cleared", level: .info)
    }

    func saveSubtitleScreenFrame(_ frame: NSRect) {
        let saved = SubtitleScreenFrame(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.size.width,
            height: frame.size.height
        )
        guard settings.subtitleScreenFrame != saved else { return }
        settings.subtitleScreenFrame = saved
    }

    func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.title == "Settings" {
            window.makeKeyAndOrderFront(nil)
            return
        }
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func startCapture() async throws {
        if settings.audioSource == .microphone || settings.audioSource == .both {
            let mic = MicrophoneCapture(onAudioChunk: audioSink(source: .microphone))
            try await mic.start()
            microphoneCapture = mic
            updateStatus("Microphone capture started", level: .connecting, log: true)
        }

        if settings.audioSource == .screen || settings.audioSource == .both {
            let screen = ScreenAudioCapture(
                onAudioChunk: audioSink(source: .screen),
                onStatus: { [weak self] message in
                    Task { @MainActor [weak self] in
                        self?.updateStatus(message, level: .error, log: true)
                    }
                }
            )
            try await screen.start()
            screenCapture = screen
            updateStatus("Screen audio capture started", level: .connecting, log: true)
        }
    }

    private func audioSink(source: AudioSource) -> @Sendable (Data) -> Void {
        { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recordAudioChunk(source: source)
                let client = self.client
                Task {
                    await client?.sendAudio(data)
                }
            }
        }
    }

    private func recordAudioChunk(source: AudioSource) {
        switch source {
        case .microphone:
            micChunkCount += 1
        case .screen:
            screenChunkCount += 1
        case .both:
            break
        }
        sentChunkCount += 1

        let now = Date()
        guard now.timeIntervalSince(lastAudioStatusAt) >= 1 else { return }
        lastAudioStatusAt = now
        statusMessage = "Listening · mic \(micChunkCount) · screen \(screenChunkCount) · sent \(sentChunkCount)"
        statusLevel = .running
    }

    private func resetAudioCounters() {
        micChunkCount = 0
        screenChunkCount = 0
        sentChunkCount = 0
        lastAudioStatusAt = .distantPast
    }

    private func appendCaption(_ text: String, language: String?, kind: CaptionKind) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var pending = captionDraft + (captionDraft.isEmpty ? "" : " ") + trimmed
        let sentences = completedSentences(from: pending)
        for sentence in sentences.completed {
            captions.append(CaptionLine(text: sentence, languageCode: language, kind: kind))
        }
        pending = sentences.remainder
        captionDraft = pending
        if captions.count > 80 {
            captions.removeFirst(captions.count - 80)
        }
    }

    var subtitleText: String {
        let committed = captions
            .filter { $0.kind == .output }
            .map(\.text)
        if captionDraft.isEmpty {
            return committed.joined(separator: "\n")
        }
        return (committed + [captionDraft]).joined(separator: "\n")
    }

    private func completedSentences(from text: String) -> (completed: [String], remainder: String) {
        let terminators = CharacterSet(charactersIn: ".?!。？！")
        var completed: [String] = []
        var start = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let scalar = text[index].unicodeScalars.first
            if let scalar, terminators.contains(scalar) {
                var end = text.index(after: index)
                
                while end < text.endIndex,
                    let nextScalar = text[end].unicodeScalars.first,
                    terminators.contains(nextScalar) {
                    end = text.index(after: end)
                }
                
                var isEndOfSentence = false
                if end == text.endIndex {
                    isEndOfSentence = true
                } else if let nextScalar = text[end].unicodeScalars.first,
                        CharacterSet.whitespacesAndNewlines.contains(nextScalar) {
                    isEndOfSentence = true
                }
                
                if isEndOfSentence {
                    let sentence = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sentence.isEmpty {
                        completed.append(sentence)
                    }
                    start = end
                }
                index = end
            } else {
                index = text.index(after: index)
            }
        }

        let remainder = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (completed, remainder)
    }

    private func saveSettings() {
        do {
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: [.atomic])
        } catch {
            updateStatus("Cannot save settings", level: .error, log: true)
        }
    }

    private func rebuildRunningSessionIfNeeded(oldValue: AppSettings) {
        guard isRunning, settings.requiresSessionRestart(comparedTo: oldValue) else { return }
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            await self?.stop()
            await self?.start()
        }
    }

    private func handleClientStatus(_ message: String) {
        let lowered = message.lowercased()
        if lowered.contains("error") || lowered.contains("failed") || lowered.contains("closed") || lowered.contains("disconnected") {
            updateStatus(message, level: .error, log: true)
        } else if lowered.contains("ready") || lowered.contains("listening") || lowered.contains("receiving") {
            updateStatus(message, level: .running, log: false)
        } else {
            updateStatus(message, level: isRunning ? .running : .connecting, log: false)
        }
    }

    private func updateStatus(_ message: String, level: LiveStatusLevel, log: Bool) {
        statusMessage = message
        statusLevel = level
        if log {
            appendLog(message, level: level == .error ? .error : .info)
        }
    }

    private func appendLog(_ message: String, level: LogLevel) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        logs.append(LogEntry(message: trimmed, level: level))
        if logs.count > 400 {
            logs.removeFirst(logs.count - 400)
        }
    }

    // MARK: - Transcript Sessions

    private func beginTranscriptSession() {
        let session = TranscriptSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            targetLanguage: TranslationLanguage.name(for: settings.targetLanguageCode),
            audioSource: settings.audioSource.title,
            lines: []
        )
        currentSessionID = session.id
        transcriptSessions.insert(session, at: 0)
    }

    private func finishTranscriptSession() {
        guard let sessionID = currentSessionID,
              let index = transcriptSessions.firstIndex(where: { $0.id == sessionID }) else { return }

        let outputLines = captions
            .filter { $0.kind == .output }
            .map { TranscriptLine(id: $0.id, text: $0.text, languageCode: $0.languageCode, timestamp: $0.timestamp) }

        var session = transcriptSessions[index]
        session.lines = outputLines
        session.endedAt = Date()
        transcriptSessions[index] = session
        currentSessionID = nil
        saveTranscriptSessions()
    }

    func deleteTranscriptSession(_ session: TranscriptSession) {
        transcriptSessions.removeAll { $0.id == session.id }
        saveTranscriptSessions()
    }

    func deleteAllTranscriptSessions() {
        transcriptSessions.removeAll()
        saveTranscriptSessions()
    }

    private func saveTranscriptSessions() {
        do {
            try FileManager.default.createDirectory(at: transcriptsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(transcriptSessions)
            try data.write(to: transcriptsURL, options: [.atomic])
        } catch {
            appendLog("Cannot save transcripts: \(error.localizedDescription)", level: .error)
        }
    }

    private func loadTranscriptSessions() {
        guard let data = try? Data(contentsOf: transcriptsURL),
              let decoded = try? JSONDecoder().decode([TranscriptSession].self, from: data) else { return }
        transcriptSessions = decoded
    }
}

enum LiveStatusLevel {
    case stopped
    case connecting
    case running
    case error
}

enum LogLevel {
    case info
    case error
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp = Date()
    let message: String
    let level: LogLevel
}

enum CaptionKind {
    case input
    case output
}

struct CaptionLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let languageCode: String?
    let kind: CaptionKind
    let timestamp = Date()
}
