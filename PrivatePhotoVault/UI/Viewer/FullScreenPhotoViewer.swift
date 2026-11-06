import SwiftUI
import AVKit
import Photos

/// Trình xem ảnh & video toàn màn hình cao cấp chuẩn Apple Photos
public struct FullScreenPhotoViewer: View {
    public let photos: [EncryptedPhoto]
    public let initialPhotoId: UUID
    public let onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var areControlsVisible: Bool = true
    @State private var fullImages: [UUID: UIImage] = [:]
    @State private var isDeleteAlertPresented: Bool = false
    @State private var isShareSheetPresented: Bool = false
    @State private var shareItems: [Any] = []
    
    @State private var isExportToPhotosAlertPresented: Bool = false
    @State private var alertMessage: String = ""
    @State private var isStatusAlertPresented: Bool = false
    
    public init(
        photos: [EncryptedPhoto],
        initialPhotoId: UUID,
        onDismiss: @escaping () -> Void
    ) {
        self.photos = photos
        self.initialPhotoId = initialPhotoId
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !photos.isEmpty && currentIndex < photos.count {
                TabView(selection: $currentIndex) {
                    ForEach(0..<photos.count, id: \.self) { index in
                        let item = photos[index]
                        ZStack {
                            if item.isVideo {
                                // Trình phát Video Native AVPlayer
                                let videoURL = PhotoStorageManager.shared.vaultDirectory.appendingPathComponent(item.encryptedFileName)
                                VideoPlayer(player: AVPlayer(url: videoURL))
                                    .ignoresSafeArea()
                            } else {
                                // Trình xem ảnh phóng to thu nhỏ Pinch-to-zoom
                                if let image = fullImages[item.id] {
                                    ZoomableImageView(image: image) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            areControlsVisible.toggle()
                                        }
                                    }
                                } else {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { newIndex in
                    preloadAdjacentImages(for: newIndex)
                }
            }
            
            // Thanh công cụ trên (Top Bar)
            if areControlsVisible {
                VStack {
                    HStack {
                        Button(action: onDismiss) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 17))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        if !photos.isEmpty {
                            Text("\(currentIndex + 1) / \(photos.count)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(16)
                        }
                        
                        Spacer()
                        
                        Color.clear
                            .frame(width: 70, height: 40)
                    }
                    .padding(.top, 48)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Thanh công cụ dưới (Bottom Bar)
                    HStack(spacing: 30) {
                        // 1. Lưu ra Photos
                        Button(action: exportCurrentToPhotos) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20))
                                Text("Lưu Photos")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.white)
                        }
                        
                        // 2. Chia sẻ
                        Button(action: shareCurrentMedia) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                                Text("Chia sẻ")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.white)
                        }
                        
                        // 3. Yêu thích
                        Button(action: toggleFavorite) {
                            VStack(spacing: 4) {
                                Image(systemName: currentPhoto?.isFavorite == true ? "heart.fill" : "heart")
                                    .font(.system(size: 20))
                                Text("Yêu thích")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(currentPhoto?.isFavorite == true ? .red : .white)
                        }
                        
                        // 4. Xóa
                        Button(action: { isDeleteAlertPresented = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                Text("Xóa")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 28)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(28)
                    .padding(.bottom, 36)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            if let initialIndex = photos.firstIndex(where: { $0.id == initialPhotoId }) {
                self.currentIndex = initialIndex
                preloadAdjacentImages(for: initialIndex)
            }
        }
        .alert("Xóa Khỏi Kho", isPresented: $isDeleteAlertPresented) {
            Button("Chuyển Vào Thùng Rác", role: .destructive) {
                if let photo = currentPhoto {
                    PhotoStorageManager.shared.deletePhoto(id: photo.id, permanent: false)
                    onDismiss()
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Mục này sẽ được chuyển vào mục Thùng rác (Trash). Bạn có thể khôi phục lại trong Cài đặt.")
        }
        .alert("Thông Báo", isPresented: $isStatusAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityView(activityItems: shareItems)
        }
    }
    
    private var currentPhoto: EncryptedPhoto? {
        guard currentIndex >= 0 && currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }
    
    private func toggleFavorite() {
        guard let photo = currentPhoto,
              let index = PhotoStorageManager.shared.photos.firstIndex(where: { $0.id == photo.id }) else { return }
        PhotoStorageManager.shared.photos[index].isFavorite.toggle()
        PhotoStorageManager.shared.saveMetadata()
    }
    
    /// Lưu 1 ảnh hoặc 1 video hiện tại ra Thư viện Photos của máy
    private func exportCurrentToPhotos() {
        guard let item = currentPhoto else { return }
        Task {
            let result = await ExportBackupManager.shared.exportMediaToPhotosLibrary(items: [item])
            await MainActor.run {
                if result.successCount > 0 {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    alertMessage = "Đã lưu thành công vào Thư viện ảnh Photos iPhone!"
                } else {
                    alertMessage = "Không thể lưu vào Photos. Vui lòng cấp quyền trong Cài đặt máy."
                }
                isStatusAlertPresented = true
            }
        }
    }
    
    private func shareCurrentMedia() {
        guard let item = currentPhoto else { return }
        if item.isVideo {
            let videoURL = PhotoStorageManager.shared.vaultDirectory.appendingPathComponent(item.encryptedFileName)
            shareItems = [videoURL]
            isShareSheetPresented = true
        } else {
            if let img = fullImages[item.id] {
                shareItems = [img]
                isShareSheetPresented = true
            } else {
                Task {
                    if let loaded = await PhotoStorageManager.shared.loadFullImage(for: item) {
                        await MainActor.run {
                            shareItems = [loaded]
                            isShareSheetPresented = true
                        }
                    }
                }
            }
        }
    }
    
    private func preloadAdjacentImages(for index: Int) {
        let indicesToLoad = [index, index - 1, index + 1].filter { $0 >= 0 && $0 < photos.count }
        
        for idx in indicesToLoad {
            let photo = photos[idx]
            if photo.isVideo { continue }
            if fullImages[photo.id] != nil { continue }
            
            Task {
                if let img = await PhotoStorageManager.shared.loadFullImage(for: photo) {
                    await MainActor.run {
                        self.fullImages[photo.id] = img
                    }
                }
            }
        }
    }
}
