import SwiftUI
import PhotosUI
import Photos

/// Bộ điều phối mở native iOS Photos Picker, nhập mã hóa ảnh và xử lý xác nhận xóa ảnh gốc
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
        config.selectionLimit = 0 // Cho phép chọn không giới hạn số lượng ảnh
        config.filter = .images
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
            
            // Xử lý nạp ảnh bất đồng bộ trong background task
            Task {
                var importedCount = 0
                var assetIdsToDelete: [String] = []
                
                for result in results {
                    // Thu thập Asset Identifier để hỗ trợ xóa sau khi nhập thành công
                    if let assetId = result.assetIdentifier {
                        assetIdsToDelete.append(assetId)
                    }
                    
                    let provider = result.itemProvider
                    if provider.canLoadObject(ofClass: UIImage.self) {
                        if let image = await self.loadImage(from: provider) {
                            do {
                                _ = try await PhotoStorageManager.shared.importAndEncryptPhoto(
                                    image: image,
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
                    
                    // Nếu đã nhập thành công và có asset identifiers, hiển thị hộp thoại xác nhận xóa ảnh gốc
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
        
        /// Hiển thị hộp thoại hỏi xóa ảnh gốc khỏi Thư viện ảnh iPhone chuẩn Apple
        private func promptDeleteOriginals(assetIds: [String]) {
            let activeWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            guard let topVC = activeWindow?.rootViewController else { return }
            
            let alert = UIAlertController(
                title: "Thư viện ảnh iPhone",
                message: "Do you want to delete the original photos from your iPhone Photos library?\n\n(Bạn có muốn xóa các ảnh gốc đã nhập khỏi Thư viện ảnh Photos của máy để tối ưu bộ nhớ và bảo mật không?)",
                preferredStyle: .alert
            )
            
            let deleteAction = UIAlertAction(title: "Delete Original Photos", style: .destructive) { _ in
                self.deleteAssetsFromSystemLibrary(assetIds: assetIds)
            }
            
            let keepAction = UIAlertAction(title: "Keep Original Photos", style: .default, handler: nil)
            
            alert.addAction(deleteAction)
            alert.addAction(keepAction)
            
            // Hiển thị alert
            var presenter = topVC
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
        
        /// Gọi API chính thức của Apple Photos để thực hiện yêu cầu xóa ảnh an toàn
        private func deleteAssetsFromSystemLibrary(assetIds: [String]) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                guard status == .authorized || status == .limited else { return }
                
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(assets)
                }) { success, error in
                    if success {
                        print("Đã xóa ảnh gốc thành công qua Apple Photos API.")
                    } else if let error = error {
                        print("Lỗi khi yêu cầu xóa ảnh gốc: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
