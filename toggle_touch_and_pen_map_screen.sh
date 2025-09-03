 
#!/usr/bin/env bash
# Toggle ELAN finger touchscreen + stylus pen between TOP and BOTTOM screens (X11)

set -Eeuo pipefail

# ---- Device name patterns (regex, case-insensitive) ----
TOUCH_PAT='^ELAN9009:00 04F3:2A5A$'
PEN_PATS=(
  '^ELAN9009:00 04F3:2A5A Stylus'   # stylus tool(s)
  '^ELAN9009:00 04F3:2A5A Eraser'   # eraser tool(s), if present
)

# ---- Outputs (names as shown by xrandr) ----
TOP_OUT="eDP"            # 3840x2400+0+0
BOT_OUT="DisplayPort-0"  # 3840x1100+0+2400

# ---- Desktop ratios ----
SY_TOP=0.685714286
TY_TOP=0
SY_BOT=0.314285714
TY_BOT=0.685714286

STATE_FILE="$HOME/.cache/duo-touch-state"
mkdir -p "$(dirname "$STATE_FILE")"
LAST="bottom"; [ -f "$STATE_FILE" ] && LAST="$(cat "$STATE_FILE" 2>/dev/null || echo bottom)"

if [ "$LAST" = "bottom" ]; then
  TARGET="top"; OUT="$TOP_OUT"; SY="$SY_TOP"; TY="$TY_TOP"
else
  TARGET="bottom"; OUT="$BOT_OUT"; SY="$SY_BOT"; TY="$TY_BOT"
fi

notify () {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  else
    printf '%s\n' "$*" >&2
  fi
}

notify "Switching touch + pen to $TARGET ($OUT)…"

# Find the first device whose name matches a regex (case-insensitive).
find_device_by_pat () {
  local pat="$1"
  # xinput --list can print UTF-8 names; use --name-only for clean output.
  xinput --list --name-only \
    | awk -v IGNORECASE=1 -v pat="$pat" 'tolower($0) ~ tolower(pat) {print; exit}'
}

# Apply mapping and calibration if supported.
apply_map () {
  local DEV="$1"
  [ -z "$DEV" ] && return 0
  # Reset libinput calibration if the property exists
  if xinput list-props "$DEV" 2>/dev/null | grep -q "libinput Calibration Matrix"; then
    xinput set-prop "$DEV" "libinput Calibration Matrix" 1 0 0  0 1 0  0 0 1 || true
  fi
  # Map to output (ignore errors if device is floating or already mapped)
  xinput map-to-output "$DEV" "$OUT" 2>/dev/null || true
  # Then apply the coordinate transform
  xinput set-prop "$DEV" "Coordinate Transformation Matrix" \
    1 0 0  0 "$SY" "$TY"  0 0 1 2>/dev/null || true
}

# Background watcher that applies mapping once a device matching PAT appears.
watch_and_map_once () {
  local pat="$1"
  (
    for _ in $(seq 1 600); do   # ~10 minutes @ 1s
      local dev
      dev="$(find_device_by_pat "$pat" || true)"
      if [ -n "${dev:-}" ]; then
        apply_map "$dev"
        notify "Mapped input: $dev → $OUT"
        exit 0
      fi
      sleep 1
    done
    # Timed out quietly; not fatal.
  ) >/dev/null 2>&1 &
  disown
}

# 1) Touchscreen (usually present from login)
TOUCH_DEV="$(find_device_by_pat "$TOUCH_PAT" || true)"
if [ -n "${TOUCH_DEV:-}" ]; then
  apply_map "$TOUCH_DEV"
else
  notify "Touchscreen not found right now; will apply when it shows up."
  watch_and_map_once "$TOUCH_PAT"
fi

# 2) Pen tools (often absent until first hover). Handle all patterns.
any_pen_now=false
for pat in "${PEN_PATS[@]}"; do
  # There can be multiple tools; map each match.
  while IFS= read -r dev; do
    [ -z "$dev" ] && break
    apply_map "$dev"
    any_pen_now=true
  done < <(xinput --list --name-only | awk -v IGNORECASE=1 -v pat="$pat" 'tolower($0) ~ tolower(pat) {print}')
done

# If none found, set watchers so the mapping is applied on first proximity.
if [ "$any_pen_now" = false ]; then
  notify "Pen not detected yet; will auto-map on first hover."
  for pat in "${PEN_PATS[@]}"; do
    watch_and_map_once "$pat"
  done
fi

echo "$TARGET" > "$STATE_FILE"
echo "Done."
