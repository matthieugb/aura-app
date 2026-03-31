import SwiftUI

struct PromptScreen: View {
    let photos: [Data]
    let ratio: OutputRatio
    @EnvironmentObject private var router: AppRouter
    @State private var lieu = ""
    @State private var action = ""
    @FocusState private var focusedField: PromptField?

    enum PromptField { case lieu, action }

    private var prompt: String {
        let l = lieu.trimmingCharacters(in: .whitespaces)
        let a = action.trimmingCharacters(in: .whitespaces)
        return a.isEmpty ? l : "\(l), \(a)"
    }

    // Crop state (single photo only)
    @State private var cropScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var cropOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let lieuSuggestions = [
        "Golden hour on a Capri terrace",
        "Candlelit Parisian brasserie",
        "Backstage at a fashion show",
        "Dusk light in a Marrakech riad",
        "Studio with dramatic shadows",
    ]

    private let actionSuggestions = [
        "Laughing, glass of wine in hand",
        "Reading a letter by the window",
        "Dancing slowly alone",
        "Staring into the distance",
        "Walking through a crowd",
    ]

    // Frame size matching the output ratio
    private var frameW: CGFloat {
        switch ratio {
        case .portrait:  return 180
        case .square:    return 280
        case .landscape: return 320
        }
    }
    private var frameH: CGFloat {
        switch ratio {
        case .portrait:  return 320
        case .square:    return 280
        case .landscape: return 180
        }
    }

    // Keep image covering the frame at all times
    private func clampedOffset(_ raw: CGSize) -> CGSize {
        let maxX = frameW * (cropScale - 1) / 2
        let maxY = frameH * (cropScale - 1) / 2
        return CGSize(
            width:  min(maxX, max(-maxX, raw.width)),
            height: min(maxY, max(-maxY, raw.height))
        )
    }

    // Render the cropped region to Data
    @MainActor
    private func buildCroppedPhotos() -> [Data] {
        guard photos.count == 1, let img = UIImage(data: photos[0]) else { return photos }
        let scale = cropScale
        let offset = cropOffset
        let fw = frameW
        let fh = frameH
        let cropView = Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale, anchor: .center)
            .offset(offset)
            .frame(width: fw, height: fh)
            .clipped()
        let renderer = ImageRenderer(content: cropView)
        renderer.scale = 3.0
        guard let cropped = renderer.uiImage,
              let data = cropped.jpegData(compressionQuality: 0.92) else { return photos }
        return [data]
    }

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────
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

                    VStack(spacing: 8) {
                        Text("Your Scene")
                            .font(.custom("CormorantGaramond-Light", size: 30))
                            .foregroundColor(.white)
                            .tracking(6)
                        Rectangle()
                            .fill(Color(hex: "C4894A"))
                            .frame(width: 24, height: 1)
                        Text("Décrivez votre univers")
                            .font(.custom("CormorantGaramond-LightItalic", size: 15))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(1)
                    }
                }
                .padding(.top, 68)
                .padding(.bottom, 24)

                // ── Photo ───────────────────────────────────────────────
                if photos.count == 1, let img = UIImage(data: photos[0]) {
                    // Crop frame
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(cropScale, anchor: .center)
                        .offset(cropOffset)
                        .frame(width: frameW, height: frameH)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "C4894A").opacity(0.45), lineWidth: 1)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    cropOffset = clampedOffset(CGSize(
                                        width: lastOffset.width + v.translation.width,
                                        height: lastOffset.height + v.translation.height
                                    ))
                                }
                                .onEnded { _ in lastOffset = cropOffset }
                        )
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { v in
                                    cropScale = max(1.0, lastScale * v)
                                    cropOffset = clampedOffset(cropOffset)
                                }
                                .onEnded { _ in
                                    lastScale = cropScale
                                    cropOffset = clampedOffset(cropOffset)
                                }
                        )
                        .padding(.bottom, 8)

                    // Crop hint
                    Text("GLISSER · PINCER POUR RECADRER")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.25))
                        .tracking(2)
                        .padding(.bottom, 20)

                } else {
                    // Multiple photos — simple scroll strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(photos.indices, id: \.self) { i in
                                if let img = UIImage(data: photos[i]) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 138)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color(hex: "C4894A").opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 24)
                }

                // ── Prompt inputs ────────────────────────────────────────
                VStack(spacing: 14) {
                    // ── Lieu (required) ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LIEU")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(hex: "C4894A").opacity(0.7))
                                .tracking(3)
                            TextField("Golden hour rooftop in Paris…", text: $lieu, axis: .vertical)
                                .font(.custom("CormorantGaramond-Regular", size: 18))
                                .foregroundColor(.white)
                                .tint(Color(hex: "C4894A"))
                                .lineLimit(2...3)
                                .focused($focusedField, equals: .lieu)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(focusedField == .lieu ? Color(hex: "C4894A").opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1))
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(lieuSuggestions, id: \.self) { s in
                                    Button { lieu = s } label: {
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

                    // ── Action (optional) ────────────────────────────────
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
                                .focused($focusedField, equals: .action)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(focusedField == .action ? Color(hex: "C4894A").opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1))
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
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                Spacer(minLength: 0)

                // ── Generate button ──────────────────────────────────────
                Button {
                    let croppedPhotos = buildCroppedPhotos()
                    let req = GenerationRequest(selfiePhotos: croppedPhotos, prompt: prompt, ratio: ratio, model: .nanobanana)
                    router.push(.processing(req))
                } label: {
                    HStack(spacing: 10) {
                        Text("Generate")
                            .font(.custom("DMSans-Medium", size: 16))
                        HStack(spacing: 4) {
                            Image(systemName: "circle.hexagongrid.fill")
                                .font(.system(size: 11))
                            Text("1 crédit")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "18120C").opacity(0.55))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "18120C").opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .foregroundColor(Color(hex: "18120C"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        prompt.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color(hex: "C4894A").opacity(0.3)
                            : Color(hex: "C4894A")
                    )
                    .clipShape(Capsule())
                }
                .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fermer") { focusedField = nil }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "C4894A"))
            }
        }
        .overlay(alignment: .topTrailing) {
            CreditsIndicator()
                .padding(.trailing, 24)
                .padding(.top, 18)
        }
    }
}
