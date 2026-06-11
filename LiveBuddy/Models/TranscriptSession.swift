import Foundation

struct TranscriptSession: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    let targetLanguage: String
    let audioSource: String
    var lines: [TranscriptLine]

    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startedAt)
    }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        guard let duration else { return "In progress…" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var fullText: String {
        lines.map(\.text).joined(separator: "\n")
    }

    var wordCount: Int {
        lines.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }
}

struct TranscriptLine: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let languageCode: String?
    let timestamp: Date

    init(id: UUID = UUID(), text: String, languageCode: String?, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.languageCode = languageCode
        self.timestamp = timestamp
    }
}
