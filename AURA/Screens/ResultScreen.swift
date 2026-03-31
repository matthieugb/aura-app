import SwiftUI

struct ResultScreen: View {
    let chosenUrl: String
    let generation: Generation
    @StateObject private var genService = GenerationService.shared
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var credits: CreditsService
    @State private var isAnimating = false
    @State private var showAnimateSheet = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Result image
            ZStack(alignment: .top) {
                AsyncImage(url: URL(string: chosenUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .empty:
                        ZStack {
                            Color(hex: "18120C")
                            ProgressView().tint(Color(hex: "C4894A"))
                        }
                    default:
                        Color(hex: "18120C")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 480)
                .clipped()

                // Top controls
                HStack {
                    Button { router.pop() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "E8C084")).frame(width: 6, height: 6)
                        Text("AI Generated")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1)
                            .foregroundColor(Color(hex: "E8C084"))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 70)
            }

            // Bottom panel
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(generation.prompt)
                            .font(.custom("CormorantGaramond-Regular", size: 18))
                            .foregroundColor(Color(hex: "18120C"))
                            .lineLimit(1)
                        Text("AURA AI Studio")
                            .font(.system(size: 11))
                            .tracking(2)
                            .foregroundColor(Color(hex: "9A8878"))
                    }
                    Spacer()
                    Button { router.pop() } label: {
                        Text("Other")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "C4894A"))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(hex: "C4894A").opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    ResultActionButton(icon: "arrow.down.circle", label: "Save") { saveToPhotos() }
                    ResultActionButton(icon: "square.and.arrow.up", label: "Share") { shareImage() }
                    AnimateButton(isLoading: isAnimating) {
                        showAnimateSheet = true
                    }
                }

                // Credits bar
                HStack {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "C4894A"))
                    Text("**\(credits.balance)** crédits restants")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "9A8878"))
                    Spacer()
                    Button("Recharger →") { }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "C4894A"))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(hex: "F7F3ED"))
                .cornerRadius(12)
            }
            .padding(20)
            .padding(.bottom, 20)
            .background(Color(hex: "FDFAF7"))
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .background(Color(hex: "FDFAF7"))
        .sheet(isPresented: $showAnimateSheet) {
            AnimateSheet(
                imageUrl: chosenUrl,
                prompt: generation.prompt
            ) { model, audioData in
                Task { await requestAnimation(model: model, audioData: audioData) }
            }
            .environmentObject(credits)
        }
    }

    private func saveToPhotos() {
        guard let url = URL(string: chosenUrl) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }

    private func shareImage() {
        guard let url = URL(string: chosenUrl) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func requestAnimation(model: GenerationModel, audioData: Data?) async {
        isAnimating = true
        errorMessage = nil
        defer { isAnimating = false }
        var req = GenerationRequest(selfiePhotos: [], prompt: generation.prompt, ratio: .portrait, model: model)
        req.audioData = audioData
        do {
            let result = try await genService.generate(request: req, animate: true)
            let gen = Generation(
                id: result.generationId,
                prompt: generation.prompt,
                resultUrls: result.resultUrls,
                animationUrl: result.animationUrl,
                status: "done",
                createdAt: Date()
            )
            router.push(.pick(gen))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ── Shared components ─────────────────────────────────────────────────────────
struct ResultActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 20, weight: .light))
                Text(label).font(.system(size: 10, weight: .medium)).tracking(3)
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
                    ProgressView().tint(Color(hex: "E8C084")).frame(height: 22)
                } else {
                    Image(systemName: "play.circle").font(.system(size: 20, weight: .light))
                }
                Text("Animate ✦").font(.system(size: 10, weight: .medium)).tracking(3)
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
