import SwiftUI
import AVFoundation

enum SoundOption { case none, ambient }

struct AnimateSheet: View {
    let imageUrl: String
    let prompt: String
    let onGenerate: (GenerationModel, Data?) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var credits: CreditsService

    @State private var soundOption: SoundOption = .none
    @State private var duration: Int = 5

    private var selectedModel: GenerationModel {
        switch soundOption {
        case .none:    return duration == 5 ? .klingV25Video5s : .klingV25Video10s
        case .ambient: return duration == 5 ? .klingV3Video5s  : .klingV3Video10s
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "18120C").ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Title
                HStack {
                    Text("Créer une vidéo")
                        .font(.custom("CormorantGaramond-Regular", size: 24))
                        .foregroundColor(.white)
                        .tracking(2)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "circle.hexagongrid.fill").font(.system(size: 11))
                        Text("\(selectedModel.creditCost) cr")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "C4894A"))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Sound options
                VStack(spacing: 10) {
                    SoundOptionCard(
                        icon: "speaker.slash",
                        title: "Sans son",
                        subtitle: "Motion cinématique · Kling 2.5",
                        credits: duration == 5 ? 6 : 11,
                        isSelected: soundOption == .none
                    ) { soundOption = .none }

                    SoundOptionCard(
                        icon: "waveform",
                        title: "Son ambiant",
                        subtitle: "Sons de scène générés · Kling 3",
                        credits: duration == 5 ? 10 : 18,
                        isSelected: soundOption == .ambient
                    ) { soundOption = .ambient }

                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Duration picker
                HStack(spacing: 0) {
                    ForEach([5, 10], id: \.self) { d in
                        Button { duration = d } label: {
                            Text("\(d)s")
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(duration == d ? Color(hex: "18120C") : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(duration == d ? Color(hex: "C4894A") : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                Spacer()

                // Generate button
                Button {
                    onGenerate(selectedModel, nil)
                    dismiss()
                } label: {
                    Text("Générer · \(selectedModel.creditCost) crédits")
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(Color(hex: "18120C"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "C4894A"))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: soundOption)
        .presentationDetents([.medium, .large])
    }
}

// ── Sound Option Card ─────────────────────────────────────────────────────────
struct SoundOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let credits: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(isSelected ? Color(hex: "18120C") : Color(hex: "C4894A"))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(isSelected ? Color(hex: "18120C") : .white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color(hex: "18120C").opacity(0.5) : .white.opacity(0.35))
                }

                Spacer()

                Text("\(credits) cr")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "18120C") : Color(hex: "C4894A"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isSelected ? Color(hex: "C4894A") : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1
            ))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// ── Voice Recorder ────────────────────────────────────────────────────────────
struct VoiceRecorderView: View {
    let maxSeconds: Int
    @Binding var isRecording: Bool
    @Binding var recordedData: Data?
    @Binding var recordingSeconds: Int

    @State private var recorder: AVAudioRecorder?
    @State private var timer: Timer?
    @State private var audioURL: URL?
    @State private var hasPermission = false

    var body: some View {
        VStack(spacing: 12) {
            // Waveform / status
            HStack(spacing: 4) {
                if isRecording {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "C4894A"))
                            .frame(width: 3, height: CGFloat.random(in: 8...24))
                            .animation(.easeInOut(duration: 0.3).repeatForever().delay(Double(i) * 0.05), value: isRecording)
                    }
                } else if recordedData != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "C4894A"))
                    Text("Enregistrement prêt")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("Appuie pour enregistrer ta voix")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(height: 32)

            // Timer
            if isRecording {
                Text("\(recordingSeconds)s / \(maxSeconds)s")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "C4894A"))
            }

            // Record / Stop button
            Button {
                if isRecording { stopRecording() } else { startRecording() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 20))
                    Text(isRecording ? "Stop" : recordedData != nil ? "Réenregistrer" : "Enregistrer")
                        .font(.custom("DMSans-Medium", size: 14))
                }
                .foregroundColor(isRecording ? .red : Color(hex: "C4894A"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                    isRecording ? Color.red.opacity(0.4) : Color(hex: "C4894A").opacity(0.3), lineWidth: 1
                ))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task { await requestPermission() }
    }

    private func requestPermission() async {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                hasPermission = granted
                continuation.resume()
            }
        }
    }

    private func startRecording() {
        guard hasPermission else { return }
        recordingSeconds = 0
        recordedData = nil
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aura_voice.m4a")
        audioURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            recordingSeconds += 1
            if recordingSeconds >= maxSeconds { stopRecording() }
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        if let url = audioURL {
            recordedData = try? Data(contentsOf: url)
        }
    }
}
