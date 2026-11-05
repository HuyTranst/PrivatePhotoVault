import SwiftUI

/// Trình xem ảnh toàn màn hình cao cấp chuẩn Apple Photos
public struct FullScreenPhotoViewer: View {
    public let photos: [EncryptedPhoto]
    public let initialPhotoId: UUID
    public let onDismiss: () -> Void
    
    @State private var currentIndex: Int = 0
    @State private var areControlsVisible: Bool = true
    @State private var fullImages: [UUID: UIImage] = [:]
    @State private var isDeleteAlertPresented: Bool = false
    @State private var isShareSheetPresented: Bool = false
    @State private var shareItem: UIImage? = nil
    
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
                // TabView hỗ trợ vuốt ngang mượt mà 60/120fps chuyển ảnh
                TabView(selection: $currentIndex) {
                    ForEach(0..<photos.count, id: \.self) { index in
                        let photo = photos[index]
                        ZStack {
                            if let image = fullImages[photo.id] {
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
                        
                        // Cân bằng khoảng trống bên phải
                        Color.clear
                            .frame(width: 70, height: 40)
                    }
                    .padding(.top, 48)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Thanh công cụ dưới (Bottom Bar)
                    HStack(spacing: 36) {
                        Button(action: shareCurrentPhoto) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: toggleFavorite) {
                            Image(systemName: currentPhoto?.isFavorite == true ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundColor(currentPhoto?.isFavorite == true ? .red : .white)
                        }
                        
                        Button(action: { isDeleteAlertPresented = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 40)
                    .background(Color.black.opacity(0.5))
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
        .alert("Xóa Ảnh Khỏi Kho", isPresented: $isDeleteAlertPresented) {
            Button("Chuyển Vào Thùng Rác", role: .destructive) {
                if let photo = currentPhoto {
                    PhotoStorageManager.shared.deletePhoto(id: photo.id, permanent: false)
                    onDismiss()
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bức ảnh sẽ được chuyển vào mục Thùng rác (Trash). Bạn có thể khôi phục lại trong Cài đặt.")
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let img = shareItem {
                ActivityView(activityItems: [img])
            }
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
    
    private func shareCurrentPhoto() {
        guard let photo = currentPhoto else { return }
        if let img = fullImages[photo.id] {
            shareItem = img
            isShareSheetPresented = true
        } else {
            Task {
                if let loaded = await PhotoStorageManager.shared.loadFullImage(for: photo) {
                    await MainActor.run {
                        shareItem = loaded
                        isShareSheetPresented = true
                    }
                }
            }
        }
    }
    
    /// Giải mã trước (Preload Pipeline) ảnh hiện tại và các ảnh liền kề (index - 1, index + 1)
    private func preloadAdjacentImages(for index: Int) {
        let indicesToLoad = [index, index - 1, index + 1].filter { $0 >= 0 && $0 < photos.count }
        
        for idx in indicesToLoad {
            let photo = photos[idx]
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

/// Helper hiển thị native UIActivityViewController để chia sẻ ảnh
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
