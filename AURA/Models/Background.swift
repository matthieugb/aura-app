import SwiftUI

// Stub — will be replaced in Task 6
struct Background: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let isPremium: Bool

    var previewGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "18120C")], startPoint: .top, endPoint: .bottom)
    }
}
