import SwiftUI

/// Cửa sổ tiến trình hiển thị quá trình nén ZIP và xuất media ra Photos
public struct ExportProgressSheet: View {
    public let title: String
    public let currentItemText: String
    public let progressValue: Double // 0.0 .. 1.0
    public let onCancel: () -> Void
    
    public init(
        title: String,
        currentItemText: String,
        progressValue: Double,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.currentItemText = currentItemText
        self.progressValue = progressValue
        self.onCancel = onCancel
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(currentItemText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                ProgressView(value: progressValue, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 8)
                
                Text(String(format: "%.0f%%", progressValue * 100))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                
                Button(action: onCancel) {
                    Text("Hủy Tiến Trình")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 36)
        }
    }
}
