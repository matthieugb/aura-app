import SwiftUI

struct PaywallScreen: View {
    @StateObject private var purchases = PurchaseService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "FDFAF7").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("AURA")
                        .font(.custom("CormorantGaramond-Light", size: 48))
                        .tracking(12)
                        .foregroundColor(Color(hex: "18120C"))

                    Rectangle()
                        .fill(Color(hex: "C4894A"))
                        .frame(width: 30, height: 1)

                    Text("Premium")
                        .font(.custom("CormorantGaramond-Regular", size: 22))
                        .tracking(4)
                        .foregroundColor(Color(hex: "9A8878"))
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                // Features list
                VStack(spacing: 0) {
                    PaywallFeatureRow(
                        icon: "play.circle",
                        title: "Kling Animations",
                        subtitle: "20 animated portraits per month"
                    )
                    PaywallFeatureRow(
                        icon: "photo.stack",
                        title: "Unlimited Photos",
                        subtitle: "No daily limit on generations"
                    )
                    PaywallFeatureRow(
                        icon: "star",
                        title: "Full Catalog",
                        subtitle: "8 premium backgrounds unlocked"
                    )
                    PaywallFeatureRow(
                        icon: "sparkles",
                        title: "Priority Processing",
                        subtitle: "Faster generation queue"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // CTA
                VStack(spacing: 12) {
                    if let error = purchases.errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await purchases.purchase() }
                    } label: {
                        if purchases.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(height: 20)
                        } else {
                            Text("Subscribe · $14.99 / month")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(purchases.isLoading)

                    Button {
                        Task { await purchases.restore() }
                    } label: {
                        Text("Restore purchases")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "9A8878"))
                    }
                    .disabled(purchases.isLoading)

                    Button("Maybe later") { dismiss() }
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "9A8878").opacity(0.6))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onChange(of: purchases.isPremium) { isPremium in
            if isPremium { dismiss() }
        }
    }
}

private struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(Color(hex: "C4894A"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "18120C"))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "9A8878"))
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .overlay(
            Rectangle()
                .fill(Color(hex: "EAE0D2"))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
