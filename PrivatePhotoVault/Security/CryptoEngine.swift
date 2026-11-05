import Foundation
import CryptoKit
import Security

/// Động cơ mã hóa AES-256-GCM chuẩn công nghiệp, bảo vệ khóa qua iOS Keychain
public final class CryptoEngine {
    public static let shared = CryptoEngine()
    
    private let masterKeyKeychainAccount = "com.secure.photovault.master_aes_key"
    private var symmetricKey: SymmetricKey!
    
    public enum CryptoError: Error, LocalizedError {
        case keyGenerationFailed
        case encryptionFailed(String)
        case decryptionFailed(String)
        case invalidCiphertext
        
        public var errorDescription: String? {
            switch self {
            case .keyGenerationFailed:
                return "Không thể khởi tạo hoặc truy xuất khóa mã hóa bảo mật."
            case .encryptionFailed(let msg):
                return "Lỗi mã hóa dữ liệu ảnh: \(msg)"
            case .decryptionFailed(let msg):
                return "Lỗi giải mã dữ liệu ảnh: \(msg)"
            case .invalidCiphertext:
                return "Dữ liệu mã hóa không hợp lệ hoặc đã bị chỉnh sửa."
            }
        }
    }
    
    private init() {
        initializeMasterKey()
    }
    
    /// Khởi tạo hoặc nạp khóa đối xứng 256-bit từ Keychain
    private func initializeMasterKey() {
        if let existingKeyData = KeychainHelper.shared.load(key: masterKeyKeychainAccount) {
            self.symmetricKey = SymmetricKey(data: existingKeyData)
        } else {
            // Sinh khóa AES-256 ngẫu nhiên chuẩn mã hóa an toàn phần cứng
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data(Array($0)) }
            KeychainHelper.shared.save(key: masterKeyKeychainAccount, data: keyData)
            self.symmetricKey = newKey
        }
    }
    
    /// Mã hóa dữ liệu bằng AES-256-GCM (trả về dữ liệu kết hợp Nonce + Ciphertext + Tag)
    public func encrypt(data: Data) throws -> Data {
        do {
            // AES.GCM.seal tự động tạo 12-byte Nonce ngẫu nhiên duy nhất cho mỗi lần mã hóa
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed("Không thể trích xuất dữ liệu kết hợp từ GCM SealedBox.")
            }
            return combined
        } catch {
            throw CryptoError.encryptionFailed(error.localizedDescription)
        }
    }
    
    /// Giải mã dữ liệu AES-256-GCM an toàn trực tiếp vào RAM
    public func decrypt(combinedData: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return decryptedData
        } catch {
            throw CryptoError.decryptionFailed("Xác thực tag thất bại hoặc dữ liệu bị sai lệch.")
        }
    }
}
