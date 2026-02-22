#!/usr/bin/env python3
"""Monitor /dev/video10 consumers and toggle OBS virtual camera via obs-websocket."""

import asyncio
import json
import os
from pathlib import Path

import websockets

DEVICE = "/dev/video10"
OBS_WS_URL = "ws://localhost:4455"
POLL_INTERVAL = 2


def get_consumers():
    """Return PIDs that have DEVICE open, excluding OBS and self."""
    my_pid = os.getpid()
    consumers = set()
    proc = Path("/proc")
    for pid_dir in proc.iterdir():
        if not pid_dir.name.isdigit():
            continue
        pid = int(pid_dir.name)
        if pid == my_pid:
            continue
        try:
            comm = (pid_dir / "comm").read_text().strip()
            if comm in ("obs", "obs-studio", "obs-ffmpeg-mux"):
                continue
        except (OSError, PermissionError):
            continue
        fd_dir = pid_dir / "fd"
        try:
            for fd in fd_dir.iterdir():
                try:
                    if os.readlink(str(fd)) == DEVICE:
                        consumers.add(pid)
                        break
                except (OSError, PermissionError):
                    continue
        except (OSError, PermissionError):
            continue
    return consumers


async def obs_command(request_type):
    """Connect to OBS WebSocket and send a single command."""
    async with websockets.connect(OBS_WS_URL) as ws:
        # Hello (op 0)
        await ws.recv()
        # Identify (op 1)
        await ws.send(json.dumps({"op": 1, "d": {"rpcVersion": 1}}))
        # Identified (op 2)
        await ws.recv()
        # Request (op 6)
        await ws.send(json.dumps({
            "op": 6,
            "d": {"requestType": request_type, "requestId": request_type},
        }))
        resp = json.loads(await ws.recv())
        return resp


async def main():
    was_active = False
    print(f"Monitoring {DEVICE} for consumers...")

    while True:
        consumers = get_consumers()
        is_active = len(consumers) > 0

        if is_active and not was_active:
            print(f"Consumer detected (PIDs: {consumers}), starting virtual camera")
            try:
                await obs_command("StartVirtualCam")
                print("Virtual camera started")
            except Exception as e:
                print(f"Failed to start virtual cam: {e}")

        elif not is_active and was_active:
            print("No consumers, stopping virtual camera")
            try:
                await obs_command("StopVirtualCam")
                print("Virtual camera stopped")
            except Exception as e:
                print(f"Failed to stop virtual cam: {e}")

        was_active = is_active
        await asyncio.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    asyncio.run(main())
