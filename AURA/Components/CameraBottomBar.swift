import SwiftUI

struct CameraBottomBar: View {
    let onCapture: () -> Void
    let onSeeAll: () -> Void
    @StateObject private var bgStore = BackgroundStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Strip header
            HStack {
                Text("BACKGROUND")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(4)
                    .foregroundColor(Color(hex: "9A8878"))
                Spacer()
                Button("See all →", action: onSeeAll)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "C4894A"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Thumbnail strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(bgStore.backgrounds) { bg in
                        BackgroundThumb(
                            bg: bg,
                            isSelected: bgStore.selected?.id == bg.id
                        )
                        .onTapGesture { bgStore.select(bg) }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)

            // Capture row
            HStack(spacing: 48) {
                // Spacer left (gallery placeholder)
                Color.clear.frame(width: 40, height: 40)

                // Capture button
                Button(action: onCapture) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 58, height: 58)
                    }
                }

                // Flip camera (handled by top bar now)
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.bottom, 40)
        }
        .background(Color(hex: "0D0B09").opacity(0.95))
    }
}

struct BackgroundThumb: View {
    let bg: Background
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 12)
                .fill(bg.previewGradient)
                .frame(width: 60, height: 80)

            Text(bg.name)
                .font(.system(size: 7, weight: .medium))
                .tracking(0.5)
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.bottom, 6)
                .padding(.horizontal, 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "C4894A"), lineWidth: isSelected ? 2 : 0)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
