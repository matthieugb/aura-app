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
                        CameraScreen()
                            .navigationDestination(for: AppRoute.self) { route in
                                switch route {
                                case .camera:
                                    CameraScreen()
                                case .gallery:
                                    GalleryScreen()
                                case .processing(let req):
                                    ProcessingScreen(request: req)
                                case .result(let gen):
                                    ResultScreen(generation: gen)
                                }
                            }
                    }
                    .environmentObject(router)
                }
            }
        }
    }
}
