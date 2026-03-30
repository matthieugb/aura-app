import SwiftUI

struct OvalFrameGuide: View {
    var body: some View {
        ZStack {
            Ellipse()
                .stroke(Color(hex: "C4894A").opacity(0.4), lineWidth: 1)
                .frame(width: 240, height: 350)

            // Corner accents
            ForEach(CornerPosition.allCases, id: \.self) { corner in
                CornerAccent(position: corner)
            }
        }
    }
}

private enum CornerPosition: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct CornerAccent: View {
    let position: CornerPosition

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
        .offset(x: hSign * 118, y: vSign * 173)
    }

    var isTop: Bool { position == .topLeft || position == .topRight }
    var isLeft: Bool { position == .topLeft || position == .bottomLeft }
    var hSign: CGFloat { isLeft ? -1 : 1 }
    var vSign: CGFloat { isTop ? -1 : 1 }
    var vOffset: CGFloat { vSign * 8 }
    func hOffset(_ w: CGFloat) -> CGFloat { hSign * w / 2 }
}
