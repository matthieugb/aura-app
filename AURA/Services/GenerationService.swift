import Foundation
import UIKit

@MainActor
final class GenerationService: ObservableObject {
    static let shared = GenerationService()

    @Published var progress: GenerationProgress = .idle
    @Published var isGenerating = false

    enum GenerationProgress: Equatable {
        case idle
        case generating    // Kling Image compositing selfies + scene
        case finalizing    // saving + storing result
        case animating     // Kling Video (premium)
        case done(String)
        case failed(String)

        static func == (lhs: GenerationProgress, rhs: GenerationProgress) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.generating, .generating),
                 (.finalizing, .finalizing), (.animating, .animating):
                return true
            case (.done(let a), .done(let b)): return a == b
            case (.failed(let a), .failed(let b)): return a == b
            default: return false
            }
        }
    }

    private init() {}

    func generate(request: GenerationRequest, animate: Bool = false) async throws -> GenerationResponse {
        await AuthService.shared.refreshSession()
        guard let session = AuthService.shared.session else {
            throw GenerationError.notAuthenticated
        }

        isGenerating = true
        progress = .generating
        defer { isGenerating = false }

        let url = AppConfig.supabaseURL.appendingPathComponent("functions/v1/generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(session.accessToken, forHTTPHeaderField: "x-user-token")
        urlRequest.timeoutInterval = 180

        let boundary = "AURABoundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendField(name: "prompt", value: request.prompt, boundary: boundary)
        body.appendField(name: "animate", value: animate ? "true" : "false", boundary: boundary)
        body.appendField(name: "aspect_ratio", value: request.ratio.klingValue, boundary: boundary)
        body.appendField(name: "model", value: request.model.rawValue, boundary: boundary)
        if let sourceUrl = request.animateSourceUrl {
            body.appendField(name: "animate_source_url", value: sourceUrl, boundary: boundary)
        }

        for (i, photoData) in request.selfiePhotos.enumerated() {
            // Compress to max ~1.5MB JPEG to stay within edge function limits
            let compressed: Data
            if let img = UIImage(data: photoData) {
                compressed = img.jpegData(compressionQuality: 0.7) ?? photoData
            } else {
                compressed = photoData
            }
            body.appendFile(
                name: "selfie_\(i)",
                filename: "selfie_\(i).jpg",
                data: compressed,
                mimeType: "image/jpeg",
                boundary: boundary
            )
        }

        // Audio for lip sync (OmniHuman)
        if let audioData = request.audioData {
            body.appendFile(
                name: "audio",
                filename: "voice.m4a",
                data: audioData,
                mimeType: "audio/m4a",
                boundary: boundary
            )
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body

        // Simulate step transitions
        Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if self.progress == .generating { self.progress = .finalizing }
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.networkError("Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GenerationError.serverError("HTTP \(httpResponse.statusCode): \(msg)")
        }

        let result = try JSONDecoder().decode(GenerationResponse.self, from: data)
        progress = .done(result.resultUrls.first ?? "")
        // Refresh credits after generation
        await CreditsService.shared.fetchBalance()
        return result
    }
}

enum GenerationError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in to generate images."
        case .networkError(let msg): return "Network error: \(msg)"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}

// ── Multipart helpers ──────────────────────────────────────────────────────────
extension Data {
    mutating func appendField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendFile(name: String, filename: String, data fileData: Data, mimeType: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(fileData)
        append("\r\n".data(using: .utf8)!)
    }
}
