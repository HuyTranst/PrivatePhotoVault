import SwiftUI

/// Màn hình Quản lý các file sao lưu ZIP đã tạo trong Cài đặt (Settings)
public struct ZipBackupManagementView: View {
    @ObservedObject var exportManager = ExportBackupManager.shared
    @State private var backups: [BackupArchiveInfo] = []
    @State private var selectedBackupForShare: BackupArchiveInfo? = nil
    @State private var selectedBackupForExport: BackupArchiveInfo? = nil
    @State private var backupToDelete: BackupArchiveInfo? = nil
    @State private var isDeleteConfirmPresented: Bool = false
    @State private var isSharePresented: Bool = false
    @State private var isDocumentExporterPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Danh Sách File Sao Lưu ZIP")) {
                if backups.isEmpty {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Chưa có bản sao lưu ZIP nào")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Bạn có thể tạo file ZIP từ Album hoặc chọn nhiều ảnh rồi chọn 'Nén thành ZIP'.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(backups) { backup in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "doc.zipper")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                
                                Text(backup.fileName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(backup.formattedSize)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text(backup.formattedDate)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // Nút Lưu vào Files
                                Button(action: {
                                    selectedBackupForExport = backup
                                    isDocumentExporterPresented = true
                                }) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .padding(.horizontal, 8)
                                
                                // Nút Chia sẻ
                                Button(action: {
                                    selectedBackupForShare = backup
                                    isSharePresented = true
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .padding(.horizontal, 8)
                                
                                // Nút Xóa
                                Button(action: {
                                    backupToDelete = backup
                                    isDeleteConfirmPresented = true
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            
            Section(
                header: Text("Thông Tin Dung Lượng"),
                footer: Text("Các file sao lưu ZIP được lưu cục bộ trong Documents/Backups. Bạn có thể lưu vào mục Files (Tệp) trên máy hoặc đẩy lên iCloud Drive bất cứ lúc nào.")
            ) {
                HStack {
                    Text("Tổng số bản sao lưu:")
                    Spacer()
                    Text("\(backups.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Tổng dung lượng chiếm dụng:")
                    Spacer()
                    Text(formatTotalSize())
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle("ZIP Backups")
        .onAppear {
            loadBackups()
        }
        .sheet(isPresented: $isSharePresented) {
            if let b = selectedBackupForShare {
                ActivityView(activityItems: [b.fileURL])
            }
        }
        .sheet(isPresented: $isDocumentExporterPresented) {
            if let b = selectedBackupForExport {
                DocumentExporterView(fileURL: b.fileURL) {
                    isDocumentExporterPresented = false
                }
            }
        }
        .alert("Xác Nhận Xóa File ZIP", isPresented: $isDeleteConfirmPresented) {
            Button("Xóa File", role: .destructive) {
                if let b = backupToDelete {
                    exportManager.deleteBackup(url: b.fileURL)
                    loadBackups()
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn xóa file sao lưu '\(backupToDelete?.fileName ?? "")' khỏi thiết bị không?")
        }
    }
    
    private func loadBackups() {
        backups = exportManager.listSavedBackups()
    }
    
    private func formatTotalSize() -> String {
        let total = backups.reduce(0) { $0 + $1.fileSizeBytes }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }
}
