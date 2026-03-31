import SwiftUI
import AVFoundation

struct AnimateScreen: View {
    let imageUrl: String
    let generation: Generation
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var credits: CreditsService
    @StateObject private var genService = GenerationService.shared

    @State private var soundOption: SoundOption = .none
    @State private var duration: Int = 5
    @State private var action: String = ""
    @FocusState private var actionFocused: Bool

    private let actionSuggestions = [
        "Slow zoom in",
        "Camera pulls back slowly",
        "Turns head toward camera",
        "Laughing, raises a glass",
        "Wind moves through hair",
        "Looks out the window",
    ]

    private var selectedModel: GenerationModel {
        switch soundOption {
        case .none:    return duration == 5 ? .klingV25Video5s : .klingV25Video10s
        case .ambient: return duration == 5 ? .klingV3Video5s  : .klingV3Video10s
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────────────────
                    ZStack {
                        HStack {
                            Button { router.pop() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .light))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 6) {
                            Text("Créer une vidéo")
                                .font(.custom("CormorantGaramond-Light", size: 28))
                                .foregroundColor(.white)
                                .tracking(4)
                            Rectangle()
                                .fill(Color(hex: "C4894A"))
                                .frame(width: 24, height: 1)
                        }
                    }
                    .padding(.top, 68)
                    .padding(.bottom, 24)

                    // ── Image preview ────────────────────────────────────
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            ZStack { Color(hex: "2A1F14"); ProgressView().tint(Color(hex: "C4894A")) }
                        }
                    }
                    .frame(width: 140, height: 186)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "C4894A").opacity(0.3), lineWidth: 1))

                    Text("La vidéo commencera par cette image")
                        .font(.custom("CormorantGaramond-LightItalic", size: 13))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(0.5)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    // ── Action box ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("ACTION")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(Color(hex: "C4894A").opacity(0.7))
                                    .tracking(3)
                                Text("· facultatif")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.25))
                                    .tracking(1)
                            }
                            TextField("Raising a glass, laughing…", text: $action, axis: .vertical)
                                .font(.custom("CormorantGaramond-Regular", size: 18))
                                .foregroundColor(.white)
                                .tint(Color(hex: "C4894A"))
                                .lineLimit(2...3)
                                .focused($actionFocused)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(actionFocused ? Color(hex: "C4894A").opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1))
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(actionSuggestions, id: \.self) { s in
                                    Button { action = s } label: {
                                        Text(s)
                                            .font(.custom("DMSans-Regular", size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(Color.white.opacity(0.07))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    // ── Sound options ────────────────────────────────────
                    VStack(spacing: 10) {
                        SoundOptionCard(
                            icon: "speaker.slash",
                            title: "Sans son",
                            subtitle: "Motion cinématique · Kling 2.5",
                            credits: duration == 5 ? 6 : 11,
                            isSelected: soundOption == .none
                        ) { soundOption = .none }

                        SoundOptionCard(
                            icon: "waveform",
                            title: "Son ambiant",
                            subtitle: "Sons de scène générés · Kling 3",
                            credits: duration == 5 ? 10 : 18,
                            isSelected: soundOption == .ambient
                        ) { soundOption = .ambient }

                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // ── Duration toggle ──────────────────────────────────
                    HStack(spacing: 0) {
                        ForEach([5, 10], id: \.self) { d in
                            Button { duration = d } label: {
                                Text("\(d)s")
                                    .font(.custom("DMSans-Medium", size: 14))
                                    .foregroundColor(duration == d ? Color(hex: "18120C") : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(duration == d ? Color(hex: "C4894A") : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // ── Generate button ──────────────────────────────────
                    let canGenerate = true
                    Button {
                        guard canGenerate else { return }
                        let videoPrompt = action.trimmingCharacters(in: .whitespaces).isEmpty
                            ? generation.prompt
                            : "\(generation.prompt), \(action.trimmingCharacters(in: .whitespaces))"
                        router.push(.videoProcessing(imageUrl, videoPrompt, selectedModel))
                    } label: {
                        HStack(spacing: 8) {
                            Text("Générer")
                                .font(.custom("DMSans-Medium", size: 16))
                            HStack(spacing: 4) {
                                Image(systemName: "circle.hexagongrid.fill").font(.system(size: 11))
                                Text("\(selectedModel.creditCost) crédits")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "18120C").opacity(0.55))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color(hex: "18120C").opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .foregroundColor(Color(hex: "18120C"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canGenerate ? Color(hex: "C4894A") : Color(hex: "C4894A").opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .disabled(!canGenerate)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                }
            }
        }
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.2), value: soundOption)
    }
}
