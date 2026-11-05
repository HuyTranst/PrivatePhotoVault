import SwiftUI

/// Màn hình thông tin Hồ sơ Vault và Trạng thái Bản quyền Offline
public struct AccountStatusView: View {
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Thông Tin Kho Riêng Tư")) {
                HStack {
                    Text("Trạng Thái Tài Khoản:")
                    Spacer()
                    Text("Cục bộ (Zero-Account)")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Hình Thức Cài Đặt:")
                    Spacer()
                    Text("TrollStore IPA")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Thời Hạn Sử Dụng:")
                    Spacer()
                    Text("Vĩnh viễn (Không hết hạn)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Xác Thực Trực Tuyến:")
                    Spacer()
                    Text("Tắt (100% Offline)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Bảo Mật Phần Cứng")) {
                HStack {
                    Text("Thuật Toán Mã Hóa:")
                    Spacer()
                    Text("AES-256-GCM")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Lưu Trữ Khóa:")
                    Spacer()
                    Text("iOS Keychain (Enclave)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Kết Nối Mạng Ngoài:")
                    Spacer()
                    Text("Đã chặn hoàn toàn (0 byte)")
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Account")
    }
}
