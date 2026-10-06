import AppKit
import ServiceManagement

/// Точка входа менюбар-приложения InfiniWake.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: InfiniWakeController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = InfiniWakeController()
        self.controller = controller
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }
}
