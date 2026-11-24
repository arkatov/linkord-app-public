#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=1.0
build=44
mkdir -p .build dist
# The distribution directory contains only generated Linkord releases.
find dist -maxdepth 1 \( -name 'Linkord*.app' -o -name 'Linkord*.dmg' \) -exec rm -rf {} +
stage="$(mktemp -d "$PWD/.build/package.XXXXXX")"
mount="$stage/mount"
trap 'hdiutil detach "$mount" -quiet 2>/dev/null || true; rm -rf "$stage"' EXIT
app="$stage/image/Linkord.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$stage/Linkord.iconset" "$stage/image/.background"
swift -module-cache-path "$PWD/.build/ModuleCache" scripts/artwork.swift "$stage"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$stage/icon.png" --out "$stage/Linkord.iconset/icon_${size}x${size}.png" >/dev/null
    pixels=$((size * 2))
    sips -z "$pixels" "$pixels" "$stage/icon.png" --out "$stage/Linkord.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$stage/Linkord.iconset" -o "$app/Contents/Resources/Linkord.icns"
sdk="$(xcrun --sdk macosx --show-sdk-path)"
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find Sources/Linkord -name '*.swift' | sort)
for arch in arm64 x86_64; do
    swiftc -I Sources/CHTML -Xcc "-I$sdk/usr/include/libxml2" -warnings-as-errors -O -parse-as-library -sdk "$sdk" -target "$arch-apple-macosx14.0" \
        -module-cache-path "$PWD/.build/ModuleCache" "${sources[@]}" -o "$stage/Linkord-$arch"
done
lipo -create "$stage/Linkord-arm64" "$stage/Linkord-x86_64" -output "$app/Contents/MacOS/Linkord"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Linkord</string>
<key>CFBundleIdentifier</key><string>com.arkatov.linkord</string>
<key>CFBundleName</key><string>Linkord</string>
<key>CFBundleIconFile</key><string>Linkord.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$build</string>
<key>CFBundleLocalizations</key><array><string>ru</string><string>en</string></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
codesign --verify --strict "$app"
ditto "$app" dist/Linkord.app
cp "$stage/background.png" "$stage/image/.background/background.png"
ln -s /Applications "$stage/image/Applications"
hdiutil create -quiet -size 40m -volname "Linkord v$version" -format UDRW -srcfolder "$stage/image" "$stage/writable.dmg"
hdiutil attach -quiet -nobrowse -mountpoint "$mount" "$stage/writable.dmg"
osascript - "$mount" <<'APPLESCRIPT'
on run argv
    set mountPath to item 1 of argv
    set mountedDisk to POSIX file mountPath as alias
    tell application "Finder"
        open mountedDisk
        set diskWindow to container window of mountedDisk
        set current view of diskWindow to icon view
        set toolbar visible of diskWindow to false
        set statusbar visible of diskWindow to false
        set bounds of diskWindow to {160, 120, 800, 548}
        set options to icon view options of diskWindow
        set arrangement of options to not arranged
        set icon size of options to 100
        set text size of options to 14
        set background picture of options to POSIX file (mountPath & "/.background/background.png")
        set position of item "Linkord.app" of diskWindow to {170, 185}
        set position of item "Applications" of diskWindow to {470, 185}
        close diskWindow
    end tell
end run
APPLESCRIPT
sync
hdiutil detach -quiet "$mount"
hdiutil convert -quiet "$stage/writable.dmg" -format UDZO -o "dist/Linkord-$version.dmg"
printf 'Built Linkord %s (arm64 + x86_64)\n' "$version"
