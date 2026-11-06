import Foundation
import UIKit
import Photos
import AVFoundation

/// Cấu trúc lưu thông tin file sao lưu ZIP đã tạo
public struct BackupArchiveInfo: Identifiable, Equatable {
    public let id: UUID
    public let fileName: String
    public let fileURL: URL
    public let fileSizeBytes: Int64
    public let createdAt: Date
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

/// Trình quản lý xuất dữ liệu ra Photos, nén ZIP toàn bộ Album và khôi phục sao lưu
public final class ExportBackupManager: ObservableObject {
    public static let shared = ExportBackupManager()
    
    private let fileManager = FileManager.default
    
    /// Thư mục lưu trữ các file backup ZIP trong Documents/Backups/
    public var backupsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backups = docs.appendingPathComponent("Backups", isDirectory: true)
        if !fileManager.fileExists(atPath: backups.path) {
            try? fileManager.createDirectory(at: backups, withIntermediateDirectories: true)
        }
        return backups
    }
    
    private init() {}
    
    // MARK: - 1. Save Media to iOS Photos Library
    
    /// Xuất danh sách ảnh và video đã chọn về Thư viện ảnh iOS Photos native
    public func exportMediaToPhotosLibrary(
        items: [EncryptedPhoto],
        progress: ((Int, Int) -> Void)? = nil
    ) async -> (successCount: Int, failedCount: Int) {
        // Kiểm tra quyền truy cập Thư viện ảnh Photos
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return (0, items.count)
        }
        
        var successCount = 0
        var failedCount = 0
        let total = items.count
        
