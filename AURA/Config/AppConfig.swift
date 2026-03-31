// AURA/Config/AppConfig.swift
import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        let host = Bundle.main.infoDictionary?["SUPABASE_HOST"] as? String ?? ""
        return URL(string: "https://\(host)") ?? URL(string: "https://placeholder.supabase.co")!
    }()
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
