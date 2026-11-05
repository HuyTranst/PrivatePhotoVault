import Foundation
import CoreGraphics

/// Đại diện cho một bức ảnh đã được mã hóa lưu trữ an toàn trong kho
public struct EncryptedPhoto: Identifiable, Codable, Equatable {
    /// Định danh duy nhất của bức ảnh
    public let id: UUID
    
    /// Tên file ảnh gốc đã mã hóa AES-256-GCM trên đĩa
    public let encryptedFileName: String
    
    /// Tên file thumbnail đã mã hóa AES-256-GCM trên đĩa
    public let thumbnailFileName: String
    
    /// Thời gian nhập vào kho
    public let createdAt: Date
    
    /// Chiều rộng ảnh gốc
    public let originalWidth: CGFloat
    
    /// Chiều cao ảnh gốc
    public let originalHeight: CGFloat
    
    /// Kích thước dữ liệu mã hóa (bytes)
    public let fileSizeBytes: Int64
    
    /// Danh sách ID các album chứa ảnh này
    public var albumIds: [UUID]
    
    /// Trạng thái đã chuyển vào thùng rác hay chưa
    public var isTrash: Bool
    
    /// Thời điểm chuyển vào thùng rác
    public var deletedAt: Date?
    
    /// Đánh dấu yêu thích
    public var isFavorite: Bool
    
    /// Tỉ lệ khung hình (Aspect Ratio = Width / Height)
    public var aspectRatio: CGFloat {
        guard originalHeight > 0 else { return 1.0 }
        return originalWidth / originalHeight
    }
    
    public init(
        id: UUID = UUID(),
        encryptedFileName: String,
        thumbnailFileName: String,
        createdAt: Date = Date(),
        originalWidth: CGFloat,
        originalHeight: CGFloat,
        fileSizeBytes: Int64,
        albumIds: [UUID] = [],
        isTrash: Bool = false,
        deletedAt: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.encryptedFileName = encryptedFileName
        self.thumbnailFileName = thumbnailFileName
        self.createdAt = createdAt
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.fileSizeBytes = fileSizeBytes
        self.albumIds = albumIds
        self.isTrash = isTrash
        self.deletedAt = deletedAt
        self.isFavorite = isFavorite
    }
}
