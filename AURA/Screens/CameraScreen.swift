import SwiftUI

struct CameraScreen: View {
    let mode: CaptureMode
    let ratio: OutputRatio
    @StateObject private var camera = CameraManager()
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var credits: CreditsService

    @State private var fillLightOn = false
    @State private var capturedPhotos: [UIImage] = []

    private var maxPhotos: Int { mode == .pose ? 1 : 5 }
    private var minPhotos: Int { mode == .pose ? 1 : 3 }

    // Guided positions for identity scan
    private let scanPositions = [
        (label: "Face",         instruction: "Regardez droit devant"),
        (label: "Profil gauche", instruction: "Tournez la tête à gauche"),
        (label: "Profil droit",  instruction: "Tournez la tête à droite"),
        (label: "3/4 gauche",   instruction: "Légèrement à gauche"),
        (label: "3/4 droit",    instruction: "Légèrement à droite"),
    ]

    private var currentPosition: (label: String, instruction: String)? {
        guard mode == .identity, capturedPhotos.count < scanPositions.count else { return nil }
        return scanPositions[capturedPhotos.count]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camera.captureSession)
                .ignoresSafeArea()

            // Fill light overlay
            if fillLightOn {
                Color.white
                    .opacity(0.82)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Letterbox overlay for landscape/square ratios
            if ratio != .portrait {
                GeometryReader { geo in
                    let ovalH = ratio.ovalHeight
                    let centerY = geo.size.height / 2
                    let stripH = max(0, centerY - ovalH / 2 - 16)
                    VStack(spacing: 0) {
                        Color.white.opacity(0.88)
                            .frame(height: stripH)
                        Spacer()
                        Color.white.opacity(0.88)
                            .frame(height: stripH)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Frame guide
            OvalFrameGuide(ratio: ratio)

            // Top bar
            VStack {
                ZStack {
                    // Back
                    HStack {
                        Button { router.pop() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .light))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        Spacer()
                        // Camera controls right side
                        HStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) { fillLightOn.toggle() }
                            } label: {
                                Image(systemName: fillLightOn ? "sun.max.fill" : "sun.max")
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundColor(fillLightOn ? Color(hex: "C4894A") : .white)
                                    .frame(width: 36, height: 36)
                                    .background(fillLightOn ? Color(hex: "C4894A").opacity(0.18) : Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            Button { camera.flipCamera() } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Centered title
                    VStack(spacing: 6) {
                        Text("AURA")
                            .font(.custom("CormorantGaramond-Light", size: 28))
                            .foregroundColor(.white)
                            .tracking(10)
                        Text(mode == .identity ? "VISAGE SCAN" : "SELFIE")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(hex: "C4894A").opacity(0.8))
                            .tracking(4)
                    }
                }
                .padding(.top, 70)

                Spacer()
            }
            .overlay(alignment: .topTrailing) {
                CreditsIndicator()
                    .padding(.trailing, 24)
                    .padding(.top, 18)
            }

            // Error
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

            // Position guidance (identity mode)
            if let pos = currentPosition {
                VStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Text(pos.label.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(3)
                            .foregroundColor(Color(hex: "C4894A"))
                        Text(pos.instruction)
                            .font(.custom("CormorantGaramond-LightItalic", size: 18))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 170)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: capturedPhotos.count)
            }

            // Bottom controls
            VStack {
                Spacer()

                // Photo thumbnails strip
                if !capturedPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(capturedPhotos.indices, id: \.self) { i in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: capturedPhotos[i])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Button {
                                        capturedPhotos.remove(at: i)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.4))
                                            .clipShape(Circle())
                                    }
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 12)
                }

                HStack(spacing: 24) {
                    // Counter
                    VStack(spacing: 2) {
                        Text("\(capturedPhotos.count)/\(maxPhotos)")
                            .font(.custom("CormorantGaramond-Regular", size: 22))
                            .foregroundColor(.white)
                        Text("photos")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(2)
                    }
                    .frame(width: 60)

                    // Shutter
                    Button {
                        if capturedPhotos.count < maxPhotos {
                            camera.capturePhoto()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                .frame(width: 84, height: 84)
                        }
                    }
                    .disabled(capturedPhotos.count >= maxPhotos)

                    // Continue button
                    Button {
                        let photosData = capturedPhotos.compactMap {
                            $0.jpegData(compressionQuality: 0.85)
                        }
                        router.push(.prompt(photosData, ratio))
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(capturedPhotos.count >= minPhotos ? Color(hex: "C4894A") : .white.opacity(0.2))
                            Text("next")
                                .font(.system(size: 10))
                                .foregroundColor(capturedPhotos.count >= minPhotos ? Color(hex: "C4894A") : .white.opacity(0.2))
                                .tracking(2)
                        }
                        .frame(width: 60)
                    }
                    .disabled(capturedPhotos.count < minPhotos)
                }
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .task { await camera.requestPermission() }
        .onChange(of: camera.capturedImage) { image in
            guard let image else { return }
            capturedPhotos.append(image)
            camera.capturedImage = nil
            // Pose mode: auto-advance after 1 photo
            if mode == .pose, let data = image.jpegData(compressionQuality: 0.85) {
                router.push(.prompt([data], ratio))
            }
        }
    }
}

