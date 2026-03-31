import AVFoundation
import SwiftUI

@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isAuthorized = false
    @Published var error: CameraError?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .front

    var captureSession: AVCaptureSession { session }

    enum CameraError: LocalizedError {
        case notAuthorized
        case setupFailed
        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Camera access denied. Please enable in Settings."
            case .setupFailed: return "Could not set up camera."
            }
        }
    }

    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        case .authorized:
            isAuthorized = true
        default:
            isAuthorized = false
            error = .notAuthorized
        }
        if isAuthorized { setupSession() }
    }

    private func setupSession() {
        session.beginConfiguration()
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: currentPosition
        ) else {
            error = .setupFailed
            session.commitConfiguration()
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            error = .setupFailed
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()

        Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func flipCamera() {
        currentPosition = currentPosition == .front ? .back : .front
        setupSession()
    }

    func stopSession() {
        Task.detached { [session] in
            session.stopRunning()
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        Task { @MainActor in
            let finalImage = self.currentPosition == .front
                ? image.withHorizontallyFlippedOrientation()
                : image
            self.capturedImage = finalImage
        }
    }
}

// UIImage mirroring helper
extension UIImage {
    func withHorizontallyFlippedOrientation() -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .leftMirrored)
    }
}
