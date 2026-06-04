#!/bin/bash
# Arrange windows at startup:
# - WS1 (DP-6, left):           Chrome work profile (all session-restored
#                               work windows go here)
# - DP-6 second workspace:      Chrome personal profile (default width).
#                               Lives on the implicit dynamic workspace right
#                               below WS1 — no named workspace for it.
# - WS2 (DP-4, center):         Alacritty
# - WS3 (DP-5, above center):   Gmail(top)+Calendar(bottom) | Slack | TOKIMEKI | X

# Seconds to wait after the first work Chrome window appears before
# snapshotting — session restore can spawn additional work windows in this
# window of time and they must all be classified as "work".
WORK_CHROME_SETTLE_SECONDS=4

list_chrome_ids() {
    niri msg -j windows | python3 -c "
import json, sys
print(' '.join(str(w['id']) for w in sorted(
    (w for w in json.load(sys.stdin) if w['app_id']=='google-chrome'),
    key=lambda w: w['id']
)))
"
}

wait_for_app() {
    local app_id="$1"
    local index="${2:-0}"
    # Sort by window id ascending so the index reflects creation order — niri's
    # default window list order is not stable, which would otherwise let later-
    # focused windows reorder the matches.
    for i in $(seq 1 60); do
        local wid
        wid=$(niri msg -j windows | python3 -c "
import json,sys
ws=sorted([w for w in json.load(sys.stdin) if w['app_id']=='$app_id'], key=lambda w: w['id'])
if len(ws) > $index: print(ws[$index]['id'])
" 2>/dev/null)
        if [ -n "$wid" ]; then
            echo "$wid"
            return 0
        fi
        sleep 0.5
    done
    return 1
}

move_to_workspace() {
    local wid="$1"
    local ws="$2"
    [ -n "$wid" ] || return
    niri msg action move-window-to-workspace --window-id "$wid" --focus false "$ws"
    sleep 0.2
}

focus() {
    local wid="$1"
    [ -n "$wid" ] || return
    niri msg action focus-window --id "$wid"
    sleep 0.2
}

# === Identify work vs personal Chrome ===
# Both profiles share app-id "google-chrome", so we time-slice instead of
# indexing: wait for the first work window to appear, let session restore
# settle, snapshot every google-chrome id at that point (= work), then launch
# the personal profile ourselves and watch for a window id that is not in the
# snapshot (= personal).
for i in $(seq 1 60); do
    if [ -n "$(list_chrome_ids)" ]; then
        break
    fi
    sleep 0.5
done
sleep "$WORK_CHROME_SETTLE_SECONDS"
work_chrome_ids="$(list_chrome_ids)"

# Launch the personal profile after the snapshot. setsid -f keeps it detached
# from this script's process group so it survives session-layout.sh exiting.
setsid -f google-chrome-stable --profile-directory=Default >/dev/null 2>&1 || true

chrome_default_id=""
for i in $(seq 1 60); do
    chrome_default_id=$(niri msg -j windows | python3 -c "
import json, sys
existing = set('$work_chrome_ids'.split())
new = sorted(
    w['id'] for w in json.load(sys.stdin)
    if w['app_id']=='google-chrome' and str(w['id']) not in existing
)
if new: print(new[0])
" 2>/dev/null)
    if [ -n "$chrome_default_id" ]; then
        break
    fi
    sleep 0.5
done

# Wait for the remaining apps.
alacritty_id=$(wait_for_app "Alacritty")
gmail_id=$(wait_for_app "chrome-fmgjjmmmlfnkbppncabfkddbjimcfncm-Profile_1")
calendar_id=$(wait_for_app "chrome-kjbdgfilnfhdoflbpgamdcdgpehopbep-Profile_1")
slack_id=$(wait_for_app "slack")
tokimeki_id=$(wait_for_app "chrome-oabljfpldnlibhnolagcomejpdljdgda-Default")
x_id=$(wait_for_app "chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default")

sleep 0.5

# Move all work Chrome windows to WS1 (top of DP-6).
for wid in $work_chrome_ids; do
    move_to_workspace "$wid" "WS1"
done
move_to_workspace "$alacritty_id" "WS2"
# Personal Chrome: park it on WS1 first, then push it down to the dynamic
# workspace right below WS1 on DP-6.
move_to_workspace "$chrome_default_id" "WS1"
if [ -n "$chrome_default_id" ]; then
    focus "$chrome_default_id"
    niri msg action move-column-to-workspace-down
    sleep 0.2
fi
move_to_workspace "$gmail_id" "WS3"
move_to_workspace "$calendar_id" "WS3"
move_to_workspace "$slack_id" "WS3"
move_to_workspace "$tokimeki_id" "WS3"
move_to_workspace "$x_id" "WS3"

sleep 0.5

# === WS3: build column order explicitly ===
# Target: [gmail+calendar] | slack | tokimeki | x
#
# Strategy: position from right to left, then merge gmail+calendar.
# After all moves to WS3, columns are in unknown order.
# We anchor gmail at col1 and x at last, then place the rest.

niri msg action focus-workspace "WS3"
sleep 0.3

# Step 1: gmail → col1
focus "$gmail_id"
niri msg action move-column-to-first
sleep 0.2

# Step 2: x → last
focus "$x_id"
niri msg action move-column-to-last
sleep 0.2

# Step 3: tokimeki → second to last (move to last, then left once)
focus "$tokimeki_id"
niri msg action move-column-to-last
sleep 0.2
niri msg action move-column-left
sleep 0.2

# Step 4: slack → third from right (move to last, then left twice)
focus "$slack_id"
niri msg action move-column-to-last
sleep 0.2
niri msg action move-column-left
sleep 0.2
niri msg action move-column-left
sleep 0.2

# Now order: [gmail] | [calendar] | [slack] | [tokimeki] | [x]

# Step 5: calendar → col2 (right of gmail)
focus "$calendar_id"
niri msg action move-column-to-first
sleep 0.2
niri msg action move-column-right
sleep 0.2

# Now order: [gmail] | [calendar] | [slack] | [tokimeki] | [x]

# Step 6: merge - focus gmail and consume calendar from the right
# gmail is alone at col1, calendar is alone at col2
# consume-or-expel-window-right: grabs calendar into gmail's column below gmail ✓
focus "$gmail_id"
niri msg action consume-or-expel-window-right
sleep 0.3

# Final order: [gmail(top)+calendar(bottom)] | [slack] | [tokimeki] | [x]

# === Set column widths ===
[ -n "$gmail_id" ]    && { focus "$gmail_id";    niri msg action set-column-width "50%"; sleep 0.1; }
[ -n "$slack_id" ]    && { focus "$slack_id";    niri msg action set-column-width "33%"; sleep 0.1; }
[ -n "$tokimeki_id" ] && { focus "$tokimeki_id"; niri msg action set-column-width "23%"; sleep 0.1; }
[ -n "$x_id" ]        && { focus "$x_id";        niri msg action set-column-width "23%"; sleep 0.1; }

# Return focus to WS2 (Alacritty)
niri msg action focus-workspace "WS2"
