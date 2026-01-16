#!/bin/bash
#
# test-gamma.sh - Test brightness sync across full range
#
# Uses feedback loop: keep pressing until we hit target, with max attempts as failsafe.
#

set -e

MAX_ATTEMPTS=50
DELAY=0.3

# Get current display brightness from log
get_brightness() {
    grep "Sync:" ~/.twinkley-debug.log | tail -1 | sed 's/.*display=\([0-9.]*\).*/\1/'
}

# Press key until brightness reaches target (or max attempts)
# Args: key_code target_check direction_name
press_until() {
    local key_code=$1
    local target=$2
    local direction=$3
    local attempts=0
    local current

    while [ $attempts -lt $MAX_ATTEMPTS ]; do
        osascript -e "tell application \"System Events\" to key code $key_code" 2>/dev/null
        sleep $DELAY
        current=$(get_brightness)
        attempts=$((attempts + 1))

        # Check if we hit target (≤0.0625 for min, ≥0.9375 for max - will be snapped to 0/1)
        if [ "$target" = "min" ] && [ "$(echo "$current <= 0.0625" | bc)" -eq 1 ]; then
            echo "        Hit minimum ($current) after $attempts presses"
            return 0
        elif [ "$target" = "max" ] && [ "$(echo "$current >= 0.9375" | bc)" -eq 1 ]; then
            echo "        Hit maximum ($current) after $attempts presses"
            return 0
        fi
    done
    echo "        Stopped at $current after $attempts presses (max reached)"
    return 1
}

echo "=== TwinKley Gamma Test ==="
echo

# Ensure app is running in debug mode
pkill -9 -x TwinKley 2>/dev/null || true
sleep 0.5
rm -f ~/.twinkley-debug.log
~/Applications/TwinKley.app/Contents/MacOS/TwinKley --debug &
APP_PID=$!
sleep 2

cleanup() {
    kill $APP_PID 2>/dev/null || true
    echo "App stopped."
}
trap cleanup EXIT

# Get initial brightness
INITIAL=$(get_brightness)
echo "Initial display brightness: $INITIAL"
echo

echo "Step 1: Going to MINIMUM..."
press_until 145 min "down"
echo "        Log: $(grep 'Sync:' ~/.twinkley-debug.log | tail -1)"
echo

echo "Step 2: Going to MAXIMUM..."
press_until 144 max "up"
echo "        Log: $(grep 'Sync:' ~/.twinkley-debug.log | tail -1)"
echo

# Return to initial: from max (1.0), go down to closest step
STEPS_DOWN=$(echo "scale=0; (1.0 - $INITIAL) / 0.0625" | bc)
echo "Step 3: Returning to ~$INITIAL ($STEPS_DOWN steps down)..."
for i in $(seq 1 $STEPS_DOWN); do
    osascript -e 'tell application "System Events" to key code 145' 2>/dev/null
    sleep $DELAY
done
sleep 0.5
echo "        Restored: $(grep 'Sync:' ~/.twinkley-debug.log | tail -1)"
echo

echo "=== Summary ==="
echo "Snapped entries:"
grep "snapped" ~/.twinkley-debug.log || echo "  (none)"
echo
echo "Min display: $(grep 'Sync:' ~/.twinkley-debug.log | sed 's/.*display=\([0-9.]*\).*/\1/' | sort -n | head -1)"
echo "Max display: $(grep 'Sync:' ~/.twinkley-debug.log | sed 's/.*display=\([0-9.]*\).*/\1/' | sort -n | tail -1)"
echo
echo "Log: ~/.twinkley-debug.log"
