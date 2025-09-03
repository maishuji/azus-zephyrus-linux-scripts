#!/usr/bin/env bash
# File: ~/programs/cycle_screenpad_brightness.sh

BL_DIR="/sys/class/backlight/asus_screenpad"
MAX=$(<"$BL_DIR/max_brightness")        # 235 on your machine
STEP=$(( MAX / 10 ))                    # 10 % per press (change if you like)

# Read current level
CUR=$(<"$BL_DIR/brightness")

if (( CUR > 0 )); then
    # Decrement but never below 0
    NEW=$(( CUR - STEP ))
    (( NEW < 0 )) && NEW=0
else
    # We were at 0 → return to 100 %
    NEW=$MAX
fi

echo "$NEW" | sudo tee "$BL_DIR/brightness" >/dev/null

# Show brightness percentage on screen
PERCENT=$(( NEW * 100 / MAX ))
notify-send "ScreenPad Brightness" "$PERCENT%"
