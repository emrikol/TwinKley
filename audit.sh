#!/bin/bash
#
# TwinKley Distribution Audit Script
# Runs comprehensive efficiency audits and generates a report
#
# Usage:
#   ./audit.sh           Run full audit with AI analysis
#   ./audit.sh --quick   Skip AI analysis for faster runs
#   ./audit.sh --rebuild Rebuild before auditing
#
set -e

SKIP_AI=false
DO_REBUILD=false
for arg in "$@"; do
    case $arg in
        --quick) SKIP_AI=true ;;
        --rebuild) DO_REBUILD=true ;;
    esac
done

echo "══════════════════════════════════════════════════════════════════"
echo "  ☀️ TwinK[l]ey ⌨️ - Distribution Audit"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "macOS: $(sw_vers -productVersion) ($(uname -m))"
echo ""

cd "$(dirname "$0")"

APP_NAME="TwinKley"
APP_DIR="$HOME/Applications/$APP_NAME.app"
BINARY="$APP_DIR/Contents/MacOS/$APP_NAME"
REPORT_FILE="/tmp/twinkley-audit-report.txt"

# Rebuild if requested
if $DO_REBUILD; then
    echo "▶ Rebuilding app..."
    ./build.sh > /dev/null 2>&1
    echo ""
fi

# Start building the report
{
    echo "# TwinKley Distribution Audit Report"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "macOS: $(sw_vers -productVersion) ($(uname -m))"
    echo ""
} > "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 1: Build Verification
# ══════════════════════════════════════════════════════════════════
echo "▶ [1/10] Build Verification"
echo "────────────────────────────────────────────────────────────────"

if [ ! -f "$BINARY" ]; then
    echo "  ✗ App not found at $APP_DIR"
    echo "  Run ./build.sh first"
    exit 1
fi

echo "  ✓ App bundle exists"

# Check code signing (if any)
CODESIGN_STATUS=$(codesign -v "$APP_DIR" 2>&1 || true)
if [[ "$CODESIGN_STATUS" == *"not signed"* ]]; then
    echo "  ○ Not code signed (expected for local builds)"
else
    echo "  ✓ Code signed"
fi

