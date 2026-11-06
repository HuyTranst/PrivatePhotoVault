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
        
        Task {
            var importedCount = 0
            var verifiedAssetIds: [String] = []
            
            for (index, asset) in targetAssets.enumerated() {
                await MainActor.run {
                    self.importProgressValue = Double(index) / Double(max(1, total))
                    self.importProgressText = "\(index + 1) / \(total)"
                }
                
                let resources = PHAssetResource.assetResources(for: asset)
                
                // 1. Nhập Video
                if asset.mediaType == .video {
                    let videoResource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) ?? resources.first
                    if let res = videoResource {
                        let filename = res.originalFilename
                        let tempDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_" + filename)
                        
                        let writeSuccess = await self.writeAssetResource(res, to: tempDest)
                        if writeSuccess {
                            do {
                                let importedItem = try await PhotoStorageManager.shared.importVideo(
                                    sourceURL: tempDest,
                                    originalFileName: filename,
                                    albumId: self.targetAlbumId
                                )
                                try? FileManager.default.removeItem(at: tempDest)
                                
                                if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(importedItem) {
                                    importedCount += 1
                                    verifiedAssetIds.append(asset.localIdentifier)
                                }
                            } catch {
                                print("Lỗi nhập video từ resource: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                // 2. Nhập Ảnh (HEIC, RAW, JPEG, PNG 100% nguyên bản)
                else {
                    let photoResource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) ?? resources.first
                    if let res = photoResource {
                        let filename = res.originalFilename
                        let tempDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_" + filename)
                        
                        let writeSuccess = await self.writeAssetResource(res, to: tempDest)
                        if writeSuccess {
                            if let data = try? Data(contentsOf: tempDest), !data.isEmpty {
                                do {
                                    let savedPhoto = try await PhotoStorageManager.shared.importAndEncryptPhotoData(
                                        data: data,
                                        originalFileName: filename,
                                        albumId: self.targetAlbumId
                                    )
                                    try? FileManager.default.removeItem(at: tempDest)
                                    
                                    if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(savedPhoto) {
                                        importedCount += 1
                                        verifiedAssetIds.append(asset.localIdentifier)
                                    }
                                } catch {
                                    print("Lỗi lưu ảnh raw: \(error.localizedDescription)")
                                }
                            }
                        } else {
                            // Fallback qua PHImageManager nếu writeResource không được
                            if let uiImage = await self.requestUIImage(from: asset) {
                                do {
                                    let savedPhoto = try await PhotoStorageManager.shared.importAndEncryptPhoto(
                                        image: uiImage,
                                        originalFileName: "\(asset.localIdentifier.prefix(8)).jpg",
                                        albumId: self.targetAlbumId
                                    )
                                    if PhotoStorageManager.shared.isMediaPhysicallyOnDisk(savedPhoto) {
                                        importedCount += 1
                                        verifiedAssetIds.append(asset.localIdentifier)
                                    }
                                } catch {
                                    print("Lỗi lưu ảnh UIImage: \(error.localizedDescription)")
                                }
                            }
                        }
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
    
    // MARK: - Low-Level Extraction Helpers
    
    private func writeAssetResource(_ resource: PHAssetResource, to destinationURL: URL) async -> Bool {
        return await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            
            PHAssetResourceManager.default().writeData(for: resource, toFile: destinationURL, options: options) { error in
                if let error = error {
                    print("Lỗi trích xuất resource \(resource.originalFilename): \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    private func requestUIImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
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