        for (index, item) in items.enumerated() {
            progress?(index + 1, total)
            
            if item.isVideo {
                // Xuất Video
                let videoURL = PhotoStorageManager.shared.vaultDirectory.appendingPathComponent(item.encryptedFileName)
                guard fileManager.fileExists(atPath: videoURL.path) else {
                    failedCount += 1
                    continue
                }
                
                let success: Bool = await withCheckedContinuation { continuation in
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .video, fileURL: videoURL, options: nil)
                    }) { saved, _ in
                        continuation.resume(returning: saved)
                    }
                }
                if success { successCount += 1 } else { failedCount += 1 }
                
            } else {
                // Xuất Ảnh (Giải mã AES-256 về ảnh gốc uncompressed)
                let encURL = PhotoStorageManager.shared.vaultDirectory.appendingPathComponent(item.encryptedFileName)
                guard let encData = try? Data(contentsOf: encURL),
                      let decData = try? CryptoEngine.shared.decrypt(combinedData: encData),
                      let image = UIImage(data: decData) else {
                    failedCount += 1
                    continue
                }
                
                let success: Bool = await withCheckedContinuation { continuation in
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { saved, _ in
                        continuation.resume(returning: saved)
                    }
                }
                if success { successCount += 1 } else { failedCount += 1 }
            }
        }
        
        return (successCount, failedCount)
    }
    
    // MARK: - 2. Compress Selected Items to ZIP
    
    /// Nén danh sách ảnh & video đã chọn thành một file ZIP duy nhất
    public func compressItemsToZip(
        items: [EncryptedPhoto],
        zipFileName: String,
        progress: ((Int, Int, String) -> Void)? = nil,
        isCancelled: (() -> Bool)? = nil
    ) async throws -> URL {
        let sanitizedName = zipFileName.hasSuffix(".zip") ? zipFileName : "\(zipFileName).zip"
        let destinationURL = backupsDirectory.appendingPathComponent(sanitizedName)
        
        var entries: [ZipEntry] = []
        let total = items.count
        
        for (index, item) in items.enumerated() {
            if isCancelled?() == true {
                throw NSError(domain: "ExportBackupManager", code: 99, userInfo: [NSLocalizedDescriptionKey: "Tiến trình đã bị hủy."])
            }
            
            let defaultName = item.isVideo ? "Video_\(index + 1).mp4" : "Photo_\(index + 1).jpg"
            let entryName = item.originalFileName ?? defaultName
            progress?(index + 1, total, entryName)
            
            if item.isVideo {
                let videoURL = PhotoStorageManager.shared.vaultDirectory.appendingPathComponent(item.encryptedFileName)
                if let videoData = try? Data(contentsOf: videoURL) {
                    entries.append(ZipEntry(relativePath: entryName, data: videoData, modificationDate: item.createdAt))
                }
            } else {
                let encURL = PhotoStorageManager.shared.vaultDirectory.appendingPathComponent(item.encryptedFileName)
                if let encData = try? Data(contentsOf: encURL),
                   let decData = try? CryptoEngine.shared.decrypt(combinedData: encData) {
                    entries.append(ZipEntry(relativePath: entryName, data: decData, modificationDate: item.createdAt))
                }
            }
        }
        
        try ZipArchiver.shared.createZip(
            entries: entries,
            destinationURL: destinationURL,
            progress: progress,
            isCancelled: isCancelled
        )
        
        return destinationURL
    }
    
    // MARK: - 3. Compress Entire Album to ZIP (with Manifest.json)
    
    /// Nén toàn bộ Album thành file ZIP theo cấu trúc chuẩn Album_Name/Photos & Album_Name/Videos kèm manifest.json
    public func compressAlbumToZip(
        album: Album,
        progress: ((Int, Int, String) -> Void)? = nil,
        isCancelled: (() -> Bool)? = nil
    ) async throws -> URL {
        let albumPhotos = AlbumManager.shared.photos(in: album.id)
        let sanitizedAlbumName = album.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\\", with: "_")
        let zipFileName = "\(sanitizedAlbumName).zip"
        let destinationURL = backupsDirectory.appendingPathComponent(zipFileName)
        
        var entries: [ZipEntry] = []
        var manifestFiles: [[String: Any]] = []
        let total = albumPhotos.count
        
        var photoCounter = 1
        var videoCounter = 1
        
        for (index, item) in albumPhotos.enumerated() {
            if isCancelled?() == true {
                throw NSError(domain: "ExportBackupManager", code: 99, userInfo: [NSLocalizedDescriptionKey: "Tiến trình nén đã bị hủy."])
            }
            
            if item.isVideo {
                let vName = item.originalFileName ?? String(format: "VID_%03d.mp4", videoCounter)
                videoCounter += 1
                let relativePath = "\(sanitizedAlbumName)/Videos/\(vName)"
                progress?(index + 1, total, vName)
                
                let vURL = PhotoStorageManager.shared.vaultDirectory.appendingPathComponent(item.encryptedFileName)
                if let vData = try? Data(contentsOf: vURL) {
                    entries.append(ZipEntry(relativePath: relativePath, data: vData, modificationDate: item.createdAt))
                    manifestFiles.append([
                        "filename": relativePath,
                        "mediaType": "video",
                        "sizeBytes": vData.count,
                        "duration": item.duration ?? 0
                    ])
                }
            } else {
                let pName = item.originalFileName ?? String(format: "IMG_%03d.jpg", photoCounter)
                photoCounter += 1
                let relativePath = "\(sanitizedAlbumName)/Photos/\(pName)"
                progress?(index + 1, total, pName)
                
                let pURL = PhotoStorageManager.shared.vaultDirectory.appendingPathComponent(item.encryptedFileName)
                if let pEnc = try? Data(contentsOf: pURL),
                   let pDec = try? CryptoEngine.shared.decrypt(combinedData: pEnc) {
                    entries.append(ZipEntry(relativePath: relativePath, data: pDec, modificationDate: item.createdAt))
                    manifestFiles.append([
                        "filename": relativePath,
                        "mediaType": "photo",
                        "sizeBytes": pDec.count,
                        "width": item.originalWidth,
                        "height": item.originalHeight
                    ])
                }
            }
        }
        
        // Tạo file manifest.json
        let manifestData: [String: Any] = [
            "albumName": album.name,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "totalPhotos": photoCounter - 1,
            "totalVideos": videoCounter - 1,
            "files": manifestFiles
        ]
        
        if let manifestJson = try? JSONSerialization.data(withJSONObject: manifestData, options: [.prettyPrinted]) {
            let manifestPath = "\(sanitizedAlbumName)/manifest.json"
            entries.append(ZipEntry(relativePath: manifestPath, data: manifestJson, modificationDate: Date()))
        }
        
        try ZipArchiver.shared.createZip(
            entries: entries,
            destinationURL: destinationURL,
            progress: progress,
            isCancelled: isCancelled
        )
        
        return destinationURL
    }
    
    // MARK: - 4. Manage Saved Backups
    
    /// Liệt kê danh sách các file sao lưu ZIP đã tạo
    public func listSavedBackups() -> [BackupArchiveInfo] {
        guard let files = try? fileManager.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: []) else {
            return []
        }
        
        return files.filter { $0.pathExtension.lowercased() == "zip" }.compactMap { url in
            guard let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                  let size = attrs.fileSize,
                  let date = attrs.creationDate else { return nil }
            return BackupArchiveInfo(
                id: UUID(),
                fileName: url.lastPathComponent,
                fileURL: url,
                fileSizeBytes: Int64(size),
                createdAt: date
            )
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Xóa một file sao lưu ZIP
    public func deleteBackup(url: URL) {
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - 5. Restore ZIP Backup
    
    /// Khôi phục ảnh & video từ file ZIP vào kho riêng tư
    public func restoreBackupFromZip(
        zipURL: URL,
        targetAlbumId: UUID,
        progress: ((Int, Int, String) -> Void)? = nil
    ) async throws -> Int {
        let entries = try ZipArchiver.shared.extractZip(from: zipURL)
        var restoredCount = 0
        let total = entries.count
        
        for (index, entry) in entries.enumerated() {
            let path = entry.relativePath
            if path.hasSuffix("manifest.json") || path.hasSuffix("/") { continue }
            
            progress?(index + 1, total, (path as NSString).lastPathComponent)
            
            let ext = (path as NSString).pathExtension.lowercased()
            let isVideo = ["mp4", "mov", "m4v"].contains(ext)
            
            if isVideo {
                // Lưu video vào kho
                _ = try await PhotoStorageManager.shared.importVideoData(
                    data: entry.data,
                    originalFileName: (path as NSString).lastPathComponent,
                    albumId: targetAlbumId
                )
                restoredCount += 1
            } else {
                // Mã hóa ảnh AES-256 và lưu vào kho
                if let image = UIImage(data: entry.data) {
                    _ = try await PhotoStorageManager.shared.importAndEncryptPhoto(
                        image: image,
                        originalFileName: (path as NSString).lastPathComponent,
                        albumId: targetAlbumId
                    )
                    restoredCount += 1
                }
            }
        }
        
        return restoredCount
    }
}
