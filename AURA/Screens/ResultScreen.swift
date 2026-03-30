import SwiftUI

struct ResultScreen: View {
    let generation: Generation
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack {
            Text("Result")
            Button("Done") { router.reset() }
        }
        .navigationBarHidden(true)
    }
}
