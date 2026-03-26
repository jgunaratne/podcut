# Podcut

**AI-powered podcast player for iOS.** Transcribe, summarize, and chat with any podcast episode.

## Features

- 🔍 **Discover** — Search millions of podcasts via iTunes, browse by category
- 🎧 **Listen** — Stream episodes with background playback, lock screen controls, and playback speed (0.5x–2x)
- 📝 **Transcribe** — On-device transcription with timestamped segments — tap any timecode to jump
- ✨ **AI Summaries** — Timestamped summaries powered by Gemini 2.5 Flash Lite
- 💬 **Chat** — Ask questions about any episode, get answers grounded in the transcript
- ⭐ **Favorites** — Save podcasts for quick access (list or grid view)
- 🔒 **Privacy-first** — Transcription happens on-device. No audio leaves your phone.

## Tech Stack

- **SwiftUI** (iOS 26)
- **SwiftData** for persistence
- **Firebase AI / Gemini** for summaries and chat
- **Apple Speech** for on-device transcription
- **StoreKit 2** for subscriptions
- **AVFoundation** + **MediaPlayer** for audio playback

## Requirements

- iOS 26.0+
- Xcode 26+
- Firebase project with Gemini AI enabled

## Setup

1. Clone the repo
2. Add your `GoogleService-Info.plist` to the `Podcut/` directory
3. Open `Podcut.xcodeproj` in Xcode
4. Build and run

## Subscription

Podcut Pro ($2.99/mo) unlocks:
- AI-powered episode summaries
- Chat with episodes
- Regenerate summaries anytime

Free users get full search, playback, and transcription.

## License

MIT
