import AppKit
import WebKit

protocol TileViewDelegate: AnyObject {
    func tileRequestedActivate(_ tile: TileView)
    func tileRequestedFocus(_ tile: TileView)
}

final class TileView: NSView, WKNavigationDelegate {
    weak var delegate: TileViewDelegate?

    let web: WKWebView
    let label = NSTextField(labelWithString: "")
    let stats = NSTextField(labelWithString: "")
    let spinner = NSProgressIndicator()
    private(set) var channel: Channel
    private var playerReady = false
    private let playerID = "player_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    
    private var watchdogTimer: Timer?
    private var lastTime: Double = -1
    private var stillTicks: Int = 0
    
    private var focusTile: TileView?
    private var sideStrip: NSScrollView?

    private let APP_ORIGIN = "https://newswall.local"

    enum YouTubeURL {
        static func channelId(from url: URL) -> String? {
            // Works for URLs like https://www.youtube.com/channel/UCxxxx/live
            let comps = url.pathComponents
            if let idx = comps.firstIndex(of: "channel"), idx + 1 < comps.count {
                let cand = comps[idx + 1]
                return cand.hasPrefix("UC") ? cand : nil
            }
            return nil
        }
    }

    init(channel: Channel) {
        self.channel = channel
        let cfg = WKWebViewConfiguration()
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let ucc = WKUserContentController()
        cfg.userContentController = ucc
        web = WKWebView(frame: .zero, configuration: cfg)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor(white: 1, alpha: 0.25).cgColor

        addSubview(web)
        web.navigationDelegate = self
        web.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: leadingAnchor),
            web.trailingAnchor.constraint(equalTo: trailingAnchor),
            web.topAnchor.constraint(equalTo: topAnchor),
            web.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Title label
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.35)
        label.wantsLayer = true
        label.layer?.cornerRadius = 6
        label.layer?.masksToBounds = true
        label.alignment = .left
        label.stringValue = channel.title
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8)
        ])

        // Stats overlay
        stats.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        stats.textColor = .white
        stats.backgroundColor = NSColor.black.withAlphaComponent(0.35)
        stats.wantsLayer = true
        stats.layer?.cornerRadius = 6
        stats.layer?.masksToBounds = true
        stats.alignment = .right
        stats.stringValue = "—"
        addSubview(stats)
        stats.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stats.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stats.topAnchor.constraint(equalTo: topAnchor, constant: 8)
        ])

        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(handleClick)))

        // handle the double clicks
        let dbl = NSClickGestureRecognizer(target: self, action: #selector(doubleClicked))
        dbl.numberOfClicksRequired = 2
        addGestureRecognizer(dbl)

        // Spinner
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }


    required init?(coder: NSCoder) { nil }

    @objc private func handleClick() { delegate?.tileRequestedActivate(self) }

    @objc private func doubleClicked() {
        delegate?.tileRequestedFocus(self)
    }

//    func load() {
//        let origin = "https://localhost"
//        let params = embedParams() + "&origin=\(origin)"
//        let embed: String
//        if let vid = toVideoID(channel.url) {
//            embed = "https://www.youtube.com/embed/\(vid)?\(params)"
//        } else if channel.url.absoluteString.contains("/live") {
//            // If you know the channelId, prefer live_stream?channel=<id>
//            embed = "https://www.youtube.com/embed/live_stream?\(params)"
//        } else {
//            embed = "https://www.youtube.com/embed/\(channel.url.lastPathComponent)?\(params)"
//        }
//
//        // Minimal—no IFrame API yet; it should still render and autoplay muted
//        let html = """
//        <!doctype html><html><head>
//          <meta name="viewport" content="width=device-width,initial-scale=1">
//          <style>html,body,#host{margin:0;height:100%;background:#000;overflow:hidden}
//                 iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style>
//        </head><body>
//          <div id="host">
//            <iframe src="\(embed)" allow="autoplay; encrypted-media"></iframe>
//          </div>
//        </body></html>
//        """
//        web.loadHTMLString(html, baseURL: URL(string: origin))
//    }
    
