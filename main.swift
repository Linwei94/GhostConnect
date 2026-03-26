import Cocoa
import SwiftUI
import ServiceManagement

// MARK: - Catppuccin Mocha Colors

extension Color {
    static let cBase = Color(red: 30/255, green: 30/255, blue: 46/255)
    static let cMantle = Color(red: 24/255, green: 24/255, blue: 37/255)
    static let cSurface0 = Color(red: 49/255, green: 50/255, blue: 68/255)
    static let cSurface1 = Color(red: 69/255, green: 71/255, blue: 90/255)
    static let cSurface2 = Color(red: 88/255, green: 91/255, blue: 112/255)
    static let cOverlay0 = Color(red: 108/255, green: 112/255, blue: 134/255)
    static let cText = Color(red: 205/255, green: 214/255, blue: 244/255)
    static let cSubtext0 = Color(red: 166/255, green: 173/255, blue: 200/255)
    static let cLavender = Color(red: 180/255, green: 190/255, blue: 254/255)
    static let cMauve = Color(red: 203/255, green: 166/255, blue: 247/255)
    static let cGreen = Color(red: 166/255, green: 227/255, blue: 161/255)
    static let cRed = Color(red: 243/255, green: 139/255, blue: 168/255)
    static let cPeach = Color(red: 250/255, green: 179/255, blue: 135/255)
}

// MARK: - SSH Config Parser

func parseSSHConfig() -> [String] {
    let path = NSString("~/.ssh/config").expandingTildeInPath
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
    var hosts: [String] = []
    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("Host ") && !trimmed.contains("*") && !trimmed.hasPrefix("#") {
            let host = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if !host.isEmpty { hosts.append(host) }
        }
    }
    return hosts
}

// MARK: - Menu Bar Ghost Icon

func createMenuBarIcon() -> NSImage {
    let ghost: [[Int]] = [
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,1,1,0,0,1,1,0,0,1,1,0],
        [0,1,1,0,0,1,1,0,0,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,0,1,1,1,0,0,1,1,1,0,1],
        [1,0,0,1,0,0,0,0,1,0,0,1],
    ]
    let ps: CGFloat = 1.3
    let imgS: CGFloat = 18
    let ox = (imgS - 12 * ps) / 2, oy = (imgS - 13 * ps) / 2
    let image = NSImage(size: NSSize(width: imgS, height: imgS), flipped: true) { _ in
        NSColor.black.setFill()
        for y in 0..<13 { for x in 0..<12 {
            if ghost[y][x] == 1 {
                NSRect(x: ox + CGFloat(x) * ps, y: oy + CGFloat(y) * ps, width: ps, height: ps).fill()
            }
        }}
        return true
    }
    image.isTemplate = true
    return image
}

// MARK: - Data Model

struct SessionTab: Identifiable {
    let id = UUID()
    var name: String
}

