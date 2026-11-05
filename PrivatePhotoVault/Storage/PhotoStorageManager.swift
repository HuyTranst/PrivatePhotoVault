import Foundation
import UIKit
import Photos

/// Quản lý toàn bộ tiến trình mã hóa lưu trữ, giải mã bất đồng bộ và siêu dữ liệu ảnh
public final class PhotoStorageManager: ObservableObject {
    public static let shared = PhotoStorageManager()
    
    @Published public var photos: [EncryptedPhoto] = []
    
    private let fileManager = FileManager.default
    private let metadataFileName = "vault_photos_meta.json"
    
    /// Thư mục bảo mật Documents/Vault lưu toàn bộ file mã hóa
    private var vaultDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vault = docs.appendingPathComponent("Vault", isDirectory: true)
        if !fileManager.fileExists(atPath: vault.path) {
            try? fileManager.createDirectory(at: vault, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.protectionKey: FileProtectionType.completeUnlessOpen
            ])
            // Đánh dấu không đồng bộ lên iCloud tự động để bảo đảm tính bí mật
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
            // Giải mã file metadata (nếu đã mã hóa) hoặc đọc trực tiếp JSON
            if let decrypted = try? CryptoEngine.shared.decrypt(combinedData: data) {
                let decoded = try JSONDecoder().decode([EncryptedPhoto].self, from: decrypted)
                self.photos = decoded
            } else {
                let decoded = try JSONDecoder().decode([EncryptedPhoto].self, from: data)
                self.photos = decoded
            }
        } catch {
            print("Lỗi nạp metadata ảnh: \(error.localizedDescription)")
        }
    }
    
    public func saveMetadata() {
        do {
            let encoded = try JSONEncoder().encode(photos)
            let encrypted = try CryptoEngine.shared.encrypt(data: encoded)
            try encrypted.write(to: metadataURL, options: .atomic)
        } catch {
            print("Lỗi lưu metadata ảnh: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Import & Encryption Pipeline
    
    /// Mã hóa và lưu ảnh mới vào kho bí mật với thumbnail hiệu năng cao
    public func importAndEncryptPhoto(image: UIImage, albumId: UUID) async throws -> EncryptedPhoto {
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
            
            // Mã hóa Thumbnail
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
            
            let photo = EncryptedPhoto(
                id: id,
                encryptedFileName: fullEncFileName,
                thumbnailFileName: thumbEncFileName,
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
    
    // MARK: - Decryption & Lazy Loading
    
    /// Tải thumbnail từ bộ đệm RAM hoặc giải mã nhanh từ đĩa (< 1ms)
    public func loadThumbnail(for photo: EncryptedPhoto) async -> UIImage? {
        if let cached = VaultCacheManager.shared.getThumbnail(for: photo.id.uuidString) {
            return cached
        }
        
        return await Task.detached(priority: .userInteractive) {
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
    
    // MARK: - Photo Deletion & Trash Operations
    
    /// Chuyển ảnh vào thùng rác (soft delete) hoặc xóa vĩnh viễn khỏi đĩa
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
    
    /// Khôi phục ảnh từ Thùng rác về trạng thái hoạt động bình thường
    public func restorePhoto(id: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].isTrash = false
        photos[index].deletedAt = nil
        saveMetadata()
    }
    
    /// Xóa vĩnh viễn toàn bộ ảnh có trong Thùng rác
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
    
    /// Phân tích dung lượng thực tế trên thiết bị
    public func calculateStorageUsage() -> (photosBytes: Int64, thumbBytes: Int64, totalBytes: Int64, freeBytes: Int64) {
        var photosSize: Int64 = 0
        var thumbSize: Int64 = 0
        
        if let files = try? fileManager.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: [.fileSizeKey], options: []) {
            for file in files {
                guard let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize else { continue }
                if file.lastPathComponent.contains("_thumb") {
                    thumbSize += Int64(size)
                } else if file.lastPathComponent.hasSuffix(".enc") {
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
        let ratio = originalSize.width / originalSize.height
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
