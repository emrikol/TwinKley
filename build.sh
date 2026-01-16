#!/bin/bash
set -e

# Parse arguments
INSTALL_FLAG=false
RESET_PERMS_FLAG=false
RELEASE_MODE=false
SKIP_CHECKS=false
SIGN_IDENTITY=""  # Auto-detect based on mode

while getopts "irdrs:h-:" opt; do
	case $opt in
		i) INSTALL_FLAG=true ;;
		r) RESET_PERMS_FLAG=true ;;
		d) SKIP_CHECKS=true ;;
		s) SIGN_IDENTITY="$OPTARG" ;;
		-)
			case "$OPTARG" in
				dev) SKIP_CHECKS=true ;;
				release) RELEASE_MODE=true ;;
				*) echo "Unknown option: --$OPTARG" >&2; exit 1 ;;
			esac
			;;
		h)
			echo "Usage: ./build.sh [options]"
			echo ""
			echo "Options:"
			echo "  -i              Install and run after build (kills existing instance)"
			echo "  -r              Reset accessibility permissions"
			echo "  -d, --dev       Skip checks for fast iteration (still runs full checks by default)"
			echo "  --release       Release mode: use Developer ID cert + hardened runtime for notarization"
			echo "  -s IDENTITY     Override signing certificate (default: auto-detect)"
			echo "  -h              Show this help"
			echo ""
			echo "Build modes:"
			echo "  ./build.sh           Normal build (Apple Development, all checks, ~10s)"
			echo "  ./build.sh -d -i     Fast iteration (Apple Development, skip checks, ~3s)"
			echo "  ./build.sh --release Release build (Developer ID, all checks, notarization-ready, ~15s)"
			echo ""
			echo "Certificate auto-detection:"
			echo "  Normal/Dev:  Apple Development > TwinKley Development > ad-hoc"
			echo "  Release:     Developer ID Application"
			echo ""
			echo "Examples:"
			echo "  ./build.sh -d -i                    # Fast dev iteration"
			echo "  ./build.sh -i                       # Normal build with checks"
			echo "  ./build.sh --release                # Prepare for distribution"
			echo ""
			echo "Certificate setup:"
			echo "  • Apple Development: Xcode → Settings → Accounts → Manage Certificates → +"
			echo "  • Developer ID:      Requires Apple Developer Program (\$99/year)"
			echo "  • Self-signed (free): ./scripts/setup-signing.sh"
			exit 0
			;;
		*) exit 1 ;;
	esac
done

# Auto-detect signing identity if not specified
if [ -z "$SIGN_IDENTITY" ]; then
	if [ "$RELEASE_MODE" = true ]; then
		# Release mode: Use Developer ID for notarization
		SIGN_IDENTITY="Developer ID Application: Derrick Tennant (3T9RX85H44)"
	else
		# Normal/dev mode: Try to find best development certificate
		if security find-identity -v -p codesigning | grep -q "Apple Development"; then
			SIGN_IDENTITY="Apple Development"
		elif security find-identity -v -p codesigning | grep -q "TwinKley Development"; then
			SIGN_IDENTITY="TwinKley Development"
		else
			SIGN_IDENTITY="-"  # Ad-hoc signing
			echo "⚠️  No signing certificate found - using ad-hoc (permissions reset each build)"
			echo "   Create one: Xcode → Settings → Accounts → Manage Certificates → + → Apple Development"
			echo ""
		fi
	fi
fi

echo "══════════════════════════════════════════"
if [ "$RELEASE_MODE" = true ]; then
	echo "  ☀️ TwinK[l]ey ⌨️ - Release Build"
elif [ "$SKIP_CHECKS" = true ]; then
	echo "  ☀️ TwinK[l]ey ⌨️ - Fast Build"
else
	echo "  ☀️ TwinK[l]ey ⌨️ - Build"
fi
echo "══════════════════════════════════════════"

cd "$(dirname "$0")"

APP_NAME="TwinKley"
APP_DIR="$HOME/Applications/$APP_NAME.app"
BUNDLE_ID="com.local.$APP_NAME"

