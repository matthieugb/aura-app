import SwiftUI
import RevenueCat

struct PaywallScreen: View {
    @StateObject private var purchases = PurchaseService.shared
    @EnvironmentObject private var credits: CreditsService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "100C08").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "C4894A").opacity(0.10), .clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Header — proche du haut
                VStack(spacing: 4) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "C4894A"))
                    Text(NSLocalizedString("Crédits AURA", comment: ""))
                        .font(.custom("DMSans-Medium", size: 24))
                        .foregroundColor(.white)
                        .tracking(4)
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("3")
                            Image(systemName: "circle.hexagongrid.fill")
                            Text("2 portraits")
                        }
                        HStack(spacing: 4) {
                            Text("4")
                            Image(systemName: "circle.hexagongrid.fill")
                            Text(NSLocalizedString("paywall_1_video", comment: ""))
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "9A8878"))
                    .tracking(0.5)
                }
                .padding(.top, 16)
                .padding(.bottom, 28)

                Spacer(minLength: 0)

                // All offers
                VStack(spacing: 0) {
                    // Section: Recharges
                    SectionLabel(title: NSLocalizedString("Recharges", comment: ""))
                    VStack(spacing: 8) {
                        ForEach(purchases.rechargePacks.filter { $0.id != "aura_test_pack" || !purchases.hasTestPack }) { pack in
                            PackCard(pack: pack) {
                                Task { await purchases.purchase(productId: pack.id) }
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    // Section: Abonnements
                    SectionLabel(title: NSLocalizedString("Abonnements", comment: ""))
                    VStack(spacing: 8) {
                        ForEach(purchases.subscriptionPacks.filter { $0.id != purchases.activeSubscriptionId }) { pack in
                            PackCard(pack: pack, badgeText: nil) {
                                Task { await purchases.purchase(productId: pack.id) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                // Error
                if let error = purchases.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 6)
                }

                if purchases.isLoading {
                    ProgressView()
                        .tint(Color(hex: "C4894A"))
                        .padding(.vertical, 6)
                }

                Text(NSLocalizedString("Résiliation à tout moment depuis les réglages de l'App Store.", comment: ""))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.15))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                Button {
                    Task { await purchases.restore() }
                } label: {
                    Text(NSLocalizedString("Restaurer les achats", comment: ""))
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(Color(hex: "9A8878").opacity(0.6))
                }
                .padding(.top, 12)

                // Legal links required by App Store
                HStack(spacing: 16) {
                    Link(NSLocalizedString("paywall_privacy_policy", comment: ""), destination: URL(string: "https://matthieugb.github.io/aura-app/privacy")!)
                    Text("·")
                    Link(NSLocalizedString("paywall_terms_of_use", comment: ""), destination: URL(string: "https://matthieugb.github.io/aura-app/terms")!)
                }
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "9A8878").opacity(0.5))
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .onChange(of: credits.balance) { newBalance in if newBalance > 0 { dismiss() } }
        .onChange(of: purchases.isPremium) { newVal in if newVal { dismiss() } }
        .onChange(of: purchases.hasTestPack) { newVal in if newVal { dismiss() } }
    }
}

private struct SectionLabel: View {
    let title: String
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "C4894A").opacity(0.7))
                .tracking(2)
            Rectangle()
                .fill(Color(hex: "C4894A").opacity(0.15))
                .frame(height: 1)
        }
        .padding(.bottom, 12)
    }
}


private struct PackCard: View {
    let pack: CreditPack
    var badgeText: String? = nil
    let onBuy: () -> Void

    var body: some View {
        Button(action: onBuy) {
            HStack(spacing: 12) {
                // Credits
                HStack(alignment: .center, spacing: 3) {
                    Text("\(pack.credits)")
                        .font(.custom("DMSans-Medium", size: 24))
                        .foregroundColor(Color(hex: "C4894A"))
                        .lineLimit(1)
                        .frame(width: 54, alignment: .trailing)
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "C4894A").opacity(0.7))
                        .frame(width: 14)
                }
                .frame(width: 72)

                HStack(spacing: 6) {
                    Text(pack.title)
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if let badge = pack.tag ?? badgeText {
                        Text(badge)
                            .font(.system(size: 8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(Color(hex: "18120C"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "C4894A"))
                            .clipShape(Capsule())
                    }
                }
                .layoutPriority(1)

                Spacer()

                Text(pack.price)
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "2A1F16"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
