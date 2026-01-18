#!/bin/bash
#
# TwinK[l]ey Sync Mode Benchmark
# Compares energy/CPU/memory usage between Live Sync and Timed Sync modes
#

set -e

# Configuration
APP_NAME="TwinKley"
APP_PATH="$HOME/Applications/TwinKley.app"
SETTINGS_FILE="$HOME/.twinkley.json"
BENCHMARK_DURATION=${1:-300}  # Default 5 minutes (300 seconds)
SAMPLE_INTERVAL=5             # Sample every 5 seconds
REPORT_FILE="/tmp/twinkley-benchmark-$(date +%Y%m%d-%H%M%S).md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  ☀️ TwinK[l]ey ⌨️ - Sync Mode Benchmark${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Duration: ${BENCHMARK_DURATION}s per mode ($(( BENCHMARK_DURATION / 60 )) minutes)"
echo "Sample interval: ${SAMPLE_INTERVAL}s"
echo "Report: $REPORT_FILE"
echo ""

# Backup original settings
backup_settings() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        cp "$SETTINGS_FILE" "${SETTINGS_FILE}.benchmark-backup"
        echo -e "${GREEN}✓${NC} Settings backed up"
    fi
}

# Restore original settings
restore_settings() {
    if [[ -f "${SETTINGS_FILE}.benchmark-backup" ]]; then
        cp "${SETTINGS_FILE}.benchmark-backup" "$SETTINGS_FILE"
        rm "${SETTINGS_FILE}.benchmark-backup"
        echo -e "${GREEN}✓${NC} Settings restored"
    fi
}

# Update settings file
update_settings() {
    local live_sync="$1"
    local timed_sync="$2"

    # Convert bash true/false to Python True/False
    local py_live_sync="True"
    local py_timed_sync="True"
    [[ "$live_sync" == "false" ]] && py_live_sync="False"
    [[ "$timed_sync" == "false" ]] && py_timed_sync="False"

    # Read current settings and update
    if [[ -f "$SETTINGS_FILE" ]]; then
        # Use Python for reliable JSON manipulation
        python3 << EOF
import json
with open('$SETTINGS_FILE', 'r') as f:
    settings = json.load(f)
settings['liveSyncEnabled'] = $py_live_sync
settings['timedSyncEnabled'] = $py_timed_sync
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2, sort_keys=True)
EOF
    else
        # Create new settings file
        cat > "$SETTINGS_FILE" << EOF
{
  "brightnessGamma": 1.5,
  "hasLaunchedBefore": true,
  "liveSyncEnabled": $live_sync,
  "pauseTimedSyncOnBattery": false,
  "pauseTimedSyncOnLowBattery": true,
  "timedSyncEnabled": $timed_sync,
  "timedSyncIntervalMs": 10000
}
EOF
    fi
}

# Restart the app
restart_app() {
    echo -n "  Restarting app... "
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 1
    open "$APP_PATH"
    sleep 3  # Wait for app to fully launch

    if pgrep -x "$APP_NAME" > /dev/null; then
        echo -e "${GREEN}running${NC}"
    else
        echo -e "${RED}failed to start${NC}"
        exit 1
    fi
}

# Get current memory footprint
get_memory() {
    local pid=$(pgrep -x "$APP_NAME")
    if [[ -n "$pid" ]]; then
        # Get physical footprint in KB
        vmmap -summary "$pid" 2>/dev/null | grep "Physical footprint:" | awk '{print $3}' | sed 's/[^0-9.]//g'
    else
        echo "0"
    fi
}

# Get current CPU usage (percentage)
get_cpu() {
    local pid=$(pgrep -x "$APP_NAME")
    if [[ -n "$pid" ]]; then
        ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' '
    else
        echo "0"
    fi
}

# Get CPU time (cumulative)
get_cpu_time() {
    local pid=$(pgrep -x "$APP_NAME")
    if [[ -n "$pid" ]]; then
        ps -p "$pid" -o cputime= 2>/dev/null | tr -d ' '
    else
        echo "0:00.00"
    fi
}

# Convert CPU time string to seconds
cpu_time_to_seconds() {
    local time_str="$1"
    # Format is either M:SS.ss or H:MM:SS.ss
    if [[ "$time_str" =~ ^([0-9]+):([0-9]+)\.([0-9]+)$ ]]; then
        local mins="${BASH_REMATCH[1]}"
        local secs="${BASH_REMATCH[2]}"
        local frac="${BASH_REMATCH[3]}"
        echo "$mins * 60 + $secs + 0.$frac" | bc
    elif [[ "$time_str" =~ ^([0-9]+):([0-9]+):([0-9]+)\.([0-9]+)$ ]]; then
        local hours="${BASH_REMATCH[1]}"
        local mins="${BASH_REMATCH[2]}"
        local secs="${BASH_REMATCH[3]}"
        local frac="${BASH_REMATCH[4]}"
        echo "$hours * 3600 + $mins * 60 + $secs + 0.$frac" | bc
    else
        echo "0"
    fi
}