if [ "$SKIP_CHECKS" = false ]; then
	# Step 1: Check formatting
	echo ""
	echo "▶ Checking code formatting..."
	if command -v swiftformat &> /dev/null; then
		swiftformat --lint Sources/ Tests/ || {
			echo "❌ Formatting check failed. Run 'swiftformat Sources/ Tests/' to fix."
			exit 1
		}
		echo "  ✓ Formatting OK"
	else
		echo "  ⚠ swiftformat not found (install: brew install swiftformat)"
	fi

	# Step 2: Lint code
	echo ""
	echo "▶ Linting code..."
	if command -v swiftlint &> /dev/null; then
		swiftlint lint --strict Sources/ Tests/ || {
			echo "❌ Linting failed. Fix issues above."
			exit 1
		}
		echo "  ✓ Linting OK"
	else
		echo "  ⚠ swiftlint not found (install: brew install swiftlint)"
	fi

	# Step 3: Run tests (fail fast)
	echo ""
	echo "▶ Running tests..."
	swift test --parallel || {
		echo "❌ Tests failed."
		exit 1
	}
	echo "  ✓ All tests passed"
else
	echo ""
	echo "▶ Skipping checks (use './build.sh' without -d for full checks)"
fi

# Step 4: Build release
echo ""
echo "▶ Building release..."
swift build -c release

# Step 6: Create app bundle structure
echo ""
echo "▶ Creating app bundle..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Step 4: Copy and strip binary (removes debug symbols, ~30% size reduction)
strip -S -x .build/release/$APP_NAME -o "$APP_DIR/Contents/MacOS/$APP_NAME"

BINARY_SIZE=$(ls -lh "$APP_DIR/Contents/MacOS/$APP_NAME" | awk '{print $5}')
echo "  Binary size: $BINARY_SIZE (stripped)"

# Signing happens after all resources are added (see Step 10b below)

# Step 7: Generate and optimize icon
if [ "$SKIP_CHECKS" = true ] && [ -f "$APP_DIR/Contents/Resources/AppIcon.icns" ]; then
	echo ""
	echo "▶ Using existing icon (fast mode - delete to regenerate)"
else
	echo ""
	echo "▶ Generating app icon..."
	ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
	mkdir -p "$ICONSET_DIR"

