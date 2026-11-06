import SwiftUI

/// Giao diện ngụy trang ngân hàng Vietcombank (VCB Digibank) theo ảnh 001.PNG
public struct DecoyView: View {
    @ObservedObject var appState: AppState = AppState.shared
    @State private var isPasswordSheetPresented: Bool = false
    @State private var notificationTapCount: Int = 0
    @State private var lastTapTimestamp: TimeInterval = 0
    
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
                        // Chạm vào bất kỳ điểm bình thường nào sẽ reset số lần chạm và thu nhỏ / đóng ứng dụng về Home Screen
                        notificationTapCount = 0
                        appState.suspendToHomeScreen()
                    }
                
                // Vùng chạm bí mật: Phải nhấp đủ 10 lần liên tiếp vào biểu tượng Thông báo (Chuông + badge 9+) mới mở mật khẩu
                // Tọa độ tính toán tương đối: X ~ 80%, Y ~ 83.5%
                Button(action: {
                    let now = Date().timeIntervalSince1970
                    // Nếu thời gian giữa các lần nhấp quá 3 giây thì tính lại từ đầu
                    if now - lastTapTimestamp > 3.0 {
                        notificationTapCount = 0
                    }
                    lastTapTimestamp = now
                    notificationTapCount += 1
                    
                    // Rung phản hồi nhẹ cho mỗi lần chạm
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    // Khi đủ 10 lần chạm liên tiếp -> mở hộp thoại nhập mật khẩu
                    if notificationTapCount >= 10 {
                        notificationTapCount = 0
                        let successGen = UINotificationFeedbackGenerator()
                        successGen.notificationOccurred(.success)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isPasswordSheetPresented = true
                        }
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
