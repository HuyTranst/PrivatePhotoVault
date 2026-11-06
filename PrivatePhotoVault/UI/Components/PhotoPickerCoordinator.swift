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
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        var config: PHPickerConfiguration
        if authStatus == .authorized || authStatus == .limited {
            config = PHPickerConfiguration(photoLibrary: .shared())
        } else {
            // Khi chưa cấp quyền Photos, khởi tạo không cần tham số để tránh crash bảo mật
            config = PHPickerConfiguration()
        }
        
        config.selectionLimit = 0 // Cho phép chọn nhiều ảnh/video cùng lúc
        config.filter = .any(of: [.images, .videos]) // Hỗ trợ cả Ảnh và Video
        config.preferredAssetRepresentationMode = .current
        
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
            // Trường hợp người dùng nhấn "Hủy" (Cancel) hoặc không chọn gì
            guard !results.isEmpty else {
                picker.dismiss(animated: true) {
                    self.parent.isPresented = false
                    self.parent.onImportCompleted(0, [])
                }
                return
            }
            
            // Giữ picker trên màn hình trong khi đọc tệp để bảo toàn kết nối XPC với hệ thống
            Task {
                var importedCount = 0
                var verifiedSavedAssetIds: [String] = []
                
                for result in results {
                    let assetId = result.assetIdentifier
                    let provider = result.itemProvider
                    let registeredTypes = provider.registeredTypeIdentifiers
                    
                    // 1. Kiểm tra nếu là Video
                    let isVideo = registeredTypes.contains(where: { type in
                        if let ut = UTType(type) { return ut.conforms(to: .movie) }
                        return type.contains("movie") || type.contains("video") || type.contains("mp4") || type.contains("quicktime")
                    })
                    
                    if isVideo {
                        if let videoURL = await self.loadVideoFile(from: provider) {
                            do {
                                let importedItem = try await PhotoStorageManager.shared.importVideo(
                                    sourceURL: videoURL,
                                    originalFileName: provider.suggestedName.map { "\($0).\(videoURL.pathExtension)" },
                                    albumId: self.parent.targetAlbumId
                                )
                                try? FileManager.default.removeItem(at: videoURL)
                                
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
                    // 2. Xử lý Ảnh (Đa tầng: Hỗ trợ 100% HEIC, JPEG, PNG, RAW, v.v.)
                    else {
                        var savedPhoto: EncryptedPhoto? = nil
                        
                        // Tầng 1: Nạp raw Data trực tiếp theo đúng Type Identifier đã đăng ký của tệp (public.heic, public.jpeg...)
                        if let (data, ext) = await self.loadRawImageData(from: provider) {
                            do {
                                savedPhoto = try await PhotoStorageManager.shared.importAndEncryptPhotoData(
                                    data: data,
                                    originalFileName: provider.suggestedName.map { "\($0).\(ext)" },
                                    albumId: self.parent.targetAlbumId
                                )
                            } catch {
                                print("Lỗi lưu raw Data ảnh: \(error.localizedDescription)")
                            }
                        }
                        
                        // Tầng 2: Nếu chưa nạp được, thử nạp qua file representation
                        if savedPhoto == nil {
                            if let fileURL = await self.loadImageFile(from: provider) {
                                if let fileData = try? Data(contentsOf: fileURL), !fileData.isEmpty {
                                    do {
                                        savedPhoto = try await PhotoStorageManager.shared.importAndEncryptPhotoData(
                                            data: fileData,
                                            originalFileName: provider.suggestedName.map { "\($0).\(fileURL.pathExtension)" },
                                            albumId: self.parent.targetAlbumId
                                        )
                                    } catch {
                                        print("Lỗi lưu file ảnh: \(error.localizedDescription)")
                                    }
                                }
                                try? FileManager.default.removeItem(at: fileURL)
                            }
                        }
                        
                        // Tầng 3: Fallback qua UIImage
                        if savedPhoto == nil && provider.canLoadObject(ofClass: UIImage.self) {
                            if let image = await self.loadImageObject(from: provider) {
                                do {
                                    savedPhoto = try await PhotoStorageManager.shared.importAndEncryptPhoto(
                                        image: image,
                                        originalFileName: provider.suggestedName.map { "\($0).jpg" },
                                        albumId: self.parent.targetAlbumId
                                    )
                                } catch {
                                    print("Lỗi lưu UIImage: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        // Kiểm tra xác thực vật lý
                        if let photo = savedPhoto, PhotoStorageManager.shared.isMediaPhysicallyOnDisk(photo) {
                            importedCount += 1
                            if let id = assetId {
                                verifiedSavedAssetIds.append(id)
                            }
                        }
                    }
                }
                
                // Sau khi đã nạp và lưu an toàn toàn bộ ảnh vào đĩa, tiến hành đóng picker
                await MainActor.run {
                    picker.dismiss(animated: true) {
                        self.parent.isPresented = false
                        
                        // Đợi 0.35 giây cho hiệu ứng đóng sheet hoàn tất hoàn toàn trước khi gọi onImportCompleted
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            self.parent.onImportCompleted(importedCount, verifiedSavedAssetIds)
                        }
                    }
                }
            }
        }
        
        // MARK: - Helpers Nạp Dữ Liệu An Toàn Tuyệt Đối
        
        /// Nạp raw data của ảnh theo đúng định dạng HEIC/JPEG/PNG từ ItemProvider
        private func loadRawImageData(from provider: NSItemProvider) async -> (Data, String)? {
            let registered = provider.registeredTypeIdentifiers
            // Ưu tiên theo thứ tự: heic, jpeg, png, bất kỳ image nào
            let candidateTypes = registered.filter { type in
                if let ut = UTType(type) { return ut.conforms(to: .image) }
                return type.contains("image") || type.contains("heic") || type.contains("jpeg") || type.contains("png")
            }
            
            for typeId in candidateTypes {
                let result: Data? = await withCheckedContinuation { continuation in
                    var hasResumed = false
                    provider.loadDataRepresentation(forTypeIdentifier: typeId) { data, error in
                        guard !hasResumed else { return }
                        hasResumed = true
                        continuation.resume(returning: data)
                    }
                }
                
                if let data = result, !data.isEmpty {
                    let ext = UTType(typeId)?.preferredFilenameExtension ?? "jpg"
                    return (data, ext)
                }
            }
            return nil
        }
        
        /// Nạp ảnh qua File Representation
        private func loadImageFile(from provider: NSItemProvider) async -> URL? {
            let registered = provider.registeredTypeIdentifiers
            let candidateTypes = registered.filter { type in
                if let ut = UTType(type) { return ut.conforms(to: .image) }
                return type.contains("image") || type.contains("heic") || type.contains("jpeg") || type.contains("png")
            }
            
            for typeId in candidateTypes {
                let result: URL? = await withCheckedContinuation { continuation in
                    var hasResumed = false
                    provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, _ in
                        guard !hasResumed else { return }
                        hasResumed = true
                        guard let src = url else {
                            continuation.resume(returning: nil)
                            return
                        }
                        let tempDest = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent(UUID().uuidString + "_" + src.lastPathComponent)
                        do {
                            if FileManager.default.fileExists(atPath: tempDest.path) {
                                try FileManager.default.removeItem(at: tempDest)
                            }
                            try FileManager.default.copyItem(at: src, to: tempDest)
                            continuation.resume(returning: tempDest)
                        } catch {
                            continuation.resume(returning: nil)
                        }
                    }
                }
                
                if let url = result {
                    return url
                }
            }
            return nil
        }
        
        /// Nạp ảnh qua UIImage object
        private func loadImageObject(from provider: NSItemProvider) async -> UIImage? {
            guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }
            return await withCheckedContinuation { continuation in
                var hasResumed = false
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }
        
        /// Nạp Video qua File Representation
        private func loadVideoFile(from provider: NSItemProvider) async -> URL? {
            let registered = provider.registeredTypeIdentifiers
            let candidateTypes = registered.filter { type in
                if let ut = UTType(type) { return ut.conforms(to: .movie) }
                return type.contains("movie") || type.contains("video") || type.contains("mp4") || type.contains("quicktime")
            }
            
            let typesToTry = candidateTypes.isEmpty ? [UTType.movie.identifier] : candidateTypes
            
            for typeId in typesToTry {
                let result: URL? = await withCheckedContinuation { continuation in
                    var hasResumed = false
                    provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, _ in
                        guard !hasResumed else { return }
                        hasResumed = true
                        guard let src = url else {
                            continuation.resume(returning: nil)
                            return
                        }
                        let tempDest = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent(UUID().uuidString + "_" + src.lastPathComponent)
                        do {
                            if FileManager.default.fileExists(atPath: tempDest.path) {
                                try FileManager.default.removeItem(at: tempDest)
                            }
                            try FileManager.default.copyItem(at: src, to: tempDest)
                            continuation.resume(returning: tempDest)
                        } catch {
                            continuation.resume(returning: nil)
                        }
                    }
                }
                
                if let url = result {
                    return url
                }
            }
            return nil
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
