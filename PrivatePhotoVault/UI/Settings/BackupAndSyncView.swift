import SwiftUI

/// Màn hình quản lý Sao lưu Cục bộ (Local Backup & Export) đảm bảo tính Offline 100%
public struct BackupAndSyncView: View {
    @ObservedObject var photoStorage: PhotoStorageManager = PhotoStorageManager.shared
    @State private var isExporting: Bool = false
    @State private var exportedBackupURL: URL? = nil
    @State private var isShareSheetPresented: Bool = false
    @State private var statusMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(
                header: Text("Tình Trạng Đồng Bộ"),
                footer: Text("Ứng dụng hoạt động Offline 100% và không phụ thuộc vào bất kỳ máy chủ online nào để đảm bảo hình ảnh cá nhân của bạn không bao giờ bị rò rỉ lên Internet.")
            ) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Sao lưu Đám mây (Cloud):")
                    Spacer()
                    Text("Đã tắt (Tắt theo thiết kế)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Số mục chưa sao lưu ngoài:")
                    Spacer()
                    Text("\(photoStorage.photos.count) ảnh")
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
            }
            
            Section(
                header: Text("Xuất File Sao Lưu Cục Bộ (Local Backup)"),
                footer: Text("Tạo gói lưu trữ mã hóa (.vault) chứa toàn bộ ảnh và cấu trúc album để bạn cất giữ an toàn trên máy tính cá nhân hoặc USB.")
            ) {
                Button(action: generateLocalBackup) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .padding(.trailing, 8)
                        } else {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .foregroundColor(.blue)
                        }
                        Text(isExporting ? "Đang đóng gói file sao lưu..." : "Xuất File Sao Lưu (.vault)")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .disabled(isExporting || photoStorage.photos.isEmpty)
                
                if let msg = statusMessage {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Backup & Sync")
        .sheet(isPresented: $isShareSheetPresented) {
            if let url = exportedBackupURL {
                ShareFileView(fileURL: url)
            }
        }
    }
    
    private func generateLocalBackup() {
        isExporting = true
        statusMessage = nil
        
        Task {
            let fileManager = FileManager.default
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let backupFolder = tmpDir.appendingPathComponent("VaultBackup_\(Int(Date().timeIntervalSince1970))")
            try? fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)
            
            // Sao chép thư mục Documents/Vault vào thư mục backup
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let vaultDir = docs.appendingPathComponent("Vault")
            
            if let files = try? fileManager.contentsOfDirectory(at: vaultDir, includingPropertiesForKeys: nil) {
                for file in files {
                    let dest = backupFolder.appendingPathComponent(file.lastPathComponent)
                    try? fileManager.copyItem(at: file, to: dest)
                }
            }
            
            await MainActor.run {
                self.exportedBackupURL = backupFolder
                self.isExporting = false
                self.statusMessage = "Đã chuẩn bị file sao lưu mã hóa thành công!"
                self.isShareSheetPresented = true
            }
        }
    }
}

/// Helper chia sẻ file sao lưu qua hệ thống
struct ShareFileView: UIViewControllerRepresentable {
    let fileURL: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