# Generate icon PNGs using Swift
swift - "$ICONSET_DIR" << 'SWIFT_ICON'
import AppKit
func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    // Solid background (compresses much better than gradient - saves ~300KB)
    let bgRect = CGRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: size * 0.2, cornerHeight: size * 0.2, transform: nil)
    ctx.setFillColor(CGColor(red: 0.15, green: 0.2, blue: 0.4, alpha: 1.0))
    ctx.addPath(bgPath)
    ctx.fillPath()
    let sunX = size * 0.32, sunY = size * 0.5, sunR = size * 0.15
    ctx.setFillColor(CGColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
    ctx.addArc(center: CGPoint(x: sunX, y: sunY), radius: sunR, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    ctx.fillPath()
    ctx.setStrokeColor(CGColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
    ctx.setLineWidth(size * 0.025); ctx.setLineCap(.round)
    for i in 0..<8 { let a = CGFloat(i) * .pi / 4; let r1 = sunR + size * 0.03, r2 = sunR + size * 0.08
        ctx.move(to: CGPoint(x: sunX + cos(a) * r1, y: sunY + sin(a) * r1))
        ctx.addLine(to: CGPoint(x: sunX + cos(a) * r2, y: sunY + sin(a) * r2)) }
    ctx.strokePath()
    ctx.setStrokeColor(CGColor(red: 0.5, green: 0.6, blue: 0.8, alpha: 0.5))
    ctx.setLineWidth(size * 0.015)
    ctx.move(to: CGPoint(x: size * 0.5, y: size * 0.25))
    ctx.addLine(to: CGPoint(x: size * 0.5, y: size * 0.75)); ctx.strokePath()
    let kX = size * 0.68, kY = size * 0.5, kH = size * 0.35, kW = size * 0.22
    ctx.setStrokeColor(CGColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0))
    ctx.setLineWidth(size * 0.05); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: kX - kW * 0.4, y: kY - kH / 2))
    ctx.addLine(to: CGPoint(x: kX - kW * 0.4, y: kY + kH / 2)); ctx.strokePath()
    ctx.move(to: CGPoint(x: kX + kW * 0.5, y: kY - kH / 2))
    ctx.addLine(to: CGPoint(x: kX - kW * 0.4, y: kY))
    ctx.addLine(to: CGPoint(x: kX + kW * 0.5, y: kY + kH / 2)); ctx.strokePath()
    image.unlockFocus(); return image
}
func savePNG(_ img: NSImage, _ path: String, _ size: Int) {
    let r = NSImage(size: NSSize(width: size, height: size)); r.lockFocus()
    img.draw(in: NSRect(x: 0, y: 0, width: size, height: size)); r.unlockFocus()
    guard let t = r.tiffRepresentation, let b = NSBitmapImageRep(data: t),
          let p = b.representation(using: .png, properties: [:]) else { return }
    try? p.write(to: URL(fileURLWithPath: path))
}
let icon = createIcon(size: 512), dir = CommandLine.arguments[1]
// Generate sizes for menu bar utility app (skip 512@2x/1024 - saves ~200KB)
// Sizes: 16, 16@2x, 32, 32@2x, 128, 128@2x, 256, 256@2x (max 512px)
for (name, size) in [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512)
] {
    savePNG(icon, "\(dir)/\(name)", size)
}
SWIFT_ICON

	# Step 8: Measure raw PNG sizes, then optimize
	RAW_PNG_SIZE=$(du -sk "$ICONSET_DIR" | cut -f1)
	ICON_OPTIMIZER="none"

	if command -v pngquant &> /dev/null; then
		echo "▶ Optimizing icons with pngquant..."
		ICON_OPTIMIZER="pngquant"
		for f in "$ICONSET_DIR"/*.png; do
			pngquant --force --quality=50-70 --speed=1 --output "$f" "$f" 2>/dev/null
		done
	elif [ -x "/Applications/ImageOptim.app/Contents/MacOS/ImageOptim" ]; then
		echo "▶ Optimizing icons with ImageOptim..."
		ICON_OPTIMIZER="ImageOptim"
		/Applications/ImageOptim.app/Contents/MacOS/ImageOptim "$ICONSET_DIR"/*.png 2>/dev/null &
		OPTIM_PID=$!
		for i in {1..30}; do
			if ! kill -0 $OPTIM_PID 2>/dev/null; then break; fi
			sleep 1
		done
		kill $OPTIM_PID 2>/dev/null || true
	else
		echo "  (No optimizer found - install pngquant: brew install pngquant)"
	fi

	OPTIMIZED_PNG_SIZE=$(du -sk "$ICONSET_DIR" | cut -f1)

	# Step 9: Build icns
	echo "▶ Building icns..."
	iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
	rm -rf "$(dirname "$ICONSET_DIR")"

	ICON_SIZE=$(ls -lh "$APP_DIR/Contents/Resources/AppIcon.icns" | awk '{print $5}')
	ICON_SIZE_KB=$(wc -c < "$APP_DIR/Contents/Resources/AppIcon.icns" | awk '{print int($1/1024)}')

	# Calculate PNG compression ratio
	if [ "$RAW_PNG_SIZE" -gt 0 ]; then
		PNG_REDUCTION=$((100 - (OPTIMIZED_PNG_SIZE * 100 / RAW_PNG_SIZE)))
	else
		PNG_REDUCTION=0
	fi

	echo "  Icon optimization:"
	echo "    Raw PNGs:      ${RAW_PNG_SIZE}KB"
	echo "    After $ICON_OPTIMIZER: ${OPTIMIZED_PNG_SIZE}KB (${PNG_REDUCTION}% smaller)"
	echo "    Final icns:    ${ICON_SIZE_KB}KB (iconutil re-encodes to 32-bit)"
fi

# Save build stats for audit script
BINARY_SIZE_KB=$(wc -c < "$APP_DIR/Contents/MacOS/$APP_NAME" | awk '{print int($1/1024)}')
UNSTRIPPED_SIZE_KB=$(wc -c < ".build/release/$APP_NAME" | awk '{print int($1/1024)}')

# Get icon stats (may be from existing icon if dev mode skipped regeneration)
if [ -f "$APP_DIR/Contents/Resources/AppIcon.icns" ]; then
	ICON_SIZE_KB=$(wc -c < "$APP_DIR/Contents/Resources/AppIcon.icns" | awk '{print int($1/1024)}')
else
	ICON_SIZE_KB=0
fi

# Set defaults for icon stats if not generated this build
: ${RAW_PNG_SIZE:=0}
: ${OPTIMIZED_PNG_SIZE:=0}
: ${PNG_REDUCTION:=0}
: ${ICON_OPTIMIZER:="cached"}

cat > "$APP_DIR/Contents/Resources/build-stats.json" << STATS_EOF
{
  "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "binary": {
    "unstrippedKB": $UNSTRIPPED_SIZE_KB,
    "strippedKB": $BINARY_SIZE_KB,
    "reductionPercent": $((100 - (BINARY_SIZE_KB * 100 / UNSTRIPPED_SIZE_KB)))
  },
  "icon": {
    "rawPngKB": $RAW_PNG_SIZE,
    "optimizedPngKB": $OPTIMIZED_PNG_SIZE,
    "pngReductionPercent": $PNG_REDUCTION,
    "finalIcnsKB": $ICON_SIZE_KB,
    "optimizer": "$ICON_OPTIMIZER",
    "note": "iconutil re-encodes 8-bit PNGs to 32-bit ARGB, inflating compressed files"
  },
  "optimizations": [
    "Binary stripped with strip -S -x (removes debug symbols)",
    "Solid background color instead of gradient (fewer unique colors)",
    "pngquant lossy compression (8-bit palette)",
    "Skipped 512@2x icon size (menu bar app doesn't need it)"
  ]
}
STATS_EOF

# Step 10: Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>☀️ TwinK[l]ey ⌨️</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSBackgroundOnly</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF

# Step 10b: Sign app bundle (AFTER all resources are added)
echo ""
echo "▶ Signing app bundle..."
if [ "$SIGN_IDENTITY" = "-" ]; then
	# Ad-hoc signing (no hardened runtime)
	codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR" 2>/dev/null
	echo "  Signed: ad-hoc (⚠️  permissions reset each build)"
	echo "  Tip: Create Apple Development cert in Xcode for stable permissions"
else
	# Sign with hardened runtime
	ENTITLEMENTS="TwinKley.entitlements"

	# Determine if we need timestamp (Developer ID only)
	if [[ "$SIGN_IDENTITY" == "Developer ID"* ]]; then
		# Developer ID: Use timestamp for notarization
		codesign --force --deep --options runtime --timestamp \
			--entitlements "$ENTITLEMENTS" \
			--sign "$SIGN_IDENTITY" \
			--identifier "$BUNDLE_ID" \
			"$APP_DIR" 2>/dev/null
		echo "  Signed: $SIGN_IDENTITY"
		echo "  ✓ Hardened runtime enabled (notarization-ready)"
	else
		# Apple Development or self-signed: No timestamp needed
		codesign --force --deep --options runtime \
			--entitlements "$ENTITLEMENTS" \
			--sign "$SIGN_IDENTITY" \
			--identifier "$BUNDLE_ID" \
			"$APP_DIR" 2>/dev/null
		echo "  Signed: $SIGN_IDENTITY"
		echo "  ✓ Permissions persist across rebuilds"
	fi
fi

# Update bundle folder timestamp so Finder shows correct modification time
touch "$APP_DIR"

# Step 11: Create LaunchAgent
echo ""
echo "▶ Creating LaunchAgent..."
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENT_DIR"

cat > "$LAUNCH_AGENT_DIR/$BUNDLE_ID.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_DIR/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

# Done!
echo ""
echo "══════════════════════════════════════════"
echo "  ✓ Build complete!"
echo "══════════════════════════════════════════"
echo ""
echo "  App:         $APP_DIR"
echo "  LaunchAgent: $LAUNCH_AGENT_DIR/$BUNDLE_ID.plist"
echo ""
echo "Commands:"
echo "  Start:       open ~/Applications/$APP_NAME.app"
echo "  Auto-start:  launchctl load ~/Library/LaunchAgents/$BUNDLE_ID.plist"
echo "  Stop auto:   launchctl unload ~/Library/LaunchAgents/$BUNDLE_ID.plist"
echo ""

# Step 12: Install and run (if -i flag)
if [ "$INSTALL_FLAG" = true ]; then
	echo "▶ Installing and launching..."

	# Kill existing instance
	if pgrep -x "$APP_NAME" > /dev/null; then
		echo "  Stopping existing instance..."
		pkill -x "$APP_NAME" || true
		sleep 0.5
	fi

	# Launch the app
	echo "  Launching $APP_NAME..."
	open "$APP_DIR"

	echo ""
	echo "  ✓ $APP_NAME is now running"
fi

# Step 13: Reset Accessibility permissions (if -r flag)
# Note: CGEventTap with .defaultTap requires Accessibility permission
if [ "$RESET_PERMS_FLAG" = true ]; then
	echo ""
	echo "▶ Resetting Accessibility permissions..."
	tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
	echo "  ✓ Permissions reset for $BUNDLE_ID"
	echo ""
	echo "  Opening System Settings > Accessibility..."
	echo "  Please add TwinKley.app from ~/Applications/"
	open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi
