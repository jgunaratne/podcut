import SwiftUI
import SwiftData

/// App settings screen with cache management, playback defaults, and account info.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var audioCacheSize: String = "Calculating…"
    @State private var transcriptionCount: Int = 0
    @State private var defaultPlaybackRate: Float = 1.0
    @State private var showClearCacheAlert = false
    @State private var showClearTranscriptionsAlert = false
    @State private var showAbout = false

    private let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private var manager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Account
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(.indigo.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: manager.isPro ? "crown.fill" : "person.fill")
                                .foregroundStyle(.indigo)
                                .font(.title3)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.isPro ? "Podcut Pro" : "Podcut Free")
                                .font(.headline)
                            Text(manager.isPro ? "All features unlocked" : "Upgrade for AI summaries & chat")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if !manager.isPro {
                        Button {
                            showAbout = true
                        } label: {
                            Label("Upgrade to Pro", systemImage: "sparkles")
                                .foregroundStyle(.indigo)
                        }
                    }
                } header: {
                    Text("Account")
                }

                // MARK: - Playback
                Section {
                    Picker("Default Speed", selection: $defaultPlaybackRate) {
                        ForEach(availableRates, id: \.self) { rate in
                            Text(rateLabel(rate)).tag(rate)
                        }
                    }
                    .onChange(of: defaultPlaybackRate) {
                        UserDefaults.standard.set(defaultPlaybackRate, forKey: "defaultPlaybackRate")
                    }

                    HStack {
                        Label("Skip Forward", systemImage: "goforward.30")
                        Spacer()
                        Text("30s")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Skip Backward", systemImage: "gobackward.15")
                        Spacer()
                        Text("15s")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Playback")
                } footer: {
                    Text("Default speed applies to new episodes. You can change it per-episode in the player.")
                }

                // MARK: - Storage
                Section {
                    HStack {
                        Label("Audio Cache", systemImage: "speaker.wave.2")
                        Spacer()
                        Text(audioCacheSize)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Saved Transcriptions", systemImage: "doc.text")
                        Spacer()
                        Text("\(transcriptionCount)")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Label("Clear Audio Cache", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        showClearTranscriptionsAlert = true
                    } label: {
                        Label("Clear All Transcriptions", systemImage: "trash")
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Clearing the audio cache will require re-downloading episodes for playback and transcription.")
                }

                // MARK: - About
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://podcut.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://podcut.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.plaintext")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .alert("Clear Audio Cache?", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    AudioCache.shared.clearAll()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    calculateCacheSize()
                }
            } message: {
                Text("This will remove all downloaded episode audio. You can re-download them anytime.")
            }
            .alert("Clear All Transcriptions?", isPresented: $showClearTranscriptionsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearTranscriptions()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } message: {
                Text("This will permanently delete all saved transcriptions and summaries.")
            }
            .sheet(isPresented: $showAbout) {
                PaywallView()
            }
            .onAppear {
                loadDefaults()
                calculateCacheSize()
                countTranscriptions()
            }
        }
    }

    // MARK: - Helpers

    private func rateLabel(_ rate: Float) -> String {
        if rate == 1.0 { return "1× (Normal)" }
        if rate == 0.5 { return "0.5× (Slow)" }
        if rate == 0.75 { return "0.75×" }
        if rate == 1.25 { return "1.25×" }
        if rate == 1.5 { return "1.5× (Fast)" }
        if rate == 2.0 { return "2× (Fastest)" }
        return "\(rate)×"
    }

    private func loadDefaults() {
        let saved = UserDefaults.standard.float(forKey: "defaultPlaybackRate")
        defaultPlaybackRate = saved > 0 ? saved : 1.0
    }

    private func calculateCacheSize() {
        Task {
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PodcutAudio", isDirectory: true)

            guard let enumerator = FileManager.default.enumerator(
                at: cacheDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                audioCacheSize = "0 MB"
                return
            }

            var totalSize: Int64 = 0
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }

            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            audioCacheSize = formatter.string(fromByteCount: totalSize)
        }
    }

    private func countTranscriptions() {
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        transcriptionCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private func clearTranscriptions() {
        do {
            try modelContext.delete(model: TranscriptionRecord.self)
            try modelContext.save()
            transcriptionCount = 0
        } catch {
            print("Failed to clear transcriptions: \(error)")
        }
    }
}
