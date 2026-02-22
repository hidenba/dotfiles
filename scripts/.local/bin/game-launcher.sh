#!/bin/bash
# Run game at HD resolution, upscaled to 4K via gamescope
# -W/-H: output (display) resolution, -w/-h: game render resolution
# -f: fullscreen, -r: refresh rate

gamescope -W 3840 -H 2160 -w 1920 -h 1080 -f -r 144 -- "$@"
