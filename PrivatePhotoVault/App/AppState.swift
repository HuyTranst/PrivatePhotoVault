import Foundation
import SwiftUI
import Combine

/// Quản lý trạng thái toàn cục của ứng dụng (Navigation, Authentication, Appearance)
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    /// Trạng thái mở khóa kho ảnh riêng tư
    @Published public var isUnlocked: Bool = false
    
    /// Hiển thị màn hình cài đặt (Settings modal sheet)
    @Published public var isSettingsPresented: Bool = false
    
    /// Hiển thị hộp thoại tạo Album mới
    @Published public var isCreateAlbumPresented: Bool = false
    
    /// Hiển thị trình chọn ảnh iOS Photos Picker
    @Published public var isPhotoPickerPresented: Bool = false
    
    /// Album đang được mở chi tiết
    @Published public var currentOpenAlbum: Album? = nil
    
    /// Bức ảnh đang được xem toàn màn hình
    @Published public var selectedPhotoForViewer: EncryptedPhoto? = nil
    
    /// Cấu hình người dùng
    @Published public var settings: VaultSettings
    
    private let settingsKey = "com.secure.photovault.settings"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(VaultSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = VaultSettings()
        }
    }
    
    public func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    /// Thoát an toàn khỏi kho riêng tư, dọn sạch bộ nhớ RAM và khóa ứng dụng
    public func lockVaultAndReset() {
        DispatchQueue.main.async {
            self.isUnlocked = false
            self.isSettingsPresented = false
            self.currentOpenAlbum = nil
            self.selectedPhotoForViewer = nil
            
            // Xóa sạch toàn bộ ảnh giải mã trong RAM
            VaultCacheManager.shared.purgeAllCaches()
            AuthenticationManager.shared.lockVault()
        }
    }
    
    /// Thu nhỏ ứng dụng về màn hình chính iOS (Home Screen)
    public func suspendToHomeScreen() {
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    }
}
