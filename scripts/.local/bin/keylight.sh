#!/bin/bash
KEYLIGHT="http://192.168.1.4:9123/elgato/lights"

get_state() {
    curl -s "$KEYLIGHT" 2>/dev/null
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
        curl -s -X PUT "$KEYLIGHT" -H "Content-Type: application/json" \
            -d "{\"numberOfLights\":1,\"lights\":[{\"on\":$new_on}]}" > /dev/null
        ;;
    brightness-up)
        state=$(get_state)
        br=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin)['lights'][0]['brightness'])")
        new_br=$((br + 10))
        [ "$new_br" -gt 100 ] && new_br=100
        curl -s -X PUT "$KEYLIGHT" -H "Content-Type: application/json" \
            -d "{\"numberOfLights\":1,\"lights\":[{\"brightness\":$new_br}]}" > /dev/null
        ;;
    brightness-down)
        state=$(get_state)
        br=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin)['lights'][0]['brightness'])")
        new_br=$((br - 10))
        [ "$new_br" -lt 3 ] && new_br=3
        curl -s -X PUT "$KEYLIGHT" -H "Content-Type: application/json" \
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
