import Cocoa
import SwiftUI

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
    static let cYellow = Color(red: 249/255, green: 226/255, blue: 175/255)
    static let cTeal = Color(red: 148/255, green: 226/255, blue: 213/255)
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

// MARK: - Data Model

struct SessionTab: Identifiable {
    let id = UUID()
    var name: String
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var selectedServer: String = ""
    @Published var sessions: [SessionTab] = []
    @Published var servers: [String] = []
    @Published var isLaunching = false

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
    }

    func addSession() {
        sessions.append(SessionTab(name: "new-session"))
    }

    func removeSession(at index: Int) {
        guard sessions.count > 1 else { return }
        sessions.remove(at: index)
    }

    // MARK: Persistence

    func saveConfig() {
        let config: [String: Any] = [
            "server": selectedServer,
            "sessions": sessions.map { $0.name }
        ]
        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            FileManager.default.createFile(atPath: configPath, contents: data)
        }
    }

    func loadConfig() {
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let server = config["server"] as? String, servers.contains(server) {
            selectedServer = server
        }
        if let names = config["sessions"] as? [String], !names.isEmpty {
            sessions = names.map { SessionTab(name: $0) }
        }
    }

    // MARK: Launch

    func launch() {
        guard !selectedServer.isEmpty, !sessions.isEmpty else { return }
        isLaunching = true
        saveConfig()

        let server = selectedServer
        let names = sessions.map { $0.name }

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let oldClip = shellOutput("/usr/bin/pbpaste", [])

            osascript("tell application \"Ghostty\" to activate")
            Thread.sleep(forTimeInterval: 0.5)

            for (i, name) in names.enumerated() {
                if i > 0 {
                    osascript("tell application \"System Events\" to tell process \"Ghostty\" to keystroke \"t\" using command down")
                    Thread.sleep(forTimeInterval: 0.5)
                }

                let cmd = "printf '\\e]1;\(name)\\a' && ssh \(server) -t 'tmux attach -t \(name) || tmux new -s \(name)'"
                pbcopy(cmd)

                osascript("""
                tell application "System Events" to tell process "Ghostty"
                    keystroke "v" using command down
                    delay 0.2
                    keystroke return
                end tell
                """)
                Thread.sleep(forTimeInterval: 0.3)
            }

            pbcopy(oldClip)

            DispatchQueue.main.async { self.isLaunching = false }
        }
    }

    // MARK: Helpers

    private func osascript(_ script: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    private func pbcopy(_ text: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        p.standardInput = pipe
        try? p.run()
        pipe.fileHandleForWriting.write(text.data(using: .utf8) ?? Data())
        pipe.fileHandleForWriting.closeFile()
        p.waitUntilExit()
    }

    private func shellOutput(_ cmd: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

// MARK: - Pixel Ghost View

struct PixelGhostView: View {
    let pixelSize: CGFloat
    let color: Color
    @Binding var animate: Bool

    // 12x13 pixel ghost: 0=clear, 1=body, 2=eye white, 3=eye pupil
    let pixels: [[Int]] = [
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,1,1,2,2,1,1,2,2,1,1,0],
        [0,1,1,3,2,1,1,3,2,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,0,1,1,1,0,0,1,1,1,0,1],
        [1,0,0,1,0,0,0,0,1,0,0,1],
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<pixels.count, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<pixels[row].count, id: \.self) { col in
                        Rectangle()
                            .fill(colorFor(pixels[row][col]))
                            .frame(width: pixelSize, height: pixelSize)
                    }
                }
            }
        }
        .offset(y: animate ? -6 : 0)
        .animation(
            Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
            value: animate
        )
    }

    func colorFor(_ v: Int) -> Color {
        switch v {
        case 1: return color
        case 2: return .white
        case 3: return Color.cBase
        default: return .clear
        }
    }
}

// MARK: - Scanline Overlay

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(0..<Int(geo.size.height / 2), id: \.self) { _ in
                    Color.clear.frame(height: 1)
                    Color.black.opacity(0.04).frame(height: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - UI Components

struct PixelButtonStyle: ButtonStyle {
    let bg: Color
    let fg: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Menlo", size: 13).bold())
            .foregroundColor(fg)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 2).fill(configuration.isPressed ? bg.opacity(0.7) : bg))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 6) {
            Text(">").foregroundColor(.cGreen)
            Text(title).foregroundColor(.cText)
        }
        .font(.custom("Menlo", size: 12).bold())
    }
}

struct SessionRow: View {
    let index: Int
    @Binding var session: SessionTab
    let onDelete: () -> Void
    let canDelete: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("TAB \(index + 1)")
                .font(.custom("Menlo", size: 11))
                .foregroundColor(.cOverlay0)
                .frame(width: 48, alignment: .leading)

            TextField("session", text: $session.name)
                .textFieldStyle(.plain)
                .font(.custom("Menlo", size: 13))
                .foregroundColor(.cText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cBase)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.cSurface2, lineWidth: 1))
                )

            if canDelete {
                Button(action: onDelete) {
                    Text("\u{00D7}")
                        .font(.custom("Menlo", size: 16).bold())
                        .foregroundColor(.cRed)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 24)
            }
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var state = AppState()
    @State private var ghostAnimate = false

    var body: some View {
        ZStack {
            Color.cBase.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    PixelGhostView(pixelSize: 5, color: .cMauve, animate: $ghostAnimate)
                        .onAppear { ghostAnimate = true }

                    Text("GHOST CONNECT")
                        .font(.custom("Menlo", size: 20).bold())
                        .foregroundColor(.cLavender)
                        .tracking(4)

                    Text("tmux session launcher")
                        .font(.custom("Menlo", size: 10))
                        .foregroundColor(.cOverlay0)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                Rectangle().fill(Color.cSurface1).frame(height: 1).padding(.horizontal, 20)

                // Server
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "SERVER")

                    Picker("", selection: $state.selectedServer) {
                        ForEach(state.servers, id: \.self) { server in
                            Text(server).font(.custom("Menlo", size: 13)).tag(server)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 2).fill(Color.cSurface0))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Sessions
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "SESSIONS")

                    VStack(spacing: 6) {
                        ForEach(Array(state.sessions.enumerated()), id: \.element.id) { index, _ in
                            SessionRow(
                                index: index,
                                session: $state.sessions[index],
                                onDelete: { state.removeSession(at: index) },
                                canDelete: state.sessions.count > 1
                            )
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 2).fill(Color.cSurface0))

                    Button(action: { state.addSession() }) {
                        HStack(spacing: 4) { Text("+"); Text("ADD TAB") }
                    }
                    .buttonStyle(PixelButtonStyle(bg: .cSurface1, fg: .cSubtext0))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Launch
                Button(action: { state.launch() }) {
                    HStack(spacing: 8) {
                        if state.isLaunching {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .cBase))
                        }
                        Text(state.isLaunching ? "CONNECTING..." : "\u{25B6}  LAUNCH")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PixelButtonStyle(bg: state.isLaunching ? .cSurface2 : .cGreen, fg: .cBase))
                .disabled(state.isLaunching)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            ScanlineOverlay().ignoresSafeArea()
        }
        .frame(width: 420, height: 520)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ghost Connect"
        window.center()
        window.contentView = NSHostingView(rootView: ContentView())
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(red: 30/255, green: 30/255, blue: 46/255, alpha: 1)
        window.titlebarAppearsTransparent = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
