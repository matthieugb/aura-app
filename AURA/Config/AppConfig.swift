// AURA/Config/AppConfig.swift
import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? "https://placeholder.supabase.co")!
    static let supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    static let revenueCatAPIKey = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String ?? ""

    enum Entitlements {
        static let premium = "premium"
    }

    enum Credits {
        static let freePhotosPerDay = 5
        static let premiumAnimationsPerMonth = 20
    }
}
