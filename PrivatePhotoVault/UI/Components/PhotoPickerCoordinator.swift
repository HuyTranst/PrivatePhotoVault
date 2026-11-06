import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

/// Bộ điều phối mở native iOS Photos Picker hỗ trợ cả ẢNH và VIDEO chất lượng gốc 100%
public struct PhotoPickerCoordinator: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    public let targetAlbumId: UUID
    public let onImportCompleted: (Int, [String]) -> Void
    
    public init(
        isPresented: Binding<Bool>,
        targetAlbumId: UUID,
        onImportCompleted: @escaping (Int, [String]) -> Void
    ) {
        self._isPresented = isPresented
        self.targetAlbumId = targetAlbumId
        self.onImportCompleted = onImportCompleted
    }
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0 // Không giới hạn số lượng ảnh/video chọn
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
            // Đóng sheet trên MainActor
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
            
            guard !results.isEmpty else {
                DispatchQueue.main.async {
                    self.parent.onImportCompleted(0, [])
                }
                return
            }
            
            Task {
                var importedCount = 0
                var verifiedSavedAssetIds: [String] = []
                
                for result in results {
                    let assetId = result.assetIdentifier
                    let provider = result.itemProvider
                    
                    // 1. Kiểm tra nếu là Video
                    if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ||
                       provider.hasItemConformingToTypeIdentifier("public.movie") {
                        if let videoURL = await self.loadVideoFile(from: provider) {
                            do {
                                let importedItem = try await PhotoStorageManager.shared.importVideo(
                                    sourceURL: videoURL,
                                    originalFileName: provider.suggestedName.map { "\($0).\(videoURL.pathExtension)" },
                                    albumId: self.parent.targetAlbumId
                                )
                                try? FileManager.default.removeItem(at: videoURL)
                                
                                // Kiểm tra vật lý tệp đã tồn tại trên đĩa chưa
                                if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(importedItem) {
                                    importedCount += 1
                                    if let id = assetId {
                                        verifiedSavedAssetIds.append(id)
                                    }
                                }
                            } catch {
                                print("Lỗi nhập video: \(error.localizedDescription)")
                            }
                        }
                    }
                    // 2. Nếu là Ảnh (HEIC, JPEG, PNG, RAW...)
                    else {
                        var photoSaved: EncryptedPhoto? = nil
                        
                        // Bước 2.1: Thử load raw file representation (bảo toàn 100% định dạng HEIC/PNG/EXIF gốc)
                        if let fileURL = await self.loadImageFile(from: provider) {
                            if let data = try? Data(contentsOf: fileURL), !data.isEmpty {
                                do {
                                    photoSaved = try await PhotoStorageManager.shared.importAndEncryptPhotoData(
                                        data: data,
                                        originalFileName: provider.suggestedName.map { "\($0).\(fileURL.pathExtension)" },
                                        albumId: self.parent.targetAlbumId
                                    )
                                } catch {
                                    print("Lỗi mã hóa Data ảnh: \(error.localizedDescription)")
                                }
                            }
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                        
                        // Bước 2.2: Nếu chưa được, thử nạp data trực tiếp qua loadDataRepresentation
                        if photoSaved == nil {
                            if let data = await self.loadImageData(from: provider) {
                                do {
                                    photoSaved = try await PhotoStorageManager.shared.importAndEncryptPhotoData(
                                        data: data,
                                        originalFileName: provider.suggestedName.map { "\($0).jpg" },
                                        albumId: self.parent.targetAlbumId
                                    )
                                } catch {
                                    print("Lỗi nạp Data: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        // Bước 2.3: Fallback cuối cùng nạp qua UIImage
                        if photoSaved == nil && provider.canLoadObject(ofClass: UIImage.self) {
                            if let image = await self.loadImageObject(from: provider) {
                                do {
                                    photoSaved = try await PhotoStorageManager.shared.importAndEncryptPhoto(
                                        image: image,
                                        originalFileName: provider.suggestedName.map { "\($0).jpg" },
                                        albumId: self.parent.targetAlbumId
                                    )
                                } catch {
                                    print("Lỗi nạp UIImage: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        // Xác thực vật lý: Chỉ tính thành công và thêm assetId để xóa khi tệp đã lưu THỰC SỰ trên đĩa
                        if let saved = photoSaved, PhotoStorageManager.shared.isMediaPhysicallyOnDisk(saved) {
                            importedCount += 1
                            if let id = assetId {
                                verifiedSavedAssetIds.append(id)
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    self.parent.onImportCompleted(importedCount, verifiedSavedAssetIds)
                }
            }
        }
        
        // MARK: - Helpers Nạp Dữ Liệu
        
        private func loadImageFile(from provider: NSItemProvider) async -> URL? {
            return await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                    guard let src = url else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let tempDest = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString + "_" + src.lastPathComponent)
                    do {
                        try FileManager.default.copyItem(at: src, to: tempDest)
                        continuation.resume(returning: tempDest)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        
        private func loadImageData(from provider: NSItemProvider) async -> Data? {
            return await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
            }
        }
        
        private func loadImageObject(from provider: NSItemProvider) async -> UIImage? {
            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    continuation.resume(returning: image as? UIImage)
                }
            }
        }
        
        private func loadVideoFile(from provider: NSItemProvider) async -> URL? {
            return await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let src = url else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let tempDest = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString + "_" + src.lastPathComponent)
                    do {
                        try FileManager.default.copyItem(at: src, to: tempDest)
                        continuation.resume(returning: tempDest)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Static Library Deletion Helper
    
    /// Xóa an toàn các ảnh/video gốc khỏi Thư viện ảnh Apple Photos (chỉ gọi sau khi đã kiểm tra tệp tồn tại trên đĩa)
    public static func deleteAssetsFromSystemLibrary(assetIds: [String], onCompleted: ((Bool) -> Void)? = nil) {
        guard !assetIds.isEmpty else {
            onCompleted?(true)
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                print("Chưa có quyền xóa ảnh trong thư viện Photos.")
                onCompleted?(false)
                return
            }
            
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
            guard assets.count > 0 else {
                onCompleted?(true)
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Đã xóa \(assets.count) ảnh/video gốc khỏi thư viện Apple Photos.")
                    } else if let err = error {
                        print("Lỗi khi xóa gốc: \(err.localizedDescription)")
                    }
                    onCompleted?(success)
                }
            }
        }
    }
}
