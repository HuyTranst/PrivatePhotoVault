import SwiftUI

/// Màn hình giới thiệu thông số kiến trúc và bản quyền TrollStore
public struct AboutAppView: View {
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Biểu tượng ứng dụng và tên
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 88, height: 88)
                            .shadow(color: Color.green.opacity(0.35), radius: 12, x: 0, y: 6)
                        
                        Image(systemName: "photo.fill.on.rectangle.fill")
                            .font(.system(size: 42))
                            .foregroundColor(.white)
                    }
                    
                    Text("Private Photo Vault")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Phiên bản 1.0.0 (TrollStore Edition)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Khối thông tin kiến trúc
                VStack(spacing: 14) {
                    AboutInfoRow(
                        icon: "lock.shield.fill",
                        iconColor: .green,
                        title: "Mã Hóa Quân Sự",
                        detail: "Toàn bộ ảnh được mã hóa bằng thuật toán AES-256-GCM chuẩn phần cứng Apple CryptoKit."
                    )
                    
                    AboutInfoRow(
                        icon: "key.fill",
                        iconColor: .orange,
                        title: "Bảo Vệ Khóa Bằng Keychain",
                        detail: "Khóa đối xứng 256-bit được cất giữ an toàn trong iOS Keychain Enclave."
                    )
                    
                    AboutInfoRow(
                        icon: "wifi.slash",
                        iconColor: .blue,
                        title: "Hoạt Động 100% Offline",
                        detail: "Không cần tài khoản, không máy chủ, không theo dõi, không gửi bất kỳ dữ liệu nào ra bên ngoài."
                    )
                    
                    AboutInfoRow(
                        icon: "shippingbox.fill",
                        iconColor: .purple,
                        title: "Cài Đặt Qua TrollStore",
                        detail: "Định dạng IPA tương thích hoàn hảo TrollStore 1 & 2 (iOS 14.0 - 17.0+), vĩnh viễn không bao giờ bị thu hồi chứng chỉ."
                    )
                }
                .padding(18)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(18)
                .padding(.horizontal, 16)
                
                Text("Thiết kế và phát triển riêng tư tuyệt đối cho iPhone.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
        }
        .navigationTitle("Help & Info")
    }
}

struct AboutInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
