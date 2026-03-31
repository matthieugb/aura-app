import Foundation

struct Generation: Identifiable, Codable, Hashable {
    let id: String
    let prompt: String
    let resultUrls: [String]
    let animationUrl: String?
    let status: String
    let createdAt: Date
    var ratio: OutputRatio = .portrait

    enum CodingKeys: String, CodingKey {
        case id, status, prompt
        case resultUrls  = "result_urls"
        case animationUrl = "animation_url"
        case createdAt   = "created_at"
        // ratio is local only, not stored in DB
    }
}

struct GenerationResponse: Codable {
    let generationId: String
    let resultUrls: [String]
    let animationUrl: String?
}
