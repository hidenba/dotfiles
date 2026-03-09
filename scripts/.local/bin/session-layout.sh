#!/bin/bash
# Arrange windows at startup:
# - WS1 (DP-6, left):         Chrome (full width)
# - WS2 (DP-4, center):       Alacritty
# - WS3 (DP-5, above center): Gmail(top)+Calendar(bottom) | Slack | TOKIMEKI | X

wait_for_app() {
    local app_id="$1"
    for i in $(seq 1 60); do
        local wid
        wid=$(niri msg -j windows | python3 -c "
import json,sys
ws=[w for w in json.load(sys.stdin) if w['app_id']=='$app_id']
if ws: print(ws[0]['id'])
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

# Wait for all apps to launch
chrome_id=$(wait_for_app "google-chrome")
alacritty_id=$(wait_for_app "Alacritty")
gmail_id=$(wait_for_app "chrome-fmgjjmmmlfnkbppncabfkddbjimcfncm-Default")
calendar_id=$(wait_for_app "chrome-kjbdgfilnfhdoflbpgamdcdgpehopbep-Default")
slack_id=$(wait_for_app "Slack")
tokimeki_id=$(wait_for_app "chrome-oabljfpldnlibhnolagcomejpdljdgda-Default")
x_id=$(wait_for_app "chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default")

sleep 0.5

# Move all windows to their workspaces
move_to_workspace "$chrome_id" "WS1"
move_to_workspace "$alacritty_id" "WS2"
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

# === WS1: Chrome full width ===
[ -n "$chrome_id" ] && { focus "$chrome_id"; niri msg action set-column-width "100%"; sleep 0.1; }

# Return focus to WS2 (Alacritty)
niri msg action focus-workspace "WS2"
