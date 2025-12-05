import AppKit
import Combine
import SwiftUI

final class WallViewController: NSViewController, TileViewDelegate {
    private var store: ChannelStore!
    private var rowsStack: NSStackView!
    private(set) var tiles: [TileView] = []
    private var pageIndex = 0

    private var filterGroup: String = "All"
    private var globalMuted = false
    private var cancellables = Set<AnyCancellable>()
    private var layoutStore = LayoutStore.shared
    
    // Focus mode state
    private var focusedTile: TileView?
    private var sideStripContainer: NSView?
    private var sideStripScroll: NSScrollView?
    private var sideStripStack: NSStackView?
    
    // PiP windows
    private var pipWindows: [PiPWindowController] = []

    private var rows: Int { GridConfig.rows }
    private var cols: Int { GridConfig.cols }

    private var activeTile: TileView? { didSet {
        oldValue?.setActiveStyle(false); oldValue?.mute(true)
        activeTile?.setActiveStyle(true); activeTile?.mute(false); activeTile?.play()
    }}

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        store = try! ChannelStore()
        buildGrid()
        loadPage(0)
        installKeyMonitor()
        setupObservers()
    }

    private func setupObservers() {
        SettingsStore.shared.$rows
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildGrid() }
            .store(in: &cancellables)
            
        SettingsStore.shared.$cols
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildGrid() }
            .store(in: &cancellables)

        SettingsStore.shared.$ytControls
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadVisibleTiles() }
            .store(in: &cancellables)

        // Observe layout changes
        layoutStore.$activeLayoutID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyActiveLayout() }
            .store(in: &cancellables)
    }

    private func applyActiveLayout() {
        guard let layout = layoutStore.activeLayout else { return }
        
        // Update grid size to match layout
        SettingsStore.shared.rows = layout.rows
        SettingsStore.shared.cols = layout.cols
        
        // Grid will rebuild automatically via settings observers
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        
        // Listen for PiP return notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReturnPiPToGrid(_:)),
            name: NSNotification.Name("ReturnPiPToGrid"),
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildGrid() {
        rowsStack = NSStackView()
        rowsStack.orientation = .vertical
        rowsStack.spacing = 6
        rowsStack.alignment = .centerX
        rowsStack.distribution = .fillEqually
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rowsStack)

        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            rowsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            rowsStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            rowsStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])

        for _ in 0..<rows {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 6
            row.alignment = .centerY
            row.distribution = .fillEqually
            row.translatesAutoresizingMaskIntoConstraints = false
            rowsStack.addArrangedSubview(row)

            for _ in 0..<cols {
                // placeholder that we'll replace on loadPage
                let v = NSView()
                v.wantsLayer = true
                v.layer?.backgroundColor = NSColor.black.cgColor
                row.addArrangedSubview(v)
            }
        }
        
        setupControlBar()
    }
    
    private func setupControlBar() {
        let bar = ControlBarView(
            onMuteAll: { [weak self] in self?.tiles.forEach { $0.mute(true) } },
            onReloadAll: { [weak self] in self?.reloadVisibleTiles() },
            onSettings: { NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil) }
        )
        let hosting = NSHostingView(rootView: bar)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        
        NSLayoutConstraint.activate([
            hosting.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    private func rebuildGrid() {
        rowsStack.removeFromSuperview()
        buildGrid()
        loadPage(pageIndex)
    }

    private func rowStack(at r: Int) -> NSStackView {
        return rowsStack.arrangedSubviews[r] as! NSStackView
    }

    func loadPage(_ idx: Int) {
        pageIndex = idx

        let all = store.channels.filter { $0.enabled && (filterGroup == "All" || $0.group == filterGroup) }
        let perPage = rows * cols
        let start = idx * perPage
        let slice = start < all.count ? all[start..<min(start+perPage, all.count)] : []

        // Build a map of current tiles by channel ID for reuse
        var existingTiles: [UUID: TileView] = [:]
        for tile in tiles {
            existingTiles[tile.channel.id] = tile
        }
        
        var newTiles: [TileView] = []
        var i = 0
        
        for r in 0..<rows {
            let row = rowStack(at: r)
            for c in 0..<cols {
                let holder = row.arrangedSubviews[c]
                
                if i < slice.count {
                    let channel = slice[slice.index(slice.startIndex, offsetBy: i)]
                    
                    // Try to reuse existing tile if it's the same channel
                    if let existingTile = existingTiles[channel.id] {
                        // Reuse the tile - just move it if needed
                        if existingTile.superview != holder {
                            existingTile.removeFromSuperview()
                            holder.subviews.forEach { $0.removeFromSuperview() }
                            holder.addSubview(existingTile)
                            existingTile.translatesAutoresizingMaskIntoConstraints = false
                            NSLayoutConstraint.activate([
                                existingTile.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
                                existingTile.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
                                existingTile.topAnchor.constraint(equalTo: holder.topAnchor),
                                existingTile.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
                            ])
                        }
                        newTiles.append(existingTile)
                        existingTiles.removeValue(forKey: channel.id)
                    } else {
                        // Create new tile and auto-load
                        holder.subviews.forEach { $0.removeFromSuperview() }
                        let tile = TileView(channel: channel)
                        tile.delegate = self
                        tile.translatesAutoresizingMaskIntoConstraints = false
                        holder.addSubview(tile)
                        NSLayoutConstraint.activate([
                            tile.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
                            tile.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
                            tile.topAnchor.constraint(equalTo: holder.topAnchor),
                            tile.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
                        ])
                        // Auto-load the stream
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 * Double(i)) {
                            tile.load()
                        }
                        newTiles.append(tile)
                    }
                    i += 1
                } else {
                    // Empty slot
                    holder.subviews.forEach { $0.removeFromSuperview() }
                    let filler = NSView()
                    filler.wantsLayer = true
                    filler.layer?.backgroundColor = NSColor.darkGray.cgColor
                    filler.translatesAutoresizingMaskIntoConstraints = false
                    holder.addSubview(filler)
                    NSLayoutConstraint.activate([
                        filler.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
                        filler.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
                        filler.topAnchor.constraint(equalTo: holder.topAnchor),
                        filler.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
                    ])
                }
            }
        }
        
        // Clean up unused tiles
        for (_, tile) in existingTiles {
            tile.pause()
            tile.removeFromSuperview()
        }
        
        tiles = newTiles
        
        // Preserve active tile if it still exists, otherwise pick first
        if let active = activeTile, tiles.contains(where: { $0 === active }) {
            // Keep current active tile
        } else {
            activeTile = tiles.first
        }
        applyGlobalMute()
    }

    // MARK: TileViewDelegate
    func tileRequestedActivate(_ tile: TileView) { activeTile = tile }
    
    func tileRequestedFocus(_ tile: TileView) {
        if focusedTile != nil {
            // Exit focus mode
            exitFocusMode()
        } else {
            // Enter focus mode
            enterFocusMode(with: tile)
        }
    }
    
    private func enterFocusMode(with tile: TileView) {
        focusedTile = tile
        
        // Hide the grid
        rowsStack.isHidden = true
        
        // Create side strip container
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        sideStripContainer = container
        
        // Create scroll view for side strip
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)
        sideStripScroll = scroll
        
        // Create stack for thumbnails
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = stack
        sideStripStack = stack
        
        // Position the side strip on the right (1/3 of screen width)
        NSLayoutConstraint.activate([
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.0/3.0),
            
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
        ])
        
        // Move focused tile to main area
        tile.removeFromSuperview()
        tile.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tile)
        
        NSLayoutConstraint.activate([
            tile.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tile.trailingAnchor.constraint(equalTo: container.leadingAnchor),
            tile.topAnchor.constraint(equalTo: view.topAnchor),
            tile.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add other tiles to side strip
        for otherTile in tiles where otherTile !== tile {
            otherTile.removeFromSuperview()
            otherTile.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(otherTile)
            
            // Maintain 16:9 aspect ratio (height = width * 9/16)
            NSLayoutConstraint.activate([
                otherTile.heightAnchor.constraint(equalTo: otherTile.widthAnchor, multiplier: 9.0/16.0)
            ])
        }
    }
    
    private func exitFocusMode() {
        guard let focused = focusedTile else { return }
        
        // Remove side strip
        sideStripContainer?.removeFromSuperview()
        sideStripContainer = nil
        sideStripScroll = nil
        sideStripStack = nil
        
        // Remove focused tile from main area
        focused.removeFromSuperview()
        
        // Show grid again
        rowsStack.isHidden = false
        
        // Reload the page to restore all tiles to grid
        loadPage(pageIndex)
        
        focusedTile = nil
    }

    // MARK: Keyboard
    private var keyMonitor: Any?
    private func installKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self = self else { return e }
            let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Paging
            if mods == [.command] && e.keyCode == 124 { self.nextPage(); return nil } // Cmd→
            if mods == [.command] && e.keyCode == 123 { self.prevPage(); return nil } // Cmd←

            // Navigation
            if mods.isEmpty {
                switch e.keyCode {
                case 123: self.moveActive(dx:-1)       // ←
                case 124: self.moveActive(dx:+1)       // →
                case 125: self.moveActive(dy:+1)       // ↓
                case 126: self.moveActive(dy:-1)       // ↑
                default: break
                }
                if let ch = e.charactersIgnoringModifiers?.lowercased() {
                    switch ch {
                    case " ": // space -> unmute active, mute others
                        self.globalMuted = false
                        self.tiles.forEach { $0.mute(true) }
                        self.activeTile?.mute(false); self.activeTile?.play()
                        return nil
                    case "r": self.activeTile?.reload(); return nil
                    case "m": self.globalMuted.toggle(); self.applyGlobalMute(); return nil
                    case "p": self.togglePiPForActiveTile(); return nil  // PiP shortcut
                    case "c":
                        GridConfig.ytControls.toggle()
                        return nil
                    case "+":
                        GridConfig.rows = min(5, GridConfig.rows + 1)
                        GridConfig.cols = min(5, GridConfig.cols + 1)
                        return nil
                    case "-":
                        GridConfig.rows = max(1, GridConfig.rows - 1)
                        GridConfig.cols = max(1, GridConfig.cols - 1)
                        return nil
                    case "0":
                        self.filterGroup = "All"; self.loadPage(0); return nil
                    case "1":
                        self.filterGroup = "Finance"; self.loadPage(0); return nil
                    case "2":
                        self.filterGroup = "World"; self.loadPage(0); return nil
                    case "3":
                        self.filterGroup = "Tech"; self.loadPage(0); return nil
                    case "4":
                        self.filterGroup = "Arabic"; self.loadPage(0); return nil
                    default: break
                    }
                }
            }
            
            // Cmd+key shortcuts for windows
            if mods == [.command] {
                if let ch = e.charactersIgnoringModifiers?.lowercased() {
                    switch ch {
                    case "k":
                        NSApp.sendAction(#selector(AppDelegate.openKeywordAlerts), to: nil, from: nil)
                        return nil
                    case "t":
                        NSApp.sendAction(#selector(AppDelegate.openTranscriptionFeed), to: nil, from: nil)
                        return nil
                    case "l":
                        NSApp.sendAction(#selector(AppDelegate.openLayouts), to: nil, from: nil)
                        return nil
                    case ",":
                        NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                        return nil
                    default: break
                    }
                }
            }
            return nil
        }
    }

    private func reloadVisibleTiles() { tiles.forEach { $0.reload() } }

    private func applyGlobalMute() {
        if globalMuted { tiles.forEach { $0.mute(true) } }
        else { tiles.forEach { $0.mute(true) }; activeTile?.mute(false); activeTile?.play() }
    }


    private func indexOfActive() -> Int? { tiles.firstIndex { $0 === activeTile } }

    private func moveActive(dx: Int = 0, dy: Int = 0) {
        guard let idx = indexOfActive() else { return }
        var r = idx / cols, c = idx % cols
        r = max(0, min(rows-1, r + dy))
        c = max(0, min(cols-1, c + dx))
        let newIdx = r * cols + c
        if newIdx < tiles.count { activeTile = tiles[newIdx] }
    }

    private func nextPage() { loadPage(pageIndex + 1) }
    private func prevPage() { loadPage(max(0, pageIndex - 1)) }
    
    // MARK: Picture-in-Picture
    private func togglePiPForActiveTile() {
        guard let tile = activeTile else { return }
        
        // Check if we already have 4 PiP windows (limit)
        if pipWindows.count >= 4 {
            let alert = NSAlert()
            alert.messageText = "PiP Limit Reached"
            alert.informativeText = "Maximum of 4 Picture-in-Picture windows allowed."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Remove tile from grid
        tile.removeFromSuperview()
        if let index = tiles.firstIndex(where: { $0 === tile }) {
            tiles.remove(at: index)
        }
        
        // Create PiP window
        let pipController = PiPWindowController(tile: tile)
        pipController.showWindow(nil)
        pipWindows.append(pipController)
        
        // Select next tile as active
        activeTile = tiles.first
        
        // Reload page to fill the gap
        loadPage(pageIndex)
    }
    
    @objc private func handleReturnPiPToGrid(_ notification: Notification) {
        guard let tile = notification.userInfo?["tile"] as? TileView else { return }
        
        // Find and remove the PiP window
        if let index = pipWindows.firstIndex(where: { $0.getTile() === tile }) {
            pipWindows.remove(at: index)
        }
        
        // Add tile back to the grid
        // For simplicity, just reload the current page which will add it back
        loadPage(pageIndex)
    }

    deinit { if let m = keyMonitor { NSEvent.removeMonitor(m) } }
    
    
}
