import UIKit

/// AppDelegate xử lý vòng đời ứng dụng và bảo vệ kho ảnh khi ứng dụng ẩn/chạy ngầm
public final class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Đảm bảo không cho phép chụp ảnh màn hình lộ dữ liệu trong đa nhiệm (App Switcher)
        addSecurityPrivacyOverlay()
        return true
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
        let timeout = AppState.shared.settings.autoLockTimeoutSeconds
        if timeout == 0 {
            // Khóa ngay lập tức khi ra màn hình chính hoặc đổi app
            AppState.shared.lockVaultAndReset()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(timeout)) {
                if UIApplication.shared.applicationState == .background {
                    AppState.shared.lockVaultAndReset()
                }
            }
        }
    }
    
    public func applicationWillEnterForeground(_ application: UIApplication) {
        removeSecurityPrivacyOverlay()
    }
    
    // MARK: - App Switcher Privacy Blur
    
    private var privacyWindow: UIWindow?
    
    private func addSecurityPrivacyOverlay() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Khi người dùng vuốt mở đa nhiệm App Switcher, làm mờ màn hình để không ai nhìn lén được ảnh
            if AppState.shared.isUnlocked {
                VaultCacheManager.shared.purgeAllCaches()
            }
        }
    }
    
    private func removeSecurityPrivacyOverlay() {
        privacyWindow?.isHidden = true
        privacyWindow = nil
    }
}
