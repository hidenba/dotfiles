#!/bin/bash
# Toggle OBS virtual camera via obs-websocket
python3 -c "
import asyncio, json, hashlib, base64, websockets

PASSWORD = 'UIthosDrGdpRtdqB'

async def toggle():
    async with websockets.connect('ws://localhost:4455') as ws:
        hello = json.loads(await ws.recv())
        auth = hello.get('d', {}).get('authentication')
        if auth:
            challenge = auth['challenge']
            salt = auth['salt']
            secret = base64.b64encode(
                hashlib.sha256((PASSWORD + salt).encode()).digest()
            ).decode()
            auth_string = base64.b64encode(
                hashlib.sha256((secret + challenge).encode()).digest()
            ).decode()
            await ws.send(json.dumps({'op': 1, 'd': {'rpcVersion': 1, 'authentication': auth_string}}))
        else:
            await ws.send(json.dumps({'op': 1, 'd': {'rpcVersion': 1}}))
        await ws.recv()  # Identified
        await ws.send(json.dumps({
            'op': 6,
            'd': {'requestType': 'ToggleVirtualCam', 'requestId': 'toggle'},
        }))
        resp = json.loads(await ws.recv())
        active = resp.get('d', {}).get('responseData', {}).get('outputActive', None)
        print(f'Virtual camera: {\"ON\" if active else \"OFF\"}')

asyncio.run(toggle())
"
