import Foundation
import Security

/// Trình hỗ trợ lưu trữ khóa bảo mật an toàn trong iOS Keychain
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private let serviceIdentifier = "com.secure.photovault.keychain"
    
    private init() {}
    
    /// Lưu dữ liệu bảo mật vào Keychain với quyền bảo vệ chỉ mở sau khi máy được mở khóa
    @discardableResult
    public func save(key: String, data: Data, accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) -> Bool {
        // Xóa dữ liệu cũ nếu đã tồn tại trước đó
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Đọc dữ liệu từ Keychain theo khóa
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
        return nil
    }
    
    /// Xóa dữ liệu khỏi Keychain theo khóa
    @discardableResult
    public func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
