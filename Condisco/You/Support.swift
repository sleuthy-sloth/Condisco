import StoreKit
import SwiftUI

// MARK: - Support (tip jar)
//
// Condisco is free with everything unlocked. Support is a set of one-time,
// non-consumable purchases that unlock nothing at all — they exist only
// so learners who want to say thanks have a way to do it. Purchases are
// tied to the learner's Apple account and restore on any device.

@MainActor
final class SupportStore: ObservableObject {
    enum Tier: String, CaseIterable, Identifiable {
        case espresso
        case cappuccino
        case feast

        var id: String { rawValue }

        /// Must match the non-consumable product IDs in App Store Connect
        /// exactly, or the StoreKit configuration file used for testing.
        var productID: String {
            "com.sleuthysloth.condisco.support.\(rawValue)"
        }

        var title: String {
            switch self {
            case .espresso: return "Espresso"
            case .cappuccino: return "Cappuccino"
            case .feast: return "Feast"
            }
        }

        var blurb: String {
            switch self {
            case .espresso: return "A small thank-you."
            case .cappuccino: return "A generous thank-you."
            case .feast: return "The full spread. Thank you, truly."
            }
        }

        /// The highest-ranked owned tier decides the supporter badge.
        var rank: Int {
            switch self {
            case .espresso: return 0
            case .cappuccino: return 1
            case .feast: return 2
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isSupporter = false
    @Published private(set) var supporterTier: Tier?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var notice: String?

    init() {
        // The task ends itself when the store is deallocated.
        Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { break }
                await self.handle(update)
            }
        }
    }

    func load() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(
                for: Tier.allCases.map(\.productID))
            // Keep tier order even if the store returns its own.
            products = Tier.allCases.compactMap { tier in
                fetched.first(where: { $0.id == tier.productID })
            }
        } catch {
            notice = "Support options could not be loaded right now."
        }
        await refreshEntitlements()
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    notice = nil
                    await refreshEntitlements()
                case .unverified(_, let error):
                    notice =
                        "The purchase could not be verified: \(error.localizedDescription)"
                }
            case .userCancelled:
                break
            case .pending:
                notice =
                    "The purchase is pending. It will complete once it is approved."
            @unknown default:
                break
            }
        } catch {
            notice = "The purchase could not be completed. Try again."
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
        if !isSupporter {
            notice = "No previous thank-you was found on this account."
        } else {
            notice = nil
        }
    }

    private func handle(_ update: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var best: Tier?
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                transaction.revocationDate == nil,
                let tier = Tier.allCases.first(where: {
                    $0.productID == transaction.productID
                })
            else { continue }
            if let current = best {
                if tier.rank > current.rank { best = tier }
            } else {
                best = tier
            }
        }
        supporterTier = best
        isSupporter = best != nil
    }
}

// MARK: - Support sheet

struct SupportView: View {
    @ObservedObject var store: SupportStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if let notice = store.notice {
                            Text(notice)
                                .font(DesignTokens.text(13))
                                .foregroundStyle(DesignTokens.attentionInk)
                        }
                        if store.isSupporter {
                            thankYou
                        } else {
                            tiers
                        }
                        finePrint
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Condisco is free, with everything unlocked — no tiers, no paywalls.")
                .font(DesignTokens.text(15, weight: .medium))
                .foregroundStyle(DesignTokens.inkDeep)
            Text(
                "If it has helped you learn, a one-time thank-you below is the nicest way to say so. It unlocks nothing, because there is nothing left to unlock."
            )
            .font(DesignTokens.text(14))
            .foregroundStyle(DesignTokens.muted)
        }
    }

    private var tiers: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isLoadingProducts {
                ProgressView()
                    .tint(DesignTokens.primary)
            } else if store.products.isEmpty {
                Text(
                    "Support options are unavailable right now. Check your connection and try again later."
                )
                .font(DesignTokens.text(14))
                .foregroundStyle(DesignTokens.muted)
            } else {
                ForEach(store.products) { product in
                    tierRow(product)
                }
            }
            Button("Restore previous thank-yous") {
                Task { await store.restore() }
            }
            .font(DesignTokens.text(15, weight: .semibold))
            .foregroundStyle(DesignTokens.primary)
        }
    }

    private func tierRow(_ product: Product) -> some View {
        let tier = SupportStore.Tier.allCases.first(where: {
            $0.productID == product.id
        })
        return PaperCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier?.title ?? product.displayName)
                        .font(DesignTokens.text(16, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkDeep)
                    Text(tier?.blurb ?? product.description)
                        .font(DesignTokens.text(13))
                        .foregroundStyle(DesignTokens.muted)
                }
                Spacer()
                if store.isPurchasing {
                    ProgressView()
                        .tint(DesignTokens.primary)
                } else {
                    Button(product.displayPrice) {
                        Task { await store.purchase(product) }
                    }
                    .font(DesignTokens.text(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.stock)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DesignTokens.primary)
                    .cornerRadius(10)
                    .disabled(store.isPurchasing)
                }
            }
        }
    }

    private var thankYou: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Thank you, truly.", systemImage: "heart.fill")
                    .font(DesignTokens.display(20))
                    .foregroundStyle(DesignTokens.primary)
                if let tier = store.supporterTier {
                    Text(
                        "You're a \(tier.title) supporter. Every lesson stays free because of people like you."
                    )
                    .font(DesignTokens.text(14))
                    .foregroundStyle(DesignTokens.muted)
                }
                Button("Restore previous thank-yous") {
                    Task { await store.restore() }
                }
                .font(DesignTokens.text(15, weight: .semibold))
                .foregroundStyle(DesignTokens.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var finePrint: some View {
        Text(
            "One-time purchases, kept on your Apple account and restorable on any device."
        )
        .font(DesignTokens.text(12))
        .foregroundStyle(DesignTokens.muted)
    }
}
