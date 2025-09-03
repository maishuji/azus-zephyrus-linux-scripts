#!/usr/bin/env bash
# File: ~/programs/cycle_screenpad_brightness.sh

BL_DIR="/sys/class/backlight/asus_screenpad"
MAX=$(<"$BL_DIR/max_brightness")        # Maximum brightness value
STEP=$(( MAX / 10 ))                     # Adjust brightness by 10% per step

# Read current brightness
CUR=$(<"$BL_DIR/brightness")

# Check argument
if [[ $# -ne 1 || ( "$1" != "up" && "$1" != "down" ) ]]; then
    echo "Usage: $0 {up|down}"
    exit 1
fi

NEW=$CUR

if [[ "$1" == "up" ]]; then
    # Increase brightness but do not exceed MAX
    NEW=$(( CUR + STEP ))
    (( NEW > MAX )) && NEW=$MAX
elif [[ "$1" == "down" ]]; then
    # Decrease brightness but do not go below 0
    NEW=$(( CUR - STEP ))
    (( NEW < 0 )) && NEW=0
fi

# Apply new brightness
echo "$NEW" | sudo tee "$BL_DIR/brightness" >/dev/null

# Show brightness percentage
PERCENT=$(( NEW * 100 / MAX ))
notify-send "ScreenPad Brightness" "$PERCENT%"
