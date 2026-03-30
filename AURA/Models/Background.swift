import SwiftUI

struct Background: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: BackgroundCategory
    let storagePath: String
    let isPremium: Bool
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, category, isPremium = "is_premium", sortOrder = "sort_order"
        case storagePath = "storage_path"
    }

    enum BackgroundCategory: String, Codable, CaseIterable, Hashable {
        case studio, nature, urban, luxury
        var label: String { rawValue.capitalized }
    }

    var previewGradient: LinearGradient {
        switch id {
        case "golden-hour":
            return LinearGradient(
                colors: [Color(hex: "D4621A"), Color(hex: "F0953C"), Color(hex: "C4956A")],
                startPoint: .top, endPoint: .bottom)
        case "forest":
            return LinearGradient(
                colors: [Color(hex: "1A3A10"), Color(hex: "2D5A1A"), Color(hex: "4A7A2A")],
                startPoint: .top, endPoint: .bottom)
        case "night-city":
            return LinearGradient(
                colors: [Color(hex: "060A18"), Color(hex: "0E1830"), Color(hex: "1A2E58")],
                startPoint: .top, endPoint: .bottom)
        case "studio":
            return LinearGradient(
                colors: [Color(hex: "ECE8E4"), Color(hex: "D8D0C8")],
                startPoint: .top, endPoint: .bottom)
        case "beach":
            return LinearGradient(
                colors: [Color(hex: "FF7A50"), Color(hex: "FFE0A0"), Color(hex: "C4956A")],
                startPoint: .top, endPoint: .bottom)
        case "blue-hour":
            return LinearGradient(
                colors: [Color(hex: "1A2A5E"), Color(hex: "2A4A9E"), Color(hex: "C4D4F0")],
                startPoint: .top, endPoint: .bottom)
        case "marble":
            return LinearGradient(
                colors: [Color(hex: "F0EDE8"), Color(hex: "E4DDD4"), Color(hex: "DED6CC")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case "terracotta":
            return LinearGradient(
                colors: [Color(hex: "8B3A1A"), Color(hex: "C4623A"), Color(hex: "E8C0A0")],
                startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [Color(hex: "EAE0D2")], startPoint: .top, endPoint: .bottom)
        }
    }
}
