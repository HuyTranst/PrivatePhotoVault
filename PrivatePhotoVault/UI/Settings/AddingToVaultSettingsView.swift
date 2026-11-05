import SwiftUI

/// Cài đặt Quy trình Nhập ảnh vào kho bí mật
public struct AddingToVaultSettingsView: View {
    @ObservedObject var appState: AppState = AppState.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(
                header: Text("Tự Động Hỏi Xóa Ảnh Gốc"),
                footer: Text("Khi bật, sau mỗi lần nhập ảnh thành công vào kho mã hóa, ứng dụng sẽ hiện hộp thoại hỏi bạn có muốn xóa các bức ảnh gốc khỏi Thư viện ảnh iPhone để giải phóng dung lượng và tránh lộ ảnh hay không.")
            ) {
                Toggle("Hỏi Xóa Ảnh Gốc Sau Khi Nhập", isOn: $appState.settings.autoDeleteOriginalsPrompt)
                    .onChange(of: appState.settings.autoDeleteOriginalsPrompt) { _ in
                        appState.saveSettings()
                    }
            }
            
            Section(
                header: Text("Chất Lượng Nhập Ảnh"),
                footer: Text("Giữ nguyên 100% độ phân giải và chất lượng của ảnh gốc (HEIC, RAW, JPEG, PNG).")
            ) {
                Picker("Chất lượng ảnh", selection: $appState.settings.importQuality) {
                    Text("Nguyên Bản (Max Quality)").tag("original")
                    Text("Nén Tiết Kiệm Dung Lượng").tag("compressed")
                }
                .onChange(of: appState.settings.importQuality) { _ in
                    appState.saveSettings()
                }
            }
        }
        .navigationTitle("Adding to Vault")
    }
}
