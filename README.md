# Private Photo Vault – Kho Ảnh Bí Mật (iOS / TrollStore)

> **Ứng dụng kho ảnh riêng tư bảo mật chuẩn quân sự cho iPhone, hoạt động 100% Offline, ngụy trang tinh vi giao diện ngân hàng Vietcombank (VCB Digibank), tích hợp sẵn cài đặt vĩnh viễn qua TrollStore (định dạng IPA).**

---

## 1. Điểm Nổi Bật & Tính Năng Chính

- **Cài đặt vĩnh viễn qua TrollStore**: Đóng gói định dạng IPA chuẩn, không cần gia hạn chứng chỉ 7 ngày, không sợ bị thu hồi chứng chỉ (Revoke), tương thích iOS 14.0 đến 17.0+ và 18.x (TrollStore 1 & 2).
- **Mã Hóa Chuẩn Quân Sự AES-256-GCM**: Toàn bộ ảnh gốc và ảnh thu nhỏ đều được mã hóa bằng thuật toán `AES-256-GCM` thông qua Apple `CryptoKit`. Dữ liệu chỉ được giải mã tạm thời trên bộ nhớ RAM khi xem và không bao giờ ghi ảnh chưa mã hóa ra đĩa.
- **Bảo Vệ Khóa Qua iOS Keychain**: Khóa đối xứng 256-bit được sinh ngẫu nhiên an toàn và lưu trữ trong `Keychain Secure Enclave` với cờ bảo vệ `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **Hoạt Động 100% Offline (Zero Cloud / Zero Network)**: Không cần tài khoản, không máy chủ kích hoạt, không đăng ký định kỳ, không gửi bất kỳ dữ liệu nào ra mạng Internet.
- **Giao Diện Ngụy Trang Tinh Vi (Decoy Interface)**:
  - Khi mở ứng dụng, màn hình hiển thị giao diện đăng nhập **VCB Digibank** (`001.PNG`).
  - Mọi thao tác chạm thông thường vào màn hình sẽ tự động đóng/thu nhỏ ứng dụng về màn hình chính iOS (Home Screen).
  - Chỉ khi chạm chính xác vào biểu tượng **Thông báo** (chuông vàng kèm huy hiệu đỏ `9+` ở góc dưới bên phải), cửa sổ nhập mật khẩu bí mật mới xuất hiện.
  - Mật khẩu truy cập mặc định: `36@Hamnghi`.
- **Kho Ảnh Chuẩn Native Apple Photos (`xemanh.jpg`)**:
  - Bố cục danh sách Album dạng lưới 2 cột mượt mà, bo góc mềm mại (~18pt).
  - Thanh điều hướng đáy 3 nút: **Create Album**, nút tròn màu xanh dương nổi bật **Add Picture (+)**, và **Exit**.
  - Nút Cài đặt (biểu tượng bánh răng - Gear) ở góc trên bên phải.
  - Trình xem ảnh toàn màn hình mượt mà: Hỗ trợ Pinch-to-zoom (phóng to đến 4x), Double-tap zoom, vuốt ngang chuyển ảnh tức thì nhờ thuật toán **Preloading Pipeline** nạp trước ảnh liền kề trong luồng nền.
- **Quy Trình Nhập Ảnh & Hỏi Xóa Ảnh Gốc Chuẩn Apple**:
  - Mở `PHPickerViewController` cho phép chọn cùng lúc nhiều ảnh chất lượng cao.
  - Tự động mã hóa và tạo ảnh thumbnail siêu tốc (< 1ms).
  - Hiển thị hộp thoại chính thức: *"Do you want to delete the original photos from your iPhone Photos library?"* với 2 lựa chọn: **Delete Original Photos** và **Keep Original Photos** thông qua API chính thức `PHPhotoLibrary`.
- **Trung Tâm Cài Đặt Đầy Đủ Chức Năng Thực Tế (`cauhinh.jpg`)**:
  - **Backup & Sync**: Quản lý xuất file sao lưu cục bộ dạng `.vault` an toàn.
  - **Account**: Kiểm tra trạng thái kho offline và bản quyền TrollStore vĩnh viễn.
  - **Trash**: Quản lý ảnh trong thùng rác (Recently Deleted), khôi phục hoặc xóa vĩnh viễn khỏi thiết bị.
  - **Alerts**: Kiểm toán tính toàn vẹn của khóa và tệp tin mã hóa.
  - **Lock Screen**: Đổi mật khẩu (`36@Hamnghi` sang mật khẩu mới), bật/tắt Face ID/Touch ID, cài đặt thời gian tự động khóa khi chạy ngầm.
  - **Adding to Vault**: Bật/tắt tùy chọn tự động hỏi xóa ảnh gốc, chọn chất lượng ảnh.
  - **Appearance**: Chuyển đổi giao diện Sáng / Tối / Tự động.
  - **Storage & Cache**: Xem dung lượng thực tế của ảnh mã hóa, thumbnail, bộ nhớ trống của máy, kèm nút **Clear Cache** dọn dẹp RAM an toàn.
  - **Exit Application**: Thoát và khóa kho ảnh tức thì, xóa sạch dữ liệu RAM và trở về giao diện ngụy trang.

---

## 2. Cấu Trúc Thư Mục Dự Án

```
D:\PrivatePhotoVault\
├── .github\
│   └── workflows\
│       └── build-ipa.yml              # CI/CD tự động build IPA và Release trên macOS
├── PrivatePhotoVault\
│   ├── App\
│   │   ├── AppDelegate.swift          # Quản lý vòng đời app, tự động khóa khi chạy ngầm
│   │   ├── AppState.swift             # Quản lý trạng thái mở khóa, navigation toàn cục
│   │   └── PrivatePhotoVaultApp.swift # Điểm khởi chạy chính (@main SwiftUI)
│   ├── Models\
│   │   ├── Album.swift                # Thực thể Album ảnh
│   │   ├── EncryptedPhoto.swift       # Thực thể bức ảnh đã mã hóa AES-256
│   │   └── VaultSettings.swift        # Cấu hình người dùng
│   ├── Security\
│   │   ├── AuthenticationManager.swift# Xác thực mật khẩu (36@Hamnghi), Face ID
│   │   ├── CryptoEngine.swift         # Động cơ mã hóa AES-256-GCM (CryptoKit)
│   │   └── KeychainHelper.swift       # Giao tiếp iOS Keychain Enclave
│   ├── Storage\
│   │   ├── AlbumManager.swift         # Quản lý tạo/xóa/sửa album
│   │   ├── PhotoStorageManager.swift  # Nhập, lưu, giải mã và quản lý dung lượng ảnh
│   │   └── VaultCacheManager.swift    # Bộ nhớ đệm RAM NSCache tốc độ cao
│   ├── UI\
│   │   ├── Components\
│   │   │   ├── BottomNavigationBar.swift    # Thanh điều hướng 3 nút (xemanh.jpg)
│   │   │   └── PhotoPickerCoordinator.swift # Trình chọn ảnh & hỏi xóa ảnh gốc
│   │   ├── Decoy\
│   │   │   ├── DecoyView.swift              # Giao diện ngụy trang VCB Digibank (001.PNG)
│   │   │   └── PasswordEntryView.swift      # Cửa sổ nhập mật khẩu bảo mật
│   │   ├── Gallery\
│   │   │   ├── AlbumDetailView.swift        # Lưới ảnh 3 cột trong Album
│   │   │   ├── CreateAlbumSheet.swift       # Hộp thoại tạo album mới
│   │   │   ├── MainAlbumsView.swift         # Màn hình kho ảnh chính (xemanh.jpg)
│   │   │   └── PhotoThumbnailView.swift     # Ô thumbnail bất đồng bộ
│   │   ├── Viewer\
│   │   │   ├── FullScreenPhotoViewer.swift  # Trình xem ảnh toàn màn hình
│   │   │   └── ZoomableImageView.swift      # Thành phần Pinch-to-zoom & Double-tap
│   │   └── Settings\
│   │       ├── AboutAppView.swift           # Thông tin ứng dụng và bản quyền
│   │       ├── AccountStatusView.swift      # Trạng thái tài khoản offline
│   │       ├── AddingToVaultSettingsView.swift # Cài đặt chất lượng & hỏi xóa gốc
│   │       ├── AlertsAuditView.swift        # Kiểm toán an toàn dữ liệu
│   │       ├── AppearanceSettingsView.swift # Cài đặt giao diện Sáng / Tối
│   │       ├── BackupAndSyncView.swift      # Xuất sao lưu .vault cục bộ
│   │       ├── LockScreenSettingsView.swift # Đổi mật khẩu & Face ID
│   │       ├── SettingsView.swift           # Giao diện Cài đặt (cauhinh.jpg)
│   │       ├── StorageAndCacheView.swift    # Quản lý dung lượng & Clear Cache
│   │       └── TrashManagementView.swift    # Quản lý thùng rác (khôi phục/xóa)
│   └── Resources\
│       ├── Assets.xcassets\           # Bộ icon đầy đủ kích thước từ ico.jpg & 001.png
│       ├── Info.plist                 # Quyền Photos, Face ID, cấm network
│       └── entitlements.plist         # Quyền TrollStore (no-sandbox)
├── PrivatePhotoVault.xcodeproj\       # Dự án Xcode hoàn chỉnh
├── build_ipa.py                       # Script đóng gói file IPA tự động
├── generate_pbxproj.py                # Script sinh cấu hình Xcode tự động
└── README.md                          # Tài liệu hướng dẫn sử dụng và cài đặt
```

---

## 3. Hướng Dẫn Cài Đặt Qua TrollStore Trên iPhone

### Cách 1: Tải file IPA trực tiếp và cài đặt qua TrollStore (Khuyên dùng)
1. Tải file `PrivatePhotoVault.ipa` (hoặc từ GitHub Release).
2. Chuyển file IPA vào iPhone qua AirDrop, tải trực tiếp bằng Safari, hoặc gửi qua Telegram/iMessage.
3. Chạm vào file `.ipa` đã tải về -> Chọn biểu tượng **Share (Chia sẻ)** -> Chọn **TrollStore** (hoặc mở TrollStore và nhấn dấu `+` chọn `Install IPA File`).
4. Ứng dụng sẽ được cài đặt ngay lập tức và xuất hiện trên màn hình chính với icon dải ruy-băng xanh lá (`ico.jpg`).
5. **Không bao giờ bị hết hạn chứng chỉ 7 ngày!**

---

## 4. Hướng Dẫn Sử Dụng Chi Tiết

### 4.1. Mở Kho Bí Mật Từ Giao Diện Ngụy Trang
1. Mở ứng dụng từ màn hình chính: Bạn sẽ thấy giao diện đăng nhập ngân hàng **VCB Digibank** (`001.PNG`).
2. Nếu người khác mượn máy hoặc bạn chạm bất kỳ đâu: Ứng dụng sẽ tự động thu nhỏ về màn hình chính iOS (Home Screen) như một ứng dụng bình thường.
3. Để mở kho bí mật:
   - Chạm vào biểu tượng **Thông báo** (hình quả chuông màu vàng có badge đỏ `9+` ở góc dưới bên phải thanh menu).
   - Cửa sổ xác thực sẽ hiện lên.
   - Nhập mật khẩu: `36@Hamnghi` (hoặc sử dụng Face ID nếu đã kích hoạt trong Cài đặt).
   - Nhấn **Mở Khóa Kho Ảnh**.

### 4.2. Quản Lý Album & Thêm Ảnh
- **Thêm ảnh mới**:
  - Nhấn nút tròn màu xanh dương **Add Picture (+)** ở giữa thanh công cụ đáy.
  - Chọn các bức ảnh bạn muốn đưa vào kho bí mật.
  - Ứng dụng sẽ tự động mã hóa bằng `AES-256-GCM` và lưu vào thư mục bảo mật.
  - Sau khi mã hóa xong, ứng dụng sẽ hiện hộp thoại hỏi bạn có muốn xóa ảnh gốc khỏi Thư viện ảnh iPhone để giải phóng bộ nhớ và tránh lộ ảnh không. Chọn **Delete Original Photos** nếu muốn xóa sạch ảnh gốc.
- **Tạo Album mới**:
  - Nhấn nút **Create Album** ở góc trái thanh công cụ đáy -> Điền tên album -> Nhấn **Tạo Album**.
- **Xem ảnh**:
  - Chạm vào bất kỳ album nào để vào lưới ảnh.
  - Chạm vào ảnh để mở trình xem toàn màn hình. Hỗ trợ phóng to thu nhỏ bằng 2 ngón tay, chạm đúp để zoom, và vuốt ngang qua lại cực kỳ mượt mà.
- **Thoát an toàn**:
  - Nhấn nút **Exit** (màu đỏ) ở góc phải thanh đáy. Ứng dụng sẽ ngay lập tức giải phóng toàn bộ dữ liệu RAM, khóa ứng dụng và quay lại giao diện ngụy trang VCB Digibank.

---

## 5. Hướng Dẫn Đóng Gói (Build) Thủ Công

### Trên Windows / Linux:
Chạy script Python đóng gói gói IPA chuẩn TrollStore:
```powershell
python D:\PrivatePhotoVault\build_ipa.py
```
File IPA sẽ được tạo tại `D:\PrivatePhotoVault\PrivatePhotoVault.ipa`.

### Trên macOS (Xcode):
Mở file `PrivatePhotoVault.xcodeproj` bằng Xcode, chọn thiết bị đích là `Any iOS Device (arm64)`, nhấn `Product -> Build` hoặc `Archive`.

### Tự Động Qua GitHub Actions CI:
Chỉ cần đưa mã nguồn lên kho lưu trữ GitHub của bạn, file workflow `.github/workflows/build-ipa.yml` sẽ tự động kích hoạt trên máy ảo `macos-14`, biên dịch toàn bộ mã nguồn Swift bằng `swiftc`, ký quyền TrollStore và tự động tạo file tải về tại tab **Releases** của GitHub!

---

## 6. Bảo Mật & Quyền Riêng Tư

- Ứng dụng không chứa bất kỳ framework theo dõi, phân tích hành vi hay quảng cáo nào.
- Dữ liệu khóa mã hóa được cô lập trong phần cứng Keychain của chính thiết bị người dùng.
- Khi sao lưu iPhone qua iTunes/Finder/iCloud, dữ liệu trong kho được gắn cờ `isExcludedFromBackup` để tránh tự động đưa dữ liệu nhạy cảm lên đám mây ngoài ý muốn.
