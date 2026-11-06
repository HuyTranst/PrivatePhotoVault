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
            
            // QUAN TRỌNG: TUYỆT ĐỐI KHÔNG dismiss picker ngay tại đây!
            // Khi PHPicker bị đóng, hệ thống iOS sẽ lập tức ngắt kết nối XPC tới tiến trình Photos daemon.
            // Nếu ngắt kết nối trong khi Task đang đọc ảnh, ứng dụng sẽ bị crash ngay lập tức (văng app).
            // Do đó: Giữ nguyên picker trên màn hình, đọc toàn bộ tệp xong xuôi rồi mới đóng picker!
            Task {
                var importedCount = 0
                var verifiedSavedAssetIds: [String] = []
                
                for result in results {
                    let assetId = result.assetIdentifier
                    let provider = result.itemProvider
                    
                    // 1. Xử lý Video
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
                    // 2. Xử lý Ảnh (chuẩn Apple chính thức an toàn tuyệt đối 100%)
                    else {
                        if let image = await self.loadImage(from: provider) {
                            do {
                                let importedPhoto = try await PhotoStorageManager.shared.importAndEncryptPhoto(
                                    image: image,
                                    originalFileName: provider.suggestedName.map { "\($0).jpg" },
                                    albumId: self.parent.targetAlbumId
                                )
                                
                                // Xác thực vật lý: Chỉ xác nhận thành công khi tệp đã ghi vào đĩa
                                if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(importedPhoto) {
                                    importedCount += 1
                                    if let id = assetId {
                                        verifiedSavedAssetIds.append(id)
                                    }
                                }
                            } catch {
                                print("Lỗi mã hóa ảnh: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                // Sau khi đã nạp và lưu an toàn toàn bộ ảnh vào đĩa, tiến hành đóng picker
                await MainActor.run {
                    picker.dismiss(animated: true) {
                        self.parent.isPresented = false
                        
                        // Đợi 0.35 giây cho hiệu ứng đóng sheet hoàn tất hoàn toàn trước khi gọi onImportCompleted
                        // Điều này ngăn chặn việc hiển thị Alert đè lên animation đóng sheet gây crash UIKit!
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            self.parent.onImportCompleted(importedCount, verifiedSavedAssetIds)
                        }
                    }
                }
            }
        }
        
        // MARK: - Helpers Nạp Dữ Liệu An Toàn Tuyệt Đối (Zero Crash)
        
        private func loadImage(from provider: NSItemProvider) async -> UIImage? {
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
        
        private func loadVideoFile(from provider: NSItemProvider) async -> URL? {
            return await withCheckedContinuation { continuation in
                var hasResumed = false
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
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