# Run benchmark for a mode
run_benchmark() {
    local mode_name="$1"
    local live_sync="$2"
    local timed_sync="$3"

    echo ""
    echo -e "${YELLOW}▶ Benchmarking: $mode_name${NC}"
    echo "  Live Sync: $live_sync, Timed Sync: $timed_sync"

    # Update settings and restart
    update_settings "$live_sync" "$timed_sync"
    restart_app

    # Initialize arrays for samples
    local cpu_samples=()
    local mem_samples=()
    local samples_taken=0
    local start_cpu_time=$(get_cpu_time)

    # Progress tracking
    local total_samples=$(( BENCHMARK_DURATION / SAMPLE_INTERVAL ))

    echo -n "  Sampling: "

    # Sample loop
    for (( i=0; i<BENCHMARK_DURATION; i+=SAMPLE_INTERVAL )); do
        local cpu=$(get_cpu)
        local mem=$(get_memory)

        cpu_samples+=("$cpu")
        mem_samples+=("$mem")
        ((samples_taken++))

        # Progress indicator
        local progress=$(( samples_taken * 100 / total_samples ))
        echo -ne "\r  Sampling: ${progress}% (${samples_taken}/${total_samples} samples)"

        sleep "$SAMPLE_INTERVAL"
    done

    local end_cpu_time=$(get_cpu_time)
    echo -e "\r  Sampling: ${GREEN}100%${NC} (${samples_taken} samples collected)     "

    # Calculate statistics
    local cpu_sum=0
    local cpu_max=0
    local cpu_nonzero=0
    for cpu in "${cpu_samples[@]}"; do
        cpu_sum=$(echo "$cpu_sum + $cpu" | bc)
        if (( $(echo "$cpu > $cpu_max" | bc -l) )); then
            cpu_max=$cpu
        fi
        if (( $(echo "$cpu > 0" | bc -l) )); then
            ((cpu_nonzero++))
        fi
    done
    local cpu_avg=$(echo "scale=2; $cpu_sum / ${#cpu_samples[@]}" | bc)

    local mem_sum=0
    local mem_max=0
    local mem_min=999999
    for mem in "${mem_samples[@]}"; do
        mem_sum=$(echo "$mem_sum + $mem" | bc)
        if (( $(echo "$mem > $mem_max" | bc -l) )); then
            mem_max=$mem
        fi
        if (( $(echo "$mem < $mem_min" | bc -l) )); then
            mem_min=$mem
        fi
    done
    local mem_avg=$(echo "scale=1; $mem_sum / ${#mem_samples[@]}" | bc)

    # Calculate CPU time used during benchmark
    local start_secs=$(cpu_time_to_seconds "$start_cpu_time")
    local end_secs=$(cpu_time_to_seconds "$end_cpu_time")
    local cpu_time_used=$(echo "scale=2; $end_secs - $start_secs" | bc)

    # Store results in global variables (bash doesn't have easy return of multiple values)
    eval "${mode_name}_cpu_avg=$cpu_avg"
    eval "${mode_name}_cpu_max=$cpu_max"
    eval "${mode_name}_cpu_nonzero=$cpu_nonzero"
    eval "${mode_name}_cpu_time=$cpu_time_used"
    eval "${mode_name}_mem_avg=$mem_avg"
    eval "${mode_name}_mem_max=$mem_max"
    eval "${mode_name}_mem_min=$mem_min"
    eval "${mode_name}_samples=$samples_taken"

    echo "  Results:"
    echo "    CPU: avg=${cpu_avg}%, max=${cpu_max}%, non-zero samples=${cpu_nonzero}"
    echo "    CPU time used: ${cpu_time_used}s"
    echo "    Memory: avg=${mem_avg}MB, min=${mem_min}MB, max=${mem_max}MB"
}

# Generate report
generate_report() {
    echo ""
    echo -e "${YELLOW}▶ Generating report...${NC}"

    cat > "$REPORT_FILE" << EOF
# TwinK[l]ey Sync Mode Benchmark Report

**Date:** $(date "+%Y-%m-%d %H:%M:%S")
**Duration per mode:** ${BENCHMARK_DURATION}s ($(( BENCHMARK_DURATION / 60 )) minutes)
**Sample interval:** ${SAMPLE_INTERVAL}s
**System:** $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))

## Summary

