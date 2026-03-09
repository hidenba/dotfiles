#!/bin/sh
# Reset Keyball44 USB device to fix bad enumeration state at boot/resume.
# Uses a flag file to prevent recursive triggering (deauth/auth causes new ADD event).

DEVPATH="$1"
DEVNAME=$(basename "$DEVPATH")
FLAG="/run/keyball44-resetting-$DEVNAME"

# Bail out if already resetting this device (prevents udev loop)
[ -f "$FLAG" ] && exit 0
touch "$FLAG"

sleep 0.8
echo 0 > "/sys${DEVPATH}/authorized"
sleep 0.5
echo 1 > "/sys${DEVPATH}/authorized"

# Keep flag alive briefly so the resulting ADD event is ignored
sleep 2
rm -f "$FLAG"
