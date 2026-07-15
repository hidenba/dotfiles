#!/bin/bash
# Forza Horizon 6 wrapper - G923 steering wheel
#
# PROTON_DISABLE_HIDRAW=1: Wine WGI uses SDL/evdev instead of hidraw.
#   hidraw passthrough in pressure-vessel is unreliable; evdev path is stable.
# SDL_JOYSTICK_HIDAPI=0: SDL uses evdev backend, generating an evdev GUID
#   that is NOT in SDL's GameController DB, so G923 stays a raw joystick
#   and WGI exposes it as RawGameController (not Gamepad) to FH6.

export PROTON_DISABLE_HIDRAW=1
export SDL_JOYSTICK_HIDAPI=0

gamescope -W 3840 -H 2160 -w 1920 -h 1080 -f -r 144 -- "$@"
