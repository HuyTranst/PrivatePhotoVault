import SwiftUI
import Photos

/// Màn hình chi tiết hiển thị toàn bộ ảnh & video trong Album kèm bộ công cụ Chọn nhiều & Xuất ZIP chuyên nghiệp
public struct AlbumDetailView: View {
    public let album: Album
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var photoStorage: PhotoStorageManager = PhotoStorageManager.shared
    @ObservedObject var albumManager: AlbumManager = AlbumManager.shared
    @ObservedObject var appState: AppState = AppState.shared
    @ObservedObject var exportManager: ExportBackupManager = ExportBackupManager.shared
    
    @State private var isSelectionMode: Bool = false
    @State private var selectedPhotoIds: Set<UUID> = []
    @State private var isMoveSheetPresented: Bool = false
    @State private var isRenameAlertPresented: Bool = false
    @State private var renameText: String = ""
    @State private var isDeleteConfirmPresented: Bool = false
    @State private var photoForViewer: EncryptedPhoto? = nil
    
    // Xuất & Nén ZIP State
    @State private var isExportingProgressPresented: Bool = false
    @State private var exportProgressTitle: String = ""
    @State private var exportCurrentItemText: String = ""
    @State private var exportProgressValue: Double = 0.0
    @State private var isExportCancelled: Bool = false
    
    @State private var isZipNamePromptPresented: Bool = false
    @State private var customZipName: String = ""
    @State private var generatedZipURL: URL? = nil
    @State private var isDocumentExporterPresented: Bool = false
    @State private var isDocumentImporterPresented: Bool = false
    
    @State private var isPostExportDeletePromptPresented: Bool = false
    @State private var exportedItemsForCleanup: [EncryptedPhoto] = []
    
