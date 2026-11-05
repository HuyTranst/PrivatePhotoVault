import Foundation

/// Cấu hình và tùy chọn của kho ảnh riêng tư
public struct VaultSettings: Codable, Equatable {
    /// Bật/tắt bảo vệ xác thực mật khẩu khi mở kho
    public var isAuthProtectionEnabled: Bool
    
    /// Bật/tắt mở khóa nhanh bằng sinh trắc học (Face ID / Touch ID)
    public var isBiometricEnabled: Bool
    
    /// Tự động hiển thị hộp thoại hỏi xóa ảnh gốc khỏi iPhone Photos sau khi nhập
    public var autoDeleteOriginalsPrompt: Bool
    
    /// Giao diện ứng dụng: "system" (Theo hệ thống), "dark" (Giao diện tối), "light" (Giao diện sáng)
    public var appearanceTheme: String
    
    /// Thời gian tự động khóa khi ứng dụng chạy ngầm (giây): 0 = khóa ngay lập tức
    public var autoLockTimeoutSeconds: Int
    
    /// Chất lượng nhập ảnh: "original" (giữ nguyên độ phân giải gốc), "high"
    public var importQuality: String
    
    public init(
        isAuthProtectionEnabled: Bool = true,
        isBiometricEnabled: Bool = false,
        autoDeleteOriginalsPrompt: Bool = true,
        appearanceTheme: String = "system",
        autoLockTimeoutSeconds: Int = 0,
        importQuality: String = "original"
    ) {
        self.isAuthProtectionEnabled = isAuthProtectionEnabled
        self.isBiometricEnabled = isBiometricEnabled
        self.autoDeleteOriginalsPrompt = autoDeleteOriginalsPrompt
        self.appearanceTheme = appearanceTheme
        self.autoLockTimeoutSeconds = autoLockTimeoutSeconds
        self.importQuality = importQuality
    }
}