// MARK: - App State

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var selectedServer: String = ""
    @Published var sessions: [SessionTab] = []
    @Published var servers: [String] = []
    @Published var isLaunching = false
    @Published var launchError: String? = nil
    @Published var autoStart: Bool = false
    @Published var showServerList = false

    private let configPath = NSString("~/.config/ghostty/ghost-connect.json").expandingTildeInPath

    init() {
        servers = parseSSHConfig()
        selectedServer = servers.contains("linwei-lab2") ? "linwei-lab2" : (servers.first ?? "")
        sessions = [
            SessionTab(name: "research"),
            SessionTab(name: "research-2"),
            SessionTab(name: "projects")
        ]
        loadConfig()
        if #available(macOS 13.0, *) { autoStart = SMAppService.mainApp.status == .enabled }
    }

    func addSession() { sessions.append(SessionTab(name: "new-session")) }
    func removeSession(at i: Int) { guard sessions.count > 1 else { return }; sessions.remove(at: i) }

    func toggleAutoStart() {
        if #available(macOS 13.0, *) {
            do {
                if autoStart { try SMAppService.mainApp.unregister() }
                else { try SMAppService.mainApp.register() }
                autoStart = SMAppService.mainApp.status == .enabled
            } catch {}
        }
    }

    func saveConfig() {
        let config: [String: Any] = ["server": selectedServer, "sessions": sessions.map { $0.name }]
        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            FileManager.default.createFile(atPath: configPath, contents: data)
        }
    }

    func loadConfig() {
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let s = config["server"] as? String, servers.contains(s) { selectedServer = s }
        if let n = config["sessions"] as? [String], !n.isEmpty { sessions = n.map { SessionTab(name: $0) } }
    }

    func launch() {
        guard !selectedServer.isEmpty, !sessions.isEmpty else { return }
        isLaunching = true; launchError = nil; saveConfig()
        let server = selectedServer, names = sessions.map { $0.name }

        var script = "#!/bin/bash\nOLD_CB=\"$(pbpaste 2>/dev/null)\"\n"
        script += "printf '\\e]0;\(names[0])\\a'\n"

        for i in 1..<names.count {
            let name = names[i]
            let cmd = "printf '\\e]0;\(name)\\a' && ssh \(server) -t 'tmux attach -t \(name) || tmux new -s \(name)'"
            script += "\nosascript -e 'tell application \"System Events\" to tell process \"Ghostty\" to keystroke \"t\" using command down'\nsleep 1\n"
            script += "echo -n '\(cmd.replacingOccurrences(of: "'", with: "'\\''"))' | pbcopy\n"
            script += "osascript -e 'tell application \"System Events\" to tell process \"Ghostty\"' -e 'keystroke \"v\" using command down' -e 'end tell'\nsleep 0.3\n"
            script += "osascript -e 'tell application \"System Events\" to tell process \"Ghostty\"' -e 'key code 36' -e 'end tell'\nsleep 0.5\n"
        }

        script += "\necho -n \"$OLD_CB\" | pbcopy 2>/dev/null\n"
        if names.count > 1 {
            script += "\nosascript -e 'tell application \"System Events\" to tell process \"Ghostty\"' -e 'keystroke \"1\" using command down' -e 'end tell'\nsleep 0.3\n"
        }
        script += "\nexec ssh \(server) -t 'tmux attach -t \(names[0]) || tmux new -s \(names[0])'\n"

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let p = NSTemporaryDirectory() + "ghost-connect-launcher.sh"
            do {
                try script.write(toFile: p, atomically: true, encoding: .utf8)
                let ch = Process(); ch.executableURL = URL(fileURLWithPath: "/bin/chmod"); ch.arguments = ["+x", p]; try ch.run(); ch.waitUntilExit()
                let o = Process(); o.executableURL = URL(fileURLWithPath: "/usr/bin/open"); o.arguments = ["-na", "Ghostty.app", "--args", "-e", p]; try o.run(); o.waitUntilExit()
            } catch { DispatchQueue.main.async { self.launchError = error.localizedDescription } }
            DispatchQueue.main.async { self.isLaunching = false }
        }
    }
}

// MARK: - Mini Ghost

struct MiniGhost: View {
    let pixels: [[Int]] = [
        [0,0,1,1,1,1,0,0],[0,1,1,1,1,1,1,0],[1,1,0,1,1,0,1,1],
        [1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1],
        [1,0,1,1,1,1,0,1],[1,0,0,1,1,0,0,1],
    ]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<pixels.count, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<pixels[r].count, id: \.self) { c in
                        Rectangle().fill(pixels[r][c] == 1 ? Color.cMauve : Color.clear).frame(width: 3, height: 3)
                    }
                }
            }
        }
    }
}

// MARK: - Panel Content

