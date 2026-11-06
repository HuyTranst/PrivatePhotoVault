import SwiftUI

/// Giao diện kho ảnh chính dạng lưới 2 cột Album tái hiện chuẩn xác ảnh xemanh.jpg
public struct MainAlbumsView: View {
    @ObservedObject var appState: AppState = AppState.shared
    @ObservedObject var albumManager: AlbumManager = AlbumManager.shared
    @ObservedObject var photoStorage: PhotoStorageManager = PhotoStorageManager.shared
    
    @State private var isCreateAlbumPresented: Bool = false
    @State private var isPhotoPickerPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var activeAlbumForDetail: Album? = nil
    
    // Quản lý trạng thái nhập ảnh & xác thực trước khi hỏi xóa ảnh gốc
    @State private var importedSuccessCount: Int = 0
    @State private var verifiedDeleteAssetIds: [String] = []
    @State private var isDeleteOriginalPromptPresented: Bool = false
    
    // Bố cục lưới 2 cột đáp ứng kích thước mọi dòng iPhone
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(albumManager.albums) { album in
                                NavigationLink(
                                    destination: AlbumDetailView(album: album)
                                ) {
                                    AlbumCardView(album: album)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    
                    // Thanh điều hướng đáy 3 nút (Create Album, Add Picture, Exit)
                    BottomNavigationBar(
                        onCreateAlbum: {
                            isCreateAlbumPresented = true
                        },
                        onAddPicture: {
                            isPhotoPickerPresented = true
                        },
                        onExit: {
                            appState.lockVaultAndReset()
                        }
                    )
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Nút Cài đặt (Gear icon) ở góc trên bên phải theo đúng yêu cầu
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        isSettingsPresented = true
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 34, height: 34)
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $isCreateAlbumPresented) {
                CreateAlbumSheet(isPresented: $isCreateAlbumPresented)
            }
            .sheet(isPresented: $isPhotoPickerPresented) {
                // Mặc định nhập vào Main Album nếu ở màn hình ngoài
                let targetId = albumManager.albums.first?.id ?? UUID()
                NativePhotoPickerView(
                    isPresented: $isPhotoPickerPresented,
                    targetAlbumId: targetId,
                    onImportCompleted: { count, verifiedAssetIds in
                        if count > 0 {
                            self.importedSuccessCount = count
                            self.verifiedDeleteAssetIds = verifiedAssetIds
                            // CHỈ hiển thị thông báo hỏi xóa gốc khi ĐÃ KIỂM TRA THỰC SỰ có ảnh lưu trong thư mục
                            if !verifiedAssetIds.isEmpty {
                                self.isDeleteOriginalPromptPresented = true
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView(isPresented: $isSettingsPresented)
            }
            .alert("Đã Lưu An Toàn Vào Kho Riêng Tư", isPresented: $isDeleteOriginalPromptPresented) {
                Button("Xóa Ảnh/Video Gốc Khỏi Máy", role: .destructive) {
                    NativePhotoPickerView.deleteAssetsFromSystemLibrary(assetIds: verifiedDeleteAssetIds)
                    verifiedDeleteAssetIds.removeAll()
                }
                Button("Giữ Lại Trên iPhone", role: .cancel) {
                    verifiedDeleteAssetIds.removeAll()
                }
            } message: {
                Text("Đã mã hóa và lưu trữ an toàn \(importedSuccessCount) mục vào kho riêng tư.\n\nBạn có muốn xóa các ảnh & video gốc khỏi Thư viện ảnh iPhone để tránh lộ dữ liệu và giải phóng bộ nhớ không?")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

/// Thẻ hiển thị một Album dạng khối bo góc chuẩn thiết kế xemanh.jpg
struct AlbumCardView: View {
    let album: Album
    @ObservedObject var albumManager: AlbumManager = AlbumManager.shared
    @ObservedObject var photoStorage: PhotoStorageManager = PhotoStorageManager.shared
    @State private var coverImage: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Ảnh bìa Album bo góc ~18pt mượt mà
            ZStack {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo.stack")
                                .font(.system(size: 38))
                                .foregroundColor(.gray.opacity(0.4))
                        )
                }
            }
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            
            // Tên Album bên dưới ảnh bìa
            Text(album.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // Số lượng ảnh trong Album (tự động cập nhật tức thì)
            Text("\(albumManager.photoCount(for: album.id)) ảnh")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
        }
        .onAppear {
            loadCoverImage()
        }
        .onReceive(photoStorage.$photos) { _ in
            loadCoverImage()
        }
    }
    
    private func loadCoverImage() {
        if let cover = albumManager.coverPhoto(for: album) {
            Task {
                let img = await photoStorage.loadThumbnail(for: cover)
                await MainActor.run {
                    self.coverImage = img
                }
            }
        } else {
            self.coverImage = nil
        }
    }
}
