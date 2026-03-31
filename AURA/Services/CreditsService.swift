import Foundation
import Supabase

@MainActor
final class CreditsService: ObservableObject {
    static let shared = CreditsService()
    @Published var balance: Int = 0
    @Published var isLoading = false

    private let client = AuthService.shared.client

    private init() {
        Task { await fetchBalance() }
    }

    func fetchBalance() async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = AuthService.shared.session?.user.id.uuidString else { return }
        do {
            let row = try await client
                .from("user_credits")
                .select("balance")
                .eq("user_id", value: userId)
                .single()
                .execute()
            if let json = try? JSONSerialization.jsonObject(with: row.data) as? [String: Any],
               let b = json["balance"] as? Int {
                balance = b
            }
        } catch {
            // credits row may not exist yet
        }
    }

    func deductLocally(_ amount: Int) {
        balance = max(0, balance - amount)
    }
}
