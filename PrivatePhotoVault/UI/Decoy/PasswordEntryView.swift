import SwiftUI

/// Màn hình nhập mật khẩu bảo mật chuẩn iOS để mở khóa kho ảnh bí mật
public struct PasswordEntryView: View {
    @Binding var isPresented: Bool
    @ObservedObject var appState: AppState = AppState.shared
    @ObservedObject var authManager: AuthenticationManager = AuthenticationManager.shared
    
    @State private var passwordInput: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var errorMessage: String? = nil
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            // Nền làm mờ siêu mịn chuẩn Apple Material
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut) {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 22) {
                // Biểu tượng bảo mật hình chiếc khiên / ổ khóa màu xanh lá
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.85), Color.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.green.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 6) {
                    Text("Xác Thực Bảo Mật")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Nhập mật khẩu truy cập kho ảnh riêng tư")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Ô nhập mật khẩu kèm nút bật/tắt hiển thị
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                        .padding(.leading, 12)
                    
                    if isPasswordVisible {
                        TextField("Mật khẩu truy cập", text: $passwordInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isInputFocused)
                    } else {
                        SecureField("Mật khẩu truy cập", text: $passwordInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isInputFocused)
                    }
                    
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 12)
                    }
                }
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(errorMessage != nil ? Color.red : Color.gray.opacity(0.2), lineWidth: 1.5)
                )
                .offset(x: shakeOffset)
                
                // Thông báo lỗi nếu mật khẩu không đúng
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
                
                // Nút Mở khóa và Hủy
                VStack(spacing: 12) {
                    Button(action: performUnlock) {
                        HStack {
                            Text("Mở Khóa Kho Ảnh")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 18))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.58, blue: 0.28), Color(red: 0.08, green: 0.45, blue: 0.22)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    // Nếu bật Face ID, cho phép mở khóa sinh trắc học nhanh
                    if appState.settings.isBiometricEnabled {
                        Button(action: performBiometricUnlock) {
                            HStack {
                                Image(systemName: "faceid")
                                    .font(.system(size: 18))
                                Text("Mở khóa bằng Face ID")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut) {
                            isPresented = false
                        }
                    }) {
                        Text("Quay Lại")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
            )
            .padding(.horizontal, 28)
        }
        .onAppear {
            isInputFocused = true
            if appState.settings.isBiometricEnabled {
                performBiometricUnlock()
            }
        }
    }
    
    private func performUnlock() {
        if authManager.verifyPassword(passwordInput) {
            // Rung phản hồi thành công
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = false
                appState.isUnlocked = true
            }
        } else {
            // Rung phản hồi báo lỗi và hiệu ứng lắc
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            withAnimation(.default) {
                errorMessage = "Mật khẩu không chính xác. Vui lòng thử lại."
            }
            triggerShake()
            passwordInput = ""
        }
    }
    
    private func performBiometricUnlock() {
        authManager.authenticateWithBiometrics { success in
            if success {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation {
                    isPresented = false
                    appState.isUnlocked = true
                }
            }
        }
    }
    
    private func triggerShake() {
        withAnimation(.default) {
            shakeOffset = -12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) { shakeOffset = 12 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.default) { shakeOffset = -8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.default) { shakeOffset = 8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.default) { shakeOffset = 0 }
        }
    }
}
