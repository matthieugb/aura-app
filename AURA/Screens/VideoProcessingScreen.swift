import SwiftUI

struct VideoProcessingScreen: View {
    let imageUrl: String
    let prompt: String
    let model: GenerationModel

    @EnvironmentObject private var router: AppRouter
    @StateObject private var genService = GenerationService.shared
    @State private var errorMessage: String?
    @State private var elapsed = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                // Image preview with sweep animation
                ZStack {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Color(hex: "2A1F14")
                        }
                    }
                    .frame(width: 140, height: 186)

                    // Sweep highlight (only during generation)
                    if errorMessage == nil {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, Color(hex: "C4894A").opacity(0.35), .clear],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: 140, height: 186)
                            .modifier(SweepModifier())
                    }
                }
                .frame(width: 140, height: 186)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "C4894A").opacity(0.3), lineWidth: 1))
                .padding(.bottom, 48)

                // Status
                if let err = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.red.opacity(0.7))

                        Text("Erreur")
                            .font(.custom("CormorantGaramond-Light", size: 26))
                            .foregroundColor(.white)
                            .tracking(3)

                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            errorMessage = nil
                            Task { await generate() }
                        } label: {
                            Text("Réessayer")
                                .font(.custom("DMSans-Medium", size: 15))
                                .foregroundColor(Color(hex: "18120C"))
                                .frame(width: 160, height: 48)
                                .background(Color(hex: "C4894A"))
                                .clipShape(Capsule())
                        }

                        Button { router.pop() } label: {
                            Text("Annuler")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(Color(hex: "C4894A"))
                            .padding(.bottom, 8)

                        Text("Création de la vidéo…")
                            .font(.custom("CormorantGaramond-Light", size: 26))
                            .foregroundColor(.white)
                            .tracking(3)

                        Text("« \(prompt) »")
                            .font(.custom("CormorantGaramond-LightItalic", size: 14))
                            .foregroundColor(Color(hex: "C4894A").opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                            .padding(.top, 4)

                        Text(elapsedLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.25))
                            .tracking(2)
                            .padding(.top, 8)
                    }
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task { await generate() }
        .onDisappear { timer?.invalidate() }
    }

    private var elapsedLabel: String {
        if elapsed < 60 { return "\(elapsed)s — peut prendre 1 à 3 min" }
        let m = elapsed / 60
        let s = elapsed % 60
        return "\(m)m\(s > 0 ? "\(s)s" : "") écoulées"
    }

    private func startTimer() {
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
        }
    }

    private func generate() async {
        startTimer()
        var req = GenerationRequest(selfiePhotos: [], prompt: prompt, ratio: .portrait, model: model)
        req.animateSourceUrl = imageUrl
        do {
            let result = try await genService.generate(request: req, animate: true)
            timer?.invalidate()
            if let videoUrl = result.animationUrl ?? result.resultUrls.first {
                router.push(.videoResult(videoUrl))
            } else {
                errorMessage = "Aucune vidéo reçue."
            }
        } catch {
            timer?.invalidate()
            errorMessage = error.localizedDescription
        }
    }
}
