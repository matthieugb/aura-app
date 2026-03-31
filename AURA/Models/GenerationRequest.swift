import Foundation

struct GenerationRequest: Hashable {
    let selfiePhotos: [Data]
    let prompt: String
    let ratio: OutputRatio
    let model: GenerationModel
    var audioData: Data? = nil
    var animateSourceUrl: String? = nil  // URL of existing image to animate

    static func == (lhs: GenerationRequest, rhs: GenerationRequest) -> Bool {
        lhs.selfiePhotos == rhs.selfiePhotos &&
        lhs.prompt == rhs.prompt &&
        lhs.ratio == rhs.ratio &&
        lhs.model == rhs.model
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(selfiePhotos)
        hasher.combine(prompt)
        hasher.combine(ratio)
        hasher.combine(model)
    }
}
