import Foundation

final class GeminiLiveTranslateClient: NSObject, URLSessionWebSocketDelegate {
    var onInputTranscript: (@Sendable (String, String?) -> Void)?
    var onOutputTranscript: (@Sendable (String, String?) -> Void)?
    var onAudioChunk: (@Sendable (Data) -> Void)?
    var onStatus: (@Sendable (String) -> Void)?

    private let settings: AppSettings
    private var webSocket: URLSessionWebSocketTask?
    private var openContinuation: CheckedContinuation<Void, Error>?
    private var isOpen = false
    private var receivedAudioChunks = 0
    private var lastReceiveStatusAt = Date.distantPast
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)

    init(settings: AppSettings) {
        self.settings = settings
    }

    func connect() async throws {
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(escapedKey)") else {
            throw LiveTranslateError.invalidAPIKey
        }

        let task = session.webSocketTask(with: url)
        webSocket = task
        try await waitForSocketOpen(task)
        try await sendSetup()
        try await waitForSetupComplete()
        receiveLoop()
    }

    func sendAudio(_ data: Data) async {
        guard !data.isEmpty else { return }
        let message: [String: Any] = [
            "realtimeInput": [
                "audio": [
                    "data": data.base64EncodedString(),
                    "mimeType": "audio/pcm;rate=16000"
                ]
            ]
        ]
        do {
            try await sendJSON(message)
        } catch {
            onStatus?("Send failed: \(error.localizedDescription)")
        }
    }

    func close() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session.invalidateAndCancel()
    }

    private func sendSetup() async throws {
        let instruction = settings.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        var setup: [String: Any] = [
            "model": "models/gemini-3.5-live-translate-preview",
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "translationConfig": [
                    "targetLanguageCode": settings.targetLanguageCode,
                    "echoTargetLanguage": settings.echoTargetLanguage
                ]
            ],
            "inputAudioTranscription": [:],
            "outputAudioTranscription": [:],
            "contextWindowCompression": [
                "triggerTokens": "0",
                "slidingWindow": ["targetTokens": "0"]
            ]
        ]
        if !instruction.isEmpty {
            setup["systemInstruction"] = ["parts": [["text": instruction]]]
        }
        try await sendJSON(["setup": setup])
    }

    private func waitForSocketOpen(_ task: URLSessionWebSocketTask) async throws {
        if isOpen { return }
        try await withCheckedThrowingContinuation { continuation in
            openContinuation = continuation
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isOpen = true
        onStatus?("Gemini socket opened")
        openContinuation?.resume()
        openContinuation = nil
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        isOpen = false
        let reasonText = reason.flatMap { String(data: $0, encoding: .utf8) }
        let message = [String(describing: closeCode), reasonText]
            .compactMap { $0 }
            .joined(separator: ": ")
        openContinuation?.resume(throwing: LiveTranslateError.socketClosed(message))
        openContinuation = nil
        onStatus?("Gemini socket closed: \(message)")
    }

    private func sendJSON(_ object: [String: Any]) async throws {
        guard let webSocket, isOpen else { throw LiveTranslateError.notConnected }
        let data = try JSONSerialization.data(withJSONObject: object)
        let text = String(decoding: data, as: UTF8.self)
        try await webSocket.send(.string(text))
    }

    private func waitForSetupComplete() async throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let message = try await receiveMessage()
            let root = try decodedObject(from: message)
            if let error = root["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LiveTranslateError.server(message)
            }
            if root["setupComplete"] != nil {
                onStatus?("Gemini session ready")
                return
            }
            handle(root)
        }
        throw LiveTranslateError.setupTimedOut
    }

    private func receiveMessage() async throws -> URLSessionWebSocketTask.Message {
        guard let webSocket else { throw LiveTranslateError.notConnected }
        return try await withCheckedThrowingContinuation { continuation in
            webSocket.receive { result in
                continuation.resume(with: result)
            }
        }
    }

    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                do {
                    let root = try self.decodedObject(from: message)
                    self.handle(root)
                } catch {
                    self.onStatus?("Gemini parse failed: \(error.localizedDescription)")
                }
                self.receiveLoop()
            case .failure(let error):
                self.onStatus?("Gemini disconnected: \(error.localizedDescription)")
            }
        }
    }

    private func decodedObject(from message: URLSessionWebSocketTask.Message) throws -> [String: Any] {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let payload):
            data = payload
        @unknown default:
            throw LiveTranslateError.unsupportedMessage
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LiveTranslateError.invalidMessage
        }
        return root
    }

    private func handle(_ root: [String: Any]) {
        if let error = root["error"] as? [String: Any],
           let message = error["message"] as? String {
            onStatus?("Gemini error: \(message)")
            return
        }
        guard let content = root["serverContent"] as? [String: Any] else { return }

        if let input = content["inputTranscription"] as? [String: Any],
           let text = input["text"] as? String {
            onInputTranscript?(text, input["languageCode"] as? String)
        }

        if let output = content["outputTranscription"] as? [String: Any],
           let text = output["text"] as? String {
            onOutputTranscript?(text, output["languageCode"] as? String)
        }

        if let modelTurn = content["modelTurn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]] {
            for part in parts {
                if let inline = part["inlineData"] as? [String: Any],
                   let encoded = inline["data"] as? String,
                   let audio = Data(base64Encoded: encoded) {
                    receivedAudioChunks += 1
                    reportReceiveStatusIfNeeded()
                    onAudioChunk?(audio)
                }
                if let text = part["text"] as? String {
                    onOutputTranscript?(text, nil)
                }
            }
        }
    }

    private func reportReceiveStatusIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastReceiveStatusAt) >= 1 else { return }
        lastReceiveStatusAt = now
        onStatus?("Receiving translated audio: \(receivedAudioChunks) chunks")
    }
}

enum LiveTranslateError: LocalizedError {
    case invalidAPIKey
    case notConnected
    case setupTimedOut
    case server(String)
    case invalidMessage
    case unsupportedMessage
    case socketClosed(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "Invalid Gemini API key"
        case .notConnected: "Gemini Live session is not connected"
        case .setupTimedOut: "Gemini Live setup timed out"
        case .server(let message): "Gemini error: \(message)"
        case .invalidMessage: "Gemini returned an invalid message"
        case .unsupportedMessage: "Gemini returned an unsupported WebSocket message"
        case .socketClosed(let message): "Gemini socket closed: \(message)"
        }
    }
}
