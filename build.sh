#!/bin/bash
set -e

# ─────────────────────────────────────────────
# Ny Mappe (7) — Universal Build Script
# Builds for both Intel (x86_64) and Apple Silicon (arm64)
# Requires: macOS 13+ with Xcode Command Line Tools (xcode-select --install)
#
# Usage:
#   ./build.sh              — Build, install, launch (no signing)
#   ./build.sh --sign       — Build + codesign + install + launch
#   ./build.sh --release    — Build + codesign + notarize + DMG
# ─────────────────────────────────────────────

APP_NAME="Ny Mappe (7) v2"
EXECUTABLE="NyMappa7"
MIN_MACOS="13.0"
VERSION="5.6"

# ── Code Signing & Notarization ──────────────────────────
# Fill in these values from your Apple Developer account:
#   SIGNING_IDENTITY: Run `security find-identity -v -p codesigning` to list yours
#   APPLE_ID:         Your Apple ID email
#   TEAM_ID:          Your 10-character team ID (developer.apple.com → Membership)
#   APP_PASSWORD:     App-specific password from appleid.apple.com
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"    # e.g. "Developer ID Application: Victoria Haugnes (XXXXXXXXXX)"
APPLE_ID="${APPLE_ID:-}"                    # e.g. "your@email.com"
TEAM_ID="${TEAM_ID:-}"                      # e.g. "XXXXXXXXXX"
APP_PASSWORD="${APP_PASSWORD:-}"            # App-specific password for notarytool

# Parse flags
DO_SIGN=false
DO_RELEASE=false
for arg in "$@"; do
    case "$arg" in
        --sign)    DO_SIGN=true ;;
        --release) DO_SIGN=true; DO_RELEASE=true ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/Ny Mappe 7"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"

# All source files
SOURCES=(
    "$SRC_DIR/NyMappe7App.swift"
    "$SRC_DIR/Models/AppState.swift"
    "$SRC_DIR/Models/StashItem.swift"
    "$SRC_DIR/Models/StashSet.swift"
    "$SRC_DIR/Models/ClipboardEntry.swift"
    "$SRC_DIR/Models/ClipboardGroup.swift"
    "$SRC_DIR/Models/QuickNote.swift"
    "$SRC_DIR/Models/CSVColumnBuilderState.swift"
    "$SRC_DIR/Models/ViewPreferences.swift"
    "$SRC_DIR/Models/Date+TimeAgo.swift"
    "$SRC_DIR/Models/BundleItem.swift"
    "$SRC_DIR/Models/ContextBundle.swift"
    "$SRC_DIR/Models/Prompt.swift"
    "$SRC_DIR/Models/PathEntry.swift"
    "$SRC_DIR/ViewModels/StashViewModel.swift"
    "$SRC_DIR/Services/StagingService.swift"
    "$SRC_DIR/Services/ThumbnailService.swift"
    "$SRC_DIR/Services/PersistenceService.swift"
    "$SRC_DIR/Services/ScreenshotWatcher.swift"
    "$SRC_DIR/Services/ClipboardWatcher.swift"
    "$SRC_DIR/Views/ContentView.swift"
    "$SRC_DIR/Views/QuickNoteView.swift"
    "$SRC_DIR/Views/CardsGridView.swift"
    "$SRC_DIR/Views/Components/TypeBadge.swift"
    "$SRC_DIR/Views/Components/DragAllButton.swift"
    "$SRC_DIR/Views/Components/FileCardView.swift"
    "$SRC_DIR/Views/Components/ActionBarView.swift"
    "$SRC_DIR/Views/Components/ErrorBanner.swift"
    "$SRC_DIR/Views/Components/MultiFileDragButton.swift"
    "$SRC_DIR/Views/Components/ToolbarView.swift"
    "$SRC_DIR/Views/Components/HeaderView.swift"
    "$SRC_DIR/Views/Components/EmptyStateView.swift"
    "$SRC_DIR/Views/Components/DraggableCardWrapper.swift"
    "$SRC_DIR/Views/Components/DesignTokens.swift"
    "$SRC_DIR/Views/Components/DragSourceView.swift"
    "$SRC_DIR/Views/Components/SetSelectorView.swift"
    "$SRC_DIR/Views/Components/ClipboardListView.swift"
    "$SRC_DIR/Views/Components/ScreenshotLightGridView.swift"
    "$SRC_DIR/Views/Components/ToastView.swift"
    "$SRC_DIR/Views/Components/AppIcon.swift"
    "$SRC_DIR/Views/Components/ViewControls.swift"
    "$SRC_DIR/Views/Components/ContextBundlesView.swift"
    "$SRC_DIR/Views/Components/PromptsView.swift"
    "$SRC_DIR/Views/Components/KontekstView.swift"
    "$SRC_DIR/Views/Components/BatchRenameSheet.swift"
    "$SRC_DIR/Views/Components/PathListView.swift"
    "$SRC_DIR/Views/Components/SettingsSheet.swift"
    "$SRC_DIR/Views/Components/SheetsCollectorView.swift"
    "$SRC_DIR/Views/Components/SheetsTabView.swift"
    "$SRC_DIR/Views/Components/ToolsTabView.swift"
)