| Metric | Live Sync Only | Timed Sync (10s) | Difference |
|--------|---------------|------------------|------------|
| Avg CPU | ${LiveSync_cpu_avg}% | ${TimedSync_cpu_avg}% | $(echo "scale=2; ${TimedSync_cpu_avg} - ${LiveSync_cpu_avg}" | bc)% |
| Max CPU | ${LiveSync_cpu_max}% | ${TimedSync_cpu_max}% | $(echo "scale=2; ${TimedSync_cpu_max} - ${LiveSync_cpu_max}" | bc)% |
| CPU Time Used | ${LiveSync_cpu_time}s | ${TimedSync_cpu_time}s | $(echo "scale=2; ${TimedSync_cpu_time} - ${LiveSync_cpu_time}" | bc)s |
| Non-zero CPU Samples | ${LiveSync_cpu_nonzero}/${LiveSync_samples} | ${TimedSync_cpu_nonzero}/${TimedSync_samples} | - |
| Avg Memory | ${LiveSync_mem_avg}MB | ${TimedSync_mem_avg}MB | $(echo "scale=1; ${TimedSync_mem_avg} - ${LiveSync_mem_avg}" | bc)MB |
| Max Memory | ${LiveSync_mem_max}MB | ${TimedSync_mem_max}MB | $(echo "scale=1; ${TimedSync_mem_max} - ${LiveSync_mem_max}" | bc)MB |

## Configuration

**Live Sync Only:**
- \`liveSyncEnabled: true\`
- \`timedSyncEnabled: false\`
- Event-driven, zero polling

**Timed Sync (10s interval):**
- \`liveSyncEnabled: true\`
- \`timedSyncEnabled: true\`
- \`timedSyncIntervalMs: 10000\`
- Polls every 10 seconds as fallback

## 8-Hour Workday Extrapolation

Based on the ${BENCHMARK_DURATION}s benchmark, extrapolated to an 8-hour workday (28,800s):

| Metric | Live Sync Only | Timed Sync (10s) |
|--------|---------------|------------------|
| CPU wake-ups | ~0 | ~2,880 |
| CPU time | ~$(echo "scale=1; ${LiveSync_cpu_time} * 28800 / ${BENCHMARK_DURATION}" | bc)s | ~$(echo "scale=1; ${TimedSync_cpu_time} * 28800 / ${BENCHMARK_DURATION}" | bc)s |
| Timer fires | 0 | 2,880 |

*Note: Timed Sync fires every 10 seconds = 2,880 times over 8 hours*

## Analysis

EOF

    # Add analysis based on results
    local cpu_diff=$(echo "scale=2; ${TimedSync_cpu_time} - ${LiveSync_cpu_time}" | bc)
    local mem_diff=$(echo "scale=1; ${TimedSync_mem_avg} - ${LiveSync_mem_avg}" | bc)
    local extrapolated_cpu_diff=$(echo "scale=1; $cpu_diff * 28800 / ${BENCHMARK_DURATION}" | bc)

    echo "- **CPU Impact:** Over 8 hours, Timed Sync would use ~${extrapolated_cpu_diff}s more CPU time." >> "$REPORT_FILE"

    if (( $(echo "${LiveSync_cpu_nonzero} < ${TimedSync_cpu_nonzero}" | bc -l) )); then
        echo "- **Wake-ups:** Live Sync had ${LiveSync_cpu_nonzero} CPU wake-ups vs ${TimedSync_cpu_nonzero} for Timed Sync during the benchmark." >> "$REPORT_FILE"
    fi

    echo "- **Battery Impact:** Each timer wake-up prevents the CPU from entering deeper sleep states, reducing battery life." >> "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
    echo "## Conclusion" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    echo "**Live Sync Only is recommended** for best battery life. It's truly event-driven with zero polling overhead. Timed Sync adds 2,880 CPU wake-ups per 8-hour workday." >> "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    echo "*Generated by benchmark-sync-modes.sh*" >> "$REPORT_FILE"

    echo -e "${GREEN}✓${NC} Report saved to: $REPORT_FILE"
}

# Cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}▶ Cleaning up...${NC}"
    restore_settings
    restart_app
    echo -e "${GREEN}✓${NC} Benchmark complete"
}

trap cleanup EXIT

# Main
echo -e "${YELLOW}▶ Starting benchmark${NC}"
backup_settings

# Benchmark 1: Live Sync only (event-driven, no polling)
run_benchmark "LiveSync" "true" "false"

# Benchmark 2: Timed Sync enabled (polling every 10s)
run_benchmark "TimedSync" "true" "true"

# Generate report
generate_report

echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Benchmark Complete!${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "View report: cat $REPORT_FILE"
echo ""
