import SwiftUI

// Placeholder models for navigation — will be filled in later tasks
struct GenerationRequest: Hashable {
    let selfieData: Data
    let backgroundID: String
}

struct Generation: Identifiable, Codable, Hashable {
    let id: String
    let backgroundId: String
    let resultUrl: String
    let animationUrl: String?
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case backgroundId = "background_id"
        case resultUrl = "result_url"
        case animationUrl = "animation_url"
        case createdAt = "created_at"
    }
}

enum AppRoute: Hashable {
    case camera
    case gallery
    case processing(GenerationRequest)
    case result(Generation)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func reset() {
        path = NavigationPath()
    }
}
