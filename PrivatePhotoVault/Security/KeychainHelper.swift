import Foundation
import Security

/// Trình hỗ trợ lưu trữ khóa bảo mật an toàn trong iOS Keychain
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private let serviceIdentifier = "com.secure.photovault.keychain"
    
    private var fallbackDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Vault", isDirectory: true).appendingPathComponent(".keys", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func fallbackURL(for key: String) -> URL {
        let safeName = key.replacingOccurrences(of: ".", with: "_") + ".bin"
        return fallbackDirectory.appendingPathComponent(safeName)
    }
    
    private init() {}
    
    /// Lưu dữ liệu bảo mật vào Keychain kèm cơ chế fallback tệp an toàn (đặc trị môi trường TrollStore / Fakesign)
    @discardableResult
    public func save(key: String, data: Data, accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) -> Bool {
        // Luôn lưu vào tệp fallback bảo mật để đảm bảo 100% không bao giờ mất khóa
        let fileURL = fallbackURL(for: key)
        try? data.write(to: fileURL, options: .atomic)
        
        // Xóa dữ liệu cũ nếu đã tồn tại trước đó trong Keychain
        deleteKeychainOnly(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess || FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Đọc dữ liệu từ Keychain theo khóa, tự động fallback sang tệp nếu Keychain bị từ chối
    public func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        }
        
        // Fallback đọc từ tệp bảo mật nếu Keychain trả về lỗi (-34018 errSecMissingEntitlement)
        let fileURL = fallbackURL(for: key)
        if let fileData = try? Data(contentsOf: fileURL), !fileData.isEmpty {
            return fileData
        }
        
        return nil
    }
    
    /// Xóa dữ liệu khỏi Keychain và tệp fallback
    @discardableResult
    public func delete(key: String) -> Bool {
        deleteKeychainOnly(key: key)
        let fileURL = fallbackURL(for: key)
        try? FileManager.default.removeItem(at: fileURL)
        return true
    }
    
    private func deleteKeychainOnly(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
