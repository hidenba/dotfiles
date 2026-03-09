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
    if [ -n "$wid" ]; then
        niri msg action move-window-to-workspace --window-id "$wid" --focus false "$ws"
        sleep 0.2
    fi
}

focus_and_set_width() {
    local wid="$1"
    local width="$2"
    niri msg action focus-window --id "$wid"
    sleep 0.1
    niri msg action set-column-width "$width"
    sleep 0.1
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

# Move to workspaces
move_to_workspace "$chrome_id" "WS1"
move_to_workspace "$alacritty_id" "WS2"
# WS3: move in desired column order (left to right)
move_to_workspace "$gmail_id" "WS3"
move_to_workspace "$calendar_id" "WS3"
move_to_workspace "$slack_id" "WS3"
move_to_workspace "$tokimeki_id" "WS3"
move_to_workspace "$x_id" "WS3"

sleep 0.5

# === WS3: stack Calendar into Gmail's column ===
# After moving, order is: gmail(col1) | calendar(col2) | slack(col3) | tokimeki(col4) | x(col5)
# Focus calendar → consume-or-expel-window-left brings gmail into this column (gmail goes below)
# Then move gmail up so it's on top
if [ -n "$calendar_id" ] && [ -n "$gmail_id" ]; then
    niri msg action focus-window --id "$calendar_id"
    sleep 0.2
    niri msg action consume-or-expel-window-left
    sleep 0.2
    niri msg action focus-window --id "$gmail_id"
    sleep 0.2
    niri msg action move-window-up
    sleep 0.2
fi

# === Set column widths explicitly ===
# WS3 columns (monitor: DP-5, 3840px wide)
[ -n "$gmail_id" ]    && focus_and_set_width "$gmail_id" "50%"
[ -n "$slack_id" ]    && focus_and_set_width "$slack_id" "33%"
[ -n "$tokimeki_id" ] && focus_and_set_width "$tokimeki_id" "23%"
[ -n "$x_id" ]        && focus_and_set_width "$x_id" "23%"

# WS1: Chrome full width
[ -n "$chrome_id" ] && focus_and_set_width "$chrome_id" "100%"

# Return focus to WS2 (Alacritty)
niri msg action focus-workspace "WS2"
