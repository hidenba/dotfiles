#!/bin/bash
CACHE_FILE="/tmp/keylight-ip"
PORT=9123

resolve_ip() {
    # Try cached IP first
    if [ -f "$CACHE_FILE" ]; then
        local cached_ip
        cached_ip=$(cat "$CACHE_FILE")
        if curl -s --max-time 1 "http://${cached_ip}:${PORT}/elgato/lights" >/dev/null 2>&1; then
            echo "$cached_ip"
            return
        fi
    fi

    # Discover via mDNS (activate avahi-daemon if not running)
    if ! systemctl is-active --quiet avahi-daemon 2>/dev/null; then
        systemctl start avahi-daemon 2>/dev/null
        sleep 1
    fi
    local discovered
    discovered=$(avahi-browse -t -r -p _elg._tcp 2>/dev/null | awk -F';' '/^=.*IPv4/ {print $8; exit}')
    if [ -n "$discovered" ]; then
        echo "$discovered" > "$CACHE_FILE"
        echo "$discovered"
        return
    fi

    # Subnet scan fallback (parallel)
    local subnet base_ip scan_result
    subnet=$(ip route | awk '/scope link/ && /192\.168/ {print $1}' | head -1)
    if [ -n "$subnet" ]; then
        base_ip=$(echo "$subnet" | sed 's/\.[0-9]*\/[0-9]*//')
        scan_result=$(mktemp)
        for i in $(seq 1 254); do
            (
                if curl -s --max-time 0.5 "http://${base_ip}.${i}:${PORT}/elgato/lights" 2>/dev/null | grep -q "lights"; then
                    echo "${base_ip}.${i}" > "$scan_result"
                fi
            ) &
        done
        wait
        if [ -s "$scan_result" ]; then
            local found
            found=$(cat "$scan_result")
            rm -f "$scan_result"
            echo "$found" > "$CACHE_FILE"
            echo "$found"
            return
        fi
        rm -f "$scan_result"
    fi

    return 1
}

get_url() {
    local ip
    ip=$(resolve_ip) || return 1
    echo "http://${ip}:${PORT}/elgato/lights"
}

get_state() {
    local url
    url=$(get_url) || return 1
    curl -s "$url" 2>/dev/null
}

case "$1" in
    toggle)
        state=$(get_state)
        on=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin)['lights'][0]['on'])")
        if [ "$on" = "1" ]; then
            new_on=0
        else
            new_on=1
        fi
        url=$(get_url) || exit 1
        curl -s -X PUT "$url" -H "Content-Type: application/json" \
            -d "{\"numberOfLights\":1,\"lights\":[{\"on\":$new_on}]}" > /dev/null
        ;;
    brightness-up)
        state=$(get_state)
        br=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin)['lights'][0]['brightness'])")
        new_br=$((br + 10))
        [ "$new_br" -gt 100 ] && new_br=100
        url=$(get_url) || exit 1
        curl -s -X PUT "$url" -H "Content-Type: application/json" \
            -d "{\"numberOfLights\":1,\"lights\":[{\"brightness\":$new_br}]}" > /dev/null
        ;;
    brightness-down)
        state=$(get_state)
        br=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin)['lights'][0]['brightness'])")
        new_br=$((br - 10))
        [ "$new_br" -lt 3 ] && new_br=3
        url=$(get_url) || exit 1
        curl -s -X PUT "$url" -H "Content-Type: application/json" \
            -d "{\"numberOfLights\":1,\"lights\":[{\"brightness\":$new_br}]}" > /dev/null
        ;;
    status)
        state=$(get_state)
        if [ -z "$state" ]; then
            echo '{"text":"","tooltip":"Key Light: offline","class":"off"}'
            exit
        fi
        on=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin)['lights'][0]['on'])")
        br=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin)['lights'][0]['brightness'])")
        temp=$(echo "$state" | python3 -c "import json,sys; t=json.load(sys.stdin)['lights'][0]['temperature']; print(round(1000000/t))")
        if [ "$on" = "1" ]; then
            echo "{\"text\":\"${br}%\",\"tooltip\":\"Key Light: ON\\nBrightness: ${br}%\\nColor: ${temp}K\",\"class\":\"on\"}"
        else
            echo "{\"text\":\"OFF\",\"tooltip\":\"Key Light: OFF\",\"class\":\"off\"}"
        fi
        ;;
esac
