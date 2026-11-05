import Foundation
import UIKit

/// Quản lý bộ nhớ đệm (Cache) tối ưu hiệu năng cao cho ảnh thumbnail và ảnh toàn màn hình
public final class VaultCacheManager {
    public static let shared = VaultCacheManager()
    
    /// Cache lưu thumbnail đã giải mã trong RAM (giới hạn 300 ảnh, tối đa ~40MB)
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    /// Cache lưu ảnh gốc chất lượng cao cho trình xem ảnh (giới hạn 6 ảnh lân cận, tối đa ~80MB)
    private let fullImageCache = NSCache<NSString, UIImage>()
    
    private init() {
        // Cấu hình giới hạn bộ nhớ Thumbnail
        thumbnailCache.countLimit = 300
        thumbnailCache.totalCostLimit = 40 * 1024 * 1024 // 40 MB
        
        // Cấu hình giới hạn bộ nhớ Full Image
        fullImageCache.countLimit = 6
        fullImageCache.totalCostLimit = 80 * 1024 * 1024 // 80 MB
        
        // Đăng ký nhận cảnh báo bộ nhớ thấp từ hệ điều hành iOS
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        // Giải phóng ngay lập tức các ảnh full-res khi nhận cảnh báo RAM từ iOS
        fullImageCache.removeAllObjects()
    }
    
    // MARK: - Thumbnail Cache Operations
    
    public func getThumbnail(for key: String) -> UIImage? {
        return thumbnailCache.object(forKey: key as NSString)
    }
    
    public func setThumbnail(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        thumbnailCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    // MARK: - Full Image Cache Operations
    
    public func getFullImage(for key: String) -> UIImage? {
        return fullImageCache.object(forKey: key as NSString)
    }
    
    public func setFullImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        fullImageCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    // MARK: - Memory & Temporary Purge
    
    /// Dọn sạch toàn bộ bộ nhớ RAM và các file tạm khi Exit hoặc khóa kho ảnh
    public func purgeAllCaches() {
        thumbnailCache.removeAllObjects()
        fullImageCache.removeAllObjects()
        
        // Dọn dẹp thư mục tạm NSTemporaryDirectory()
        let tmpDir = NSTemporaryDirectory()
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(atPath: tmpDir) {
            for file in files {
                let filePath = (tmpDir as NSString).appendingPathComponent(file)
                try? fileManager.removeItem(atPath: filePath)
            }
        }
    }
}
