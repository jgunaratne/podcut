import Speech
import SwiftUI

/// First-launch onboarding with value prop and permission requests.
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        (
            "waveform.badge.magnifyingglass",
            "Discover & Listen",
            "Search millions of podcasts and stream episodes instantly with background playback.",
            .blue
        ),
        (
            "text.badge.checkmark",
            "Transcribe Anything",
            "Convert full episodes to text on-device — no cloud, no waiting. Tap any timecode to jump right to that moment.",
            .indigo
        ),
        (
            "sparkles",
            "AI Summaries & Chat",
            "Get timestamped summaries powered by Gemini AI. Ask questions about any episode and get instant answers.",
            .purple
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    onboardingPage(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Bottom section.
            VStack(spacing: 16) {
                // Page dots.
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.indigo : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                // Action button.
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        requestPermissionsAndFinish()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 32)

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        requestPermissionsAndFinish()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.indigo.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Page View

    private func onboardingPage(page: (icon: String, title: String, subtitle: String, color: Color)) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(page.color.opacity(0.05))
                    .frame(width: 180, height: 180)

                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(page.color.gradient)
                    .symbolEffect(.variableColor.iterative.reversing)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Permissions

    private func requestPermissionsAndFinish() {
        Task {
            // Request speech recognition permission (needed for transcription).
            let status = SFSpeechRecognizer.authorizationStatus()
            if status == .notDetermined {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    SFSpeechRecognizer.requestAuthorization { _ in
                        continuation.resume()
                    }
                }
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
            }
        }
    }
}
