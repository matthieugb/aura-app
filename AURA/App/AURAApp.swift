import SwiftUI
import RevenueCat

@main
struct AURAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthService.shared
    @StateObject private var router = AppRouter()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasGrantedAIConsent") private var hasGrantedAIConsent = false

    init() {
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if auth.isLoading {
                    Color(hex: "18120C").ignoresSafeArea()
                } else if auth.session == nil {
                    SplashScreen(showOnboarding: true)
                        .transition(.opacity)
                } else if !hasSeenOnboarding {
                    OnboardingScreen()
                        .transition(.opacity)
                } else if !hasGrantedAIConsent {
                    AIConsentView()
                        .transition(.opacity)
                } else {
                    NavigationStack(path: $router.path) {
                        CaptureModeScreen()
                            .navigationDestination(for: AppRoute.self) { route in
                                switch route {
                                case .captureMode:
                                    CaptureModeScreen()
                                case .camera(let mode, let ratio):
                                    CameraScreen(mode: mode, ratio: ratio)
                                case .prompt(let photos, let ratio):
                                    PromptScreen(photos: photos, ratio: ratio)
                                case .pick(let gen):
                                    PickScreen(generation: gen)
                                case .gallery:
                                    GalleryScreen()
                                case .processing(let req):
                                    ProcessingScreen(request: req)
                                case .result(let url, let gen):
                                    ResultScreen(chosenUrl: url, generation: gen)
                                case .animate(let url, let gen):
                                    AnimateScreen(imageUrl: url, generation: gen)
                                case .videoResult(let url, let ratio):
                                    VideoResultScreen(videoUrl: url, ratio: ratio)
                                case .videoProcessing(let imageUrl, let prompt, let model, let ratio):
                                    VideoProcessingScreen(imageUrl: imageUrl, prompt: prompt, model: model, ratio: ratio)
                                case .animateDirect(let data, let ratio):
                                    DirectAnimateScreen(imageData: data, ratio: ratio)
                                case .videoProcessingDirect(let data, let prompt, let model, let ratio):
                                    VideoProcessingScreen(imageData: data, prompt: prompt, model: model, ratio: ratio)
                                }
                            }
                    }
                    .environmentObject(router)
                    .environmentObject(CreditsService.shared)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: auth.isLoading)
            .animation(.easeInOut(duration: 0.3), value: auth.session == nil)
            .onChange(of: auth.session) { newSession in
                if let userId = newSession?.user.id.uuidString {
                    // Identify user in RevenueCat — required for webhook to credit the right user
                    Purchases.shared.logIn(userId) { _, _, _ in }
                } else {
                    Purchases.shared.logOut { _, _ in }
                }
            }
        }
    }
}
