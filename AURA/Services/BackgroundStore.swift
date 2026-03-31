import SwiftUI
import Supabase

@MainActor
final class BackgroundStore: ObservableObject {
    static let shared = BackgroundStore()

    @Published var backgrounds: [Background] = BackgroundStore.defaults
    @Published var selected: Background?
    @Published var isLoading = false

    private init() {
        selected = backgrounds.first
        Task { await fetchFromSupabase() }
    }

    func fetchFromSupabase() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [Background] = try await AuthService.shared.client
                .from("backgrounds")
                .select()
                .order("sort_order")
                .execute()
                .value
            if !fetched.isEmpty {
                backgrounds = fetched
                if selected == nil { selected = fetched.first }
            }
        } catch {
            // Keep defaults on network error
        }
    }

    func select(_ bg: Background) {
        selected = bg
    }

    static let defaults: [Background] = [
        Background(id: "golden-hour", name: "Golden Hour", category: .nature,
                   storagePath: "backgrounds/golden-hour.jpg", isPremium: false, sortOrder: 1),
        Background(id: "forest", name: "Forest", category: .nature,
                   storagePath: "backgrounds/forest.jpg", isPremium: false, sortOrder: 2),
        Background(id: "night-city", name: "Night City", category: .urban,
                   storagePath: "backgrounds/night-city.jpg", isPremium: false, sortOrder: 3),
        Background(id: "studio", name: "Studio", category: .studio,
                   storagePath: "backgrounds/studio.jpg", isPremium: true, sortOrder: 4),
        Background(id: "beach", name: "Sunset Beach", category: .nature,
                   storagePath: "backgrounds/beach.jpg", isPremium: true, sortOrder: 5),
        Background(id: "blue-hour", name: "Blue Hour", category: .urban,
                   storagePath: "backgrounds/blue-hour.jpg", isPremium: true, sortOrder: 6),
        Background(id: "marble", name: "Marble", category: .luxury,
                   storagePath: "backgrounds/marble.jpg", isPremium: true, sortOrder: 7),
        Background(id: "terracotta", name: "Terracotta", category: .luxury,
                   storagePath: "backgrounds/terracotta.jpg", isPremium: true, sortOrder: 8),
    ]
}
