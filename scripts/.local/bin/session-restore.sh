#!/bin/bash
# Restore session: launch apps on specific workspaces

wait_for_window() {
    local app_id="$1"
    local count_before
    count_before=$(niri msg -j windows | python3 -c "import json,sys;print(sum(1 for w in json.load(sys.stdin) if w['app_id']=='$app_id'))" 2>/dev/null)

    for i in $(seq 1 30); do
        local count_now
        count_now=$(niri msg -j windows | python3 -c "import json,sys;print(sum(1 for w in json.load(sys.stdin) if w['app_id']=='$app_id'))" 2>/dev/null)
        if [ "$count_now" -gt "$count_before" ]; then
            return 0
        fi
        sleep 0.5
    done
    return 1
}

move_latest_window() {
    local app_id="$1"
    local workspace="$2"
    local wid
    wid=$(niri msg -j windows | python3 -c "
import json,sys
ws=[w for w in json.load(sys.stdin) if w['app_id']=='$app_id']
if ws: print(ws[-1]['id'])
" 2>/dev/null)
    if [ -n "$wid" ]; then
        niri msg action focus-window --id "$wid"
        niri msg action move-window-to-workspace "$workspace"
    fi
}

sleep 2

# Workspace 1: Chrome + Slack
google-chrome-stable &
wait_for_window "google-chrome"
move_latest_window "google-chrome" 1

slack &
wait_for_window "Slack"
move_latest_window "Slack" 1

# Workspace 2: Chrome + Notion + Alacritty
google-chrome-stable &
wait_for_window "google-chrome"
move_latest_window "google-chrome" 2

notion-app &
wait_for_window "Notion"
move_latest_window "Notion" 2

alacritty &
wait_for_window "Alacritty"
move_latest_window "Alacritty" 2

# Focus workspace 1
niri msg action focus-workspace 1
