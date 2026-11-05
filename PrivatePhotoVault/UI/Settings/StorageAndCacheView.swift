import SwiftUI

/// Màn hình Quản lý Dung lượng & Xóa bộ nhớ đệm an toàn
public struct StorageAndCacheView: View {
    @ObservedObject var photoStorage: PhotoStorageManager = PhotoStorageManager.shared
    @State private var storageData: (photosBytes: Int64, thumbBytes: Int64, totalBytes: Int64, freeBytes: Int64) = (0, 0, 0, 0)
    @State private var isCacheCleared: Bool = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Dung Lượng Sử Dụng Thực Tế")) {
                HStack {
                    Image(systemName: "photo.stack.fill")
                        .foregroundColor(.blue)
                    Text("Ảnh Gốc Đã Mã Hóa:")
                    Spacer()
                    Text(formatBytes(storageData.photosBytes))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundColor(.indigo)
                    Text("Ảnh Thu Nhỏ (Thumbnails):")
                    Spacer()
                    Text(formatBytes(storageData.thumbBytes))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(.green)
                    Text("Tổng Dung Lượng Kho Vault:")
                    Spacer()
                    Text(formatBytes(storageData.totalBytes))
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(.gray)
                    Text("Dung Lượng Máy Còn Trống:")
                    Spacer()
                    Text(formatBytes(storageData.freeBytes))
                        .foregroundColor(.secondary)
                }
            }
            
            Section(
                header: Text("Tối Ưu Bộ Nhớ RAM & Bộ Nhớ Tạm"),
                footer: Text("Xóa sạch toàn bộ các bức ảnh giải mã tạm thời trong RAM và file cache. Không ảnh hưởng đến các bức ảnh mã hóa đang lưu trữ trong kho.")
            ) {
                Button(action: clearCache) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.orange)
                        Text("Xóa Bộ Nhớ Đệm Tạm Thời (Clear Cache)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                
                if isCacheCleared {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Đã dọn dẹp bộ nhớ đệm RAM thành công!")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("Storage & Cache")
        .onAppear {
            refreshStorage()
        }
    }
    
    private func refreshStorage() {
        storageData = photoStorage.calculateStorageUsage()
    }
    
    private func clearCache() {
        VaultCacheManager.shared.purgeAllCaches()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation {
            isCacheCleared = true
        }
        refreshStorage()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
