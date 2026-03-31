import SwiftUI

enum AppRoute: Hashable {
    case captureMode
    case camera(CaptureMode, OutputRatio)
    case prompt([Data], OutputRatio)
    case pick(Generation)
    case gallery
    case processing(GenerationRequest)
    case result(String, Generation)
    case animate(String, Generation)
    case videoResult(String)
    case videoProcessing(String, String, GenerationModel)  // imageUrl, prompt, model
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: AppRoute) { path.append(route) }
    func pop() { guard !path.isEmpty else { return }; path.removeLast() }
    func reset() { path = NavigationPath() }
}