//    func load() {
//        // 1) Build a plain embed URL (no enablejsapi, no origin)
//        let embed: String
//        if let vid = toVideoID(channel.url) {
//            embed = "https://www.youtube.com/embed/\(vid)?autoplay=1&mute=1&playsinline=1&controls=\(GridConfig.ytControls ? 1 : 0)&rel=0&modestbranding=1"
//        } else if let chId = YouTubeURL.channelId(from: channel.url) {
//            // Proper live embed requires channelId
//            embed = "https://www.youtube.com/embed/live_stream?channel=\(chId)&autoplay=1&mute=1&playsinline=1&controls=\(GridConfig.ytControls ? 1 : 0)&rel=0&modestbranding=1"
//        } else {
//            // Fallback: try last path part as a video id
//            embed = "https://www.youtube.com/embed/\(channel.url.lastPathComponent)?autoplay=1&mute=1&playsinline=1&controls=\(GridConfig.ytControls ? 1 : 0)&rel=0&modestbranding=1"
//        }
//
//        let html = """
//        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
//        <style>html,body,#host{margin:0;height:100%;background:#000;overflow:hidden}
//               iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style>
//        </head><body>
//          <div id="host">
//            <iframe src="\(embed)" allow="autoplay; encrypted-media; picture-in-picture"></iframe>
//          </div>
//        </body></html>
//        """
//
//        // 2) IMPORTANT: baseURL is irrelevant here; keep it simple
//        web.loadHTMLString(html, baseURL: nil)
//    }

    func load() {
        playerReady = false
        spinner.startAnimation(nil)
        spinner.isHidden = false
        lastTime = -1; stillTicks = 0; watchdogTimer?.invalidate()

        // Build the exact iframe src that you already know plays
        let controls = GridConfig.ytControls ? 1 : 0
        let src: String
        if let vid = toVideoID(channel.url) {
            src = "https://www.youtube.com/embed/\(vid)?autoplay=1&mute=1&playsinline=1&controls=\(controls)&rel=0&modestbranding=1&enablejsapi=1&origin=\(APP_ORIGIN)"
        } else if let chId = YouTubeURL.channelId(from: channel.url) {
            src = "https://www.youtube.com/embed/live_stream?channel=\(chId)&autoplay=1&mute=1&playsinline=1&controls=\(controls)&rel=0&modestbranding=1&enablejsapi=1&origin=\(APP_ORIGIN)"
        } else {
            let last = channel.url.lastPathComponent
            src = "https://www.youtube.com/embed/\(last)?autoplay=1&mute=1&playsinline=1&controls=\(controls)&rel=0&modestbranding=1&enablejsapi=1&origin=\(APP_ORIGIN)"
        }

        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
          html,body,#host{margin:0;height:100%;background:#000;overflow:hidden}
          #frame{position:absolute;inset:0;width:100%;height:100%;border:0}
        </style>
        </head><body>
          <div id="host">
            <!-- Single authoritative iframe with origin + enablejsapi -->
            <iframe id="frame" src="\(src)" allow="autoplay; encrypted-media; picture-in-picture"></iframe>
          </div>
          <script>
            var player;
            function onYouTubeIframeAPIReady(){
              // Wrap the existing iframe; do not create a new one
              player = new YT.Player('frame', {
                events: {
                  onReady: function(e){
                    try { e.target.mute(); e.target.playVideo(); } catch(_){}
                    window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytmsg &&
                      window.webkit.messageHandlers.ytmsg.postMessage({type:'ready'});
                  }
                },
                playerVars: {
                  // keep here for completeness (src already carries them)
                  autoplay: 1, mute: 1, rel: 0, playsinline: 1,
                  controls: \(controls), modestbranding: 1, origin: '\(APP_ORIGIN)'
                }
              });
              // Stats pump
              setInterval(function(){
                try{
                  var t = player.getCurrentTime ? player.getCurrentTime() : 0;
                  var b = player.getVideoLoadedFraction ? player.getVideoLoadedFraction() : 0;
                  window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytmsg &&
                      window.webkit.messageHandlers.ytmsg.postMessage({type:'stats', time:t, buf:b});
                }catch(e){}
              }, 1000);
            }
            (function(){
              var s=document.createElement('script'); s.src='https://www.youtube.com/iframe_api';
              document.head.appendChild(s);
            })();
          </script>
        </body></html>
        """

        // CRITICAL: baseURL must match origin EXACTLY (scheme+host+port)
        web.loadHTMLString(html, baseURL: URL(string: APP_ORIGIN))

        // Watchdog as you had it
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: GridConfig.watchdogInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.web.evaluateJavaScript("try{player && player.getCurrentTime ? player.getCurrentTime() : -1}catch(e){-1}") { val, _ in
                let cur = (val as? Double) ?? -1
                if cur < 0 || cur == self.lastTime {
                    self.stillTicks += 1
                    if self.stillTicks >= GridConfig.watchdogStallTicks {
                        self.stillTicks = 0
                        self.reload()
                    }
                } else {
                    self.stillTicks = 0
                    self.lastTime = cur
                }
            }
        }
    }


    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ytmsg", let dict = message.body as? [String:Any] else { return }
        if dict["type"] as? String == "stats" {
            let t = dict["time"] as? Double ?? 0
            let b = dict["buf"] as? Double ?? 0
            DispatchQueue.main.async { self.stats.stringValue = String(format: "t=%5.1fs  buf=%3.0f%%", t, b*100) }
        } else if dict["type"] as? String == "ready" {
            DispatchQueue.main.async {
                self.playerReady = true
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
            }
        }
    }

    func reload() { web.reload() }
    func pause()  { evaluate("try{player && player.pauseVideo()}catch(e){}") }
    func play()   { evaluate("try{player && player.playVideo()}catch(e){}") }
    func mute(_ yes: Bool) { evaluate(yes ? "try{player && player.mute()}catch(e){}" : "try{player && player.unMute()}catch(e){}") }

    deinit { watchdogTimer?.invalidate() }


    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // safety sweep: ensure muted + playing
        evaluate("try{player && player.mute(); player && player.playVideo()}catch(e){}")
    }

    // MARK: - Helpers
    private func evaluate(_ js: String) { web.evaluateJavaScript(js, completionHandler: nil) }

 //   private func embedParams() -> String {
 //       // playerVars for low-chrome, autoplay, muted
 //       return [
 //           "autoplay=1",
 //           "mute=1",
 //           "playsinline=1",
 //           "enablejsapi=1",
 //           "controls=0",
 //           "rel=0"
 //       ].joined(separator: "&")
 //   }
    
    private func embedParams() -> String {
        // playerVars for low-chrome, autoplay, muted
        var parts = [
            "autoplay=1",
            "mute=1",
            "playsinline=1",
            "enablejsapi=1",
            "rel=0"
        ]
        if GridConfig.ytControls { parts.append("controls=1") } else { parts.append("controls=0") }
        return parts.joined(separator: "&")
    }


    private func toVideoID(_ url: URL) -> String? {
        if let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let v = q.first(where: {$0.name == "v"})?.value { return v }
        let last = url.lastPathComponent
        if last.count >= 10 { return last }
        return nil
    }

    private func makeHTML() -> String {
        let origin = "https://localhost"
        let params = embedParams() + "&origin=\(origin)"
        let embed: String = {
            if let vid = toVideoID(channel.url) {
                return "https://www.youtube.com/embed/\(vid)?\(params)"
            } else if channel.url.absoluteString.contains("/live") {
                return "https://www.youtube.com/embed/live_stream?\(params)"
            } else {
                return "https://www.youtube.com/embed/\(channel.url.lastPathComponent)?\(params)"
            }
        }()

        return """
        <!doctype html><html><head>
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <style>
            html,body,#host{margin:0;height:100%;background:#000;overflow:hidden}
            #frame{position:absolute;inset:0;border:0;width:100%;height:100%}
          </style>
        </head><body>
          <div id="host">
            <iframe id="frame" src="\(embed)" allow="autoplay; encrypted-media"></iframe>
          </div>
          <script>
            var player;
            function onYouTubeIframeAPIReady(){
              var f = document.getElementById('frame');
              player = new YT.Player(f, {
                events:{ onReady: function(e){ try{ e.target.mute(); e.target.playVideo(); }catch(_){ } } }
              });
            }
            (function(){
              var s=document.createElement('script'); s.src='https://www.youtube.com/iframe_api';
              document.head.appendChild(s);
            })();
          </script>
        </body></html>
        """
    }

    func setActiveStyle(_ active: Bool) {
        // avoid implicit animations when toggling focus
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // border emphasis
        layer?.borderWidth = active ? 3.0 : 0.5
        layer?.borderColor = (active
            ? NSColor.white.withAlphaComponent(0.9)
            : NSColor(white: 1.0, alpha: 0.25)
        ).cgColor

        // title pill gets a stronger tint when active
        label.backgroundColor = (active ? NSColor.systemBlue : NSColor.black)
            .withAlphaComponent(active ? 0.55 : 0.35)

        // show stats only on the active tile (optional)
        stats.isHidden = !active

        CATransaction.commit()
    }

}