FRAMEWORKS="-framework SwiftUI -framework AppKit -framework QuickLookThumbnailing -framework UniformTypeIdentifiers"
COMMON_FLAGS="-parse-as-library $FRAMEWORKS"

echo "🔨 Building Ny Mappe (7)..."
echo ""

# Create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build for Intel
echo "  [1/3] Compiling for x86_64 (Intel)..."
xcrun -sdk macosx swiftc \
    -target x86_64-apple-macosx${MIN_MACOS} \
    $COMMON_FLAGS \
    -o "$BUILD_DIR/${EXECUTABLE}-x86_64" \
    "${SOURCES[@]}" 2>&1 | grep -v "warning:" || true

# Build for Apple Silicon
echo "  [2/3] Compiling for arm64 (Apple Silicon)..."
xcrun -sdk macosx swiftc \
    -target arm64-apple-macosx${MIN_MACOS} \
    $COMMON_FLAGS \
    -o "$BUILD_DIR/${EXECUTABLE}-arm64" \
    "${SOURCES[@]}" 2>&1 | grep -v "warning:" || true

# Combine into universal binary
echo "  [3/3] Creating universal binary with lipo..."
lipo -create \
    "$BUILD_DIR/${EXECUTABLE}-x86_64" \
    "$BUILD_DIR/${EXECUTABLE}-arm64" \
    -output "$BUILD_DIR/${EXECUTABLE}"

# Create .app bundle
echo ""
echo "📦 Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/${EXECUTABLE}" "$APP_DIR/Contents/MacOS/${EXECUTABLE}"
chmod +x "$APP_DIR/Contents/MacOS/${EXECUTABLE}"

# Copy icon if exists
if [ -f "$SRC_DIR/AppIcon.icns" ]; then
    cp "$SRC_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/"
