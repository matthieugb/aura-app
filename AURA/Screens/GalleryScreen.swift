import SwiftUI

struct GalleryScreen: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack {
            Text("Gallery")
            Button("Back") { router.pop() }
        }
        .navigationBarHidden(true)
    }
}
