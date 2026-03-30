import Foundation

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

struct GenerationResponse: Codable {
    let generationId: String
    let resultUrl: String
    let animationUrl: String?
}
