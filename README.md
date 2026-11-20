# Folder Context

Adds items to the Finder right-click menu:

| Right-click on…            | Menu item                                         |
|----------------------------|---------------------------------------------------|
| One or more folders        | **Open in VS Code**                               |
| Empty space in a window    | **Open in VS Code** / **New Terminal Window Here** / **New Terminal Tab Here** |

## Build & install

```sh
./build.sh install    # builds, copies to ~/Applications, enables the extension, restarts Finder
```

If the items don't appear, enable **Folder Context** in
System Settings → General → Login Items & Extensions → Finder (or "Added Extensions").

**New Terminal Tab** presses ⌘T in Terminal for you, so it needs
**Accessibility** permission for Folder Context (System Settings → Privacy & Security → Accessibility).
Until that's granted, it opens a new window instead.

## How it works

- `Sources/Extension/FinderSync.swift`: a sandboxed Finder Sync extension that builds the menus.
  Because it's sandboxed, it hands each click to the host app as a `foldercontext://<action>?path=…` URL.
- `Sources/App/main.swift`: a background host app (no Dock icon) that opens VS Code or Terminal.
  It quits after 60 s idle.

The build is ad-hoc signed. macOS ties permissions to the signature, so a rebuild may
reset the Accessibility permission. To keep it across rebuilds, sign with a certificate:
`SIGN_IDENTITY="My Cert" ./build.sh install`.
