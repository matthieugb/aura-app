import Foundation
import RevenueCat

@MainActor
final class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    @Published var isPremium = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        Task { await checkStatus() }
    }

    func checkStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements[AppConfig.Entitlements.premium]?.isActive == true
        } catch {
            // Not authenticated with RevenueCat yet — not premium
            isPremium = false
        }
    }

    func purchase() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.availablePackages.first else {
                errorMessage = "No offerings available. Please try again later."
                return
            }
            let (_, info, _) = try await Purchases.shared.purchase(package: package)
            isPremium = info.entitlements[AppConfig.Entitlements.premium]?.isActive == true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPremium = info.entitlements[AppConfig.Entitlements.premium]?.isActive == true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
