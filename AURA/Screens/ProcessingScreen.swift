import SwiftUI

struct ProcessingScreen: View {
    let request: GenerationRequest
    @StateObject private var genService = GenerationService.shared
    @EnvironmentObject private var router: AppRouter
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Floating preview card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "C4894A").opacity(0.3), Color(hex: "18120C")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 220, height: 280)

                    if let firstPhoto = request.selfiePhotos.first,
                       let img = UIImage(data: firstPhoto) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 280)
                            .opacity(0.5)
                    }

                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color(hex: "C4894A").opacity(0.3), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: 220, height: 280)
                        .modifier(SweepModifier())
                }
                .frame(width: 220, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.bottom, 48)

                Text("Creating your scene")
                    .font(.custom("CormorantGaramond-Light", size: 28))
                    .foregroundColor(.white)
                    .tracking(2)
                    .padding(.bottom, 8)

                Text("THIS TAKES ~20 SECONDS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(4)
                    .foregroundColor(Color(hex: "9A8878"))
                    .padding(.bottom, 8)

                // Prompt preview
                Text("« \(request.prompt) »")
                    .font(.custom("CormorantGaramond-LightItalic", size: 15))
                    .foregroundColor(Color(hex: "C4894A").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                // Steps
                VStack(spacing: 0) {
                    ProcessingStep(
                        label: "Analysing your photos",
                        state: stepState(for: .generating)
                    )
                    ProcessingStep(
                        label: "Creating your scene",
                        state: stepState(for: .finalizing)
                    )
                    ProcessingStep(
                        label: "Finalising result",
                        state: stepState(for: .done(""))
                    )
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task { await runGeneration() }
        .alert("Generation failed", isPresented: .constant(errorMessage != nil)) {
            Button("Back") { errorMessage = nil; router.pop() }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func stepState(for target: GenerationService.GenerationProgress) -> ProcessingStep.StepState {
        let order: [GenerationService.GenerationProgress] = [.generating, .finalizing, .done("")]
        guard let targetIdx = order.firstIndex(of: target),
              let currentIdx = order.firstIndex(of: currentProgressKey) else { return .pending }
        if currentIdx > targetIdx { return .done }
        if currentIdx == targetIdx { return .active }
        return .pending
    }

    private var currentProgressKey: GenerationService.GenerationProgress {
        switch genService.progress {
        case .idle, .generating: return .generating
        case .finalizing, .animating: return .finalizing
        case .done, .failed: return .done("")
        }
    }

    private func runGeneration() async {
        do {
            let result = try await genService.generate(request: request)
            var gen = Generation(
                id: result.generationId,
                prompt: request.prompt,
                resultUrls: result.resultUrls,
                animationUrl: result.animationUrl,
                status: "done",
                createdAt: Date()
            )
            gen.ratio = request.ratio
            router.push(.pick(gen))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ── Processing Step ───────────────────────────────────────────────────────────
struct ProcessingStep: View {
    enum StepState { case pending, active, done }
    let label: String
    let state: StepState

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .overlay(
                    state == .active
                        ? Circle()
                            .stroke(Color(hex: "C4894A").opacity(0.25), lineWidth: 5)
                            .animation(.easeInOut(duration: 0.9).repeatForever(), value: state == .active)
                        : nil
                )

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(labelColor)

            Spacer()

            if state == .done {
                Text("✓").font(.system(size: 12)).foregroundColor(Color(hex: "C4894A"))
            }
        }
        .padding(.vertical, 16)
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .bottom)
    }

    var dotColor: Color {
        switch state {
        case .pending: return .white.opacity(0.15)
        case .active, .done: return Color(hex: "C4894A")
        }
    }
    var labelColor: Color {
        switch state {
        case .pending: return .white.opacity(0.4)
        case .active: return .white.opacity(0.9)
        case .done: return .white.opacity(0.8)
        }
    }
}

// ── Animations ────────────────────────────────────────────────────────────────
struct FloatModifier: ViewModifier {
    @State private var floating = false
    func body(content: Content) -> some View {
        content.offset(y: floating ? -8 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { floating = true }
            }
    }
}

struct SweepModifier: ViewModifier {
    @State private var offset: CGFloat = -220
    func body(content: Content) -> some View {
        content.offset(x: offset).clipped()
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { offset = 220 }
            }
    }
}
