import SwiftUI
import PhotosUI

enum CaptureMode {
    case pose      // 1 photo — exact pose preserved
    case identity  // 3-5 photos — AI learns the face, prompt the pose
}

struct CaptureModeScreen: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var credits: CreditsService
    @State private var ratio: OutputRatio = .portrait
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPicker = false

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "C4894A").opacity(0.1), .clear],
                center: .top, startRadius: 0, endRadius: 300
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header — centered
                VStack(spacing: 12) {
                    Text("AURA")
                        .font(.custom("CormorantGaramond-Light", size: 36))
                        .foregroundColor(.white)
                        .tracking(12)
                    Text("AI STUDIO")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "C4894A").opacity(0.8))
                        .tracking(6)
                    Rectangle()
                        .fill(Color(hex: "C4894A"))
                        .frame(width: 30, height: 1)
                    Text("How do you want to shoot?")
                        .font(.custom("CormorantGaramond-LightItalic", size: 18))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

                // Format picker
                RatioPicker(selection: $ratio)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                // Cards
                VStack(spacing: 14) {
                    ModeCard(
                        icon: "photo.on.rectangle",
                        title: "Importer une photo",
                        subtitle: "Depuis la galerie",
                        description: "Utilisez une photo déjà prise.",
                        tag: "Rapide",
                        tagColor: Color(hex: "C4894A")
                    ) {
                        showPicker = true
                    }

                    ModeCard(
                        icon: "person.crop.square",
                        title: "Selfie",
                        subtitle: "1 photo",
                        description: "Pour garder la même pose & tête ensuite.",
                        tag: Optional<String>.none,
                        tagColor: Color(hex: "C4894A")
                    ) {
                        router.push(.camera(.pose, ratio))
                    }

                    ModeCard(
                        icon: "person.crop.rectangle.stack",
                        title: "Visage scan",
                        subtitle: "3 – 5 photos",
                        description: "Pour pouvoir vous mettre dans n'importe quelle situation.",
                        tag: "Meilleure qualité",
                        tagColor: Color(hex: "7BAB8B")
                    ) {
                        router.push(.camera(.identity, ratio))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .overlay(alignment: .topTrailing) {
                CreditsIndicator()
                    .padding(.trailing, 24)
                    .padding(.top, 60)
            }
        }
        .navigationBarHidden(true)
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem, perform: { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    router.push(.prompt([data], ratio))
                }
                pickerItem = nil
            }
        })
    }
}

private struct RatioPicker: View {
    @Binding var selection: OutputRatio

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OutputRatio.allCases, id: \.self) { r in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = r }
                } label: {
                    VStack(spacing: 5) {
                        RatioIcon(ratio: r, selected: selection == r)
                        Text(r.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.5)
                            .foregroundColor(selection == r ? Color(hex: "C4894A") : .white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selection == r ? Color(hex: "C4894A").opacity(0.12) : Color.white.opacity(0.001))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct RatioIcon: View {
    let ratio: OutputRatio
    let selected: Bool

    var w: CGFloat {
        switch ratio {
        case .portrait:  return 14
        case .square:    return 20
        case .landscape: return 26
        }
    }
    var h: CGFloat {
        switch ratio {
        case .portrait:  return 22
        case .square:    return 20
        case .landscape: return 16
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .stroke(selected ? Color(hex: "C4894A") : Color.white.opacity(0.3), lineWidth: 1.5)
            .frame(width: w, height: h)
    }
}

private struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let tag: String?
    let tagColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .ultraLight))
                    .foregroundColor(tagColor)
                    .frame(width: 44)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.custom("CormorantGaramond-Regular", size: 20))
                            .foregroundColor(.white)
                        if let tag {
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1)
                                .foregroundColor(tagColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(tagColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(Color(hex: "C4894A").opacity(0.7))
                        .tracking(1)
                    Text(description)
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.top, 4)
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
