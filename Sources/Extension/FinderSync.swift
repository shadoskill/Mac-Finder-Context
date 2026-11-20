import Cocoa
import FinderSync

@objc(FinderSync)
final class FinderSync: FIFinderSync {

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let menu = NSMenu(title: "")

        switch menuKind {
        case .contextualMenuForItems:
            let selected = FIFinderSyncController.default().selectedItemURLs() ?? []
            guard !selected.isEmpty, selected.allSatisfy(isFolder) else { return nil }
            let item = menu.addItem(withTitle: "Open in VS Code",
                                    action: #selector(openInVSCode(_:)),
                                    keyEquivalent: "")
            item.image = vscodeIcon()

        case .contextualMenuForContainer:
            let vscode = menu.addItem(withTitle: "Open in VS Code",
                                      action: #selector(openContainerInVSCode(_:)),
                                      keyEquivalent: "")
            vscode.image = vscodeIcon()
            menu.addItem(withTitle: "New Terminal Window Here",
                         action: #selector(newTerminalWindow(_:)),
                         keyEquivalent: "")
            menu.addItem(withTitle: "New Terminal Tab Here",
                         action: #selector(newTerminalTab(_:)),
                         keyEquivalent: "")

        default:
            return nil
        }

        return menu
    }

    @objc private func openInVSCode(_ sender: AnyObject?) {
        let urls = (FIFinderSyncController.default().selectedItemURLs() ?? []).filter(isFolder)
        send("vscode", urls)
    }

    @objc private func openContainerInVSCode(_ sender: AnyObject?) {
        guard let url = FIFinderSyncController.default().targetedURL() else { return }
        send("vscode", [url])
    }

    @objc private func newTerminalWindow(_ sender: AnyObject?) {
        guard let url = FIFinderSyncController.default().targetedURL() else { return }
        send("terminal-window", [url])
    }

    @objc private func newTerminalTab(_ sender: AnyObject?) {
        guard let url = FIFinderSyncController.default().targetedURL() else { return }
        send("terminal-tab", [url])
    }

    private func send(_ action: String, _ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var components = URLComponents()
        components.scheme = "foldercontext"
        components.host = action
        components.queryItems = urls.map { URLQueryItem(name: "path", value: $0.path) }
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func isFolder(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
           let isDirectory = values.isDirectory {
            return isDirectory && !(values.isPackage ?? false)
        }
        return url.hasDirectoryPath && url.pathExtension != "app"
    }

    private func vscodeIcon() -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
        else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}
