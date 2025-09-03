import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var wallVC: WallViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        wallVC = WallViewController()
        window = NSWindow(contentViewController: wallVC)
        window.title = "News Wall"
        window.setFrame(NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1600, height: 1000), display: true)
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { self.window.toggleFullScreen(nil) }

        installMenu()
        wallVC.becomeFirstResponder()
    }

    private func installMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "Open Channels File…", action: #selector(openChannels), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(withTitle: "Channels…", action: #selector(openChannelsWindow), keyEquivalent: "l")

        NSApp.mainMenu = mainMenu
    }

    @objc private func openChannels() {
        if let url = try? ChannelStore().fileURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    private var channelsWC: ChannelsWindowController?

    @objc private func openChannelsWindow() {
        guard let store = try? ChannelStore() else { return }
        channelsWC = ChannelsWindowController(store: store) { [weak self] _ in
            // After save, rebuild the wall to reflect any changes
            self?.wallVC?.loadPage(0)
        }
        channelsWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
