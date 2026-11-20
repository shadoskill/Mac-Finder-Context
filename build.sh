#!/usr/bin/env bash
# Build Folder Context.app (host app + Finder Sync extension).
#   ./build.sh            build into ./build
#   ./build.sh install    build, copy to ~/Applications, enable the extension
# Set SIGN_IDENTITY to a certificate name to sign with it (default: ad-hoc "-").
set -euo pipefail
cd "$(dirname "$0")"

NAME=FolderContext
EXT_ID=dev.local.FolderContext.FinderExtension
APP="build/$NAME.app"
APPEX="$APP/Contents/PlugIns/${NAME}Extension.appex"
TARGET="$(uname -m)-apple-macos13.0"
SIGN="${SIGN_IDENTITY:--}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APPEX/Contents/MacOS"

echo "→ Compiling host app"
xcrun swiftc -O -target "$TARGET" -module-name "$NAME" \
  -o "$APP/Contents/MacOS/$NAME" Sources/App/*.swift

echo "→ Compiling Finder extension"
xcrun swiftc -O -target "$TARGET" -module-name "${NAME}Extension" \
  -parse-as-library -application-extension \
  -framework FinderSync -Xlinker -e -Xlinker _NSExtensionMain \
  -o "$APPEX/Contents/MacOS/${NAME}Extension" Sources/Extension/*.swift

cp Resources/App-Info.plist "$APP/Contents/Info.plist"
cp Resources/Extension-Info.plist "$APPEX/Contents/Info.plist"

echo "→ Signing ($SIGN)"
codesign --force --sign "$SIGN" --entitlements Resources/Extension.entitlements "$APPEX"
codesign --force --sign "$SIGN" "$APP"

echo "✓ Built $APP"

if [[ "${1:-}" == "install" ]]; then
  DEST="$HOME/Applications/$NAME.app"
  mkdir -p "$HOME/Applications"
  pluginkit -r "$DEST/Contents/PlugIns/${NAME}Extension.appex" 2>/dev/null || true
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  # Make sure only the installed copy is registered (same bundle ID as ./build).
  "$LSREGISTER" -u "$APP" 2>/dev/null || true
  "$LSREGISTER" -f -R -trusted "$DEST"
  pluginkit -a "$DEST/Contents/PlugIns/${NAME}Extension.appex"
  pluginkit -e use -i "$EXT_ID"
  killall Finder 2>/dev/null || true   # restart Finder so it picks up the extension
  sleep 2
  pluginkit -a "$DEST/Contents/PlugIns/${NAME}Extension.appex"
  pluginkit -e use -i "$EXT_ID"
  echo "✓ Installed to $DEST"
  pluginkit -m -v -i "$EXT_ID"
fi