elif [ -f "$SCRIPT_DIR/../Ny Mappe (7).app/Contents/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/../Ny Mappe (7).app/Contents/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

# Copy custom SVG icons into the bundle so AppIcon view can load them at runtime
if [ -d "$SRC_DIR/Resources/Icons" ]; then
    mkdir -p "$APP_DIR/Contents/Resources/Icons"
    cp "$SRC_DIR/Resources/Icons/"*.svg "$APP_DIR/Contents/Resources/Icons/" 2>/dev/null || true
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Ny Mappe (7)</string>
    <key>CFBundleDisplayName</key>
    <string>Ny Mappe (7)</string>
    <key>CFBundleIdentifier</key>
    <string>no.klippegeni.nymappe7</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>NyMappa7</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Verify
ARCHS=$(lipo -archs "$APP_DIR/Contents/MacOS/${EXECUTABLE}")
SIZE=$(du -sh "$APP_DIR" | cut -f1)

# ── Ad-hoc Code Signing (gir stabil identitet for TCC-permissions) ───
# Uten dette får appen ny identitet hver build og macOS glemmer
# tillatelser for Skrivebord/Dokumenter osv. — prompter deg konstant.
# Ad-hoc-signering (-) krever ingen Apple Developer-konto.
if [ "$DO_SIGN" = false ]; then
    echo ""
    echo "🔏 Ad-hoc signing (for stable TCC identity)..."
    codesign --force --deep --sign - "$APP_DIR" 2>&1 | grep -v "replacing existing signature" || true
fi

# ── Full Code Signing (--sign eller --release) ───────────
if [ "$DO_SIGN" = true ]; then
    if [ -z "$SIGNING_IDENTITY" ]; then
        echo ""
        echo "⚠️  SIGNING_IDENTITY is not set. Skipping code signing."
        echo "   Run: security find-identity -v -p codesigning"
        echo "   Then set: export SIGNING_IDENTITY=\"Developer ID Application: ...\""
        DO_SIGN=false
        DO_RELEASE=false
    else
        echo ""
        echo "🔏 Code signing with: $SIGNING_IDENTITY"
        codesign --force --deep --options runtime \
            --sign "$SIGNING_IDENTITY" \
            "$APP_DIR"
        echo "   ✓ Signed"

        # Verify signature
        codesign --verify --deep --strict "$APP_DIR"
        echo "   ✓ Signature verified"
    fi
fi

# ── Notarization & DMG (--release only) ───────────────────
if [ "$DO_RELEASE" = true ]; then
    if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_PASSWORD" ]; then
        echo ""
        echo "⚠️  Missing notarization credentials. Set these env vars:"
        echo "   APPLE_ID, TEAM_ID, APP_PASSWORD"
        echo "   Skipping notarization."
    else
        DMG_NAME="NyMappe7-v${VERSION}.dmg"
        DMG_PATH="$SCRIPT_DIR/$DMG_NAME"

        echo ""
        echo "📀 Creating DMG: $DMG_NAME"
        rm -f "$DMG_PATH"
        hdiutil create -volname "Ny Mappe (7)" \
            -srcfolder "$APP_DIR" \
            -ov -format UDZO \
            "$DMG_PATH"

        # Sign the DMG too
        codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"

        echo ""
        echo "📤 Submitting for notarization (this may take a few minutes)..."
        xcrun notarytool submit "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_PASSWORD" \
            --wait

        echo ""
        echo "📎 Stapling notarization ticket to DMG..."
        xcrun stapler staple "$DMG_PATH"

        echo ""
        echo "✅ Release build complete!"
        echo "   DMG:            $DMG_PATH"
        echo "   Architectures:  $ARCHS"
        echo "   Size:           $(du -sh "$DMG_PATH" | cut -f1)"
        echo ""
        echo "🎉 Ready to distribute! Users can open $DMG_NAME without Gatekeeper warnings."

        # Cleanup build artifacts
        rm -rf "$BUILD_DIR"
        exit 0
    fi
fi

# ── Local install (default / --sign without --release) ────
INSTALL_DIR="/Applications/Ny Mappe (7).app"

# Kill running instance before replacing
pkill -f "NyMappa7" 2>/dev/null && sleep 0.5 || true

# Install to /Applications
rm -rf "$INSTALL_DIR"
cp -r "$APP_DIR" "$INSTALL_DIR"

echo ""
echo "✅ Build complete!"
echo "   App:           $INSTALL_DIR"
echo "   Version:       $VERSION"
echo "   Architectures: $ARCHS"
echo "   Size:          $SIZE"
if [ "$DO_SIGN" = true ]; then
    echo "   Signed:        ✓"
fi
echo ""

# Auto-launch
open "$INSTALL_DIR"
echo "🚀 App installed to /Applications/ and launched!"

# Cleanup build artifacts
rm -rf "$BUILD_DIR"
