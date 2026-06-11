import SwiftUI

struct TranscriptsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedSession: TranscriptSession?
    @State private var searchText = ""

    private var filteredSessions: [TranscriptSession] {
        if searchText.isEmpty {
            return appState.transcriptSessions
        }
        return appState.transcriptSessions.filter {
            $0.fullText.localizedCaseInsensitiveContains(searchText)
            || $0.targetLanguage.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        if let session = selectedSession {
            detailContent(session)
        } else {
            listView
        }
    }

    // MARK: - List View

    private var listView: some View {
        VStack(spacing: 0) {
            listHeader
            Divider()

            if appState.transcriptSessions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    searchBar
                    sessionList
                }
            }
        }
    }

    private var listHeader: some View {
        HStack {
            Text("Transcripts")
                .font(.headline)
            Spacer()
            if !appState.transcriptSessions.isEmpty {
                Button(role: .destructive) {
                    appState.deleteAllTranscriptSessions()
                    selectedSession = nil
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField("Search transcripts…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(filteredSessions) { session in
                    SessionCard(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSession = session
                            }
                        }
                        .contextMenu {
                            Button("Copy Transcript") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(session.fullText, forType: .string)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                appState.deleteTranscriptSession(session)
                                if selectedSession?.id == session.id {
                                    selectedSession = nil
                                }
                            }
                        }
                }

                if filteredSessions.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundStyle(.quaternary)
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No transcripts yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start a session to begin capturing transcripts")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }




    private func detailContent(_ session: TranscriptSession) -> some View {
        VStack(spacing: 0) {
            // Session metadata
            VStack(spacing: 8) {
                HStack {
                    Label(session.displayTitle, systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Label(session.formattedDuration, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label(session.targetLanguage, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(session.audioSource, systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(session.lines.count) lines · \(session.wordCount) words")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Transcript lines
            if session.lines.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No transcript lines captured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if session.endedAt == nil {
                        Text("Session is still in progress")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(session.lines) { line in
                            TranscriptLineRow(line: line)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
            }
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: TranscriptSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.displayTitle)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(session.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !session.lines.isEmpty {
                Text(session.lines.prefix(2).map(\.text).joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Label(session.targetLanguage, systemImage: "globe")
                Label(session.audioSource, systemImage: "waveform")
                Spacer()
                Text("\(session.lines.count) lines")

                if session.endedAt == nil {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Transcript Line Row

struct TranscriptLineRow: View {
    let line: TranscriptLine

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(line.timestamp, style: .time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .leading)

            Text(line.text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}
