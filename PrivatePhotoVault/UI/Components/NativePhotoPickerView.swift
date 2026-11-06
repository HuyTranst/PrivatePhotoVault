import SwiftUI
import Photos

/// Bộ chọn Ảnh & Video Native in-process thuần SwiftUI, không sử dụng Out-of-Process XPC
/// Loại bỏ 100% lỗi văng app / crash trên môi trường TrollStore / Fakesign
public struct NativePhotoPickerView: View {
    @Binding var isPresented: Bool
    public let targetAlbumId: UUID
    public let onImportCompleted: (Int, [String]) -> Void
    
    @State private var permissionStatus: PHAuthorizationStatus = .notDetermined
    @State private var allAssets: [PHAsset] = []
    @State private var selectedAssetIds: Set<String> = []
    @State private var filterMode: PickerFilter = .all
    
    @State private var isImporting: Bool = false
    @State private var importProgressText: String = ""
    @State private var importProgressValue: Double = 0.0
    
    public enum PickerFilter: String, CaseIterable {
        case all = "Tất Cả"
        case photos = "Ảnh"
        case videos = "Video"
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    public init(
        isPresented: Binding<Bool>,
        targetAlbumId: UUID,
        onImportCompleted: @escaping (Int, [String]) -> Void
    ) {
        self._isPresented = isPresented
        self.targetAlbumId = targetAlbumId
        self.onImportCompleted = onImportCompleted
    }
    
    private var filteredAssets: [PHAsset] {
        switch filterMode {
        case .all:
            return allAssets
        case .photos:
            return allAssets.filter { $0.mediaType == .image }
        case .videos:
            return allAssets.filter { $0.mediaType == .video }
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                if permissionStatus == .authorized || permissionStatus == .limited {
                    VStack(spacing: 0) {
                        // Bộ lọc danh mục (Tất Cả / Ảnh / Video)
                        Picker("Bộ lọc", selection: $filterMode) {
                            ForEach(PickerFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        
                        // Lưới hiển thị toàn bộ ảnh và video trong máy
                        if filteredAssets.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("Không tìm thấy ảnh hoặc video nào")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(filteredAssets, id: \.localIdentifier) { asset in
                                        NativeAssetThumbnailView(
                                            asset: asset,
                                            isSelected: selectedAssetIds.contains(asset.localIdentifier)
                                        )
                                        .onTapGesture {
                                            toggleSelection(for: asset.localIdentifier)
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                } else if permissionStatus == .notDetermined {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("Đang kiểm tra quyền truy cập Thư viện ảnh...")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Quyền bị từ chối
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 56))
                            .foregroundColor(.orange)
                        
                        Text("Cần Quyền Truy Cập Thư Viện Ảnh")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Vui lòng cấp quyền truy cập Thư viện ảnh trong Cài đặt iPhone để chọn và mã hóa ảnh vào kho riêng tư.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: requestPermissions) {
                            Text("Yêu Cầu Cấp Quyền")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(22)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Màn hình tiến trình đang nhập ảnh (Import HUD Overlay)
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.55).ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.4)
                            
                            Text("Đang Mã Hóa & Lưu An Toàn...")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(importProgressText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                            
                            ProgressView(value: importProgressValue, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(width: 200)
                        }
                        .padding(24)
                        .background(Color(UIColor.darkGray).opacity(0.9))
                        .cornerRadius(18)
                        .shadow(radius: 12)
                    }
                }
            }
            .navigationTitle(selectedAssetIds.isEmpty ? "Chọn Ảnh & Video" : "Đã chọn \(selectedAssetIds.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        isPresented = false
                    }
                    .disabled(isImporting)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startImporting) {
                        Text(selectedAssetIds.isEmpty ? "Thêm" : "Thêm (\(selectedAssetIds.count))")
                            .fontWeight(.semibold)
                    }
                    .disabled(selectedAssetIds.isEmpty || isImporting)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            checkPermissionsAndLoadAssets()
        }
    }
    
