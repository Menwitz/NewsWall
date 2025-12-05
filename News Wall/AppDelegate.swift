import AppKit
import WebKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var wallVC: WallViewController!
    var settingsWindow: NSWindow?
    var layoutsWindow: NSWindow?
    var keywordAlertsWindow: NSWindow?
    var transcriptionFeedWindow: NSWindow?

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
        // Layouts menu item
        appMenu.addItem(withTitle: "Layouts…", action: #selector(openLayouts), keyEquivalent: "l")
        
        // AI Features submenu
        let aiMenu = NSMenu(title: "AI Features")
        let aiMenuItem = NSMenuItem(title: "AI Features", action: nil, keyEquivalent: "")
        aiMenuItem.submenu = aiMenu
        
        let keywordsItem = NSMenuItem(title: "Keyword Alerts…", action: #selector(openKeywordAlerts), keyEquivalent: "k")
        aiMenu.addItem(keywordsItem)
        
        let transcriptionItem = NSMenuItem(title: "Live Transcriptions…", action: #selector(openTranscriptionFeed), keyEquivalent: "t")
        aiMenu.addItem(transcriptionItem)
        
        appMenu.addItem(aiMenuItem)
        appMenu.addItem(withTitle: "Open Channels File…", action: #selector(openChannels), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(withTitle: "Channels…", action: #selector(openChannelsWindow), keyEquivalent: "c") // Changed keyEquivalent to 'c' to avoid conflict with 'k' for Keyword Alerts

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
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
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
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "Layouts"
            win.styleMask = [.titled, .closable, .resizable]
            layoutsWindow = win
        }
        layoutsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func openKeywordAlerts() {
        if keywordAlertsWindow == nil {
            let view = KeywordAlertsView()
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "Keyword Alerts"
            win.styleMask = [.titled, .closable]
            keywordAlertsWindow = win
        }
        keywordAlertsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func openTranscriptionFeed() {
        if transcriptionFeedWindow == nil {
            let view = TranscriptionFeedView()
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "Live Transcriptions"
            win.styleMask = [.titled, .closable, .resizable]
            transcriptionFeedWindow = win
        }
        transcriptionFeedWindow?.makeKeyAndOrderFront(nil)
    }
}
