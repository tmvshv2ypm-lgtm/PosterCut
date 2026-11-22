import SwiftUI

@main
struct PosterCutApp: App {
    @ObservedObject private var themeManager = PosterThemeManager.shared

    var body: some Scene {
        WindowGroup {
            StudioView()
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                .tint(themeManager.primaryAccent)
        }
    }
}
