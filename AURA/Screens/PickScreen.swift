import SwiftUI

struct PickScreen: View {
    let generation: Generation
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var credits: CreditsService

    @State private var zoomedUrl: String? = nil
    // Zoom gesture state
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero
    @State private var lastZoomOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            // ── Main pick view ───────────────────────────────────────────
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Choisissez votre préférée")
                        .font(.custom("CormorantGaramond-Light", size: 26))
                        .foregroundColor(.white)
                        .tracking(2)
                        .multilineTextAlignment(.center)
                    Text("« \(generation.prompt) »")
                        .font(.custom("CormorantGaramond-LightItalic", size: 14))
                        .foregroundColor(Color(hex: "C4894A").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 70)
                .padding(.bottom, 24)

                // Two image cards — portrait side by side, others stacked
                let isPortrait = generation.ratio == .portrait
                let urls = Array(generation.resultUrls.prefix(2))

                Group {
                    if isPortrait {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(urls, id: \.self) { url in
                                ImageCardWithActions(
                                    url: url, ratio: generation.ratio,
                                    onZoom: { resetZoom(); withAnimation(.spring(response: 0.3)) { zoomedUrl = url } },
                                    onDownload: { downloadImage(url: url) },
                                    onNext: { router.push(.animate(url, generation)) }
                                )
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            ForEach(urls, id: \.self) { url in
                                ImageCardWithActions(
                                    url: url, ratio: generation.ratio,
                                    onZoom: { resetZoom(); withAnimation(.spring(response: 0.3)) { zoomedUrl = url } },
                                    onDownload: { downloadImage(url: url) },
                                    onNext: { router.push(.animate(url, generation)) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Regenerate button
                Button {
                    router.pop(); router.pop()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13))
                        Text("Regénérer")
                            .font(.custom("DMSans-Regular", size: 14))
                        HStack(spacing: 3) {
                            Image(systemName: "circle.hexagongrid.fill").font(.system(size: 10))
                            Text("1 crédit").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "C4894A").opacity(0.6))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: "C4894A").opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 48)
            }

            // ── Fullscreen zoom overlay ──────────────────────────────────
            if let url = zoomedUrl {
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 0) {
                    // Top bar
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                zoomedUrl = nil
                                resetZoom()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Button { downloadImage(url: url) } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()

                    // Zoomable image
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .scaleEffect(zoomScale, anchor: .center)
                                .offset(zoomOffset)
                                .gesture(
                                    DragGesture()
                                        .onChanged { v in
                                            zoomOffset = CGSize(
                                                width: lastZoomOffset.width + v.translation.width,
                                                height: lastZoomOffset.height + v.translation.height
                                            )
                                        }
                                        .onEnded { _ in lastZoomOffset = zoomOffset }
                                )
                                .simultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { v in zoomScale = max(1.0, lastZoomScale * v) }
                                        .onEnded { _ in lastZoomScale = zoomScale }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation(.spring()) { resetZoom() }
                                }
                        default:
                            ProgressView().tint(Color(hex: "C4894A"))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    Spacer()

                    // Bottom action
                    Button {
                        withAnimation(.spring(response: 0.3)) { zoomedUrl = nil }
                        router.push(.animate(url, generation))
                    } label: {
                        Text("Suivant →")
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(Color(hex: "18120C"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "C4894A"))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .navigationBarHidden(true)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: zoomedUrl != nil)
    }

    private func aspectRatio(for ratio: OutputRatio) -> CGFloat {
        switch ratio {
        case .portrait:  return 9/16
        case .square:    return 1
        case .landscape: return 16/9
        }
    }

    private func resetZoom() {
        zoomScale = 1.0
        lastZoomScale = 1.0
        zoomOffset = .zero
        lastZoomOffset = .zero
    }

    private func downloadImage(url: String) {
        guard let u = URL(string: url) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: u),
                  let img = UIImage(data: data) else { return }
            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        }
    }
}

// ── ImageCardWithActions ──────────────────────────────────────────────────────
private struct ImageCardWithActions: View {
    let url: String
    let ratio: OutputRatio
    let onZoom: () -> Void
    let onDownload: () -> Void
    let onNext: () -> Void

    private var ar: CGFloat {
        switch ratio {
        case .portrait:  return 9/16
        case .square:    return 1
        case .landscape: return 16/9
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onZoom) {
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .empty:
                        ZStack { Color(hex: "2A1F14"); ProgressView().tint(Color(hex: "C4894A")) }
                    default: Color(hex: "2A1F14")
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(ar, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "C4894A").opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                Button(action: onNext) {
                    Text("Suivant →")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(Color(hex: "18120C"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(hex: "C4894A"))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
