import Foundation
import UIKit
import Photos
import AVFoundation

/// Quản lý toàn bộ tiến trình mã hóa lưu trữ, giải mã bất đồng bộ và siêu dữ liệu ảnh & video
public final class PhotoStorageManager: ObservableObject {
    public static let shared = PhotoStorageManager()
    
    @Published public var photos: [EncryptedPhoto] = []
    
    private let fileManager = FileManager.default
    private let metadataFileName = "vault_photos_meta.json"
    
    /// Thư mục bảo mật Documents/Vault lưu toàn bộ file mã hóa ảnh và video
    public var vaultDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vault = docs.appendingPathComponent("Vault", isDirectory: true)
        if !fileManager.fileExists(atPath: vault.path) {
            try? fileManager.createDirectory(at: vault, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.protectionKey: FileProtectionType.completeUnlessOpen
            ])
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableVault = vault
            try? mutableVault.setResourceValues(resourceValues)
        }
        return vault
    }
    
    private var metadataURL: URL {
        return vaultDirectory.appendingPathComponent(metadataFileName)
    }
    
    private init() {
        loadMetadata()
    }
    
    // MARK: - Metadata Persistence
    
    private func loadMetadata() {
        guard fileManager.fileExists(atPath: metadataURL.path) else { return }
        do {
            let data = try Data(contentsOf: metadataURL)
            if let decrypted = try? CryptoEngine.shared.decrypt(combinedData: data) {
                let decoded = try JSONDecoder().decode([EncryptedPhoto].self, from: decrypted)
                self.photos = decoded
            } else {
                let decoded = try JSONDecoder().decode([EncryptedPhoto].self, from: data)
                self.photos = decoded
            }
        } catch {
            print("Lỗi nạp metadata: \(error.localizedDescription)")
        }
    }
    
    public func saveMetadata() {
        do {
            let encoded = try JSONEncoder().encode(photos)
            let encrypted = try CryptoEngine.shared.encrypt(data: encoded)
            try encrypted.write(to: metadataURL, options: .atomic)
        } catch {
            print("Lỗi lưu metadata: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Import & Encryption Pipeline (Photo)
    
    /// Mã hóa và lưu ảnh mới vào kho bí mật với thumbnail hiệu năng cao
    public func importAndEncryptPhoto(
        image: UIImage,
        originalFileName: String? = nil,
        albumId: UUID
    ) async throws -> EncryptedPhoto {
        return try await Task.detached(priority: .userInitiated) {
            let id = UUID()
            let fullEncFileName = "\(id.uuidString).enc"
            let thumbEncFileName = "\(id.uuidString)_thumb.enc"
            
            let fullFileURL = self.vaultDirectory.appendingPathComponent(fullEncFileName)
            let thumbFileURL = self.vaultDirectory.appendingPathComponent(thumbEncFileName)
            
            // 1. Tạo Thumbnail tối ưu kích thước (max 400x400)
            let thumbSize = self.calculateThumbnailSize(originalSize: image.size, maxDimension: 400)
            let thumbnailImage = self.resizeImage(image: image, targetSize: thumbSize)
            guard let thumbData = thumbnailImage.jpegData(compressionQuality: 0.75) else {
                throw CryptoEngine.CryptoError.encryptionFailed("Không thể nén dữ liệu thumbnail.")
            }
            
            // Mã hóa Thumbnail bằng AES-256-GCM
            let encryptedThumb = try CryptoEngine.shared.encrypt(data: thumbData)
            try encryptedThumb.write(to: thumbFileURL, options: .atomic)
            
            // Cache thumbnail vào RAM ngay để hiển thị tức thời
            VaultCacheManager.shared.setThumbnail(thumbnailImage, for: id.uuidString)
            
            // 2. Xử lý ảnh gốc chất lượng cao nguyên bản
            guard let fullData = image.jpegData(compressionQuality: 0.95) ?? image.pngData() else {
                throw CryptoEngine.CryptoError.encryptionFailed("Không thể trích xuất dữ liệu ảnh gốc.")
            }
            
            // Mã hóa ảnh gốc bằng AES-256-GCM
            let encryptedFull = try CryptoEngine.shared.encrypt(data: fullData)
            try encryptedFull.write(to: fullFileURL, options: .atomic)
            
            // KIỂM TRA VẬT LÝ BẮT BUỘC: File đã thực sự ghi thành công vào thư mục và có dung lượng > 0
            guard self.fileManager.fileExists(atPath: fullFileURL.path),
                  let attrs = try? self.fileManager.attributesOfItem(atPath: fullFileURL.path),
                  let size = attrs[.size] as? Int64, size > 0 else {
                throw NSError(domain: "PhotoStorageManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Xác thực tệp thất bại: Ảnh không tồn tại trong kho lưu trữ sau khi ghi."])
            }
            
            let photo = EncryptedPhoto(
                id: id,
                mediaType: .photo,
                encryptedFileName: fullEncFileName,
                thumbnailFileName: thumbEncFileName,
                originalFileName: originalFileName ?? "IMG_\(id.uuidString.prefix(6)).jpg",
                duration: nil,
                createdAt: Date(),
                originalWidth: image.size.width,
                originalHeight: image.size.height,
                fileSizeBytes: Int64(encryptedFull.count),
                albumIds: [albumId],
                isTrash: false,
                deletedAt: nil,
                isFavorite: false
            )
            
            await MainActor.run {
                self.photos.insert(photo, at: 0)
                self.saveMetadata()
            }
            
            return photo
        }.value
    }
    
    /// Mã hóa và lưu trực tiếp Data ảnh gốc (giữ nguyên 100% định dạng HEIC/PNG/JPEG, EXIF và tối ưu RAM)
    public func importAndEncryptPhotoData(
        data: Data,
        originalFileName: String? = nil,
        albumId: UUID
    ) async throws -> EncryptedPhoto {
        return try await Task.detached(priority: .userInitiated) {
            let id = UUID()
            let fullEncFileName = "\(id.uuidString).enc"
            let thumbEncFileName = "\(id.uuidString)_thumb.enc"
            
            let fullFileURL = self.vaultDirectory.appendingPathComponent(fullEncFileName)
            let thumbFileURL = self.vaultDirectory.appendingPathComponent(thumbEncFileName)
            
            // 1. Mã hóa dữ liệu ảnh gốc bằng AES-256-GCM
            let encryptedFull = try CryptoEngine.shared.encrypt(data: data)
            try encryptedFull.write(to: fullFileURL, options: .atomic)
            
            // 2. Tạo Thumbnail từ ảnh gốc
            var imageWidth: CGFloat = 1920
            var imageHeight: CGFloat = 1080
            var thumbData: Data? = nil
            
            if let uiImage = UIImage(data: data) {
                imageWidth = uiImage.size.width
                imageHeight = uiImage.size.height
                let thumbSize = self.calculateThumbnailSize(originalSize: uiImage.size, maxDimension: 400)
                let thumbnailImage = self.resizeImage(image: uiImage, targetSize: thumbSize)
                thumbData = thumbnailImage.jpegData(compressionQuality: 0.75)
                VaultCacheManager.shared.setThumbnail(thumbnailImage, for: id.uuidString)
            }
            
            if let tData = thumbData {
                let encryptedThumb = try CryptoEngine.shared.encrypt(data: tData)
                try encryptedThumb.write(to: thumbFileURL, options: .atomic)
            } else {
                try? encryptedFull.write(to: thumbFileURL, options: .atomic)
            }
            
            // KIỂM TRA VẬT LÝ BẮT BUỘC: File đã thực sự ghi thành công vào thư mục và có dung lượng > 0
            guard self.fileManager.fileExists(atPath: fullFileURL.path),
                  let attrs = try? self.fileManager.attributesOfItem(atPath: fullFileURL.path),
                  let size = attrs[.size] as? Int64, size > 0 else {
                throw NSError(domain: "PhotoStorageManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Xác thực tệp thất bại: Ảnh không tồn tại trong kho lưu trữ sau khi ghi."])
            }
            
            let photo = EncryptedPhoto(
                id: id,
                mediaType: .photo,
                encryptedFileName: fullEncFileName,
                thumbnailFileName: thumbEncFileName,
                originalFileName: originalFileName ?? "IMG_\(id.uuidString.prefix(6)).jpg",
                duration: nil,
                createdAt: Date(),
                originalWidth: imageWidth,
                originalHeight: imageHeight,
                fileSizeBytes: Int64(encryptedFull.count),
                albumIds: [albumId],
                isTrash: false,
                deletedAt: nil,
                isFavorite: false
            )
            
            await MainActor.run {
                self.photos.insert(photo, at: 0)
                self.saveMetadata()
            }
            
            return photo
        }.value
    }
    
    // MARK: - Import Video Pipeline
    
    /// Nhập video vào kho bảo mật (lưu trữ nguyên định dạng video chất lượng gốc và tạo thumbnail mã hóa)
    public func importVideo(
        sourceURL: URL,
        originalFileName: String? = nil,
        albumId: UUID
    ) async throws -> EncryptedPhoto {
        return try await Task.detached(priority: .userInitiated) {
            let id = UUID()
            let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
            let videoFileName = "\(id.uuidString).\(ext)"
            let thumbEncFileName = "\(id.uuidString)_thumb.enc"
            
            let destVideoURL = self.vaultDirectory.appendingPathComponent(videoFileName)
            let destThumbURL = self.vaultDirectory.appendingPathComponent(thumbEncFileName)
            
            // Sao chép file video vào thư mục bảo mật
            if self.fileManager.fileExists(atPath: destVideoURL.path) {
                try? self.fileManager.removeItem(at: destVideoURL)
            }
            try self.fileManager.copyItem(at: sourceURL, to: destVideoURL)
            
            // Trích xuất metadata và thumbnail từ Video
            let asset = AVURLAsset(url: destVideoURL)
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 400, height: 400)
            
            var thumbImage: UIImage = UIImage()
            var videoWidth: CGFloat = 1920
            var videoHeight: CGFloat = 1080
            
            if let cgImage = try? imageGenerator.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil) {
                thumbImage = UIImage(cgImage: cgImage)
                videoWidth = CGFloat(cgImage.width)
                videoHeight = CGFloat(cgImage.height)
            }
            
            if let thumbData = thumbImage.jpegData(compressionQuality: 0.75) {
                let encThumb = try CryptoEngine.shared.encrypt(data: thumbData)
                try encThumb.write(to: destThumbURL, options: .atomic)
                VaultCacheManager.shared.setThumbnail(thumbImage, for: id.uuidString)
            }
            
            let videoSize = (try? destVideoURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            
            // KIỂM TRA VẬT LÝ BẮT BUỘC: File video đã thực sự ghi thành công vào thư mục và có dung lượng > 0
            guard self.fileManager.fileExists(atPath: destVideoURL.path),
                  let attrs = try? self.fileManager.attributesOfItem(atPath: destVideoURL.path),
                  let size = attrs[.size] as? Int64, size > 0 else {
                throw NSError(domain: "PhotoStorageManager", code: 501, userInfo: [NSLocalizedDescriptionKey: "Xác thực tệp thất bại: Video không tồn tại trong kho lưu trữ sau khi ghi."])
            }
            
            let item = EncryptedPhoto(
                id: id,
                mediaType: .video,
                encryptedFileName: videoFileName,
                thumbnailFileName: thumbEncFileName,
                originalFileName: originalFileName ?? sourceURL.lastPathComponent,
                duration: durationSeconds.isNaN ? nil : durationSeconds,
                createdAt: Date(),
                originalWidth: videoWidth,
                originalHeight: videoHeight,
                fileSizeBytes: Int64(videoSize),
                albumIds: [albumId],
                isTrash: false,
                deletedAt: nil,
                isFavorite: false
            )
            
            await MainActor.run {
                self.photos.insert(item, at: 0)
                self.saveMetadata()
            }
            
            return item
        }.value
    }
    
    /// Xác thực vật lý một tệp ảnh/video đã tồn tại thực sự trên ổ đĩa trong kho Vault
    public func isMediaPhysicallyOnDisk(_ photo: EncryptedPhoto) -> Bool {
        let fileURL = vaultDirectory.appendingPathComponent(photo.encryptedFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else { return false }
        let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        return size > 0
    }
    
    /// Nhập video từ Data bộ nhớ (khi restore từ ZIP)
    public func importVideoData(
        data: Data,
        originalFileName: String,
        albumId: UUID
    ) async throws -> EncryptedPhoto {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(originalFileName)
        try data.write(to: tempURL, options: .atomic)
        defer { try? fileManager.removeItem(at: tempURL) }
        return try await importVideo(sourceURL: tempURL, originalFileName: originalFileName, albumId: albumId)
    }
    
    // MARK: - Decryption & Lazy Loading
    
    /// Tải thumbnail từ bộ đệm RAM hoặc giải mã nhanh từ đĩa (< 1ms)
    public func loadThumbnail(for photo: EncryptedPhoto) async -> UIImage? {
        if let cached = VaultCacheManager.shared.getThumbnail(for: photo.id.uuidString) {
            return cached
        }
        
        return await Task.detached(priority: .userInitiated) {
            let fileURL = self.vaultDirectory.appendingPathComponent(photo.thumbnailFileName)
            guard let encryptedData = try? Data(contentsOf: fileURL) else { return nil }
            guard let decryptedData = try? CryptoEngine.shared.decrypt(combinedData: encryptedData) else { return nil }
            guard let image = UIImage(data: decryptedData) else { return nil }
            
            VaultCacheManager.shared.setThumbnail(image, for: photo.id.uuidString)
            return image
        }.value
    }
    
    /// Tải ảnh full-res cho trình xem ảnh toàn màn hình với bộ nhớ đệm LRU
    public func loadFullImage(for photo: EncryptedPhoto) async -> UIImage? {
        if let cached = VaultCacheManager.shared.getFullImage(for: photo.id.uuidString) {
            return cached
        }
        
        return await Task.detached(priority: .userInitiated) {
            let fileURL = self.vaultDirectory.appendingPathComponent(photo.encryptedFileName)
            guard let encryptedData = try? Data(contentsOf: fileURL) else { return nil }
            guard let decryptedData = try? CryptoEngine.shared.decrypt(combinedData: encryptedData) else { return nil }
            guard let image = UIImage(data: decryptedData) else { return nil }
            
            VaultCacheManager.shared.setFullImage(image, for: photo.id.uuidString)
            return image
        }.value
    }
    
    // MARK: - Deletion & Trash Operations
    
    public func deletePhoto(id: UUID, permanent: Bool = false) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        
        if permanent {
            let photo = photos[index]
            let fullURL = vaultDirectory.appendingPathComponent(photo.encryptedFileName)
            let thumbURL = vaultDirectory.appendingPathComponent(photo.thumbnailFileName)
            try? fileManager.removeItem(at: fullURL)
            try? fileManager.removeItem(at: thumbURL)
            photos.remove(at: index)
        } else {
            photos[index].isTrash = true
            photos[index].deletedAt = Date()
        }
        saveMetadata()
    }
    
    public func restorePhoto(id: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].isTrash = false
        photos[index].deletedAt = nil
        saveMetadata()
    }
    
    public func emptyTrash() {
        let trashItems = photos.filter { $0.isTrash }
        for photo in trashItems {
            let fullURL = vaultDirectory.appendingPathComponent(photo.encryptedFileName)
            let thumbURL = vaultDirectory.appendingPathComponent(photo.thumbnailFileName)
            try? fileManager.removeItem(at: fullURL)
            try? fileManager.removeItem(at: thumbURL)
        }
        photos.removeAll(where: { $0.isTrash })
        saveMetadata()
    }
    
    // MARK: - Storage Usage Analysis
    
    public func calculateStorageUsage() -> (photosBytes: Int64, thumbBytes: Int64, totalBytes: Int64, freeBytes: Int64) {
        var photosSize: Int64 = 0
        var thumbSize: Int64 = 0
        
        if let files = try? fileManager.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: [.fileSizeKey], options: []) {
            for file in files {
                guard let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize else { continue }
                if file.lastPathComponent.contains("_thumb") {
                    thumbSize += Int64(size)
                } else {
                    photosSize += Int64(size)
                }
            }
        }
        
        var freeBytes: Int64 = 0
        if let systemAttrs = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = systemAttrs[.systemFreeSize] as? NSNumber {
            freeBytes = freeSize.int64Value
        }
        
        return (photosSize, thumbSize, photosSize + thumbSize, freeBytes)
    }
    
    // MARK: - Helper Methods
    
    private func calculateThumbnailSize(originalSize: CGSize, maxDimension: CGFloat) -> CGSize {
        let ratio = originalSize.width / max(1, originalSize.height)
        if originalSize.width > originalSize.height {
            let newWidth = min(originalSize.width, maxDimension)
            return CGSize(width: newWidth, height: newWidth / ratio)
        } else {
            let newHeight = min(originalSize.height, maxDimension)
            return CGSize(width: newHeight * ratio, height: newHeight)
        }
    }
    
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
