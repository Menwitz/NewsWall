import AppKit

final class WallViewController: NSViewController, TileViewDelegate {
    private var store: ChannelStore!
    private var rowsStack: NSStackView!
    private(set) var tiles: [TileView] = []
    private var pageIndex = 0

    private var filterGroup: ChannelGroup = .all
    private var globalMuted = false

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
        for t in tiles { t.pause(); t.removeFromSuperview() }
        tiles.removeAll()
        pageIndex = idx

        let all = store.channels.filter { $0.enabled && (filterGroup == .all || $0.group == filterGroup) }
        let perPage = rows * cols
        let start = idx * perPage
        let slice = start < all.count ? all[start..<min(start+perPage, all.count)] : []

        var i = 0
        for r in 0..<rows {
            let row = rowStack(at: r)
            for c in 0..<cols {
                let holder = row.arrangedSubviews[c]
                holder.subviews.forEach { $0.removeFromSuperview() }
                if i < slice.count {
                    let channel = slice[slice.index(slice.startIndex, offsetBy: i)]
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
                    tile.load()
                    tiles.append(tile)
                    i += 1
                } else {
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
        activeTile = tiles.first
        applyGlobalMute()
    }

    // MARK: TileViewDelegate
    func tileRequestedActivate(_ tile: TileView) { activeTile = tile }

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
                    case "r":
                        self.activeTile?.reload(); return nil
                    case "m":
                        self.globalMuted.toggle()
                        self.applyGlobalMute()
                        return nil
                    case "c":
                        GridConfig.ytControls.toggle()
                        self.reloadVisibleTiles()
                        return nil
                    case "+":
                        GridConfig.rows = min(5, GridConfig.rows + 1)
                        GridConfig.cols = min(5, GridConfig.cols + 1)
                        self.rebuildGrid(); return nil
                    case "-":
                        GridConfig.rows = max(1, GridConfig.rows - 1)
                        GridConfig.cols = max(1, GridConfig.cols - 1)
                        self.rebuildGrid(); return nil
                    case "0":
                        self.filterGroup = .all; self.loadPage(0); return nil
                    case "1":
                        self.filterGroup = .finance; self.loadPage(0); return nil
                    case "2":
                        self.filterGroup = .world; self.loadPage(0); return nil
                    case "3":
                        self.filterGroup = .tech; self.loadPage(0); return nil
                    case "4":
                        self.filterGroup = .arabic; self.loadPage(0); return nil
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

    deinit { if let m = keyMonitor { NSEvent.removeMonitor(m) } }
    
    
}
