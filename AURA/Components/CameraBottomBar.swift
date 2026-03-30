import SwiftUI

// Stub — will be replaced in Task 6
struct CameraBottomBar: View {
    let onCapture: () -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack {
            Button("Capture", action: onCapture)
                .buttonStyle(PrimaryButtonStyle())
                .padding()
        }
        .background(Color(hex: "0D0B09").opacity(0.95))
    }
}
