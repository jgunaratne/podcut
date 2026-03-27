import SwiftUI

/// In-app privacy policy view (also hosted at podcut.app/privacy).
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle.bold())

                Text("Last updated: March 25, 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Group {
                    section(title: "Overview") {
                        "Podcut is designed with privacy in mind. We process your data locally on your device whenever possible."
                    }

                    section(title: "Data We Collect") {
                        """
                        • **Podcast searches** — Search queries are sent to Apple's iTunes Search API to find podcasts. We do not store your search history.
                        
                        • **Audio transcription** — Episode transcription happens entirely on your device using Apple's Speech framework. No audio is sent to external servers.
                        
                        • **AI summaries & chat** — When you generate a summary or chat about an episode, the transcription text is sent to Google's Gemini AI service for processing. This data is used solely to generate your summary and is not stored by us.
                        
                        • **Subscription data** — Subscription purchases are handled entirely by Apple through the App Store. We do not have access to your payment information.
                        """
                    }

                    section(title: "Data Stored on Your Device") {
                        """
                        • Saved transcriptions and summaries (SwiftData)
                        • Favorite podcasts (UserDefaults)
                        • Cached audio files (temporary storage)
                        • App preferences and settings
                        
                        All data is stored locally and can be deleted from Settings at any time.
                        """
                    }

                    section(title: "Third-Party Services") {
                        """
                        • **Apple iTunes Search API** — for podcast discovery
                        • **Google Gemini AI** — for episode summaries and chat (subject to Google's Privacy Policy)
                        • **Firebase** — for analytics and crash reporting
                        
                        We do not sell, rent, or share your personal data with third parties.
                        """
                    }

                    section(title: "Children's Privacy") {
                        "Podcut is not directed at children under 13. We do not knowingly collect personal information from children."
                    }

                    section(title: "Changes") {
                        "We may update this policy from time to time. Changes will be reflected in the app and on our website."
                    }

                    section(title: "Contact") {
                        "Questions? Reach us at support@podcut.app"
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(LocalizedStringKey(content()))
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }
}

/// In-app terms of service view.
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.largeTitle.bold())

                Text("Last updated: March 25, 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Group {
                    section(title: "Acceptance") {
                        "By using Podcut, you agree to these terms. If you do not agree, please do not use the app."
                    }

                    section(title: "Service Description") {
                        "Podcut is a podcast player with AI-powered transcription and summarization features. Free users can search, listen, and transcribe. Pro subscribers get access to AI summaries and chat."
                    }

                    section(title: "Subscriptions") {
                        """
                        • Podcut Pro is available as a monthly auto-renewable subscription.
                        • Payment is charged to your Apple ID account at confirmation of purchase.
                        • Subscription automatically renews unless canceled at least 24 hours before the end of the current period.
                        • You can manage and cancel subscriptions in your Apple ID Settings.
                        """
                    }

                    section(title: "Content") {
                        "Podcut provides access to publicly available podcast feeds. We do not host or control podcast content. All podcast content is the property of its respective creators."
                    }

                    section(title: "AI Features") {
                        "AI-generated summaries and chat responses are provided for informational purposes only. They may contain errors or inaccuracies. Do not rely on them for critical decisions."
                    }

                    section(title: "Disclaimer") {
                        "Podcut is provided \"as is\" without warranties of any kind. We are not liable for any damages arising from your use of the app."
                    }

                    section(title: "Contact") {
                        "Questions? Reach us at support@podcut.app"
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(LocalizedStringKey(content()))
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }
}