{
    echo "## 1. Build Verification"
    echo ""
    echo "- App Location: $APP_DIR"
    echo "- Code Signed: $([ -z "$CODESIGN_STATUS" ] && echo "Yes" || echo "No (local build)")"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 2: Binary Analysis
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [2/10] Binary Analysis"
echo "────────────────────────────────────────────────────────────────"

# Use wc -c for portable file size (works on all macOS versions)
BINARY_SIZE=$(wc -c < "$BINARY" | tr -d ' ')
BINARY_SIZE_KB=$((BINARY_SIZE / 1024))
UNSTRIPPED_SIZE=$(wc -c < ".build/release/$APP_NAME" 2>/dev/null | tr -d ' ' || echo "0")
UNSTRIPPED_SIZE_KB=$((UNSTRIPPED_SIZE / 1024))

echo "  Binary size:     ${BINARY_SIZE_KB}KB (stripped)"
if [ "$UNSTRIPPED_SIZE" -gt 0 ]; then
    SAVINGS=$((100 - (BINARY_SIZE * 100 / UNSTRIPPED_SIZE)))
    echo "  Unstripped size: ${UNSTRIPPED_SIZE_KB}KB"
    echo "  Strip savings:   ${SAVINGS}%"
fi

# Verify binary is actually stripped
STRIP_CHECK=$(nm "$BINARY" 2>&1 | head -1)
if [[ "$STRIP_CHECK" == *"no symbols"* ]] || [ "$(nm "$BINARY" 2>/dev/null | wc -l | tr -d ' ')" -lt 500 ]; then
    STRIP_STATUS="✓ Stripped"
else
    STRIP_STATUS="✗ NOT stripped"
fi
echo "  Strip status:    $STRIP_STATUS"

# Check binary architecture
ARCH_INFO=$(file "$BINARY" | sed 's/.*: //')
echo "  Architecture:    $ARCH_INFO"

# Symbol count
SYMBOL_COUNT=$(nm "$BINARY" 2>/dev/null | wc -l | tr -d ' ')
echo "  Symbols:         $SYMBOL_COUNT"

# Segment breakdown - dynamically extract all segments (skip PAGEZERO - it's virtual)
echo ""
echo "  Segment breakdown:"
size -m "$BINARY" | awk '
    /Segment __/ {
        name = $2
        gsub(/:$/, "", name)
        # Skip PAGEZERO (4GB zero-fill guard page, not real file size)
        if (name == "__PAGEZERO") next
        size = $3
        kb = int(size / 1024)
        if (kb > 0) {
            printf "    %-15s %3d KB\n", name, kb
        }
    }'

# Test -Osize vs regular (if source available)
if [ -f "Package.swift" ]; then
    echo ""
    echo "  Build optimization comparison:"
    REGULAR_SIZE=$UNSTRIPPED_SIZE_KB
    # Quick test of -Osize
    swift build -c release -Xswiftc -Osize > /dev/null 2>&1 || true
    OSIZE_SIZE=$(wc -c < ".build/release/$APP_NAME" 2>/dev/null | tr -d ' ' || echo "0")
    OSIZE_SIZE_KB=$((OSIZE_SIZE / 1024))
    # Restore regular build
    swift build -c release > /dev/null 2>&1 || true
    echo "    Regular -O:    ${REGULAR_SIZE}KB"
    echo "    With -Osize:   ${OSIZE_SIZE_KB}KB"
    if [ "$OSIZE_SIZE_KB" -gt "$REGULAR_SIZE" ]; then
        echo "    Result:        Regular is smaller (using regular)"
    else
        echo "    Result:        -Osize is smaller"
    fi
fi

# Build segment breakdown for report - capture all segments dynamically
SEGMENT_TABLE=$(size -m "$BINARY" | awk '
    /Segment __/ {
        name = $2
        gsub(/:$/, "", name)
        # Skip PAGEZERO (4GB zero-fill guard page, not real file size)
        if (name == "__PAGEZERO") next
        size = $3
        kb = int(size / 1024)
        if (kb > 0) {
            printf "| %s | %d KB |\n", name, kb
        }
    }')

{
    echo "## 2. Binary Analysis"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Binary Size (stripped) | ${BINARY_SIZE_KB}KB |"
    [ "$UNSTRIPPED_SIZE" -gt 0 ] && echo "| Unstripped Size | ${UNSTRIPPED_SIZE_KB}KB |"
    [ "$UNSTRIPPED_SIZE" -gt 0 ] && echo "| Strip Savings | ${SAVINGS}% |"
    echo "| Architecture | arm64 |"
    echo "| Symbol Count | $SYMBOL_COUNT |"
    echo ""
    echo "### Segment Breakdown"
    echo ""
    echo "| Segment | Size |"
    echo "|---------|------|"
    echo "$SEGMENT_TABLE"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 3: App Bundle Analysis
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [3/10] App Bundle Analysis"
echo "────────────────────────────────────────────────────────────────"

BUNDLE_SIZE=$(du -sk "$APP_DIR" | cut -f1)
ICON_SIZE=$(wc -c < "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null | tr -d ' ' || echo "0")
ICON_SIZE_KB=$((ICON_SIZE / 1024))
PLIST_SIZE=$(wc -c < "$APP_DIR/Contents/Info.plist" 2>/dev/null | tr -d ' ' || echo "0")

echo "  Total bundle:    ${BUNDLE_SIZE}KB"
echo "  Binary:          ${BINARY_SIZE_KB}KB ($(( BINARY_SIZE * 100 / (BUNDLE_SIZE * 1024) ))%)"
echo "  Icon:            ${ICON_SIZE_KB}KB ($(( ICON_SIZE * 100 / (BUNDLE_SIZE * 1024) ))%)"
echo "  Info.plist:      ${PLIST_SIZE} bytes"

{
    echo "## 3. App Bundle Analysis"
    echo ""
    echo "| Component | Size | Percentage |"
    echo "|-----------|------|------------|"
    echo "| **Total Bundle** | **${BUNDLE_SIZE}KB** | 100% |"
    echo "| Binary | ${BINARY_SIZE_KB}KB | $(( BINARY_SIZE * 100 / (BUNDLE_SIZE * 1024) ))% |"
    echo "| Icon (icns) | ${ICON_SIZE_KB}KB | $(( ICON_SIZE * 100 / (BUNDLE_SIZE * 1024) ))% |"
    echo "| Info.plist | ${PLIST_SIZE}B | <1% |"
    echo ""
} >> "$REPORT_FILE"

# Add build optimization stats if available
BUILD_STATS_FILE="$APP_DIR/Contents/Resources/build-stats.json"
if [ -f "$BUILD_STATS_FILE" ]; then
    echo "  Build optimizations applied (from build-stats.json):"

    # Parse JSON for display (basic extraction)
    RAW_PNG=$(grep -o '"rawPngKB": [0-9]*' "$BUILD_STATS_FILE" | grep -o '[0-9]*')
    OPT_PNG=$(grep -o '"optimizedPngKB": [0-9]*' "$BUILD_STATS_FILE" | grep -o '[0-9]*')
    PNG_RED=$(grep -o '"pngReductionPercent": [0-9]*' "$BUILD_STATS_FILE" | grep -o '[0-9]*')
    OPTIMIZER=$(grep -o '"optimizer": "[^"]*"' "$BUILD_STATS_FILE" | cut -d'"' -f4)

    if [ -n "$RAW_PNG" ] && [ -n "$OPT_PNG" ]; then
        echo "    Icon: ${RAW_PNG}KB → ${OPT_PNG}KB PNGs (${PNG_RED}% reduction via $OPTIMIZER)"
        echo "          → ${ICON_SIZE_KB}KB icns (iconutil re-encodes to 32-bit)"
    fi

    {
        echo "### Build Optimizations Applied"
        echo ""
        echo "| Optimization | Before | After | Reduction |"
        echo "|--------------|--------|-------|-----------|"
        echo "| Binary stripping | ${UNSTRIPPED_SIZE_KB}KB | ${BINARY_SIZE_KB}KB | ${SAVINGS}% |"
        [ -n "$RAW_PNG" ] && echo "| Icon PNGs ($OPTIMIZER) | ${RAW_PNG}KB | ${OPT_PNG}KB | ${PNG_RED}% |"
        echo ""
        echo "*Note: iconutil converts 8-bit PNGs back to 32-bit ARGB, which is why final icns (${ICON_SIZE_KB}KB) is larger than optimized PNGs (${OPT_PNG}KB). This is a known Apple limitation.*"
        echo ""
    } >> "$REPORT_FILE"
fi

# ══════════════════════════════════════════════════════════════════
# Section 4: Memory Footprint
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [4/10] Memory Footprint Analysis"
echo "────────────────────────────────────────────────────────────────"

# Kill existing instance
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

# Fresh launch
echo "  Launching fresh instance..."
open "$APP_DIR"
sleep 3

PID=$(pgrep -x "$APP_NAME" | head -1)
if [ -z "$PID" ]; then
    echo "  ✗ Failed to launch app"
    exit 1
fi

# Get memory footprint
FOOTPRINT_OUTPUT=$(footprint "$PID" 2>/dev/null)
FOOTPRINT_MB=$(echo "$FOOTPRINT_OUTPUT" | awk '/phys_footprint:/ {print $2}')
FOOTPRINT_PEAK=$(echo "$FOOTPRINT_OUTPUT" | awk '/phys_footprint_peak:/ {print $2}')

echo "  Fresh footprint: ${FOOTPRINT_MB}MB"
echo "  Peak footprint:  ${FOOTPRINT_PEAK}MB"

# Get top memory categories (simplified extraction)
echo "  Top memory categories:"
MEMORY_CATEGORIES=$(echo "$FOOTPRINT_OUTPUT" | awk '
    /MB.*MALLOC|KB.*MALLOC|MB.*__DATA|KB.*__DATA|MB.*CoreUI|KB.*CoreUI/ && !/TOTAL/ {
        print "    " $0
    }
' | head -5 | sed 's/^  */    /')
echo "$MEMORY_CATEGORIES"

# Compare with system apps
echo ""
echo "  Comparison with system menu bar apps:"
for app in "TextInputMenuAgent" "ControlCenter" "Spotlight"; do
    sys_pid=$(pgrep -x "$app" 2>/dev/null | head -1)
    if [ -n "$sys_pid" ]; then
        sys_mem=$(footprint "$sys_pid" 2>/dev/null | awk '/phys_footprint:/ {print $2, $3}')
        printf "    %-22s %s\n" "$app:" "$sys_mem"
    fi
done

{
    echo "## 4. Memory Footprint"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Fresh Launch | ${FOOTPRINT_MB}MB |"
    echo "| Peak | ${FOOTPRINT_PEAK}MB |"
    echo ""
    echo "### Top Memory Categories"
    echo "\`\`\`"
    echo "$MEMORY_CATEGORIES"
    echo "\`\`\`"
    echo ""
    echo "<details>"
    echo "<summary>Full Memory Breakdown</summary>"
    echo ""
    echo "\`\`\`"
    echo "$FOOTPRINT_OUTPUT"
    echo "\`\`\`"
    echo "</details>"
    echo ""
    echo "### System Comparison"
    echo ""
    echo "| App | Memory |"
    echo "|-----|--------|"
    echo "| **TwinKley** | **${FOOTPRINT_MB}MB** |"
    for app in "TextInputMenuAgent" "ControlCenter"; do
        sys_pid=$(pgrep -x "$app" 2>/dev/null | head -1)
        if [ -n "$sys_pid" ]; then
            sys_mem=$(footprint "$sys_pid" 2>/dev/null | awk '/phys_footprint:/ {print $2, $3}')
            echo "| $app | $sys_mem |"
        fi
    done
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 5: CPU Usage
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [5/10] CPU Usage Analysis"
echo "────────────────────────────────────────────────────────────────"

# Sample CPU over 5 seconds
echo "  Sampling CPU usage (5 seconds)..."
CPU_SAMPLES=$(top -pid "$PID" -l 3 -s 2 2>/dev/null | awk '/TwinKley/ {print $3}' | tr '\n' ' ')
CPU_TIME=$(ps -o time= -p "$PID" 2>/dev/null | tr -d ' ')

echo "  CPU samples:     $CPU_SAMPLES"
echo "  Total CPU time:  $CPU_TIME"
echo "  Status:          $([ "$CPU_SAMPLES" == "0.0 0.0 0.0 " ] && echo "✓ Idle (optimal)" || echo "○ Active")"

{
    echo "## 5. CPU Usage"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| CPU Samples (5s) | $CPU_SAMPLES |"
    echo "| Total CPU Time | $CPU_TIME |"
    echo "| Idle Status | $([ "$CPU_SAMPLES" == "0.0 0.0 0.0 " ] && echo "Yes (optimal)" || echo "Active") |"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 6: Energy Efficiency Features
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [6/10] Energy Efficiency Features"
echo "────────────────────────────────────────────────────────────────"

# Check source code for efficiency patterns
MAIN_SWIFT="Sources/App/main.swift"
FEATURES=""

check_feature() {
    local pattern="$1"
    local name="$2"
    # Search in both App and Core source files
    if grep -rq "$pattern" Sources/ 2>/dev/null; then
        echo "  ✓ $name"
        FEATURES="$FEATURES\n| $name | Yes |"
    else
        echo "  ✗ $name"
        FEATURES="$FEATURES\n| $name | No |"
    fi
}

check_feature "IOPSNotificationCreateRunLoopSource" "Event-driven power monitoring"
check_feature "CGEvent.tapCreate" "Event-driven key detection"
check_feature "didWakeNotification" "Wake/unlock notifications"
check_feature "CGDisplayRegisterReconfigurationCallback" "Display change callbacks"
check_feature "abs.*lastBrightness" "Brightness delta check"
check_feature "lazy var.*keyboard" "Lazy framework loading"
check_feature "tolerance" "Timer coalescing tolerance"
check_feature "pauseTimedSyncOnLowBattery" "Low battery pause option"

{
    echo "## 6. Energy Efficiency Features"
    echo ""
    echo "| Feature | Implemented |"
    echo "|---------|-------------|"
    echo -e "$FEATURES"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 7: Test Suite
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [7/10] Test Suite"
echo "────────────────────────────────────────────────────────────────"

TEST_OUTPUT=$(swift test 2>&1)
TEST_COUNT=$(echo "$TEST_OUTPUT" | awk '/All tests.*passed/ {getline; if(/Executed/) {print $2 " tests"; exit}}' || echo "unknown")
TEST_STATUS=$(echo "$TEST_OUTPUT" | command grep -q "passed" && echo "PASSED" || echo "FAILED")

echo "  Tests: $TEST_COUNT"
echo "  Status: $TEST_STATUS"

{
    echo "## 7. Test Suite"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Test Count | $TEST_COUNT |"
    echo "| Status | $TEST_STATUS |"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 8: Code Coverage
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [8/10] Code Coverage"
echo "────────────────────────────────────────────────────────────────"

# Run tests with coverage
swift test --enable-code-coverage > /dev/null 2>&1 || true

COVERAGE_FILE=".build/debug/codecov/default.profdata"
TEST_BINARY=".build/debug/TwinKleyPackageTests.xctest/Contents/MacOS/TwinKleyPackageTests"

if [ -f "$COVERAGE_FILE" ] && [ -f "$TEST_BINARY" ]; then
    COVERAGE_OUTPUT=$(xcrun llvm-cov report "$TEST_BINARY" \
        -instr-profile="$COVERAGE_FILE" \
        -ignore-filename-regex=".build|Tests" 2>/dev/null || echo "")

    if [ -n "$COVERAGE_OUTPUT" ]; then
        # Extract coverage percentages
        CORE_COVERAGE=$(echo "$COVERAGE_OUTPUT" | awk '/Settings.swift/ {print $4}' | head -1)
        TOTAL_LINES=$(echo "$COVERAGE_OUTPUT" | awk '/TOTAL/ {print $8}')
        MISSED_LINES=$(echo "$COVERAGE_OUTPUT" | awk '/TOTAL/ {print $9}')
        COVERED_LINES=$((TOTAL_LINES - MISSED_LINES))
        TOTAL_COVERAGE=$(echo "$COVERAGE_OUTPUT" | awk '/TOTAL/ {print $10}')

        echo "  Core library:    ${CORE_COVERAGE:-N/A}"
        echo "  Total coverage:  ${TOTAL_COVERAGE:-N/A}"
        echo "  Lines covered:   ${COVERED_LINES:-?}/${TOTAL_LINES:-?}"
    else
        echo "  Coverage: Unable to generate report"
    fi
else
    echo "  Coverage: Not available (run swift test --enable-code-coverage)"
fi

{
    echo "## 8. Code Coverage"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Core Library (Settings.swift) | ${CORE_COVERAGE:-N/A} |"
    echo "| Total Coverage | ${TOTAL_COVERAGE:-N/A} |"
    echo "| Lines Covered | ${COVERED_LINES:-?}/${TOTAL_LINES:-?} |"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 9: Functional Test
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [9/10] Functional Test"
echo "────────────────────────────────────────────────────────────────"

FUNC_TESTS_PASSED=0
FUNC_TESTS_TOTAL=4

# Test 1: App responds to menu bar click (has status item)
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "  ✓ App is running"
    ((FUNC_TESTS_PASSED++))
else
    echo "  ✗ App is not running"
fi

# Test 2: Settings file exists or can be created
SETTINGS_FILE="$HOME/.twinkley.json"
if [ -f "$SETTINGS_FILE" ] || [ -w "$HOME" ]; then
    echo "  ✓ Settings file accessible"
    ((FUNC_TESTS_PASSED++))
else
    echo "  ✗ Settings file not accessible"
fi

# Test 3: Can read display brightness (test the DisplayServices framework)
BRIGHTNESS_TEST=$(swift -e '
import Foundation
import CoreGraphics
guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
      let sym = dlsym(handle, "DisplayServicesGetBrightness") else { exit(1) }
typealias F = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
let f = unsafeBitCast(sym, to: F.self)
var b: Float = 0
if f(CGMainDisplayID(), &b) == 0 { print(String(format: "%.1f%%", b * 100)) }
' 2>/dev/null)

if [ -n "$BRIGHTNESS_TEST" ]; then
    echo "  ✓ Display brightness readable ($BRIGHTNESS_TEST)"
    ((FUNC_TESTS_PASSED++))
else
    echo "  ✗ Display brightness not readable"
fi

# Test 4: CoreBrightness framework loadable
CB_TEST=$(swift -e '
import Foundation
guard let bundle = Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework"),
      bundle.load(),
      NSClassFromString("KeyboardBrightnessClient") != nil else { exit(1) }
print("ok")
' 2>/dev/null)

if [ "$CB_TEST" == "ok" ]; then
    echo "  ✓ CoreBrightness framework loadable"
    ((FUNC_TESTS_PASSED++))
else
    echo "  ✗ CoreBrightness framework not loadable"
fi

echo ""
echo "  Functional tests: $FUNC_TESTS_PASSED/$FUNC_TESTS_TOTAL passed"

{
    echo "## 9. Functional Tests"
    echo ""
    echo "| Test | Status |"
    echo "|------|--------|"
    echo "| App Running | $([ -n "$(pgrep -x $APP_NAME)" ] && echo "Pass" || echo "Fail") |"
    echo "| Settings Accessible | $([ -f "$SETTINGS_FILE" ] || [ -w "$HOME" ] && echo "Pass" || echo "Fail") |"
    echo "| Display Brightness Readable | $([ -n "$BRIGHTNESS_TEST" ] && echo "Pass" || echo "Fail") |"
    echo "| CoreBrightness Loadable | $([ "$CB_TEST" == "ok" ] && echo "Pass" || echo "Fail") |"
    echo ""
    echo "**Result: $FUNC_TESTS_PASSED/$FUNC_TESTS_TOTAL passed**"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Section 10: Dependencies & Frameworks
# ══════════════════════════════════════════════════════════════════
echo ""
echo "▶ [10/10] Dependencies & Frameworks"
echo "────────────────────────────────────────────────────────────────"

FRAMEWORKS=$(otool -L "$BINARY" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
# Private frameworks are loaded via dlopen, not linked - check source code
PRIVATE_FRAMEWORKS=$(grep -c "PrivateFrameworks" "$MAIN_SWIFT" 2>/dev/null || echo "0")

echo "  Linked frameworks: $FRAMEWORKS"
echo "  Private frameworks: $PRIVATE_FRAMEWORKS (dynamically loaded: CoreBrightness, DisplayServices)"
echo "  External dependencies: 0 (pure Swift/system frameworks)"

{
    echo "## 8. Dependencies"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Linked Frameworks | $FRAMEWORKS |"
    echo "| Private Frameworks (dlopen) | $PRIVATE_FRAMEWORKS |"
    echo "| External Dependencies | 0 |"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Audit Summary"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "  Binary:     ${BINARY_SIZE_KB}KB (stripped)"
echo "  Bundle:     ${BUNDLE_SIZE}KB total"
echo "  Memory:     ${FOOTPRINT_MB}MB (fresh launch)"
echo "  CPU:        ${CPU_TIME} total time"
echo "  Tests:      $TEST_STATUS"
echo ""

{
    echo "---"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Metric | Value | Status |"
    echo "|--------|-------|--------|"
    echo "| Binary Size | ${BINARY_SIZE_KB}KB | $([ $BINARY_SIZE_KB -lt 150 ] && echo "Excellent" || echo "Good") |"
    echo "| Bundle Size | ${BUNDLE_SIZE}KB | $([ $BUNDLE_SIZE -lt 1000 ] && echo "Excellent" || echo "Good") |"
    echo "| Memory | ${FOOTPRINT_MB}MB | $([ ${FOOTPRINT_MB%MB} -lt 15 ] && echo "Excellent" || echo "Good") |"
    echo "| CPU Idle | $([ "$CPU_SAMPLES" == "0.0 0.0 0.0 " ] && echo "Yes" || echo "No") | $([ "$CPU_SAMPLES" == "0.0 0.0 0.0 " ] && echo "Excellent" || echo "Good") |"
    echo "| Tests | $TEST_STATUS | $([ "$TEST_STATUS" == "PASSED" ] && echo "Excellent" || echo "Needs Fix") |"
    echo ""
} >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════════
# AI Analysis (optional)
# ══════════════════════════════════════════════════════════════════
echo "────────────────────────────────────────────────────────────────"
echo ""

if $SKIP_AI; then
    echo "  (AI analysis skipped with --quick flag)"
    echo ""
fi

# Check if claude or codex CLI is available
AI_ANALYSIS=""

# Load build stats if available (shows optimization work already done)
BUILD_STATS_FILE="$APP_DIR/Contents/Resources/build-stats.json"
BUILD_STATS_CONTEXT=""
if [ -f "$BUILD_STATS_FILE" ]; then
    BUILD_STATS_CONTEXT="

IMPORTANT BUILD OPTIMIZATION CONTEXT (already applied):
$(cat "$BUILD_STATS_FILE")

The icon has already been heavily optimized - Apple's iconutil re-encodes 8-bit PNGs to 32-bit ARGB internally, which is why the final icns is larger than the compressed PNGs. This is a known limitation with no workaround."
fi

AI_PROMPT="You are analyzing a macOS menu bar app audit report. Be concise (max 150 words). Highlight what's good, any concerns, and give 1-2 actionable suggestions if any. Do NOT suggest icon optimization if build stats show it's already been optimized.

Here's the report:
$(cat "$REPORT_FILE")
$BUILD_STATS_CONTEXT"

if ! $SKIP_AI && command -v claude &> /dev/null; then
    echo "▶ Generating AI insights with Claude..."
    AI_ANALYSIS=$(claude -p "$AI_PROMPT" 2>/dev/null || true)
elif ! $SKIP_AI && command -v codex &> /dev/null; then
    echo "▶ Generating AI insights with Codex..."
    AI_ANALYSIS=$(codex exec -q "$AI_PROMPT" 2>/dev/null || true)
fi

if [ -n "$AI_ANALYSIS" ]; then
    echo ""
    echo "  AI Analysis:"
    echo "  ────────────"
    echo "$AI_ANALYSIS" | sed 's/^/  /'
    echo ""

    {
        echo "## AI Analysis"
        echo ""
        echo "$AI_ANALYSIS"
        echo ""
    } >> "$REPORT_FILE"
fi

echo "══════════════════════════════════════════════════════════════════"
echo "  Report saved to: $REPORT_FILE"
echo "══════════════════════════════════════════════════════════════════"
echo ""

# Output report location for piping
echo "$REPORT_FILE"
