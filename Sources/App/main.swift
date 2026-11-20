import Cocoa
import ApplicationServices

enum Action {
    static let vscodeBundleIDs = ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"]
    static let terminalBundleID = "com.apple.Terminal"

    static func handle(_ url: URL) {
        guard url.scheme == "foldercontext",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }

        let folders = (components.queryItems ?? [])
            .filter { $0.name == "path" }
            .compactMap { $0.value }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            .filter { url in
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
            }
        guard let first = folders.first else { return }

        switch url.host {
        case "vscode":
            guard let app = vscodeBundleIDs.lazy
                .compactMap({ NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }).first
            else {
                alert("Visual Studio Code not found", "Install VS Code in /Applications and try again.")
                return
            }
            open(folders, with: app)

        case "terminal-window":
            openTerminalWindow(at: first)

        case "terminal-tab":
            openTerminalTab(at: first)

        default:
            break
        }
    }

    private static var terminalAppURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID)
    }

    static func openTerminalWindow(at folder: URL) {
        guard let terminal = terminalAppURL else { return }
        open([folder], with: terminal)
    }

    static func openTerminalTab(at folder: URL) {
        let terminalRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: terminalBundleID).isEmpty
        guard terminalRunning else {
            openTerminalWindow(at: folder)  // nothing to add a tab to
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            openTerminalWindow(at: folder)
            return
        }

        let path = folder.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = """
        set targetPath to "\(path)"
        tell application "Terminal"
            if (count of windows) is 0 then
                do script "cd " & quoted form of targetPath & " && clear"
                activate
                return
            end if
            activate
            set tabCount to count of tabs of front window
        end tell
        tell application "System Events" to tell process "Terminal" to keystroke "t" using command down
        tell application "Terminal"
            repeat 40 times
                if (count of tabs of front window) > tabCount then exit repeat
                delay 0.05
            end repeat
            do script "cd " & quoted form of targetPath & " && clear" in selected tab of front window
        end tell
        """

        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("FolderContext: AppleScript failed: \(error)")
            openTerminalWindow(at: folder)
        }
    }

    // MARK: Helpers

    private static func open(_ urls: [URL], with app: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: config) { _, error in
            if let error { NSLog("FolderContext: open failed: \(error)") }
        }
    }

    static func alert(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var handledURL = false
    private var idleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            if !handledURL { showSetup() }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handledURL = true
        urls.forEach(Action.handle)
        scheduleIdleQuit()
    }

    private func scheduleIdleQuit() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in
            NSApp.terminate(nil)
        }
    }

    private func showSetup() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Folder Context"
        alert.informativeText = """
        Adds Finder right-click items:
        • Folders → "Open in VS Code"
        • Empty space → "New Terminal Window/Tab Here"

        Make sure the extension is enabled in System Settings → General → \
        Login Items & Extensions → Finder (or "Added Extensions").

        "New Terminal Tab" also needs Accessibility permission for Folder Context.
        """
        alert.addButton(withTitle: "Open Extension Settings")
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Done")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        default:
            break
        }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
