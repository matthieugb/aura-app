import SwiftUI
import RevenueCat

@main
struct AURAApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var router = AppRouter()

    init() {
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    SplashScreen()
                } else if auth.session == nil {
                    SplashScreen(showOnboarding: true)
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
                                case .videoResult(let url):
                                    VideoResultScreen(videoUrl: url)
                                case .videoProcessing(let imageUrl, let prompt, let model):
                                    VideoProcessingScreen(imageUrl: imageUrl, prompt: prompt, model: model)
                                }
                            }
                    }
                    .environmentObject(router)
                    .environmentObject(CreditsService.shared)
                }
            }
            .onChange(of: auth.session) { _, newSession in
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
