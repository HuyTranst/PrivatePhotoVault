import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

/// Bộ điều phối mở native iOS Photos Picker hỗ trợ cả ẢNH và VIDEO
public struct PhotoPickerCoordinator: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    public let targetAlbumId: UUID
    public let onImportCompleted: (Int) -> Void
    
    public init(
        isPresented: Binding<Bool>,
        targetAlbumId: UUID,
        onImportCompleted: @escaping (Int) -> Void
    ) {
        self._isPresented = isPresented
        self.targetAlbumId = targetAlbumId
        self.onImportCompleted = onImportCompleted
    }
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0 // Cho phép chọn không giới hạn số lượng ảnh và video
        config.filter = .any(of: [.images, .videos]) // Hỗ trợ cả Ảnh và Video
        config.preferredAssetRepresentationMode = .current // Giữ nguyên độ phân giải và chất lượng gốc
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoPickerCoordinator
        
        public init(_ parent: PhotoPickerCoordinator) {
            self.parent = parent
        }
        
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true) {
                self.parent.isPresented = false
            }
            
            guard !results.isEmpty else { return }
            
            Task {
                var importedCount = 0
                var assetIdsToDelete: [String] = []
                
                for result in results {
                    if let assetId = result.assetIdentifier {
                        assetIdsToDelete.append(assetId)
                    }
                    
                    let provider = result.itemProvider
                    
                    // 1. Kiểm tra nếu là Video
                    if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                        if let videoURL = await self.loadVideoURL(from: provider) {
                            do {
                                _ = try await PhotoStorageManager.shared.importVideo(
                                    sourceURL: videoURL,
                                    originalFileName: provider.suggestedName.map { "\($0).mp4" },
                                    albumId: self.parent.targetAlbumId
                                )
                                importedCount += 1
                                try? FileManager.default.removeItem(at: videoURL)
                            } catch {
                                print("Lỗi nhập video: \(error.localizedDescription)")
                            }
                        }
                    }
                    // 2. Kiểm tra nếu là Ảnh
                    else if provider.canLoadObject(ofClass: UIImage.self) {
                        if let image = await self.loadImage(from: provider) {
                            do {
                                _ = try await PhotoStorageManager.shared.importAndEncryptPhoto(
                                    image: image,
                                    originalFileName: provider.suggestedName.map { "\($0).jpg" },
                                    albumId: self.parent.targetAlbumId
                                )
                                importedCount += 1
                            } catch {
                                print("Lỗi mã hóa ảnh: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    self.parent.onImportCompleted(importedCount)
                    
                    if importedCount > 0 && !assetIdsToDelete.isEmpty {
                        self.promptDeleteOriginals(assetIds: assetIdsToDelete)
                    }
                }
            }
        }
        
        private func loadImage(from provider: NSItemProvider) async -> UIImage? {
            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    continuation.resume(returning: image as? UIImage)
                }
            }
        }
        
        private func loadVideoURL(from provider: NSItemProvider) async -> URL? {
            return await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let srcURL = url else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let tempDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_" + srcURL.lastPathComponent)
                    try? FileManager.default.copyItem(at: srcURL, to: tempDest)
                    continuation.resume(returning: tempDest)
                }
            }
        }
        
        /// Hiển thị hộp thoại hỏi xóa ảnh/video gốc khỏi Thư viện ảnh iPhone chuẩn Apple
        private func promptDeleteOriginals(assetIds: [String]) {
            let activeWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            guard let topVC = activeWindow?.rootViewController else { return }
            
            let alert = UIAlertController(
                title: "Thư viện ảnh iPhone",
                message: "Do you want to delete the original photos and videos from your iPhone Photos library?\n\n(Bạn có muốn xóa các ảnh & video gốc đã nhập khỏi Thư viện máy để tránh lộ dữ liệu không?)",
                preferredStyle: .alert
            )
            
            let deleteAction = UIAlertAction(title: "Delete Original Media", style: .destructive) { _ in
                self.deleteAssetsFromSystemLibrary(assetIds: assetIds)
            }
            
            let keepAction = UIAlertAction(title: "Keep Original Media", style: .default, handler: nil)
            
            alert.addAction(deleteAction)
            alert.addAction(keepAction)
            
            var presenter = topVC
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
        
        private func deleteAssetsFromSystemLibrary(assetIds: [String]) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                guard status == .authorized || status == .limited else { return }
                
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(assets)
                }) { success, error in
                    if success {
                        print("Đã xóa media gốc thành công qua Apple Photos API.")
                    } else if let error = error {
                        print("Lỗi khi yêu cầu xóa gốc: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
