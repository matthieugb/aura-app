import SwiftUI

struct CameraScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Camera").foregroundColor(.white)
        }
        .navigationBarHidden(true)
    }
}
