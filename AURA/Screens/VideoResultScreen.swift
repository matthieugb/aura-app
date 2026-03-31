import SwiftUI
import AVKit
import Photos

struct VideoResultScreen: View {
    let videoUrl: String
    @EnvironmentObject private var router: AppRouter
    @State private var player: AVPlayer?
    @State private var isSaving = false
    @State private var saved = false

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
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
                        Text("Votre vidéo")
                            .font(.custom("CormorantGaramond-Light", size: 28))
                            .foregroundColor(.white)
                            .tracking(4)
                        Rectangle()
                            .fill(Color(hex: "C4894A"))
                            .frame(width: 24, height: 1)
                    }
                }
                .padding(.top, 68)
                .padding(.bottom, 28)

                // ── Video player ─────────────────────────────────────────
                if let player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "C4894A").opacity(0.3), lineWidth: 1))
                        .padding(.horizontal, 40)
                        .onAppear { player.play() }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "2A1F14"))
                        ProgressView().tint(Color(hex: "C4894A"))
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9/16, contentMode: .fit)
                    .padding(.horizontal, 40)
                }

                Spacer()

                // ── Save button ──────────────────────────────────────────
                Button {
                    guard !isSaving && !saved else { return }
                    Task { await saveVideo() }
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView().tint(Color(hex: "18120C"))
                        } else {
                            Image(systemName: saved ? "checkmark" : "arrow.down.circle")
                                .font(.system(size: 15))
                            Text(saved ? "Sauvegardée" : "Sauvegarder")
                                .font(.custom("DMSans-Medium", size: 16))
                        }
                    }
                    .foregroundColor(Color(hex: "18120C"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "C4894A"))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                HStack(spacing: 32) {
                    Button { router.reset() } label: {
                        Text("Accueil")
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Button { router.pop(); router.pop() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 12))
                            Text("Regénérer")
                                .font(.custom("DMSans-Regular", size: 14))
                        }
                        .foregroundColor(.white.opacity(0.45))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .interactiveDismissDisabled(true)
        .onAppear {
            if let url = URL(string: videoUrl) {
                player = AVPlayer(url: url)
            }
        }
    }

    private func saveVideo() async {
        guard let url = URL(string: videoUrl) else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let (tempUrl, _) = try await URLSession.shared.download(from: url)
            // Copy to stable location before Photos accesses it
            let destUrl = FileManager.default.temporaryDirectory
                .appendingPathComponent("aura_video_\(Int(Date().timeIntervalSince1970)).mp4")
            try FileManager.default.copyItem(at: tempUrl, to: destUrl)
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { return }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destUrl)
            }
            try? FileManager.default.removeItem(at: destUrl)
            saved = true
        } catch {}
    }
}
