# News Wall

**News Wall** is a macOS application that turns your screen into a customizable video wall of live news channels.  
Instead of opening dozens of YouTube tabs, you can arrange multiple streams in a grid, switch audio focus between them, and manage channels directly from the app.

## Features

- **Grid of Streams** – Watch 2×2 up to 5×5 YouTube live channels simultaneously.
- **Dynamic Settings** – Configure grid size, playback options, and watchdog timer via the new Preferences window.
- **One-Audio Rule** – Only the active tile plays sound; all others remain muted.
- **Control Bar** – Quick access to Mute All, Reload All, and Grid Size controls.
- **Keyboard Controls** –
  - Arrows: move active selection
  - `Cmd+←/→`: flip pages
  - Space: enforce one-audio rule
  - `M`: global mute toggle
  - `R`: reload active tile
  - `C`: toggle player controls
  - `+`/`-`: adjust grid size
- **Mouse Controls** – Click a tile to activate its audio. Double-click to reload.
- **Channel Management** –
  - Create custom channel groups.
  - Reorder channels via Drag & Drop.
  - Import/Export channel lists (JSON).
- **Watchdog** – Detects stalled streams and reloads them automatically.

## Requirements

- macOS 13.0+
- Xcode 15+
- Swift 5.9+

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/youruser/news-wall.git
   cd news-wall
   ```

2. Open `News Wall.xcodeproj` in Xcode.
3. Build and Run.

## Project Structure

```
News Wall/
├── AppDelegate.swift
├── main.swift
├── UI/
│   ├── TileView.swift            # Wrapper around WKWebView for YouTube embeds
│   ├── WallViewController.swift  # Main grid controller
│   ├── ChannelsWindowController.swift # Channel management
│   ├── SettingsView.swift        # SwiftUI Preferences view
│   ├── ControlBarView.swift      # Floating control bar
│   └── ...
├── Model/
│   ├── Channel.swift             # Data model
│   └── SettingsStore.swift       # Persistence logic
├── Persistence/
│   └── ChannelStore.swift        # JSON persistence for channel lists
├── README.md
└── ROADMAP.md
```
