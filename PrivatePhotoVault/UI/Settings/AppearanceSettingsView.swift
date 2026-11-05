import SwiftUI

/// Cài đặt Giao diện (Sáng / Tối / Tự động)
public struct AppearanceSettingsView: View {
    @ObservedObject var appState: AppState = AppState.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Chủ Đề Hiển Thị")) {
                Button(action: { setTheme("system") }) {
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.blue)
                        Text("Tự Động Theo Hệ Thống")
                            .foregroundColor(.primary)
                        Spacer()
                        if appState.settings.appearanceTheme == "system" {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button(action: { setTheme("dark") }) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                        Text("Giao Diện Tối (Dark Mode)")
                            .foregroundColor(.primary)
                        Spacer()
                        if appState.settings.appearanceTheme == "dark" {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button(action: { setTheme("light") }) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                        Text("Giao Diện Sáng (Light Mode)")
                            .foregroundColor(.primary)
                        Spacer()
                        if appState.settings.appearanceTheme == "light" {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Appearance")
    }
    
    private func setTheme(_ theme: String) {
        appState.settings.appearanceTheme = theme
        appState.saveSettings()
    }
}
