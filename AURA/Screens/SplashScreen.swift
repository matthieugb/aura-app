import SwiftUI
import AuthenticationServices

struct SplashScreen: View {
    var showOnboarding: Bool = false
    @StateObject private var appleAuth = AppleSignInHandler.shared

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "C4894A").opacity(0.15), .clear],
                center: .center, startRadius: 0, endRadius: 220
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Text("AURA")
                        .font(.custom("CormorantGaramond-Light", size: 72))
                        .foregroundColor(.white)
                        .tracking(18)
                        .padding(.leading, 18)
                    Text("AI STUDIO")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "C4894A").opacity(0.8))
                        .tracking(6)
                        .padding(.leading, 6)
                    Rectangle()
                        .fill(Color(hex: "C4894A"))
                        .frame(width: 40, height: 1)
                    Text("Step into the light.")
                        .font(.custom("CormorantGaramond-LightItalic", size: 18))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                if showOnboarding {
                    VStack(spacing: 16) {
                        if let err = appleAuth.error {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "E07070"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        if appleAuth.isLoading {
                            ProgressView().tint(Color(hex: "C4894A")).frame(height: 52)
                        } else {
                            Button {
                                appleAuth.signIn()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Continuer avec Apple")
                                        .font(.custom("DMSans-Medium", size: 16))
                                }
                                .foregroundColor(Color(hex: "18120C"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color(hex: "C4894A"))
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal, 40)

                            Text("Aucune donnée partagée sans votre accord")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.25))
                                .tracking(0.3)
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
        }
    }
}
