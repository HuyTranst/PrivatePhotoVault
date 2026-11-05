import SwiftUI

/// Màn hình quản lý Thùng rác (Trash / Recently Deleted) cho phép khôi phục hoặc xóa vĩnh viễn
public struct TrashManagementView: View {
    @ObservedObject var photoStorage: PhotoStorageManager = PhotoStorageManager.shared
    @State private var isEmptyTrashConfirmPresented: Bool = false
    @State private var selectedPhotoForAction: EncryptedPhoto? = nil
    @State private var isActionSheetPresented: Bool = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    public init() {}
    
    private var trashPhotos: [EncryptedPhoto] {
        return photoStorage.photos.filter { $0.isTrash }
    }
    
    public var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            if trashPhotos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Text("Thùng Rác Đang Trống")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Khi bạn xóa ảnh trong các Album, ảnh sẽ được lưu tạm tại đây trước khi bị xóa vĩnh viễn.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                VStack(spacing: 0) {
                    // Thanh thông báo số lượng ảnh trong thùng rác
                    HStack {
                        Text("\(trashPhotos.count) ảnh trong thùng rác")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { isEmptyTrashConfirmPresented = true }) {
                            Text("Dọn Sạch Thùng Rác")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(trashPhotos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .onTapGesture {
                                        selectedPhotoForAction = photo
                                        isActionSheetPresented = true
                                    }
                            }
                        }
                        .padding(4)
                    }
                }
            }
        }
        .navigationTitle("Trash")
        .confirmationDialog(
            "Tùy Chọn Bức Ảnh",
            isPresented: $isActionSheetPresented,
            titleVisibility: .visible
        ) {
            Button("Khôi Phục Ảnh Về Album") {
                if let photo = selectedPhotoForAction {
                    photoStorage.restorePhoto(id: photo.id)
                }
            }
            Button("Xóa Vĩnh Viễn Khỏi Thiết Bị", role: .destructive) {
                if let photo = selectedPhotoForAction {
                    photoStorage.deletePhoto(id: photo.id, permanent: true)
                }
            }
            Button("Hủy", role: .cancel) {}
        }
        .alert("Xác Nhận Dọn Sạch Thùng Rác", isPresented: $isEmptyTrashConfirmPresented) {
            Button("Xóa Vĩnh Viễn Tất Cả", role: .destructive) {
                photoStorage.emptyTrash()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Toàn bộ \(trashPhotos.count) ảnh trong thùng rác sẽ bị xóa vĩnh viễn khỏi thiết bị và không thể khôi phục lại.")
        }
    }
}
