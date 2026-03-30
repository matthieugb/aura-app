import SwiftUI

struct SplashScreen: View {
    var showOnboarding: Bool = false
    @StateObject private var auth = AuthService.shared
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            // Background glow
            RadialGradient(
                colors: [Color(hex: "C4894A").opacity(0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 220
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Text("AURA")
                        .font(.custom("CormorantGaramond-Light", size: 72))
                        .foregroundColor(.white)
                        .tracking(18)

                    Rectangle()
                        .fill(Color(hex: "C4894A"))
                        .frame(width: 40, height: 1)

                    Text("Step into the light.")
                        .font(.custom("CormorantGaramond-LightItalic", size: 18))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)
                }

                Spacer()

                if showOnboarding {
                    VStack(spacing: 16) {
                        if isSigningIn {
                            ProgressView()
                                .tint(Color(hex: "C4894A"))
                                .frame(height: 56)
                        } else {
                            Button("Get Started") {
                                Task {
                                    isSigningIn = true
                                    try? await auth.signInAnonymously()
                                    isSigningIn = false
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

                        Button("I already have an account") {}
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}
