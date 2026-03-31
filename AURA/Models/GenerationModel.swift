import Foundation

enum GenerationModel: String, CaseIterable, Hashable {
    case nanobanana        = "nanobanana"
    case klingV25Video5s   = "kling_v25_5s"
    case klingV25Video10s  = "kling_v25_10s"
    case klingV3Video5s    = "kling_v3_5s"
    case klingV3Video10s   = "kling_v3_10s"
    case omniHuman5s       = "omnihuman_5s"
    case omniHuman10s      = "omnihuman_10s"

    var creditCost: Int {
        switch self {
        case .nanobanana:       return 1
        case .klingV25Video5s:  return 6
        case .klingV25Video10s: return 11
        case .klingV3Video5s:   return 10
        case .klingV3Video10s:  return 18
        case .omniHuman5s:      return 12
        case .omniHuman10s:     return 20
        }
    }

    var displayName: String {
        switch self {
        case .nanobanana:       return "Nano Banana 2"
        case .klingV25Video5s:  return "Vidéo 5s"
        case .klingV25Video10s: return "Vidéo 10s"
        case .klingV3Video5s:   return "Vidéo 5s + Son"
        case .klingV3Video10s:  return "Vidéo 10s + Son"
        case .omniHuman5s:      return "Ma voix 5s"
        case .omniHuman10s:     return "Ma voix 10s"
        }
    }

    var subtitle: String {
        switch self {
        case .nanobanana:       return "Rapide · \(creditCost) crédit"
        case .klingV25Video5s:  return "Kling 2.5 · \(creditCost) crédits"
        case .klingV25Video10s: return "Kling 2.5 · \(creditCost) crédits"
        case .klingV3Video5s:   return "Kling 3 + audio · \(creditCost) crédits"
        case .klingV3Video10s:  return "Kling 3 + audio · \(creditCost) crédits"
        case .omniHuman5s:      return "Lip sync · \(creditCost) crédits"
        case .omniHuman10s:     return "Lip sync · \(creditCost) crédits"
        }
    }

    var isVideo: Bool {
        switch self {
        case .klingV25Video5s, .klingV25Video10s, .klingV3Video5s, .klingV3Video10s,
             .omniHuman5s, .omniHuman10s:
            return true
        default: return false
        }
    }
}
