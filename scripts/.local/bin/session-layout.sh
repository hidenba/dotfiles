#!/bin/bash
# Arrange windows after startup:
# - WS1: X → Bluesky → Slack (left to right, 1/3 width each)
# - WS2: Alacritty
# - WS3: Chrome | Gmail(top) + Calendar(bottom)

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

# Wait for all apps
x_id=$(wait_for_app "chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default")
bluesky_id=$(wait_for_app "chrome-bfhhgkbefeegpcomnekbgheelhdokijo-Default")
slack_id=$(wait_for_app "Slack")
chrome_id=$(wait_for_app "google-chrome")
gmail_id=$(wait_for_app "chrome-fmgjjmmmlfnkbppncabfkddbjimcfncm-Default")
calendar_id=$(wait_for_app "chrome-kjbdgfilnfhdoflbpgamdcdgpehopbep-Default")
alacritty_id=$(wait_for_app "Alacritty")

sleep 1

# Move windows to their workspaces
move_to_workspace "$x_id" "WS1"
move_to_workspace "$bluesky_id" "WS1"
move_to_workspace "$slack_id" "WS1"
move_to_workspace "$alacritty_id" "WS2"
move_to_workspace "$chrome_id" "WS3"
move_to_workspace "$gmail_id" "WS3"
move_to_workspace "$calendar_id" "WS3"

sleep 0.5

# === WS1: X → Bluesky → Slack ===
if [ -n "$x_id" ] && [ -n "$bluesky_id" ] && [ -n "$slack_id" ]; then
    niri msg action focus-window --id "$x_id"
    sleep 0.2
    niri msg action move-column-to-first
    sleep 0.2
    niri msg action focus-window --id "$slack_id"
    sleep 0.2
    niri msg action move-column-to-last
    sleep 0.2
fi

# === WS3: Chrome(left) | Gmail(top) + Calendar(bottom) ===
if [ -n "$chrome_id" ] && [ -n "$gmail_id" ] && [ -n "$calendar_id" ]; then
    # Chrome to the leftmost
    niri msg action focus-window --id "$chrome_id"
    sleep 0.2
    niri msg action move-column-to-first
    sleep 0.2
    # Gmail next to Chrome
    niri msg action focus-window --id "$gmail_id"
    sleep 0.2
    niri msg action move-column-to-first
    sleep 0.1
    niri msg action move-column-right
    sleep 0.2
    # Calendar to the right end
    niri msg action focus-window --id "$calendar_id"
    sleep 0.2
    niri msg action move-column-to-last
    sleep 0.2
    # Consume Gmail into Calendar's column (Gmail is left of Calendar)
    niri msg action consume-or-expel-window-left
    sleep 0.2
    # Move Gmail up so it's on top
    niri msg action focus-window --id "$gmail_id"
    sleep 0.2
    niri msg action move-window-up
fi
