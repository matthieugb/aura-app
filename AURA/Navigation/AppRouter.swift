import SwiftUI

enum AppRoute: Hashable {
    case camera
    case gallery
    case processing(GenerationRequest)
    case result(Generation)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func reset() {
        path = NavigationPath()
    }
}