    // MARK: - Selection Operations
    
    private func toggleSelection(for assetId: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        if selectedAssetIds.contains(assetId) {
            selectedAssetIds.remove(assetId)
        } else {
            selectedAssetIds.insert(assetId)
        }
    }
    
    // MARK: - Permission & Assets Loading
    
    private func checkPermissionsAndLoadAssets() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.permissionStatus = status
        
        if status == .authorized || status == .limited {
            loadAssetsFromLibrary()
        } else if status == .notDetermined {
            requestPermissions()
        }
    }
    
    private func requestPermissions() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
            DispatchQueue.main.async {
                self.permissionStatus = newStatus
                if newStatus == .authorized || newStatus == .limited {
                    self.loadAssetsFromLibrary()
                }
            }
        }
    }
    
    private func loadAssetsFromLibrary() {
        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(with: options)
            var loaded: [PHAsset] = []
            loaded.reserveCapacity(fetchResult.count)
            
            fetchResult.enumerateObjects { asset, _, _ in
                loaded.append(asset)
            }
            
            DispatchQueue.main.async {
                self.allAssets = loaded
            }
        }
    }
    
    // MARK: - Robust Import Pipeline
    
    private func startImporting() {
        guard !selectedAssetIds.isEmpty else { return }
        
        isImporting = true
        importProgressValue = 0.0
        
        let targetAssets = allAssets.filter { selectedAssetIds.contains($0.localIdentifier) }
        let total = targetAssets.count
        
        // Luôn đảm bảo ảnh vừa thuộc album đích vừa thuộc Main Album để không bao giờ bị lạc
        var targetAlbumIds: [UUID] = [self.targetAlbumId]
        if let mainId = AlbumManager.shared.defaultAlbumId, !targetAlbumIds.contains(mainId) {
            targetAlbumIds.append(mainId)
        }
        
        Task.detached(priority: .userInitiated) {
            var importedCount = 0
            var verifiedAssetIds: [String] = []
            
            for (index, asset) in targetAssets.enumerated() {
                await MainActor.run {
                    self.importProgressValue = Double(index) / Double(max(1, total))
                    self.importProgressText = "Đang xử lý \(index + 1) / \(total)..."
                }
                
                // 1. Nhập Video đa tầng (AVURLAsset -> Export Passthrough -> PHAssetResource)
                if asset.mediaType == .video {
                    if let savedItem = await self.extractAndSaveVideo(asset: asset, albumIds: targetAlbumIds) {
                        importedCount += 1
                        verifiedAssetIds.append(asset.localIdentifier)
                    }
                }
                // 2. Nhập Ảnh đa tầng (Raw Data HEIC/PNG/JPG -> UIImage -> PHAssetResource)
                else {
                    if let savedItem = await self.extractAndSavePhoto(asset: asset, albumIds: targetAlbumIds) {
                        importedCount += 1
                        verifiedAssetIds.append(asset.localIdentifier)
                    }
                }
            }
            
            await MainActor.run {
                self.importProgressValue = 1.0
                self.isImporting = false
                self.isPresented = false
                
                // Đợi sheet đóng hoàn tất rồi mới kích hoạt Alert xác nhận xóa gốc
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.onImportCompleted(importedCount, verifiedAssetIds)
                }
            }
        }
    }
    
    // MARK: - Bullet-proof Multi-Tier Photo Extraction
    
    /// Trích xuất và mã hóa ảnh an toàn 100% bằng cơ chế 3 tầng
    private func extractAndSavePhoto(asset: PHAsset, albumIds: [UUID]) async -> EncryptedPhoto? {
        // TẦNG 1: Lấy trực tiếp raw Data (HEIC, RAW, PNG, JPEG) đồng bộ trên background thread
        if let (rawData, filename) = fetchRawImageDataSynchronously(for: asset) {
            do {
                let saved = try await PhotoStorageManager.shared.importAndEncryptPhotoData(
                    data: rawData,
                    originalFileName: filename,
                    albumIds: albumIds
                )
                if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(saved) {
                    return saved
                }
            } catch {
                print("Lỗi lưu rawData: \(error.localizedDescription)")
            }
        }
        
        // TẦNG 2: Fallback lấy UIImage chất lượng cao nhất đồng bộ trên background thread
        if let uiImage = fetchUIImageSynchronously(for: asset) {
            do {
                let filename = "IMG_\(asset.localIdentifier.prefix(8)).jpg"
                let saved = try await PhotoStorageManager.shared.importAndEncryptPhoto(
                    image: uiImage,
                    originalFileName: filename,
                    albumIds: albumIds
                )
                if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(saved) {
                    return saved
                }
            } catch {
                print("Lỗi lưu UIImage: \(error.localizedDescription)")
            }
        }
        
        // TẦNG 3: Fallback qua PHAssetResource nếu có
        let resources = PHAssetResource.assetResources(for: asset)
        if let res = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) ?? resources.first {
            let filename = res.originalFilename
            let tempDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_" + filename)
            let writeOk = await self.writeAssetResource(res, to: tempDest)
            if writeOk, let fileData = try? Data(contentsOf: tempDest), !fileData.isEmpty {
                defer { try? FileManager.default.removeItem(at: tempDest) }
                do {
                    let saved = try await PhotoStorageManager.shared.importAndEncryptPhotoData(
                        data: fileData,
                        originalFileName: filename,
                        albumIds: albumIds
                    )
                    if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(saved) {
                        return saved
                    }
                } catch {
                    print("Lỗi lưu resource data: \(error.localizedDescription)")
                }
            }
        }
        
        return nil
    }
    
    private func fetchRawImageDataSynchronously(for asset: PHAsset) -> (Data, String)? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        var resultData: Data? = nil
        var resultFilename = "IMG_\(asset.localIdentifier.prefix(8)).jpg"
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
            if let data = data, !data.isEmpty {
                resultData = data
                if let utiStr = uti {
                    if utiStr.contains("heic") || utiStr.contains("heif") {
                        resultFilename = "IMG_\(asset.localIdentifier.prefix(8)).heic"
                    } else if utiStr.contains("png") {
                        resultFilename = "IMG_\(asset.localIdentifier.prefix(8)).png"
                    } else {
                        resultFilename = "IMG_\(asset.localIdentifier.prefix(8)).jpg"
                    }
                }
            }
        }
        
        if let data = resultData {
            return (data, resultFilename)
        }
        return nil
    }
    
    private func fetchUIImageSynchronously(for asset: PHAsset) -> UIImage? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        var resultImage: UIImage? = nil
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            resultImage = image
        }
        return resultImage
    }
    
    // MARK: - Bullet-proof Multi-Tier Video Extraction
    
    /// Trích xuất và lưu trữ video nguyên gốc đa tầng
    private func extractAndSaveVideo(asset: PHAsset, albumIds: [UUID]) async -> EncryptedPhoto? {
        // TẦNG 1: Lấy trực tiếp file video gốc qua AVURLAsset
        if let sourceURL = await fetchVideoURL(for: asset) {
            do {
                let saved = try await PhotoStorageManager.shared.importVideo(
                    sourceURL: sourceURL,
                    originalFileName: sourceURL.lastPathComponent,
                    albumIds: albumIds
                )
                if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(saved) {
                    return saved
                }
            } catch {
                print("Lỗi lưu AVURLAsset video: \(error.localizedDescription)")
            }
        }
        
        // TẦNG 2: Export session không nén (Passthrough) ra file tạm rồi lưu
        let tempExportURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".mp4")
        let exportOk = await exportVideoPassthrough(for: asset, to: tempExportURL)
        if exportOk && FileManager.default.fileExists(atPath: tempExportURL.path) {
            defer { try? FileManager.default.removeItem(at: tempExportURL) }
            do {
                let saved = try await PhotoStorageManager.shared.importVideo(
                    sourceURL: tempExportURL,
                    originalFileName: "VID_\(asset.localIdentifier.prefix(8)).mp4",
                    albumIds: albumIds
                )
                if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(saved) {
                    return saved
                }
            } catch {
                print("Lỗi lưu exported video: \(error.localizedDescription)")
            }
        }
        
        // TẦNG 3: Fallback qua PHAssetResource
        let resources = PHAssetResource.assetResources(for: asset)
        if let res = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) ?? resources.first {
            let filename = res.originalFilename
            let tempDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_" + filename)
            let writeOk = await self.writeAssetResource(res, to: tempDest)
            if writeOk && FileManager.default.fileExists(atPath: tempDest.path) {
                defer { try? FileManager.default.removeItem(at: tempDest) }
                do {
                    let saved = try await PhotoStorageManager.shared.importVideo(
                        sourceURL: tempDest,
                        originalFileName: filename,
                        albumIds: albumIds
                    )
                    if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(saved) {
                        return saved
                    }
                } catch {
                    print("Lỗi lưu video từ resource: \(error.localizedDescription)")
                }
            }
        }
        
        return nil
    }
    
    private func fetchVideoURL(for asset: PHAsset) async -> URL? {
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            var hasResumed = false
            let lock = NSLock()
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    if let urlAsset = avAsset as? AVURLAsset {
                        continuation.resume(returning: urlAsset.url)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    private func exportVideoPassthrough(for asset: PHAsset, to destinationURL: URL) async -> Bool {
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            var hasResumed = false
            let lock = NSLock()
            
            PHImageManager.default().requestExportSession(
                forVideo: asset,
                options: options,
                exportPreset: AVAssetExportPresetPassthrough
            ) { exportSession, _ in
                guard let session = exportSession else {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: false)
                    }
                    return
                }
                
                session.outputURL = destinationURL
                session.outputFileType = .mp4
                session.exportAsynchronously {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: session.status == .completed)
                    }
                }
            }
        }
    }
    
    // MARK: - Safe Asset Deletion
    
    /// Xóa an toàn các ảnh/video gốc khỏi Thư viện ảnh Apple Photos (chỉ gọi sau khi đã kiểm tra tệp tồn tại trên đĩa)
    public static func deleteAssetsFromSystemLibrary(assetIds: [String], onCompleted: ((Bool) -> Void)? = nil) {
        guard !assetIds.isEmpty else {
            onCompleted?(true)
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                print("Chưa có quyền xóa ảnh trong thư viện Photos.")
                onCompleted?(false)
                return
            }
            
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
            guard assets.count > 0 else {
                onCompleted?(true)
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Đã xóa \(assets.count) ảnh/video gốc khỏi thư viện Apple Photos.")
                    } else if let err = error {
                        print("Lỗi khi xóa gốc: \(err.localizedDescription)")
                    }
                    onCompleted?(success)
                }
            }
        }
    }
}

// MARK: - Thumbnail View Cho Từng Item Trên Lưới

struct NativeAssetThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .aspectRatio(1.0, contentMode: .fit)
                }
                
                // Thời lượng Video nếu là file Video
                if asset.mediaType == .video {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                        Text(formatDuration(asset.duration))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(4)
                    .padding(4)
                }
            }
            
            // Checkmark Đánh Dấu Chọn
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .background(Circle().fill(isSelected ? Color.blue : Color.black.opacity(0.3)))
                    .frame(width: 24, height: 24)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(6)
        }
        .contentShape(Rectangle())
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        let targetSize = CGSize(width: 250, height: 250)
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { img, _ in
            if let image = img {
                self.thumbnail = image
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
