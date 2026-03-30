import SwiftUI

// Stub — will be replaced in Task 10
struct PaywallScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Text("AURA Premium")
                .font(.custom("CormorantGaramond-Regular", size: 36))
                .tracking(4)
                .foregroundColor(Color(hex: "18120C"))
            Text("Unlock Kling animations")
                .foregroundColor(Color(hex: "9A8878"))
            Button("Coming soon") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
        }
        .padding(32)
    }
}
