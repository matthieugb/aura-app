import SwiftUI

struct CameraScreen: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var bgStore = BackgroundStore.shared
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera preview
            CameraPreviewView(session: camera.captureSession)
                .ignoresSafeArea()

            // Active background preview tint
            if let bg = bgStore.selected {
                Rectangle()
                    .fill(bg.previewGradient)
                    .ignoresSafeArea()
                    .opacity(0.30)
                    .animation(.easeInOut(duration: 0.4), value: bgStore.selected?.id)
            }

            // Oval guide
            OvalFrameGuide()

            // Top bar
            VStack {
                HStack {
                    Text("AURA")
                        .font(.custom("CormorantGaramond-Regular", size: 22))
                        .foregroundColor(.white)
                        .tracking(6)
                    Spacer()
                    Button {
                        camera.flipCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 70)
                Spacer()
            }

            // Error overlay
            if let err = camera.error {
                VStack {
                    Spacer()
                    Text(err.localizedDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
            }

            // Bottom controls
            VStack {
                Spacer()
                CameraBottomBar(
                    onCapture: camera.capturePhoto,
                    onSeeAll: { router.push(.gallery) }
                )
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .task { await camera.requestPermission() }
        .onChange(of: camera.capturedImage) { image in
            guard let image,
                  let data = image.jpegData(compressionQuality: 0.85),
                  let bgID = bgStore.selected?.id else { return }
            router.push(.processing(GenerationRequest(selfieData: data, backgroundID: bgID)))
        }
    }
}