struct PanelView: View {
    @ObservedObject var state = AppState.shared
    var closeAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                MiniGhost()
                Text("Ghost Connect")
                    .font(.custom("Menlo-Bold", size: 13))
                    .foregroundColor(.cText)
                Spacer()
                Button(action: { state.toggleAutoStart() }) {
                    HStack(spacing: 4) {
                        Image(systemName: state.autoStart ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11))
                            .foregroundColor(state.autoStart ? .cGreen : .cOverlay0)
                        Text("Auto Start")
                            .font(.custom("Menlo", size: 10))
                            .foregroundColor(.cSubtext0)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Server - inline clickable
            HStack {
                Text("SERVER")
                    .font(.custom("Menlo-Bold", size: 9))
                    .foregroundColor(.cOverlay0)
                    .tracking(1.5)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            Button(action: { withAnimation(.easeOut(duration: 0.15)) { state.showServerList.toggle() } }) {
                HStack {
                    Text(state.selectedServer)
                        .font(.custom("Menlo", size: 12))
                        .foregroundColor(.cText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.cOverlay0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.cSurface0))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            if state.showServerList {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(state.servers, id: \.self) { server in
                            Button(action: {
                                state.selectedServer = server
                                withAnimation(.easeOut(duration: 0.15)) { state.showServerList = false }
                            }) {
                                HStack {
                                    Text(server)
                                        .font(.custom("Menlo", size: 11))
                                        .foregroundColor(server == state.selectedServer ? .cMauve : .cSubtext0)
                                    Spacer()
                                    if server == state.selectedServer {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.cMauve)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 120)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.cSurface0))
                .padding(.horizontal, 14)
                .padding(.top, 2)
            }

            // Sessions
            HStack {
                Text("SESSIONS")
                    .font(.custom("Menlo-Bold", size: 9))
                    .foregroundColor(.cOverlay0)
                    .tracking(1.5)
                Spacer()
                Button(action: { state.addSession() }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.cLavender)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            VStack(spacing: 3) {
                ForEach(Array(state.sessions.enumerated()), id: \.element.id) { i, _ in
                    HStack(spacing: 6) {
                        Text("\(i + 1)")
                            .font(.custom("Menlo", size: 9))
                            .foregroundColor(.cOverlay0)
                            .frame(width: 12)

                        TextField("session", text: $state.sessions[i].name)
                            .textFieldStyle(.plain)
                            .font(.custom("Menlo", size: 12))
                            .foregroundColor(.cText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.cSurface0))

                        if state.sessions.count > 1 {
                            Button(action: { state.removeSession(at: i) }) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.cOverlay0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }

            if let err = state.launchError {
                Text(err).font(.custom("Menlo", size: 9)).foregroundColor(.cRed).lineLimit(2)
                    .padding(.horizontal, 14).padding(.top, 4)
            }

            Spacer(minLength: 8)

            // Bottom
            HStack {
                Button(action: { closeAction(); state.launch() }) {
                    HStack(spacing: 5) {
                        if state.isLaunching {
                            ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "play.fill").font(.system(size: 9))
                        }
                        Text(state.isLaunching ? "Launching..." : "Launch")
                            .font(.custom("Menlo-Bold", size: 11))
                    }
                    .foregroundColor(.cBase)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.cGreen))
                }
                .buttonStyle(.plain)
                .disabled(state.isLaunching)

                Spacer()

                Button(action: { NSApp.terminate(nil) }) {
                    Text("Quit").font(.custom("Menlo", size: 10)).foregroundColor(.cOverlay0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .padding(.top, 6)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.cBase)
    }
}

// MARK: - Borderless Panel

class StatusPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        appearance = NSAppearance(named: .darkAqua)

        // Round corners
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 10
        contentView?.layer?.masksToBounds = true
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: StatusPanel!
    var monitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupPanel()

        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status != .enabled {
                try? SMAppService.mainApp.register()
                AppState.shared.autoStart = true
            }
        }

        // Click outside to close
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.panel.orderOut(nil)
        }
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = createMenuBarIcon()
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    func setupPanel() {
        panel = StatusPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100))

        let hostView = NSHostingView(rootView: PanelView(closeAction: { [weak self] in
            self?.panel.orderOut(nil)
        }))
        hostView.wantsLayer = true
        hostView.layer?.cornerRadius = 10
        hostView.layer?.masksToBounds = true
        panel.contentView = hostView
    }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }

        // Position directly below the status item
        guard let button = statusItem.button, let btnWindow = button.window else { return }
        let btnRect = button.convert(button.bounds, to: nil)
        let screenRect = btnWindow.convertToScreen(btnRect)

        // Size the panel to fit content
        panel.contentView?.layoutSubtreeIfNeeded()
        let contentSize = panel.contentView?.fittingSize ?? NSSize(width: 300, height: 400)
        let panelW = contentSize.width
        let panelH = contentSize.height

        let x = screenRect.minX
        let y = screenRect.minY - panelH - 4  // 4px gap from menu bar

        panel.setFrame(NSRect(x: x, y: y, width: panelW, height: panelH), display: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
