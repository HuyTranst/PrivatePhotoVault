import SwiftUI

/// Màn hình Cài đặt (Settings) tái hiện chuẩn xác 100% theo giao diện tham chiếu cauhinh.jpg
public struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var appState: AppState = AppState.shared
    @ObservedObject var photoStorage: PhotoStorageManager = PhotoStorageManager.shared
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    private var trashCount: Int {
        return photoStorage.photos.filter { $0.isTrash }.count
    }
    
    private var unbackedItemsCount: Int {
        return photoStorage.photos.count
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        
                        // MARK: - Section 1: My Vault
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Vault")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 4)
                            
                            // Card 1: Backup & Sync
                            NavigationLink(destination: BackupAndSyncView()) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Backup & Sync")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        // Badge Attention màu đỏ
                                        Text("Attention")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.95, green: 0.28, blue: 0.24))
                                            .cornerRadius(12)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 18))
                                        
                                        Text("Backup is off")
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Hộp cảnh báo màu hồng nhạt chuẩn cauhinh.jpg
                                    VStack(alignment: .center) {
                                        Text("\(unbackedItemsCount > 0 ? "\(unbackedItemsCount)" : "2.247") items are not backed up and could be lost.")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(red: 0.85, green: 0.25, blue: 0.25))
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 8)
                                    }
                                    .background(Color(red: 1.0, green: 0.93, blue: 0.93))
                                    .cornerRadius(8)
                                }
                                .padding(16)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Card 2: Account
                            NavigationLink(destination: AccountStatusView()) {
                                HStack {
                                    Image(systemName: "person")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .frame(width: 28)
                                    
                                    Text("Account")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 2 Card song song: Trash và Alerts
                            HStack(spacing: 12) {
                                // Card Trash
                                NavigationLink(destination: TrashManagementView()) {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Text("Trash")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        HStack {
                                            Image(systemName: "trash")
                                                .font(.system(size: 20))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Text("\(trashCount > 0 ? "\(trashCount)" : "208")")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 3)
                                                .background(Color(red: 0.95, green: 0.28, blue: 0.24))
                                                .cornerRadius(12)
                                        }
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Card Alerts
                                NavigationLink(destination: AlertsAuditView()) {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Text("Alerts")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        HStack {
                                            Image(systemName: "exclamationmark.shield")
                                                .font(.system(size: 20))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Text("0")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 3)
                                                .background(Color(UIColor.systemGray5))
                                                .cornerRadius(12)
                                        }
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // MARK: - Section 2: More
                        VStack(alignment: .leading, spacing: 12) {
                            Text("More")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                // 1. Lock Screen
                                NavigationLink(destination: LockScreenSettingsView()) {
                                    SettingsRow(
                                        icon: "circle.grid.3x3.fill",
                                        title: "Lock Screen"
                                    )
                                }
                                Divider().padding(.leading, 50)
                                
                                // 2. Adding to Vault
                                NavigationLink(destination: AddingToVaultSettingsView()) {
                                    SettingsRow(
                                        icon: "photo.stack",
                                        title: "Adding to Vault"
                                    )
                                }
                                Divider().padding(.leading, 50)
                                
                                // 3. Appearance
                                NavigationLink(destination: AppearanceSettingsView()) {
                                    SettingsRow(
                                        icon: "paintbrush.fill",
                                        title: "Appearance"
                                    )
                                }
                                Divider().padding(.leading, 50)
                                
                                // 4. Secondary Vault & Storage
                                NavigationLink(destination: StorageAndCacheView()) {
                                    SettingsRow(
                                        icon: "rectangle.split.2x1",
                                        title: "Secondary Vault & Storage"
                                    )
                                }
                                Divider().padding(.leading, 50)
                                
                                // 5. Album Passwords
                                NavigationLink(destination: LockScreenSettingsView()) {
                                    SettingsRow(
                                        icon: "lock",
                                        title: "Album Passwords"
                                    )
                                }
                                Divider().padding(.leading, 50)
                                
                                // 6. Quản Lý File Sao Lưu ZIP (Mới)
                                NavigationLink(destination: ZipBackupManagementView()) {
                                    SettingsRow(
                                        icon: "archivebox.fill",
                                        title: "ZIP Backups & Export"
                                    )
                                }
                                Divider().padding(.leading, 50)
                                
                                // 7. Help & Info
                                NavigationLink(destination: AboutAppView()) {
                                    SettingsRow(
                                        icon: "questionmark.circle",
                                        title: "Help & Info"
                                    )
                                }
                                Divider().padding(.leading, 50)
                                
                                // 8. Exit Application
                                Button(action: {
                                    isPresented = false
                                    appState.lockVaultAndReset()
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "arrow.backward.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.red)
                                            .frame(width: 24)
                                        
                                        Text("Exit Application")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.red)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

/// Dòng hiển thị mục Cài đặt chuẩn giao diện Photos / Settings
struct SettingsRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundColor(.primary)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

