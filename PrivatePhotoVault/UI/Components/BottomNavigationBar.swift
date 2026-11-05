import SwiftUI

/// Thanh điều hướng đáy 3 nút bấm chuẩn theo thiết kế tham chiếu xemanh.jpg
public struct BottomNavigationBar: View {
    public let onCreateAlbum: () -> Void
    public let onAddPicture: () -> Void
    public let onExit: () -> Void
    
    public init(
        onCreateAlbum: @escaping () -> Void,
        onAddPicture: @escaping () -> Void,
        onExit: @escaping () -> Void
    ) {
        self.onCreateAlbum = onCreateAlbum
        self.onAddPicture = onAddPicture
        self.onExit = onExit
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack {
                // Nút 1: Create Album (Danh sách / Thư mục tạo album)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onCreateAlbum()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.blue)
                        Text("Create Album")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Nút 2: Nút tròn màu xanh dương nổi bật với dấu cộng trắng "Add Picture"
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onAddPicture()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.12, green: 0.45, blue: 0.95))
                            .frame(width: 54, height: 54)
                            .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .offset(y: -6)
                
                // Nút 3: Exit (Thoát an toàn và khóa kho ảnh)
                Button(action: {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    onExit()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.backward.circle")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.red)
                        Text("Exit")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(
                Color(UIColor.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}
