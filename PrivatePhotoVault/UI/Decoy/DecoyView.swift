import SwiftUI

/// Giao diện ngụy trang ngân hàng Vietcombank (VCB Digibank) theo ảnh 001.PNG
public struct DecoyView: View {
    @ObservedObject var appState: AppState = AppState.shared
    @State private var isPasswordSheetPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Ảnh nền ngụy trang VCB Digibank vừa vặn toàn màn hình iPhone
                Image(uiImage: loadDecoyImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Chạm vào bất kỳ điểm bình thường nào sẽ thu nhỏ / đóng ứng dụng về Home Screen
                        appState.suspendToHomeScreen()
                    }
                
                // Vùng chạm bí mật: Chỉ biểu tượng Thông báo (Chuông + badge đỏ 9+) mới mở mật khẩu
                // Tọa độ tính toán tương đối: X ~ 80%, Y ~ 83.5%
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isPasswordSheetPresented = true
                    }
                }) {
                    Color.clear
                        .frame(
                            width: geometry.size.width * 0.22,
                            height: geometry.size.height * 0.09
                        )
                        .contentShape(Rectangle())
                }
                .position(
                    x: geometry.size.width * 0.80,
                    y: geometry.size.height * 0.835
                )
            }
            .ignoresSafeArea()
            .overlay(
                Group {
                    if isPasswordSheetPresented {
                        PasswordEntryView(isPresented: $isPasswordSheetPresented)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            )
        }
    }
    
    /// Nạp ảnh ngụy trang từ Assets xcassets hoặc trực tiếp từ file bundle
    private func loadDecoyImage() -> UIImage {
        if let assetImg = UIImage(named: "001") {
            return assetImg
        }
        if let path = Bundle.main.path(forResource: "001", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        // Trường hợp khẩn cấp nếu chưa có ảnh
        return UIImage()
    }
}
