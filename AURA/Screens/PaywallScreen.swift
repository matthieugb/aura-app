import SwiftUI
import RevenueCat

struct PaywallScreen: View {
    @StateObject private var purchases = PurchaseService.shared
    @EnvironmentObject private var credits: CreditsService
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .recharge

    enum Tab { case recharge, abonnement }

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "C4894A").opacity(0.08), .clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Header
                VStack(spacing: 6) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "C4894A"))
                    Text("Crédits AURA")
                        .font(.custom("CormorantGaramond-Light", size: 30))
                        .foregroundColor(.white)
                        .tracking(4)
                    Text("1 crédit · 1 portrait ou 1 animation")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "9A8878"))
                        .tracking(0.5)
                }
                .padding(.top, 4)
                .padding(.bottom, 20)

                // Tabs
                HStack(spacing: 0) {
                    TabButton(title: "Recharges", selected: tab == .recharge) { tab = .recharge }
                    TabButton(title: "Abonnements", selected: tab == .abonnement) { tab = .abonnement }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Cards
                ScrollView {
                    VStack(spacing: 10) {
                        if tab == .recharge {
                            // Essai pack (once only)
                            if !purchases.hasUsedEssai {
                                PackCard(pack: essaiPack, badgeText: "1 fois seulement") {
                                    Task { await purchases.purchase(productId: essaiPack.id) }
                                }
                            }
                            ForEach(rechargePacks) { pack in
                                PackCard(pack: pack) {
                                    Task { await purchases.purchase(productId: pack.id) }
                                }
                            }
                        } else {
                            ForEach(subscriptionPacks.filter { $0.id != purchases.activeSubscriptionId }) { pack in
                                PackCard(pack: pack, badgeText: nil) {
                                    Task { await purchases.purchase(productId: pack.id) }
                                }
                            }
                            Text("Résiliation à tout moment depuis les réglages de l'App Store.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.2))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 0)

                // Error
                if let error = purchases.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 8)
                }

                // Loading
                if purchases.isLoading {
                    ProgressView()
                        .tint(Color(hex: "C4894A"))
                        .padding(.bottom, 12)
                }

                // Restore
                Button {
                    Task { await purchases.restore() }
                } label: {
                    Text("Restaurer les achats")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "9A8878"))
                }
                .padding(.bottom, 40)
            }
        }
        .onChange(of: credits.balance) { _ in dismiss() }
    }
}

private struct TabButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundColor(selected ? Color(hex: "18120C") : .white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selected ? Color(hex: "C4894A") : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

private struct PackCard: View {
    let pack: CreditPack
    var badgeText: String? = nil
    let onBuy: () -> Void

    var body: some View {
        Button(action: onBuy) {
            HStack(spacing: 16) {
                // Credits
                VStack(spacing: 1) {
                    Text("\(pack.credits)")
                        .font(.custom("CormorantGaramond-Regular", size: 26))
                        .foregroundColor(Color(hex: "C4894A"))
                    Text("cr")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "C4894A").opacity(0.6))
                }
                .frame(width: 48)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(pack.title)
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(.white)
                        if let badge = pack.tag ?? badgeText {
                            Text(badge)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(hex: "18120C"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "C4894A"))
                                .clipShape(Capsule())
                        }
                    }
                    Text(pack.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }

                Spacer()

                Text(pack.price)
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
