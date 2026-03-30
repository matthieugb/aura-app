import SwiftUI

struct ProcessingScreen: View {
    let request: GenerationRequest
    @StateObject private var genService = GenerationService.shared
    @StateObject private var bgStore = BackgroundStore.shared
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Floating preview card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(bgStore.selected?.previewGradient ??
                              LinearGradient(colors: [Color(hex: "18120C")],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 220, height: 280)

                    // Light sweep animation
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color(hex: "C4894A").opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 220, height: 280)
                        .modifier(SweepModifier())
                }
                .modifier(FloatModifier())
                .padding(.bottom, 48)

                Text("Creating your light")
                    .font(.custom("CormorantGaramond-Light", size: 28))
                    .foregroundColor(.white)
                    .tracking(2)
                    .padding(.bottom, 8)

                Text("THIS TAKES ~15 SECONDS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(4)
                    .foregroundColor(Color(hex: "9A8878"))
                    .padding(.bottom, 48)

                // Steps
                VStack(spacing: 0) {
                    ProcessingStep(
                        label: "Removing background",
                        state: stepState(for: .removingBackground)
                    )
                    ProcessingStep(
                        label: "Adapting light with IC-Light",
                        state: stepState(for: .relighting)
                    )
                    ProcessingStep(
                        label: "Compositing final image",
                        state: stepState(for: .done(""))
                    )
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task { await runGeneration() }
    }

    private func stepState(for targetProgress: GenerationService.GenerationProgress) -> ProcessingStep.StepState {
        let order: [GenerationService.GenerationProgress] = [
            .removingBackground, .relighting, .done("")
        ]
        guard let targetIdx = order.firstIndex(of: targetProgress),
              let currentIdx = order.firstIndex(of: currentProgressKey) else {
            return .pending
        }
        if currentIdx > targetIdx { return .done }
        if currentIdx == targetIdx { return .active }
        return .pending
    }

    private var currentProgressKey: GenerationService.GenerationProgress {
        switch genService.progress {
        case .idle, .removingBackground: return .removingBackground
        case .relighting, .animating: return .relighting
        case .done, .failed: return .done("")
        }
    }

    private func runGeneration() async {
        do {
            let result = try await genService.generate(
                selfieData: request.selfieData,
                backgroundID: request.backgroundID
            )
            let gen = Generation(
                id: result.generationId,
                backgroundId: request.backgroundID,
                resultUrl: result.resultUrl,
                animationUrl: result.animationUrl,
                status: "done",
                createdAt: Date()
            )
            router.push(.result(gen))
        } catch {
            // Pop back to camera on error
            router.pop()
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
                Text("✓")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "C4894A"))
            }
        }
        .padding(.vertical, 16)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
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
        content
            .offset(y: floating ? -8 : 0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true)
                ) { floating = true }
            }
    }
}

struct SweepModifier: ViewModifier {
    @State private var offset: CGFloat = -220

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 2).repeatForever(autoreverses: false)
                ) { offset = 220 }
            }
    }
}
