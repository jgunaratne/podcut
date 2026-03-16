import StoreKit
import SwiftUI

/// Paywall view shown when a user tries to access Pro features.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private var manager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header.
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(.indigo.gradient)

                        Text("Podcut Pro")
                            .font(.largeTitle.bold())

                        Text("Unlock AI-powered podcast tools")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Feature list.
                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(icon: "wand.and.stars", title: "AI Summaries",
                                   detail: "Get concise, timestamped summaries of any episode")
                        featureRow(icon: "bubble.left.and.text.bubble.right", title: "Chat with Episodes",
                                   detail: "Ask questions about the podcast content")
                        featureRow(icon: "arrow.clockwise", title: "Regenerate Anytime",
                                   detail: "Re-summarize episodes for fresh insights")
                    }
                    .padding(.horizontal, 24)

                    // Price and CTA.
                    if let product = manager.products.first {
                        VStack(spacing: 12) {
                            Text("\(product.displayPrice)/month")
                                .font(.title2.bold())

                            Button {
                                Task { await manager.purchase() }
                            } label: {
                                Text("Subscribe")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                            .buttonBorderShape(.capsule)
                            .padding(.horizontal, 24)
                            .disabled(manager.isLoading)

                            Button("Restore Purchases") {
                                Task { await manager.restore() }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    } else if manager.isLoading {
                        ProgressView("Loading…")
                    }

                    // Error.
                    if let error = manager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Legal links.
                    VStack(spacing: 4) {
                        Text("Subscription auto-renews monthly. Cancel anytime in Settings.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await manager.loadProducts() }
        .onChange(of: manager.isPro) {
            if manager.isPro { dismiss() }
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
