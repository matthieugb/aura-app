import SwiftUI

struct GalleryScreen: View {
    @StateObject private var bgStore = BackgroundStore.shared
    @EnvironmentObject private var router: AppRouter
    @State private var selectedCategory: Background.BackgroundCategory? = nil

    var filtered: [Background] {
        guard let cat = selectedCategory else { return bgStore.backgrounds }
        return bgStore.backgrounds.filter { $0.category == cat }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                Text("Backgrounds")
                    .font(.custom("CormorantGaramond-Regular", size: 28))
                    .foregroundColor(Color(hex: "18120C"))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryTab(label: "All", isActive: selectedCategory == nil) {
                            withAnimation { selectedCategory = nil }
                        }
                        ForEach(Background.BackgroundCategory.allCases, id: \.self) { cat in
                            CategoryTab(label: cat.label, isActive: selectedCategory == cat) {
                                withAnimation { selectedCategory = cat }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 70)
            .padding(.bottom, 20)

            Divider()

            // Grid
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, bg in
                        GalleryCard(bg: bg, isWide: idx == 0 && selectedCategory == nil)
                            .onTapGesture {
                                bgStore.select(bg)
                                router.pop()
                            }
                    }
                }
                .padding(16)
                .padding(.bottom, 100)
            }
        }
        .overlay(alignment: .bottom) {
            // Bottom action bar
            HStack(spacing: 10) {
                Button("← Back") { router.pop() }
                    .buttonStyle(OutlineButtonStyle())
                Button("Select") { router.pop() }
                    .buttonStyle(DarkButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(
                LinearGradient(
                    colors: [.clear, Color(hex: "FDFAF7")],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        .navigationBarHidden(true)
        .background(Color(hex: "FDFAF7"))
    }
}

private struct CategoryTab: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .font(.system(size: 12))
            .foregroundColor(isActive ? .white : Color(hex: "9A8878"))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(isActive ? Color(hex: "18120C") : Color.clear)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: "EAE0D2"), lineWidth: isActive ? 0 : 1)
            )
    }
}

private struct GalleryCard: View {
    let bg: Background
    let isWide: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(bg.previewGradient)
                .aspectRatio(isWide ? CGSize(width: 16, height: 9) : CGSize(width: 3, height: 4),
                             contentMode: .fill)
                .gridCellColumns(isWide ? 2 : 1)

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )
            .cornerRadius(16)

            HStack(alignment: .bottom) {
                Text(bg.name)
                    .font(.custom("CormorantGaramond-Regular", size: 16))
                    .foregroundColor(.white)
                Spacer()
                Text(bg.isPremium ? "★ Premium" : "Free")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .foregroundColor(bg.isPremium ? Color(hex: "E8C084") : .white.opacity(0.6))
            }
            .padding(14)
        }
    }
}
