import Foundation

@MainActor
final class GenerationService: ObservableObject {
    static let shared = GenerationService()

    @Published var progress: GenerationProgress = .idle
    @Published var isGenerating = false

    enum GenerationProgress: Equatable {
        case idle
        case removingBackground
        case relighting
        case animating
        case done(String) // resultUrl
        case failed(String) // error message

        static func == (lhs: GenerationProgress, rhs: GenerationProgress) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.removingBackground, .removingBackground),
                 (.relighting, .relighting), (.animating, .animating):
                return true
            case (.done(let a), .done(let b)):
                return a == b
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private init() {}

    func generate(
        selfieData: Data,
        backgroundID: String,
        animate: Bool = false
    ) async throws -> GenerationResponse {
        guard let session = AuthService.shared.session else {
            throw GenerationError.notAuthenticated
        }

        isGenerating = true
        progress = .removingBackground
        defer {
            isGenerating = false
        }

        let url = AppConfig.supabaseURL
            .appendingPathComponent("functions/v1/generate")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(session.accessToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.timeoutInterval = 120 // 2 minutes for full pipeline

        let boundary = "AURABoundary-\(UUID().uuidString)"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()
        body.appendField(name: "backgroundId", value: backgroundID, boundary: boundary)
        body.appendField(name: "animate", value: animate ? "true" : "false", boundary: boundary)
        body.appendFile(
            name: "selfie",
            filename: "selfie.jpg",
            data: selfieData,
            mimeType: "image/jpeg",
            boundary: boundary
        )
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // Simulate progress stages (backend is a black box from iOS perspective)
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4s
            if self.progress == .removingBackground {
                self.progress = .relighting
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GenerationError.serverError("HTTP \(httpResponse.statusCode): \(body)")
        }

        let result = try JSONDecoder().decode(GenerationResponse.self, from: data)
        progress = .done(result.resultUrl)
        return result
    }
}

enum GenerationError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to generate images."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .serverError(let msg):
            return "Server error: \(msg)"
        }
    }
}

// ── Multipart form data helpers ───────────────────────────────────────────────
extension Data {
    mutating func appendField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendFile(
        name: String,
        filename: String,
        data fileData: Data,
        mimeType: String,
        boundary: String
    ) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!
        )
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(fileData)
        append("\r\n".data(using: .utf8)!)
    }
}
