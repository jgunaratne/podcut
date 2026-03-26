import StoreKit
import SwiftUI

/// Paywall view shown when a user tries to access Pro features.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private var manager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient and shapes.
                background()

                ScrollView {
                    VStack(spacing: 24) {
                        header()
                        
                        // Feature list.
                        VStack(spacing: 16) {
                            featureCard(
                                icon: "wand.and.stars.inverse",
                                title: "AI Summaries",
                                detail: "Get concise, timestamped summaries of any episode"
                            )
                            featureCard(
                                icon: "bubble.left.and.text.bubble.right.fill",
                                title: "Chat with Episodes",
                                detail: "Ask questions about the podcast content"
                            )
                            featureCard(
                                icon: "arrow.clockwise.circle.fill",
                                title: "Regenerate Anytime",
                                detail: "Re-summarize episodes for fresh insights"
                            )
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 30)
                        
                        purchaseSection()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Podcut Pro")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task { await manager.loadProducts() }
        .onChange(of: manager.isPro) {
            if manager.isPro { dismiss() }
        }
    }

    private func background() -> some View {
        LinearGradient(
            colors: [.blue.opacity(0.8), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(.blue)
                .frame(width: 400)
                .blur(radius: 100)
                .offset(y: -200)
        }
        .ignoresSafeArea()
    }

    private func header() -> some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative.reversing)

            Text("Unlock AI-powered podcast tools")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func featureCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.blue.gradient)
                .frame(width: 50)
                .symbolRenderingMode(.multicolor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(20)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func purchaseSection() -> some View {
        VStack(spacing: 16) {
            if let product = manager.products.first {
                VStack(spacing: 16) {
                    Text("Just \(product.displayPrice)/month")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        

                    Button {
                        Task { await manager.purchase() }
                    } label: {
                        Text("Subscribe to Podcut Pro")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: .capsule)
                            .foregroundStyle(.blue)
                    }
                    .buttonBorderShape(.capsule)
                    .padding(.horizontal, 24)
                    
                    .disabled(manager.isLoading)

                    Button("Restore Purchases") {
                        Task { await manager.restore() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                }
            } else if manager.isLoading {
                ProgressView()
                    .tint(.white)
            }

            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.pink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text("Subscription auto-renews monthly. Cancel anytime in Settings.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }
}