    // Thêm ảnh vào album & xác thực trước khi hỏi xóa gốc
    @State private var isPhotoPickerPresented: Bool = false
    @State private var importedSuccessCount: Int = 0
    @State private var verifiedDeleteAssetIds: [String] = []
    @State private var isDeleteOriginalPromptPresented: Bool = false
    
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isGeneralAlertPresented: Bool = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]
    
    public init(album: Album) {
        self.album = album
    }
    
    private var albumPhotos: [EncryptedPhoto] {
        if album.isDefault {
            // Main Album hiển thị toàn bộ ảnh và video đang có trong kho
            return photoStorage.photos.filter { !$0.isTrash }
        }
        return photoStorage.photos.filter { !$0.isTrash && $0.albumIds.contains(album.id) }
    }
    
    private var selectedPhotos: [EncryptedPhoto] {
        return albumPhotos.filter { selectedPhotoIds.contains($0.id) }
    }
    
    private var selectedEstimatedSize: String {
        let total = selectedPhotos.reduce(0) { $0 + $1.fileSizeBytes }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }
    
    public var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Thanh công cụ chọn bộ lọc phụ khi ở chế độ Multi-Select
                if isSelectionMode {
                    HStack {
                        Menu {
                            Button("Chọn tất cả (\(albumPhotos.count))") {
                                selectedPhotoIds = Set(albumPhotos.map { $0.id })
                            }
                            Button("Bỏ chọn tất cả") {
                                selectedPhotoIds.removeAll()
                            }
                            Divider()
                            Button("Chỉ chọn Ảnh (\(albumPhotos.filter { $0.isPhoto }.count))") {
                                selectedPhotoIds = Set(albumPhotos.filter { $0.isPhoto }.map { $0.id })
                            }
                            Button("Chỉ chọn Video (\(albumPhotos.filter { $0.isVideo }.count))") {
                                selectedPhotoIds = Set(albumPhotos.filter { $0.isVideo }.map { $0.id })
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Bộ Lọc Chọn")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Text("\(selectedPhotoIds.count) đã chọn • \(selectedEstimatedSize)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                }
                
                if albumPhotos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("Chưa Có Ảnh Hoặc Video Nào")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Nhấn nút bên dưới để chọn và mã hóa ảnh hoặc video vào album này.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: { isPhotoPickerPresented = true }) {
                            Label("Thêm Ảnh & Video", systemImage: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(25)
                                .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(albumPhotos) { photo in
                                PhotoThumbnailView(
                                    photo: photo,
                                    isSelected: selectedPhotoIds.contains(photo.id),
                                    isSelectionMode: isSelectionMode,
                                    onLongPress: {
                                        // Nhấn giữ (Long-press) để vào chế độ chọn nhiều
                                        if !isSelectionMode {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            withAnimation {
                                                isSelectionMode = true
                                                selectedPhotoIds.insert(photo.id)
                                            }
                                        }
                                    }
                                )
                                .onTapGesture {
                                    if isSelectionMode {
                                        toggleSelection(photoId: photo.id)
                                    } else {
                                        photoForViewer = photo
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 4)
                        .padding(.bottom, isSelectionMode ? 90 : 30)
                    }
                }
                
                // Thanh tác vụ hàng loạt khi ở chế độ Chọn nhiều ảnh (Batch Actions Toolbar)
                if isSelectionMode {
                    VStack(spacing: 0) {
                        Divider()
                        HStack(spacing: 16) {
                            // 1. Lưu vào Photos
                            Button(action: exportSelectedToPhotos) {
                                VStack(spacing: 3) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 20))
                                    Text("Lưu Photos")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(selectedPhotoIds.isEmpty ? .secondary : .blue)
                            }
                            .disabled(selectedPhotoIds.isEmpty)
                            .frame(maxWidth: .infinity)
                            
                            // 2. Nén thành ZIP
                            Button(action: {
                                customZipName = "\(album.name)_Backup.zip"
                                isZipNamePromptPresented = true
                            }) {
                                VStack(spacing: 3) {
                                    Image(systemName: "doc.zipper")
                                        .font(.system(size: 20))
                                    Text("Nén ZIP")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(selectedPhotoIds.isEmpty ? .secondary : .purple)
                            }
                            .disabled(selectedPhotoIds.isEmpty)
                            .frame(maxWidth: .infinity)
                            
                            // 3. Chuyển Album
                            Button(action: { isMoveSheetPresented = true }) {
                                VStack(spacing: 3) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 20))
                                    Text("Chuyển")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(selectedPhotoIds.isEmpty ? .secondary : .blue)
                            }
                            .disabled(selectedPhotoIds.isEmpty)
                            .frame(maxWidth: .infinity)
                            
                            // 4. Xóa
                            Button(action: deleteSelectedPhotos) {
                                VStack(spacing: 3) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 20))
                                    Text("Xóa")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(selectedPhotoIds.isEmpty ? .secondary : .red)
                            }
                            .disabled(selectedPhotoIds.isEmpty)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            
            // Overlay tiến trình nén / xuất
            if isExportingProgressPresented {
                ExportProgressSheet(
                    title: exportProgressTitle,
                    currentItemText: exportCurrentItemText,
                    progressValue: exportProgressValue,
                    onCancel: {
                        isExportCancelled = true
                        isExportingProgressPresented = false
                    }
                )
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSelectionMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isSelectionMode {
                    Button("Hủy") {
                        withAnimation {
                            isSelectionMode = false
                            selectedPhotoIds.removeAll()
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if !isSelectionMode {
                        Button(action: { isPhotoPickerPresented = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if !albumPhotos.isEmpty {
                        Button(isSelectionMode ? "Xong" : "Chọn") {
                            withAnimation {
                                isSelectionMode.toggle()
                                if !isSelectionMode {
                                    selectedPhotoIds.removeAll()
                                }
                            }
                        }
                    }
                    
                    Menu {
                        // Nhóm Export & Backup
                        Section("Xuất & Sao Lưu") {
                            Button(action: exportEntireAlbumToZip) {
                                Label("Export Album to ZIP", systemImage: "archivebox")
                            }
                            
                            Button(action: { isDocumentImporterPresented = true }) {
                                Label("Khôi Phục Từ File ZIP...", systemImage: "square.and.arrow.down.on.square")
                            }
                        }
                        
                        // Nhóm Quản lý Album
                        Section("Cấu Hình Album") {
                            Button(action: {
                                renameText = album.name
                                isRenameAlertPresented = true
                            }) {
                                Label("Đổi Tên Album", systemImage: "pencil")
                            }
                            
                            if !album.isDefault {
                                Button(role: .destructive, action: {
                                    isDeleteConfirmPresented = true
                                }) {
                                    Label("Xóa Album", systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .fullScreenCover(item: $photoForViewer) { photo in
            FullScreenPhotoViewer(
                photos: albumPhotos,
                initialPhotoId: photo.id,
                onDismiss: {
                    photoForViewer = nil
                }
            )
        }
        .sheet(isPresented: $isMoveSheetPresented) {
            MovePhotosSheet(
                photoIds: Array(selectedPhotoIds),
                currentAlbumId: album.id,
                isPresented: $isMoveSheetPresented,
                onCompleted: {
                    isSelectionMode = false
                    selectedPhotoIds.removeAll()
                }
            )
        }
        .sheet(isPresented: $isDocumentExporterPresented) {
            if let zipURL = generatedZipURL {
                DocumentExporterView(fileURL: zipURL) {
                    isDocumentExporterPresented = false
                }
            }
        }
        .sheet(isPresented: $isDocumentImporterPresented) {
            DocumentImporterView(
                onFilePicked: { pickedURL in
                    isDocumentImporterPresented = false
                    restoreFromPickedZip(url: pickedURL)
                },
                onCancelled: {
                    isDocumentImporterPresented = false
                }
            )
        }
        .sheet(isPresented: $isPhotoPickerPresented) {
            NativePhotoPickerView(
                isPresented: $isPhotoPickerPresented,
                targetAlbumId: album.id,
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
        .alert("Đã Lưu An Toàn Vào Kho Riêng Tư", isPresented: $isDeleteOriginalPromptPresented) {
            Button("Xóa Ảnh/Video Gốc Khỏi Máy", role: .destructive) {
                NativePhotoPickerView.deleteAssetsFromSystemLibrary(assetIds: verifiedDeleteAssetIds)
                verifiedDeleteAssetIds.removeAll()
            }
            Button("Giữ Lại Trên iPhone", role: .cancel) {
                verifiedDeleteAssetIds.removeAll()
            }
        } message: {
            Text("Đã mã hóa và lưu trữ an toàn \(importedSuccessCount) mục vào album '\(album.name)'.\n\nBạn có muốn xóa các ảnh & video gốc khỏi Thư viện ảnh iPhone để tránh lộ dữ liệu và giải phóng dung lượng không?")
        }
        .alert("Đặt Tên File ZIP", isPresented: $isZipNamePromptPresented) {
            TextField("Tên file sao lưu", text: $customZipName)
            Button("Bắt Đầu Nén", action: compressSelectedToZip)
            Button("Hủy", role: .cancel) {}
        }
        .alert("Đổi Tên Album", isPresented: $isRenameAlertPresented) {
            TextField("Tên mới", text: $renameText)
            Button("Lưu", action: {
                albumManager.renameAlbum(id: album.id, newName: renameText)
            })
            Button("Hủy", role: .cancel) {}
        }
        .alert("Xác Nhận Xóa Album", isPresented: $isDeleteConfirmPresented) {
            Button("Xóa Album và Giữ Lại Ảnh", action: {
                albumManager.deleteAlbum(id: album.id, deletePhotos: false)
                presentationMode.wrappedValue.dismiss()
            })
            Button("Xóa Album và Xóa Toàn Bộ Ảnh", role: .destructive, action: {
                albumManager.deleteAlbum(id: album.id, deletePhotos: true)
                presentationMode.wrappedValue.dismiss()
            })
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bạn có muốn xóa các bức ảnh trong album này hay chỉ xóa thư mục album?")
        }
        .alert("Xóa Bản Sao Riêng Tư?", isPresented: $isPostExportDeletePromptPresented) {
            Button("Xóa Khỏi Kho Riêng Tư", role: .destructive) {
                for item in exportedItemsForCleanup {
                    photoStorage.deletePhoto(id: item.id, permanent: false)
                }
                exportedItemsForCleanup.removeAll()
            }
            Button("Giữ Lại Trong Kho", role: .cancel) {
                exportedItemsForCleanup.removeAll()
            }
        } message: {
            Text("Đã lưu thành công các ảnh/video vào Thư viện Photos iPhone. Bạn có muốn xóa bản sao trong kho riêng tư này không?")
        }
        .alert(alertTitle, isPresented: $isGeneralAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Actions Implementation
    
    private func toggleSelection(photoId: UUID) {
        if selectedPhotoIds.contains(photoId) {
            selectedPhotoIds.remove(photoId)
        } else {
            selectedPhotoIds.insert(photoId)
        }
    }
    
    private func deleteSelectedPhotos() {
        for id in selectedPhotoIds {
            photoStorage.deletePhoto(id: id, permanent: false)
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        isSelectionMode = false
        selectedPhotoIds.removeAll()
    }
    
    /// Xuất các mục đã chọn ra ứng dụng iOS Photos
    private func exportSelectedToPhotos() {
        let items = selectedPhotos
        guard !items.isEmpty else { return }
        
        isExportCancelled = false
        exportProgressTitle = "Đang Lưu Vào Photos..."
        exportCurrentItemText = "Đang chuẩn bị giải mã..."
        exportProgressValue = 0.0
        isExportingProgressPresented = true
        
        Task {
            let result = await exportManager.exportMediaToPhotosLibrary(items: items) { current, total in
                Task { @MainActor in
                    self.exportCurrentItemText = "Đang xuất \(current)/\(total)..."
                    self.exportProgressValue = Double(current) / Double(max(1, total))
                }
            }
            
            await MainActor.run {
                self.isExportingProgressPresented = false
                if result.successCount > 0 {
                    self.exportedItemsForCleanup = items
                    self.isPostExportDeletePromptPresented = true
                } else {
                    self.alertTitle = "Lỗi Xuất Photos"
                    self.alertMessage = "Không thể lưu vào Photos. Vui lòng cấp quyền truy cập Thư viện ảnh trong Cài đặt iPhone."
                    self.isGeneralAlertPresented = true
                }
                self.isSelectionMode = false
                self.selectedPhotoIds.removeAll()
            }
        }
    }
    
    /// Nén các mục đã chọn thành file ZIP theo tên người dùng chỉ định
    private func compressSelectedToZip() {
        let items = selectedPhotos
        guard !items.isEmpty else { return }
        
        isExportCancelled = false
        exportProgressTitle = "Đang Nén Thành File ZIP..."
        exportCurrentItemText = "Bắt đầu tiến trình..."
        exportProgressValue = 0.0
        isExportingProgressPresented = true
        
        Task {
            do {
                let zipURL = try await exportManager.compressItemsToZip(
                    items: items,
                    zipFileName: customZipName.isEmpty ? "Backup.zip" : customZipName,
                    progress: { current, total, filename in
                        Task { @MainActor in
                            self.exportCurrentItemText = "Đang nén: \(filename) (\(current)/\(total))"
                            self.exportProgressValue = Double(current) / Double(max(1, total))
                        }
                    },
                    isCancelled: { self.isExportCancelled }
                )
                
                await MainActor.run {
                    self.isExportingProgressPresented = false
                    self.generatedZipURL = zipURL
                    // Mở Document Picker để lưu vào On My iPhone hoặc iCloud Drive
                    self.isDocumentExporterPresented = true
                    self.isSelectionMode = false
                    self.selectedPhotoIds.removeAll()
                }
            } catch {
                await MainActor.run {
                    self.isExportingProgressPresented = false
                    self.alertTitle = "Lỗi Nén ZIP"
                    self.alertMessage = error.localizedDescription
                    self.isGeneralAlertPresented = true
                }
            }
        }
    }
    
    /// Nén toàn bộ album thành file ZIP kèm manifest.json
    private func exportEntireAlbumToZip() {
        isExportCancelled = false
        exportProgressTitle = "Nén Toàn Bộ Album..."
        exportCurrentItemText = "Đang đọc cấu trúc album..."
        exportProgressValue = 0.0
        isExportingProgressPresented = true
        
        Task {
            do {
                let zipURL = try await exportManager.compressAlbumToZip(
                    album: album,
                    progress: { current, total, filename in
                        Task { @MainActor in
                            self.exportCurrentItemText = "Đang nén: \(filename) (\(current)/\(total))"
                            self.exportProgressValue = Double(current) / Double(max(1, total))
                        }
                    },
                    isCancelled: { self.isExportCancelled }
                )
                
                await MainActor.run {
                    self.isExportingProgressPresented = false
                    self.generatedZipURL = zipURL
                    self.isDocumentExporterPresented = true
                }
            } catch {
                await MainActor.run {
                    self.isExportingProgressPresented = false
                    self.alertTitle = "Lỗi Nén Album"
                    self.alertMessage = error.localizedDescription
                    self.isGeneralAlertPresented = true
                }
            }
        }
    }
    
    /// Khôi phục ảnh & video từ file ZIP đã chọn trong Files
    private func restoreFromPickedZip(url: URL) {
        isExportCancelled = false
        exportProgressTitle = "Khôi Phục Dữ Liệu Từ ZIP..."
        exportCurrentItemText = "Đang giải nén và mã hóa..."
        exportProgressValue = 0.0
        isExportingProgressPresented = true
        
        Task {
            do {
                let count = try await exportManager.restoreBackupFromZip(
                    zipURL: url,
                    targetAlbumId: album.id,
                    progress: { current, total, filename in
                        Task { @MainActor in
                            self.exportCurrentItemText = "Đang khôi phục: \(filename) (\(current)/\(total))"
                            self.exportProgressValue = Double(current) / Double(max(1, total))
                        }
                    }
                )
                
                await MainActor.run {
                    self.isExportingProgressPresented = false
                    self.alertTitle = "Khôi Phục Thành Công"
                    self.alertMessage = "Đã nhập thành công \(count) ảnh & video vào album '\(album.name)'."
                    self.isGeneralAlertPresented = true
                }
            } catch {
                await MainActor.run {
                    self.isExportingProgressPresented = false
                    self.alertTitle = "Lỗi Khôi Phục"
                    self.alertMessage = error.localizedDescription
                    self.isGeneralAlertPresented = true
                }
            }
        }
    }
}

/// Sheet chọn album để di chuyển ảnh
struct MovePhotosSheet: View {
    let photoIds: [UUID]
    let currentAlbumId: UUID
    @Binding var isPresented: Bool
    let onCompleted: () -> Void
    @ObservedObject var albumManager: AlbumManager = AlbumManager.shared
    
    var body: some View {
        NavigationView {
            List(albumManager.albums.filter { $0.id != currentAlbumId }) { targetAlbum in
                Button(action: {
                    albumManager.movePhotos(photoIds: photoIds, to: targetAlbum.id)
                    isPresented = false
                    onCompleted()
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                        Text(targetAlbum.name)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(albumManager.photoCount(for: targetAlbum.id)) ảnh")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Chọn Album Đích")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
