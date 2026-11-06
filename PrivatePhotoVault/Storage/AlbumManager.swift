import Foundation
import Combine

/// Quản lý danh sách album, liên kết ảnh và phân loại thư mục
public final class AlbumManager: ObservableObject {
    public static let shared = AlbumManager()
    
    @Published public var albums: [Album] = []
    private var cancellables = Set<AnyCancellable>()
    
    private let fileManager = FileManager.default
    private let albumsFileName = "vault_albums_meta.json"
    
    private var albumsFileURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vault = docs.appendingPathComponent("Vault", isDirectory: true)
        return vault.appendingPathComponent(albumsFileName)
    }
    
    private init() {
        loadAlbums()
        setupPhotoObserver()
    }
    
    private func setupPhotoObserver() {
        PhotoStorageManager.shared.$photos
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence & Initial Seed
    
    private func loadAlbums() {
        if fileManager.fileExists(atPath: albumsFileURL.path),
           let data = try? Data(contentsOf: albumsFileURL) {
            if let decrypted = try? CryptoEngine.shared.decrypt(combinedData: data),
               let decoded = try? JSONDecoder().decode([Album].self, from: decrypted) {
                self.albums = decoded
                return
            } else if let decoded = try? JSONDecoder().decode([Album].self, from: data) {
                self.albums = decoded
                return
            }
        }
        
        // Khởi tạo các Album mặc định chuẩn theo giao diện tham chiếu xemanh.jpg
        self.albums = [
            Album(name: "Main Album", isDefault: true, sortOrder: 0),
            Album(name: "MC Ngọc Nhi", isDefault: false, sortOrder: 1),
            Album(name: "Tu Loan", isDefault: false, sortOrder: 2),
            Album(name: "Fake Nude", isDefault: false, sortOrder: 3)
        ]
        saveAlbums()
    }
    
    public func saveAlbums() {
        do {
            let encoded = try JSONEncoder().encode(albums)
            let encrypted = try CryptoEngine.shared.encrypt(data: encoded)
            try encrypted.write(to: albumsFileURL, options: .atomic)
        } catch {
            print("Lỗi lưu metadata album: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Album Operations
    
    /// Tạo album mới
    @discardableResult
    public func createAlbum(name: String) -> Album {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Album Mới" : trimmed
        let album = Album(name: finalName, sortOrder: albums.count)
        albums.append(album)
        saveAlbums()
        return album
    }
    
    /// Đổi tên album
    public func renameAlbum(id: UUID, newName: String) {
        guard let index = albums.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            albums[index].name = trimmed
            saveAlbums()
        }
    }
    
    /// Xóa album và tùy chọn xóa ảnh hoặc giữ lại ảnh
    public func deleteAlbum(id: UUID, deletePhotos: Bool) {
        guard let index = albums.firstIndex(where: { $0.id == id }) else { return }
        let album = albums[index]
        if album.isDefault { return } // Không xóa album mặc định gốc
        
        if deletePhotos {
            let photosInAlbum = PhotoStorageManager.shared.photos.filter { $0.albumIds.contains(id) }
            for photo in photosInAlbum {
                PhotoStorageManager.shared.deletePhoto(id: photo.id, permanent: false)
            }
        } else {
            // Chỉ gỡ liên kết album khỏi các bức ảnh
            for i in 0..<PhotoStorageManager.shared.photos.count {
                PhotoStorageManager.shared.photos[i].albumIds.removeAll(where: { $0 == id })
            }
            PhotoStorageManager.shared.saveMetadata()
        }
        
        albums.remove(at: index)
        saveAlbums()
    }
    
    /// ID của Album mặc định ("Main Album" chứa toàn bộ ảnh)
    public var defaultAlbumId: UUID? {
        return albums.first(where: { $0.isDefault })?.id ?? albums.first?.id
    }
    
    /// Lấy danh sách ảnh thuộc về một album cụ thể (chỉ ảnh không nằm trong thùng rác)
    /// Với Album mặc định (Main Album), luôn hiển thị TOÀN BỘ ảnh có trong kho
    public func photos(in albumId: UUID) -> [EncryptedPhoto] {
        let isDefaultAlbum = albums.first(where: { $0.id == albumId })?.isDefault ?? false
        return PhotoStorageManager.shared.photos.filter {
            if $0.isTrash { return false }
            if isDefaultAlbum {
                return true
            }
            return $0.albumIds.contains(albumId)
        }
    }
    
    /// Số lượng ảnh đang có trong album
    public func photoCount(for albumId: UUID) -> Int {
        return photos(in: albumId).count
    }
    
    /// Lấy bức ảnh làm ảnh bìa cho album (hoặc ảnh mới nhất)
    public func coverPhoto(for album: Album) -> EncryptedPhoto? {
        let albumPhotos = photos(in: album.id)
        if let coverId = album.coverPhotoId, let found = albumPhotos.first(where: { $0.id == coverId }) {
            return found
        }
        return albumPhotos.first
    }
    
    /// Di chuyển danh sách ảnh sang album đích
    public func movePhotos(photoIds: [UUID], to targetAlbumId: UUID) {
        for id in photoIds {
            if let index = PhotoStorageManager.shared.photos.firstIndex(where: { $0.id == id }) {
                PhotoStorageManager.shared.photos[index].albumIds = [targetAlbumId]
            }
        }
        PhotoStorageManager.shared.saveMetadata()
    }
}
