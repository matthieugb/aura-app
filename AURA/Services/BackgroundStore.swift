import SwiftUI

// Stub — will be replaced in Task 6
@MainActor
final class BackgroundStore: ObservableObject {
    static let shared = BackgroundStore()
    @Published var backgrounds: [Background] = []
    @Published var selected: Background?
    private init() {}
    func select(_ bg: Background) { selected = bg }
}
