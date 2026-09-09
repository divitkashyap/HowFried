#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release -Xlinker -no_adhoc_codesign
build_bin="$(swift build -c release --show-bin-path)"
build_tag="$(date -u +%Y%m%dT%H%M%SZ)-$$"
app_dir="$PWD/artifacts/$build_tag/HowFried.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_bin/HowFried" "$app_dir/Contents/MacOS/HowFried"
cp "$build_bin/howfried-hook" "$app_dir/Contents/MacOS/howfried-hook"
cp docs/SETUP.md "$app_dir/Contents/Resources/SETUP.md"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>HowFried</string>
<key>CFBundleIdentifier</key><string>local.howfried.mac</string>
<key>CFBundleName</key><string>HowFried</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --sign - "$app_dir/Contents/MacOS/howfried-hook"
codesign --sign - "$app_dir"
printf '%s\n' "$app_dir"
