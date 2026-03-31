import Foundation
import RevenueCat

struct CreditPack: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let price: String
    let credits: Int
    let tag: String?
}

let essaiPack = CreditPack(
    id: "aura_essai",
    title: "Essai",
    subtitle: "Pack découverte · usage unique",
    price: "€3.99",
    credits: 14,
    tag: nil
)

let rechargePacks: [CreditPack] = [
    CreditPack(id: "aura_recharge_s", title: "Recharge S", subtitle: "13 crédits",  price: "€4.99",  credits: 13, tag: nil),
    CreditPack(id: "aura_recharge_m", title: "Recharge M", subtitle: "28 crédits",  price: "€9.99",  credits: 28, tag: "Populaire"),
    CreditPack(id: "aura_recharge_l", title: "Recharge L", subtitle: "60 crédits",  price: "€19.99", credits: 60, tag: nil),
]

let subscriptionPacks: [CreditPack] = [
    CreditPack(id: "aura_mensuel", title: "Mensuel",  subtitle: "33 crédits / mois",  price: "€9.99/mois",  credits: 33, tag: nil),
    CreditPack(id: "aura_pro",     title: "Pro",      subtitle: "72 crédits / mois",  price: "€19.99/mois", credits: 72, tag: nil),
    CreditPack(id: "aura_annuel",  title: "Annuel",   subtitle: "220 crédits / an",   price: "€59.99/an",   credits: 220, tag: "Meilleure valeur"),
]

@MainActor
final class PurchaseService: ObservableObject {
    static let shared = PurchaseService()
    @Published var isPremium = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var availablePackages: [Package] = []
    @Published var hasUsedEssai = false
    @Published var activeSubscriptionId: String? = nil

    private init() {
        Task {
            await checkStatus()
            await loadOfferings()
        }
    }

    func checkStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements[AppConfig.Entitlements.premium]?.isActive == true
            hasUsedEssai = info.nonSubscriptionTransactions
                .contains(where: { $0.productIdentifier == "aura_essai" })
            activeSubscriptionId = info.activeSubscriptions.first
        } catch {
            isPremium = false
        }
    }

    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            availablePackages = offerings.current?.availablePackages ?? []
        } catch {}
    }

    func purchase(productId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let pkg = availablePackages.first(where: { $0.storeProduct.productIdentifier == productId }) else {
            errorMessage = "Produit non disponible"
            return
        }
        do {
            let (_, info, _) = try await Purchases.shared.purchase(package: pkg)
            isPremium = info.entitlements[AppConfig.Entitlements.premium]?.isActive == true
            hasUsedEssai = info.nonSubscriptionTransactions
                .contains(where: { $0.productIdentifier == "aura_essai" })
            activeSubscriptionId = info.activeSubscriptions.first
            await CreditsService.shared.fetchBalance()
        } catch {
            if (error as NSError).code != 1 { // 1 = user cancelled
                errorMessage = error.localizedDescription
            }
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPremium = info.entitlements[AppConfig.Entitlements.premium]?.isActive == true
            hasUsedEssai = info.nonSubscriptionTransactions
                .contains(where: { $0.productIdentifier == "aura_essai" })
            activeSubscriptionId = info.activeSubscriptions.first
            await CreditsService.shared.fetchBalance()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
