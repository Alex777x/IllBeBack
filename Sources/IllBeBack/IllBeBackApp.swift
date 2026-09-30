import AppKit
import Foundation
import IllBeBackKit

@main
enum IllBeBackMain {
    static func main() {
        let args = CommandLine.arguments

        if args.contains("--self-test") {
            let passed = MainActor.assumeIsolated {
                SelfTestRunner.runAllTests()
            }
            exit(passed ? 0 : 1)
        }

        if let idx = args.firstIndex(of: "--render-previews"), idx + 1 < args.count {
            let outputDir = args[idx + 1]
            MainActor.assumeIsolated {
                do {
                    try SelfTestRunner.renderSnapshots(to: outputDir)
                    print("📸 Rendered UI previews to \(outputDir)")
                    exit(0)
                } catch {
                    fputs("Failed to render previews: \(error)\n", stderr)
                    exit(1)
                }
            }
        }

        let app = NSApplication.shared
        let delegate = MainActor.assumeIsolated {
            IllBeBackAppDelegate()
        }
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class IllBeBackAppDelegate: NSObject, NSApplicationDelegate {
    private var store: AppStore?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pure menu bar utility — hide from Dock & Command-Tab switcher
        NSApp.setActivationPolicy(.accessory)

        let appStore = AppStore()
        self.store = appStore
        self.statusBarController = StatusBarController(store: appStore)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.deactivate()
        store?.powerService.stopMonitoring()
        store?.shortcutService.unregister()
    }
}
