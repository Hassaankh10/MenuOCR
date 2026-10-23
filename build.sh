#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# Prefer the installed stable SDK when newer CLT SDKs lack SwiftUI macro plugins.
SDK="${SDKROOT:-$(xcrun --show-sdk-path)}"
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk ]]; then SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk; fi
swift build --build-system native --sdk "$SDK" ${SWIFT_BUILD_FLAGS:-} -c release --arch arm64
APP="$PWD/dist/MenuOCR.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/MenuOCR.icns"
cp .build/arm64-apple-macosx/release/MenuOCR "$APP/Contents/MacOS/MenuOCR.new"
mv -f "$APP/Contents/MacOS/MenuOCR.new" "$APP/Contents/MacOS/MenuOCR"
./bundle-ocr.sh "$APP/Contents/Resources/OCR"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleDisplayName</key><string>MenuOCR</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>MenuOCR</string>
<key>CFBundleIdentifier</key><string>local.menuocr.app</string>
<key>CFBundleIconFile</key><string>MenuOCR.icns</string>
<key>CFBundleName</key><string>MenuOCR</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.5.1</string>
<key>CFBundleVersion</key><string>11</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>

<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr "$APP"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP/Contents/Resources/OCR/bin/tesseract"
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP"
else
    codesign --force --sign - "$APP/Contents/Resources/OCR/bin/tesseract"
    codesign --force --sign - "$APP"
    echo "Local ad-hoc build: updated builds may need Screen Recording permission again."
    echo "For distribution, set SIGN_IDENTITY to your Developer ID Application identity."
fi
codesign --verify --strict "$APP/Contents/Resources/OCR/bin/tesseract"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
