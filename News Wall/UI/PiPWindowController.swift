import AppKit

class PiPWindowController: NSWindowController {
    private var tileView: TileView
    private var closeButton: NSButton!
    private var returnButton: NSButton!
    
    init(tile: TileView) {
        self.tileView = tile
        
        // Create PiP window
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 480, height: 270),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = tile.channel.title
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor
        window.contentView = contentView
        
        // Add tile view
        tileView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tileView)
        
        // Create control bar
        let controlBar = NSView()
        controlBar.wantsLayer = true
        controlBar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        controlBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controlBar)
        
        // Close button
        closeButton = NSButton(title: "✕", target: self, action: #selector(closePiP))
        closeButton.bezelStyle = .rounded
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(closeButton)
        
        // Return to grid button
        returnButton = NSButton(title: "Return to Grid", target: self, action: #selector(returnToGrid))
        returnButton.bezelStyle = .rounded
        returnButton.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(returnButton)
        
        NSLayoutConstraint.activate([
            // Tile fills most of the window
            tileView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tileView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tileView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tileView.bottomAnchor.constraint(equalTo: controlBar.topAnchor),
            
            // Control bar at bottom
            controlBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            controlBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            controlBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            controlBar.heightAnchor.constraint(equalToConstant: 40),
            
            // Buttons in control bar
            closeButton.leadingAnchor.constraint(equalTo: controlBar.leadingAnchor, constant: 8),
            closeButton.centerYAnchor.constraint(equalTo: controlBar.centerYAnchor),
            
            returnButton.trailingAnchor.constraint(equalTo: controlBar.trailingAnchor, constant: -8),
            returnButton.centerYAnchor.constraint(equalTo: controlBar.centerYAnchor),
        ])
    }
    
    @objc private func closePiP() {
        // Pause the tile before closing
        tileView.pause()
        close()
    }
    
    @objc private func returnToGrid() {
        // Notify that we want to return this tile to the grid
        NotificationCenter.default.post(
            name: NSNotification.Name("ReturnPiPToGrid"),
            object: nil,
            userInfo: ["tile": tileView]
        )
        close()
    }
    
    func getTile() -> TileView {
        return tileView
    }
}
