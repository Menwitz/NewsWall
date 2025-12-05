import AppKit
import WebKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var wallVC: WallViewController!
    var settingsWindow: NSWindow?
    var layoutsWindow: NSWindow?

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

        appMenu.addItem(withTitle: "Preferences…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(withTitle: "Layouts…", action: #selector(openLayouts), keyEquivalent: "l")
        appMenu.addItem(withTitle: "Open Channels File…", action: #selector(openChannels), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(withTitle: "Channels…", action: #selector(openChannelsWindow), keyEquivalent: "k")

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

    @objc func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            settingsWindow?.center()
            settingsWindow?.title = "Preferences"
            settingsWindow?.contentView = NSHostingView(rootView: view)
            settingsWindow?.isReleasedWhenClosed = false
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openLayouts() {
        if layoutsWindow == nil {
            let view = LayoutManagerView()
            layoutsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            layoutsWindow?.center()
            layoutsWindow?.title = "Layouts"
            layoutsWindow?.contentView = NSHostingView(rootView: view)
            layoutsWindow?.isReleasedWhenClosed = false
        }
        layoutsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
