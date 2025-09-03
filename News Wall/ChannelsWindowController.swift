import AppKit

final class ChannelsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: ChannelStore
    private let table = NSTableView()
    private let scroll = NSScrollView()
    private var onSave: (([Channel]) -> Void)?

    init(store: ChannelStore, onSave: (([Channel]) -> Void)?) {
        self.store = store
        self.onSave = onSave
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 420),
                         styleMask: [.titled, .closable, .miniaturizable],
                         backing: .buffered, defer: false)
        super.init(window: w)
        window?.title = "Channels"
        setupUI()
    }
    required init?(coder: NSCoder) { nil }

    private func setupUI() {
        let content = NSView()
        window?.contentView = content

        // Table
        let colTitle = NSTableColumn(identifier: .init("title")); colTitle.title = "Title"; colTitle.width = 220
        let colURL = NSTableColumn(identifier: .init("url")); colURL.title = "URL"; colURL.width = 350
        let colGroup = NSTableColumn(identifier: .init("group")); colGroup.title = "Group"; colGroup.width = 100
        let colEnabled = NSTableColumn(identifier: .init("enabled")); colEnabled.title = "✓"; colEnabled.width = 40

        table.addTableColumn(colTitle)
        table.addTableColumn(colURL)
        table.addTableColumn(colGroup)
        table.addTableColumn(colEnabled)
        table.usesAlternatingRowBackgroundColors = true
        table.delegate = self
        table.dataSource = self

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        // Buttons
        let addBtn = NSButton(title: "Add", target: self, action: #selector(add))
        let delBtn = NSButton(title: "Remove", target: self, action: #selector(remove))
        let editBtn = NSButton(title: "Edit", target: self, action: #selector(edit))
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))

        for b in [addBtn, delBtn, editBtn, saveBtn] { b.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(b) }

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -50),

            addBtn.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            addBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),

            delBtn.leadingAnchor.constraint(equalTo: addBtn.trailingAnchor, constant: 8),
            delBtn.bottomAnchor.constraint(equalTo: addBtn.bottomAnchor),

            editBtn.leadingAnchor.constraint(equalTo: delBtn.trailingAnchor, constant: 8),
            editBtn.bottomAnchor.constraint(equalTo: addBtn.bottomAnchor),

            saveBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            saveBtn.bottomAnchor.constraint(equalTo: addBtn.bottomAnchor)
        ])
    }

    private var items: [Channel] { get { store.channels } set { try? store.set(newValue) } }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let text = NSTextField()
        text.isEditable = false; text.isBordered = false; text.backgroundColor = .clear
        switch tableColumn?.identifier.rawValue {
        case "title":   text.stringValue = item.title
        case "url":     text.stringValue = item.url.absoluteString
        case "group":   text.stringValue = item.group.rawValue
        case "enabled": text.stringValue = item.enabled ? "✓" : ""
        default: break
        }
        return text
    }

    @objc private func add() {
        let (alert, t, u, g) = channelEditor()
        if alert.runModal() == .alertFirstButtonReturn {
            let title = t.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let urlStr = u.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let groupStr = g.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: urlStr) {
                var arr = items
                let grp = ChannelGroup(rawValue: groupStr).flatMap { $0 } ?? .custom
                arr.append(Channel(title: title, url: url, enabled: true, group: grp))
                items = arr
                table.reloadData()
            }
        }
    }

    @objc private func edit() {
        let row = table.selectedRow; guard row >= 0 else { return }
        let it = items[row]
        let (alert, t, u, g) = channelEditor(title: it.title, url: it.url.absoluteString, group: it.group.rawValue)
        if alert.runModal() == .alertFirstButtonReturn {
            let title = t.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let urlStr = u.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let groupStr = g.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: urlStr) {
                var arr = items
                let grp = ChannelGroup(rawValue: groupStr).flatMap { $0 } ?? .custom
                arr[row] = Channel(id: it.id, title: title, url: url, enabled: it.enabled, group: grp)
                items = arr
                table.reloadData()
            }
        }
    }

    @objc private func remove() {
        let row = table.selectedRow; guard row >= 0 else { return }
        var c = items; c.remove(at: row); items = c; table.reloadData()
    }

    @objc private func save() {
        try? store.save()
        onSave?(items)
        window?.close()
    }

    private func channelEditor(title: String = "", url: String = "", group: String = "All")
    -> (alert: NSAlert, titleField: NSTextField, urlField: NSTextField, groupField: NSTextField) {

        let a = NSAlert()
        a.messageText = "Channel"
        a.informativeText = "Enter Title, URL, Group (\(ChannelGroup.allCases.map{$0.rawValue}.joined(separator: ", ")))"
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")

        let t = NSTextField(string: title)
        let u = NSTextField(string: url)
        let g = NSTextField(string: group)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        func label(_ s: String) -> NSTextField {
            let l = NSTextField(labelWithString: s)
            l.font = .systemFont(ofSize: 12, weight: .semibold)
            return l
        }
        [label("Title"), t, label("URL"), u, label("Group"), g].forEach { stack.addArrangedSubview($0) }

        let v = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 140))
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor, constant: -8),
        ])

        a.accessoryView = v
        return (a, t, u, g)
    }


    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        return l
    }
}
