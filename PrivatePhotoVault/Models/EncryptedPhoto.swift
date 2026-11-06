import Foundation
import CoreGraphics

/// Loại phương tiện trong kho: Ảnh hoặc Video
public enum VaultMediaType: String, Codable, Equatable {
    case photo = "photo"
    case video = "video"
}

/// Đại diện cho một bức ảnh hoặc video được lưu trữ an toàn trong kho
public struct EncryptedPhoto: Identifiable, Codable, Equatable {
    /// Định danh duy nhất của mục phương tiện
    public let id: UUID
    
    /// Loại phương tiện (ảnh hoặc video)
    public var mediaType: VaultMediaType
    
    /// Tên file lưu trữ trên đĩa (với ảnh: mã hóa AES-256; với video: định dạng gốc mp4/mov)
    public let encryptedFileName: String
    
    /// Tên file thumbnail mã hóa AES-256-GCM trên đĩa
    public let thumbnailFileName: String
    
    /// Tên file gốc ban đầu (ví dụ: IMG_001.jpg, Clip.mp4)
    public var originalFileName: String?
    
    /// Thời lượng video tính bằng giây (nil nếu là ảnh)
    public var duration: Double?
    
    /// Thời gian nhập vào kho
    public let createdAt: Date
    
    /// Chiều rộng ảnh/video gốc
    public let originalWidth: CGFloat
    
    /// Chiều cao ảnh/video gốc
    public let originalHeight: CGFloat
    
    /// Kích thước dữ liệu (bytes)
    public let fileSizeBytes: Int64
    
    /// Danh sách ID các album chứa mục này
    public var albumIds: [UUID]
    
    /// Trạng thái đã chuyển vào thùng rác hay chưa
    public var isTrash: Bool
    
    /// Thời điểm chuyển vào thùng rác
    public var deletedAt: Date?
    
    /// Đánh dấu yêu thích
    public var isFavorite: Bool
    
    /// Kiểm tra xem có phải video không
    public var isVideo: Bool {
        return mediaType == .video
    }
    
    /// Kiểm tra xem có phải ảnh không
    public var isPhoto: Bool {
        return mediaType == .photo
    }
    
    /// Định dạng thời lượng video dạng mm:ss (ví dụ: 01:45)
    public var formattedDuration: String {
        guard let dur = duration, dur > 0 else { return "" }
        let totalSeconds = Int(dur)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Định dạng dung lượng tệp tin dễ đọc (ví dụ: 3.4 MB)
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }
    
    /// Tỉ lệ khung hình (Aspect Ratio = Width / Height)
    public var aspectRatio: CGFloat {
        guard originalHeight > 0 else { return 1.0 }
        return originalWidth / originalHeight
    }
    
    public init(
        id: UUID = UUID(),
        mediaType: VaultMediaType = .photo,
        encryptedFileName: String,
        thumbnailFileName: String,
        originalFileName: String? = nil,
        duration: Double? = nil,
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
        self.mediaType = mediaType
        self.encryptedFileName = encryptedFileName
        self.thumbnailFileName = thumbnailFileName
        self.originalFileName = originalFileName
        self.duration = duration
        self.createdAt = createdAt
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.fileSizeBytes = fileSizeBytes
        self.albumIds = albumIds
        self.isTrash = isTrash
        self.deletedAt = deletedAt
        self.isFavorite = isFavorite
    }
    
    // Custom decoder để tương thích ngược với các bản lưu metadata cũ chưa có mediaType
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.mediaType = try container.decodeIfPresent(VaultMediaType.self, forKey: .mediaType) ?? .photo
        self.encryptedFileName = try container.decode(String.self, forKey: .encryptedFileName)
        self.thumbnailFileName = try container.decode(String.self, forKey: .thumbnailFileName)
        self.originalFileName = try container.decodeIfPresent(String.self, forKey: .originalFileName)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.originalWidth = try container.decode(CGFloat.self, forKey: .originalWidth)
        self.originalHeight = try container.decode(CGFloat.self, forKey: .originalHeight)
        self.fileSizeBytes = try container.decode(Int64.self, forKey: .fileSizeBytes)
        self.albumIds = try container.decode([UUID].self, forKey: .albumIds)
        self.isTrash = try container.decode(Bool.self, forKey: .isTrash)
        self.deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        self.isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
    }
}
