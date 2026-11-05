import SwiftUI

/// Hộp thoại tạo Album mới
public struct CreateAlbumSheet: View {
    @Binding var isPresented: Bool
    @State private var albumName: String = ""
    @FocusState private var isFocused: Bool
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tên Album")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Nhập tên album mới...", text: $albumName)
                        .padding(14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .focused($isFocused)
                }
                .padding(.top, 20)
                
                Button(action: createNewAlbum) {
                    Text("Tạo Album")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.blue.opacity(0.5)
                                : Color.blue
                        )
                        .cornerRadius(12)
                }
                .disabled(albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private func createNewAlbum() {
        let trimmed = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        AlbumManager.shared.createAlbum(name: trimmed)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        isPresented = false
    }
}
