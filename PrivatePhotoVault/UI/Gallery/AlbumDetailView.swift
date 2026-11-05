import SwiftUI

/// Màn hình chi tiết hiển thị toàn bộ ảnh trong một Album cụ thể
public struct AlbumDetailView: View {
    public let album: Album
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var photoStorage: PhotoStorageManager = PhotoStorageManager.shared
    @ObservedObject var albumManager: AlbumManager = AlbumManager.shared
    @ObservedObject var appState: AppState = AppState.shared
    
    @State private var isSelectionMode: Bool = false
    @State private var selectedPhotoIds: Set<UUID> = []
    @State private var isMoveSheetPresented: Bool = false
    @State private var isRenameAlertPresented: Bool = false
    @State private var renameText: String = ""
    @State private var isDeleteConfirmPresented: Bool = false
    @State private var photoForViewer: EncryptedPhoto? = nil
    
    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]
    
    public init(album: Album) {
        self.album = album
    }
    
    private var albumPhotos: [EncryptedPhoto] {
        return albumManager.photos(in: album.id)
    }
    
    public var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                if albumPhotos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("Chưa Có Bức Ảnh Nào")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Hãy nhấn nút 'Add Picture' (+) ở thanh điều hướng để thêm ảnh mã hóa an toàn vào album này.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(albumPhotos) { photo in
                                PhotoThumbnailView(
                                    photo: photo,
                                    isSelected: selectedPhotoIds.contains(photo.id),
                                    isSelectionMode: isSelectionMode
                                )
                                .onTapGesture {
                                    if isSelectionMode {
                                        toggleSelection(photoId: photo.id)
                                    } else {
                                        photoForViewer = photo
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 4)
                        .padding(.bottom, 60)
                    }
                }
                
                // Thanh tác vụ khi ở chế độ Chọn nhiều ảnh (Multi-Select Toolbar)
                if isSelectionMode {
                    HStack {
                        Button(action: { isMoveSheetPresented = true }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Chuyển Album")
                            }
                            .font(.system(size: 14, weight: .medium))
                        }
                        .disabled(selectedPhotoIds.isEmpty)
                        
                        Spacer()
                        
                        Text("\(selectedPhotoIds.count) đã chọn")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: deleteSelectedPhotos) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Xóa")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedPhotoIds.isEmpty ? .secondary : .red)
                        }
                        .disabled(selectedPhotoIds.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSelectionMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    if !albumPhotos.isEmpty {
                        Button(isSelectionMode ? "Xong" : "Chọn") {
                            withAnimation {
                                isSelectionMode.toggle()
                                if !isSelectionMode {
                                    selectedPhotoIds.removeAll()
                                }
                            }
                        }
                    }
                    
                    Menu {
                        Button(action: {
                            renameText = album.name
                            isRenameAlertPresented = true
                        }) {
                            Label("Đổi Tên Album", systemImage: "pencil")
                        }
                        
                        if !album.isDefault {
                            Button(role: .destructive, action: {
                                isDeleteConfirmPresented = true
                            }) {
                                Label("Xóa Album", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .fullScreenCover(item: $photoForViewer) { photo in
            FullScreenPhotoViewer(
                photos: albumPhotos,
                initialPhotoId: photo.id,
                onDismiss: {
                    photoForViewer = nil
                }
            )
        }
        .sheet(isPresented: $isMoveSheetPresented) {
            MovePhotosSheet(
                photoIds: Array(selectedPhotoIds),
                currentAlbumId: album.id,
                isPresented: $isMoveSheetPresented,
                onCompleted: {
                    isSelectionMode = false
                    selectedPhotoIds.removeAll()
                }
            )
        }
        .alert("Đổi Tên Album", isPresented: $isRenameAlertPresented) {
            TextField("Tên mới", text: $renameText)
            Button("Lưu", action: {
                albumManager.renameAlbum(id: album.id, newName: renameText)
            })
            Button("Hủy", role: .cancel) {}
        }
        .alert("Xác Nhận Xóa Album", isPresented: $isDeleteConfirmPresented) {
            Button("Xóa Album và Giữ Lại Ảnh", action: {
                albumManager.deleteAlbum(id: album.id, deletePhotos: false)
                presentationMode.wrappedValue.dismiss()
            })
            Button("Xóa Album và Xóa Toàn Bộ Ảnh", role: .destructive, action: {
                albumManager.deleteAlbum(id: album.id, deletePhotos: true)
                presentationMode.wrappedValue.dismiss()
            })
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bạn có muốn xóa các bức ảnh trong album này hay chỉ xóa thư mục album?")
        }
    }
    
    private func toggleSelection(photoId: UUID) {
        if selectedPhotoIds.contains(photoId) {
            selectedPhotoIds.remove(photoId)
        } else {
            selectedPhotoIds.insert(photoId)
        }
    }
    
    private func deleteSelectedPhotos() {
        for id in selectedPhotoIds {
            photoStorage.deletePhoto(id: id, permanent: false)
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        isSelectionMode = false
        selectedPhotoIds.removeAll()
    }
}

/// Sheet chọn album để di chuyển ảnh
struct MovePhotosSheet: View {
    let photoIds: [UUID]
    let currentAlbumId: UUID
    @Binding var isPresented: Bool
    let onCompleted: () -> Void
    @ObservedObject var albumManager: AlbumManager = AlbumManager.shared
    
    var body: some View {
        NavigationView {
            List(albumManager.albums.filter { $0.id != currentAlbumId }) { targetAlbum in
                Button(action: {
                    albumManager.movePhotos(photoIds: photoIds, to: targetAlbum.id)
                    isPresented = false
                    onCompleted()
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                        Text(targetAlbum.name)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(albumManager.photoCount(for: targetAlbum.id)) ảnh")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Chọn Album Đích")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
