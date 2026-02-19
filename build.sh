#!/bin/bash
set -e

# ─────────────────────────────────────────────
# Ny Mappe (7) — Universal Build Script
# Builds for both Intel (x86_64) and Apple Silicon (arm64)
# Requires: macOS 14+ with Xcode Command Line Tools
# ─────────────────────────────────────────────

APP_NAME="Ny Mappe (7) v2"
EXECUTABLE="NyMappa7"
MIN_MACOS="13.0"

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
    "$SRC_DIR/Models/PathEntry.swift"
    "$SRC_DIR/ViewModels/StashViewModel.swift"
    "$SRC_DIR/Services/StagingService.swift"
    "$SRC_DIR/Services/ThumbnailService.swift"
    "$SRC_DIR/Services/PersistenceService.swift"
    "$SRC_DIR/Services/ScreenshotWatcher.swift"
    "$SRC_DIR/Services/ClipboardWatcher.swift"
    "$SRC_DIR/Views/ContentView.swift"
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

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
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
    <string>3.3</string>
    <key>CFBundleShortVersionString</key>
    <string>3.3</string>
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

echo ""
echo "✅ Build complete!"
echo "   App:           $APP_DIR"
echo "   Architectures: $ARCHS"
echo "   Size:          $SIZE"
echo ""
echo "To run:  open \"$APP_DIR\""
echo "To install: cp -r \"$APP_DIR\" /Applications/"

# Cleanup build artifacts
rm -rf "$BUILD_DIR"
