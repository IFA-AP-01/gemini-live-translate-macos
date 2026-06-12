# Live Translate Buddy 

LiveBuddy is a modern, native macOS application designed to provide real-time audio translation and captioning. It captures system/app audio (using macOS's native **ScreenCaptureKit**) and/or microphone input, streams the downsampled audio to the **Google Gemini Live API** over a bidirectional WebSocket, and displays live subtitles in a floating HUD overlay. It also plays back the translated speech returned by the Gemini model in real time.


https://github.com/user-attachments/assets/a5f94b11-80bf-4043-bbfc-63426b781863


---

## Key Features

*   **Real-time Speech-to-Speech & Speech-to-Text Translation**: Leverages Google Gemini's live translation capability (`models/gemini-3.5-live-translate-preview`) via low-latency bidirectional WebSockets.
*   **Dual-Source Audio Capture**:
    *   **Screen Audio**: Captures system/app output audio directly.
    *   **Microphone**: Captures local voice input.
    *   **Combined Source**: Captures and translates both inputs simultaneously.
*   **HUD Caption Window**:
    *   Borderless, floating, transparent overlay window that stays on top of other applications.
    *   Auto-hiding interactive settings bar (triggered on hover) to easily pause/play, mute/unmute, adjust volumes, or change transparency.
    *   Position and window size are automatically saved and restored.
    *   Smooth animated text scrolling to match speech timing.
*   **Highly Customizable Styles**: Fully customize the caption aesthetics from the Settings window:
    *   *Font Family*: Select between Avenir, Georgia, Helvetica Neue, Menlo, Futura, and more.
    *   *Font Size*: Adjustable slider from 14pt to 60pt.
    *   *Weight/Style*: Underline, Bold, and Italic modifiers.
    *   *Colors*: Preset options including White, Yellow, Cyan, Green, Orange, and Pink.
*   **Transcript History & Management**:
    *   Browse previously recorded sessions.
    *   Detailed statistics: Duration, line count, word count, audio source, and translation language.
    *   Search transcript contents or copy full transcripts/individual lines directly to the clipboard.
*   **Diagnostics & Runtime Logs**: Embedded log view monitoring connection status, audio capture format detection, and WebSocket status in real time.

---

## Architecture & Audio Pipeline

LiveBuddy uses a modular architecture combining modern macOS system APIs and WebSockets:

```
                  ┌────────────────────────┐
                  │   ScreenCaptureKit     │ (System Audio)
                  └───────────┬────────────┘
                              │ Float32 / Int16 (Multi-channel)
                              ▼
┌─────────────────┐     ┌───────────┐     ┌────────────────┐     ┌─────────────────────┐
│  AVAudioEngine  ├────►│Chunky mono├────►│ PCM16          ├────►│   Gemini Live API   │
└─────────────────┘     │downsampler│     │16kHz PCM chunk │     │ (Bidi WebSocket)    │
(Microphone Audio)      └───────────┘     └────────────────┘     └──────────┬──────────┘
                                                                            │
                                                                            │ Translated Audio / Subtitles
                                                                            ▼
┌─────────────────┐     ┌───────────┐     ┌────────────────┐     ┌─────────────────────┐
│ Floating Subtitle│◄────┤  App State├◄────┤  AVAudioPlayer ├◄────┤   UI Updates &      │
│     Overlay     │     │Controller │     │  Playback Node │     │   JSON Parsing      │
└─────────────────┘     └───────────┘     └────────────────┘     └─────────────────────┘
```

### 1. Audio Capture & Processing (`Services/` & `Utilities/`)
*   **`MicrophoneCapture`**: Uses `AVAudioEngine` to tap the microphone, requesting permission at runtime.
*   **`ScreenAudioCapture`**: Interfaces with `ScreenCaptureKit` (`SCStream`) to capture system audio while excluding LiveBuddy's own output to prevent loopback/feedback.
*   **`PCM16Downsampler`**: Converts captured audio (typically multi-channel Float32 at 44.1kHz/48kHz) down to the `audio/pcm;rate=16000` mono format required by Gemini.
*   **`PCM16Chunker`**: Pools the downsampled PCM stream and pushes chunks to the WebSocket client in optimal sizes.

### 2. WebSocket Client (`Services/`)
*   **`GeminiLiveTranslateClient`**: Manages the bidirectional `URLSessionWebSocketTask` session communicating with `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent`.
*   Supports live system instructions, target language codes, and toggling target language audio echo.

### 3. Audio Playback (`Utilities/`)
*   **`PCM16AudioPlayer`**: Uses `AVAudioEngine` and `AVAudioPlayerNode` to schedule and play the translated incoming `Float32` PCM audio samples generated by Gemini.

---

## Prerequisites & Setup

### Requirements
*   **macOS 13.0+** (ScreenCaptureKit requires Ventura or later).
*   **Xcode 15.0+** to compile the Swift project.

### Setup Instructions

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/<your-username>/LiveBuddy.git
    cd LiveBuddy
    ```
2.  **Open in Xcode**:
    Open `LiveBuddy.xcodeproj` in Xcode.
3.  **Configure API Key**:
    *   Obtain a Gemini API key from [Google AI Studio](https://aistudio.google.com/).
    *   Launch LiveBuddy. On first launch, a setup sheet will prompt you to enter the **Google Gemini API Key**.
4.  **Permissions**:
    *   **Microphone Access**: When selecting the Microphone audio source, grant permissions when prompted.
    *   **Screen Recording / Audio Capture**: ScreenCaptureKit requires Screen Recording permission on macOS. Make sure to enable this in *System Settings > Privacy & Security > Screen Recording* for LiveBuddy.

---

## Configuration & Customization

The app provides deep customization parameters through **Settings**:

| Category | Option | Description |
| :--- | :--- | :--- |
| **API Provider** | API Key & System Prompt | Set up your credentials and custom instructions for translation behavior. |
| **Translation** | Translate To | Choose between dozens of target languages (e.g., Vietnamese, Spanish, French, Japanese). |
| **Translation** | Echo target language | Toggles voice playback of the translated translation output. |
| **Translation** | Translation volume | Control or mute the translation playback speaker output. |
| **Caption Overlay**| Background Opacity | Adjust HUD transparency slider from 15% to 95%. |
| **Subtitle Style** | Font Family | Standard and customized typefaces (Helvetica, Georgia, Avenir, Georgia, etc.). |
| **Subtitle Style** | Font Size & Modifiers| Font size (14–60pt), Bold, Italic, and Underline formatting. |
| **Subtitle Style** | Text Color | Presets for color choices (White, Yellow, Cyan, Green, etc.). |

---

##

 License

This project is licensed under the MIT License - see the LICENSE file for details.
