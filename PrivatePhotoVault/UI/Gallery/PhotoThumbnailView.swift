import SwiftUI

/// Ô hiển thị thumbnail ảnh siêu tốc độ, giải mã bất đồng bộ và lưu đệm bộ nhớ thông minh
public struct PhotoThumbnailView: View {
    public let photo: EncryptedPhoto
    public let isSelected: Bool
    public let isSelectionMode: Bool
    
    @State private var thumbnailImage: UIImage? = nil
    @State private var isLoading: Bool = true
    
    public init(
        photo: EncryptedPhoto,
        isSelected: Bool = false,
        isSelectionMode: Bool = false
    ) {
        self.photo = photo
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    // Placeholder mượt mà trong lúc giải mã từ file mã hóa
                    Rectangle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                                .foregroundColor(.gray.opacity(0.4))
                        )
                }
                
                // Overlay chế độ chọn nhiều ảnh (Multi-Select)
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
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        // Kiểm tra RAM cache trước
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
