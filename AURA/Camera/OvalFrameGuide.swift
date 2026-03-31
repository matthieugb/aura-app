import SwiftUI

enum OutputRatio: String, CaseIterable, Hashable, Codable {
    case portrait  = "9:16"
    case square    = "1:1"
    case landscape = "16:9"

    var klingValue: String {
        switch self {
        case .portrait:  return "9:16"
        case .square:    return "1:1"
        case .landscape: return "16:9"
        }
    }

    var ovalWidth: CGFloat {
        switch self {
        case .portrait:  return 220
        case .square:    return 280
        case .landscape: return 340
        }
    }

    var ovalHeight: CGFloat {
        switch self {
        case .portrait:  return 340
        case .square:    return 280
        case .landscape: return 200
        }
    }
}

struct OvalFrameGuide: View {
    var ratio: OutputRatio = .portrait

    private var ovalWidth: CGFloat  { ratio.ovalWidth }
    private var ovalHeight: CGFloat { ratio.ovalHeight }

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(Color(hex: "C4894A").opacity(0.4), lineWidth: 1)
                .frame(width: ovalWidth, height: ovalHeight)
                .animation(.easeInOut(duration: 0.3), value: ratio)

            ForEach(CornerPosition.allCases, id: \.self) { corner in
                CornerAccent(position: corner, w: ovalWidth, h: ovalHeight)
            }
        }
    }
}

private enum CornerPosition: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct CornerAccent: View {
    let position: CornerPosition
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        let size: CGFloat = 16
        ZStack {
            Rectangle()
                .fill(Color(hex: "C4894A"))
                .frame(width: size, height: 2)
                .offset(x: hOffset(size), y: vOffset)

            Rectangle()
                .fill(Color(hex: "C4894A"))
                .frame(width: 2, height: size)
                .offset(x: hOffset(0), y: vOffset + (isTop ? size/2 - 1 : -size/2 + 1))
        }
        .offset(x: hSign * (w / 2 - 2), y: vSign * (h / 2 - 2))
        .animation(.easeInOut(duration: 0.3), value: w)
    }

    var isTop: Bool { position == .topLeft || position == .topRight }
    var isLeft: Bool { position == .topLeft || position == .bottomLeft }
    var hSign: CGFloat { isLeft ? -1 : 1 }
    var vSign: CGFloat { isTop ? -1 : 1 }
    var vOffset: CGFloat { vSign * 8 }
    func hOffset(_ fw: CGFloat) -> CGFloat { hSign * fw / 2 }
}
