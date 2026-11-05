import SwiftUI

@main
public struct PrivatePhotoVaultApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.isUnlocked {
                    MainAlbumsView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.02)),
                            removal: .opacity
                        ))
                } else {
                    DecoyView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState.isUnlocked)
            .preferredColorScheme(selectedColorScheme)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background {
                    if appState.settings.autoLockTimeoutSeconds == 0 {
                        appState.lockVaultAndReset()
                    }
                }
            }
        }
    }
    
    private var selectedColorScheme: ColorScheme? {
        switch appState.settings.appearanceTheme {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return nil // Theo hệ thống
        }
    }
}
