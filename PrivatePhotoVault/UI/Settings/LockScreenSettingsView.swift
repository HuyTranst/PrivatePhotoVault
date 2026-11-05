import SwiftUI

/// Cài đặt Màn hình khóa, Đổi mật khẩu và Sinh trắc học (Face ID / Touch ID)
public struct LockScreenSettingsView: View {
    @ObservedObject var appState: AppState = AppState.shared
    @ObservedObject var authManager: AuthenticationManager = AuthenticationManager.shared
    
    @State private var currentPasswordInput: String = ""
    @State private var newPasswordInput: String = ""
    @State private var confirmPasswordInput: String = ""
    @State private var alertMessage: String = ""
    @State private var isAlertPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Bảo Mật Truy Cập")) {
                Toggle("Bảo Vệ Bằng Mật Khẩu", isOn: $appState.settings.isAuthProtectionEnabled)
                    .onChange(of: appState.settings.isAuthProtectionEnabled) { _ in
                        appState.saveSettings()
                    }
                
                Toggle("Mở Khóa Bằng Face ID / Touch ID", isOn: $appState.settings.isBiometricEnabled)
                    .onChange(of: appState.settings.isBiometricEnabled) { _ in
                        appState.saveSettings()
                    }
            }
            
            Section(header: Text("Đổi Mật Khẩu Kho Ảnh")) {
                SecureField("Mật khẩu hiện tại (mặc định: 36@Hamnghi)", text: $currentPasswordInput)
                SecureField("Mật khẩu mới", text: $newPasswordInput)
                SecureField("Xác nhận mật khẩu mới", text: $confirmPasswordInput)
                
                Button(action: performChangePassword) {
                    Text("Cập Nhật Mật Khẩu Mới")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .disabled(currentPasswordInput.isEmpty || newPasswordInput.isEmpty || confirmPasswordInput.isEmpty)
            }
            
            Section(
                header: Text("Tự Động Khóa Khi Chạy Ngầm"),
                footer: Text("Kho ảnh sẽ tự động khóa an toàn và xóa dữ liệu giải mã khỏi RAM khi bạn chuyển sang ứng dụng khác.")
            ) {
                Picker("Thời gian chờ khóa", selection: $appState.settings.autoLockTimeoutSeconds) {
                    Text("Khóa ngay lập tức").tag(0)
                    Text("Sau 30 giây").tag(30)
                    Text("Sau 1 phút").tag(60)
                    Text("Sau 5 phút").tag(300)
                }
                .onChange(of: appState.settings.autoLockTimeoutSeconds) { _ in
                    appState.saveSettings()
                }
            }
        }
        .navigationTitle("Lock Screen")
        .alert("Thông Báo Bảo Mật", isPresented: $isAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func performChangePassword() {
        guard newPasswordInput == confirmPasswordInput else {
            alertMessage = "Mật khẩu mới và mật khẩu xác nhận không trùng khớp."
            isAlertPresented = true
            return
        }
        
        if authManager.changePassword(current: currentPasswordInput, new: newPasswordInput) {
            alertMessage = "Đổi mật khẩu thành công! Hãy ghi nhớ mật khẩu mới để đăng nhập."
            currentPasswordInput = ""
            newPasswordInput = ""
            confirmPasswordInput = ""
        } else {
            alertMessage = "Mật khẩu hiện tại không chính xác. Vui lòng thử lại."
        }
        isAlertPresented = true
    }
}
