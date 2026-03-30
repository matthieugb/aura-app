import SwiftUI

struct ProcessingScreen: View {
    let request: GenerationRequest

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()
            Text("Processing...").foregroundColor(.white)
        }
        .navigationBarHidden(true)
    }
}
