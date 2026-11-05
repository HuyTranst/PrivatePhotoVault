import Foundation

/// Đại diện cho một album ảnh trong kho riêng tư
public struct Album: Identifiable, Codable, Equatable {
    /// Định danh duy nhất của Album
    public let id: UUID
    
    /// Tên Album (ví dụ: Main Album, MC Ngọc Nhi, v.v.)
    public var name: String
    
    /// ID bức ảnh được chọn làm ảnh bìa Album
    public var coverPhotoId: UUID?
    
    /// Thời gian tạo Album
    public let createdAt: Date
    
    /// Đánh dấu là album mặc định hệ thống
    public var isDefault: Bool
    
    /// Thứ tự sắp xếp hiển thị
    public var sortOrder: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        coverPhotoId: UUID? = nil,
        createdAt: Date = Date(),
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.coverPhotoId = coverPhotoId
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }
}
