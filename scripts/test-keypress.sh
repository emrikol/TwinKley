#!/bin/bash
#
# test-keypress.sh - Test keypress detection with debug logging
#
# Usage: ./scripts/test-keypress.sh [--auto]
#
# Without flags: Starts TwinKley in debug mode and watches the log.
#                Press physical brightness keys (Fn+F1/F2) to test.
#
# With --auto:   Automatically sends simulated brightness keys via AppleScript.
#
# AppleScript key codes that trigger brightness:
#   key code 145 = Brightness DOWN
#   key code 107 = Brightness UP
#

set -e

echo "=== TwinKley Keypress Test ==="
echo

# Kill any existing instance
pkill -9 -x TwinKley 2>/dev/null || true
sleep 0.3

# Clear debug log
rm -f ~/.twinkley-debug.log

# Start in debug mode
echo "Starting TwinKley in debug mode..."
~/Applications/TwinKley.app/Contents/MacOS/TwinKley --debug &
APP_PID=$!
sleep 2

echo
echo "App started (PID: $APP_PID)"
echo "Debug log: ~/.twinkley-debug.log"
echo
# Cleanup on exit
trap "kill $APP_PID 2>/dev/null; echo 'Stopped.'" EXIT

if [[ "$1" == "--auto" ]]; then
    echo "=== Running automated test ==="
    echo
    echo "Sending brightness DOWN (key code 145)..."
    osascript -e 'tell application "System Events" to key code 145'
    sleep 1

    echo "Sending brightness UP (key code 107)..."
    osascript -e 'tell application "System Events" to key code 107'
    sleep 1

    echo
    echo "=== Debug log ==="
    cat ~/.twinkley-debug.log

    # Kill app
    kill $APP_PID 2>/dev/null
    echo
    echo "Test complete."
else
    echo ">>> Press physical brightness keys (Fn+F1 or Fn+F2) to test <<<"
    echo ">>> Press Ctrl+C to stop watching <<<"
    echo
    echo "=== Watching debug log ==="

    # Watch the log
    tail -f ~/.twinkley-debug.log
fi
