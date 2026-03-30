import UIKit
import Photos

final class ImageSaver: NSObject {
    private var completion: ((Bool) -> Void)?

    func save(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    completion(false)
                    return
                }
                UIImageWriteToSavedPhotosAlbum(
                    image, self, #selector(self.imageSaveCompleted(_:error:contextInfo:)), nil
                )
            }
        }
    }

    @objc private func imageSaveCompleted(
        _ image: UIImage, error: Error?, contextInfo: UnsafeRawPointer
    ) {
        completion?(error == nil)
    }
}
