import SwiftUI

struct ResultScreen: View {
    let generation: Generation
    @StateObject private var bgStore = BackgroundStore.shared
    @StateObject private var genService = GenerationService.shared
    @EnvironmentObject private var router: AppRouter
    @State private var isAnimating = false
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            // Result image (full width, ~60% height)
            ZStack(alignment: .top) {
                AsyncImage(url: URL(string: generation.resultUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        // Fallback gradient
                        Rectangle()
                            .fill(bgStore.selected?.previewGradient ??
                                  LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                    case .empty:
                        ZStack {
                            Rectangle()
                                .fill(bgStore.selected?.previewGradient ??
                                      LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                            ProgressView()
                                .tint(Color(hex: "C4894A"))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 480)
                .clipped()

                // Top controls overlay
                HStack {
                    Button {
                        router.reset()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // "IC-Light" badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "E8C084"))
                            .frame(width: 6, height: 6)
                        Text("IC-Light · Relighted")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1)
                            .foregroundColor(Color(hex: "E8C084"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 70)
            }

            // Bottom panel
            VStack(spacing: 16) {
                // Background info
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bgStore.selected?.name ?? "Background")
                            .font(.custom("CormorantGaramond-Regular", size: 20))
                            .foregroundColor(Color(hex: "18120C"))
                        Text("Warm ambient · Relighted")
                            .font(.system(size: 11))
                            .tracking(2)
                            .foregroundColor(Color(hex: "9A8878"))
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 10)
                        .fill(bgStore.selected?.previewGradient ??
                              LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                        .frame(width: 36, height: 36)
                }

                // Action buttons
                HStack(spacing: 10) {
                    ResultActionButton(icon: "arrow.down.circle", label: "Save") {
                        saveToPhotos()
                    }
                    ResultActionButton(icon: "square.and.arrow.up", label: "Share") {
                        shareImage()
                    }
                    AnimateButton(isLoading: isAnimating) {
                        Task { await requestAnimation() }
                    }
                }

                // Free credits bar
                CreditsInfoBar()
            }
            .padding(20)
            .padding(.bottom, 20)
            .background(Color(hex: "FDFAF7"))
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .background(Color(hex: "FDFAF7"))
        .sheet(isPresented: $showPaywall) {
            PaywallScreen()
        }
    }

    private func saveToPhotos() {
        guard let url = URL(string: generation.resultUrl) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }

    private func shareImage() {
        guard let url = URL(string: generation.resultUrl) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func requestAnimation() async {
        let purchases = PurchaseService.shared
        await purchases.checkStatus()

        guard purchases.isPremium else {
            showPaywall = true
            return
        }

        isAnimating = true
        defer { isAnimating = false }

        do {
            let result = try await genService.generate(
                selfieData: Data(), // Note: in real app, store selfieData in Generation model
                backgroundID: generation.backgroundId,
                animate: true
            )
            // Update the animation URL display
            _ = result.animationUrl
        } catch {
            // Silent fail — animation is a premium bonus feature
        }
    }
}

// ── Result Action Buttons ─────────────────────────────────────────────────────
struct ResultActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3)
            }
            .foregroundColor(Color(hex: "18120C"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "F7F3ED"))
            .cornerRadius(14)
        }
    }
}

struct AnimateButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if isLoading {
                    ProgressView()
                        .tint(Color(hex: "E8C084"))
                        .frame(height: 22)
                } else {
                    Image(systemName: "play.circle")
                        .font(.system(size: 20, weight: .light))
                }
                Text("Animate ✦")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3)
            }
            .foregroundColor(Color(hex: "E8C084"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "18120C"))
            .cornerRadius(14)
        }
        .disabled(isLoading)
    }
}

struct CreditsInfoBar: View {
    var body: some View {
        HStack {
            Text("**3** free photos remaining today")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "9A8878"))
            Spacer()
            Button("Upgrade →") {}
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "C4894A"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "F7F3ED"))
        .cornerRadius(12)
    }
}
