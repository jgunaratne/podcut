import StoreKit

/// Product identifiers for the app's subscriptions.
enum SubscriptionProduct {
    static let proMonthly = "com.podcut.app.pro.monthly"
}

/// Manages StoreKit 2 subscriptions for Podcut Pro.
@MainActor @Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    /// Whether the user has an active Pro subscription.
    /// In DEBUG builds, set `overrideProForTesting` to true to bypass the paywall.
    #if DEBUG
    var overrideProForTesting = true
    var isPro: Bool {
        overrideProForTesting ? true : _isPro
    }
    private var _isPro: Bool = false
    #else
    var isPro: Bool = false
    #endif

    /// Available products from the App Store / StoreKit configuration.
    var products: [Product] = []

    /// Loading state.
    var isLoading: Bool = false

    /// Error message.
    var errorMessage: String?

    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task {
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await refreshStatus()
                    await transaction.finish()
                }
            }
        }
    }

    /// Load products and check subscription status.
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: [SubscriptionProduct.proMonthly])
            await refreshStatus()
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    /// Purchase the Pro subscription.
    func purchase() async {
        guard let product = products.first else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = try? verification.payloadValue {
                    await transaction.finish()
                    await refreshStatus()
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    /// Restore purchases.
    func restore() async {
        isLoading = true
        defer { isLoading = false }

        try? await AppStore.sync()
        await refreshStatus()
    }

    /// Check if the user has an active subscription.
    private func refreshStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue,
               transaction.productID == SubscriptionProduct.proMonthly,
               transaction.revocationDate == nil
            {
                hasActive = true
                break
            }
        }
        #if DEBUG
        _isPro = hasActive
        #else
        isPro = hasActive
        #endif
    }
}
