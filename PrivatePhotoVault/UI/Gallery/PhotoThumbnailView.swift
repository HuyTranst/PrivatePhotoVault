import SwiftUI

/// Ô hiển thị thumbnail ảnh & video siêu tốc độ, giải mã bất đồng bộ và lưu đệm bộ nhớ thông minh
public struct PhotoThumbnailView: View {
    public let photo: EncryptedPhoto
    public let isSelected: Bool
    public let isSelectionMode: Bool
    public var onLongPress: (() -> Void)? = nil
    
    @State private var thumbnailImage: UIImage? = nil
    @State private var isLoading: Bool = true
    
    public init(
        photo: EncryptedPhoto,
        isSelected: Bool = false,
        isSelectionMode: Bool = false,
        onLongPress: (() -> Void)? = nil
    ) {
        self.photo = photo
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
        self.onLongPress = onLongPress
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Ảnh thumbnail
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            Image(systemName: photo.isVideo ? "video" : "photo")
                                .font(.system(size: 20))
                                .foregroundColor(.gray.opacity(0.4))
                        )
                }
                
                // Badge hiển thị thời lượng nếu là Video ở góc dưới bên phải
                if photo.isVideo {
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                            Text(photo.formattedDuration)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottomTrailing)
                }
                
                // Checkbox chế độ chọn nhiều ảnh/video (Multi-Select)
                if isSelectionMode {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue : Color.black.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(6)
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onLongPressGesture {
            onLongPress?()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        if let cached = VaultCacheManager.shared.getThumbnail(for: photo.id.uuidString) {
            self.thumbnailImage = cached
            self.isLoading = false
            return
        }
        
        Task {
            let image = await PhotoStorageManager.shared.loadThumbnail(for: photo)
            await MainActor.run {
                self.thumbnailImage = image
                self.isLoading = false
            }
        }
    }
}
