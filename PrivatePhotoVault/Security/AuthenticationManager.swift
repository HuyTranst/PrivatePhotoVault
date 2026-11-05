import Foundation
import LocalAuthentication
import CryptoKit

/// Quản lý xác thực mật khẩu, sinh trắc học và trạng thái bảo mật của Vault
public final class AuthenticationManager: ObservableObject {
    public static let shared = AuthenticationManager()
    
    private let passwordHashKey = "com.secure.photovault.password_hash"
    private let saltKey = "com.secure.photovault.password_salt"
    
    /// Mật khẩu mặc định theo yêu cầu dự án
    public static let defaultPassword = "36@Hamnghi"
    
    @Published public var isAuthenticated: Bool = false
    @Published public var failedAttemptsCount: Int = 0
    @Published public var isLockedOut: Bool = false
    @Published public var lockoutTimeRemaining: Int = 0
    
    private init() {
        bootstrapPasswordIfNeeded()
    }
    
    /// Đảm bảo mật khẩu mặc định được thiết lập an toàn ngay từ lần đầu khởi động
    private func bootstrapPasswordIfNeeded() {
        if KeychainHelper.shared.load(key: passwordHashKey) == nil {
            savePassword(AuthenticationManager.defaultPassword)
        }
    }
    
    /// Sinh Salt ngẫu nhiên và băm mật khẩu bằng SHA-256
    private func hashPassword(_ password: String, salt: Data) -> Data {
        var data = password.data(using: .utf8) ?? Data()
        data.append(salt)
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }
    
    /// Lưu mật khẩu mới kèm Salt vào Keychain
    @discardableResult
    public func savePassword(_ newPassword: String) -> Bool {
        // Sinh 16-byte cryptographic salt ngẫu nhiên
        var salt = Data(count: 16)
        let result = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        guard result == errSecSuccess else { return false }
        
        let hash = hashPassword(newPassword, salt: salt)
        let saltSaved = KeychainHelper.shared.save(key: saltKey, data: salt)
        let hashSaved = KeychainHelper.shared.save(key: passwordHashKey, data: hash)
        return saltSaved && hashSaved
    }
    
    /// Xác thực mật khẩu người dùng nhập vào
    public func verifyPassword(_ candidate: String) -> Bool {
        guard let storedHash = KeychainHelper.shared.load(key: passwordHashKey),
              let storedSalt = KeychainHelper.shared.load(key: saltKey) else {
            // Trường hợp dự phòng nếu chưa có salt trong Keychain
            return candidate == AuthenticationManager.defaultPassword
        }
        
        let candidateHash = hashPassword(candidate, salt: storedSalt)
        // So sánh an toàn chống tấn công đo lường thời gian (Constant-time comparison)
        let isValid = candidateHash == storedHash
        
        DispatchQueue.main.async {
            if isValid {
                self.isAuthenticated = true
                self.failedAttemptsCount = 0
            } else {
                self.failedAttemptsCount += 1
            }
        }
        
        return isValid
    }
    
    /// Thay đổi mật khẩu người dùng
    public func changePassword(current: String, new: String) -> Bool {
        guard verifyPassword(current) else { return false }
        guard !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return savePassword(new)
    }
    
    /// Xác thực thông qua Face ID hoặc Touch ID
    public func authenticateWithBiometrics(reason: String = "Mở khóa kho ảnh riêng tư", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.failedAttemptsCount = 0
                    }
                    completion(success)
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    /// Khóa kho ảnh và dọn dẹp trạng thái
    public func lockVault() {
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
}
