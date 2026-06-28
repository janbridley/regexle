import AppKit
import SwiftUI

/// macOS host for the shared `ContentView` — the exact same SwiftUI hex grid the
/// iOS app uses, just presented in a native, resizable window.
///
/// Run from the CLI with:  swift run HexGridMac   (or:  make run)
/// Resize the window to watch the vector grid rescale to any resolution.
@main
struct HexGridMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("HexGrid") {
            ContentView()
                .frame(minWidth: 320, minHeight: 360)
        }
        .defaultSize(width: 640, height: 640)
    }
}

// When launched as a bare executable (swift run) rather than an .app bundle,
// macOS defaults to keeping the process inactive and out of the Dock — so the
// window is created but never shown. Force a normal activation policy and bring
// it to the front on launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
