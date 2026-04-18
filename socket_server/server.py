import asyncio
import websockets
import json
import os
from websockets.exceptions import ConnectionClosed

SHOT_DAMAGE = 25
SERVER_HOST = os.getenv("WS_HOST", "0.0.0.0")
SERVER_PORT = int(os.getenv("WS_PORT", "8765"))

users = {}
match_started = False

async def broadcast():
    msg = json.dumps({
        "type": "users",
        "data": {
            name: {
                "hp": info["hp"],
                "alive": info["alive"],
                "ready" : info["ready"]
            }
            for name, info in users.items()
        }
    })

    await asyncio.gather(*[
        ws.send(msg)
        for ws in [u["ws"] for u in users.values()]
    ])

async def maybe_start_match():
    global match_started

    if not users:
        match_started = False
        return

    everyone_ready = all(info.get("ready", False) for info in users.values())
    if not everyone_ready:
        match_started = False
        return

    if match_started:
        return

    start_msg = json.dumps({
        "type": "start",
        "embeddings": {
            name: info.get("embeddings", [])
            for name, info in users.items()
        }
    })

    match_started = True
    print("all players ready: sending start")
    await asyncio.gather(*[
        ws.send(start_msg)
        for ws in [u["ws"] for u in users.values()]
    ])

def shoot_player(shooter_name, shot_name):
    if shooter_name != shot_name and users[shot_name]["alive"] == True:
        users[shot_name]["hp"] -= SHOT_DAMAGE
        if users[shot_name]["hp"] <= 0:
            kill_player(shot_name)

def kill_player(killed_name):
    users[killed_name]["alive"] = False

async def handler(ws):
    username = None
    
    try:
        async for message in ws:
            data = json.loads(message)

            if data["type"] == "join":
                username = data["username"]

                users[username] = {
                    "ws": ws,
                    "hp": 100,
                    "alive": True,
                    "ready": False,
                    "embeddings": []
                }
                print("joined:", username)
                print("all users:", users.keys())

                await broadcast()

            if data["type"] == "ready":
                username = data["username"]

                users[username]["ready"] = data["ready"]
                print("is ready:", username)
                
                await broadcast()
                await maybe_start_match()

            if data["type"] == "embedding":
                username = data["username"]
                embeddings = data.get("embeddings", [])

                if username in users:
                    users[username]["embeddings"] = embeddings
                    users[username]["ready"] = True
                    print(f"embeddings received: {username}, count={len(embeddings)}")
                    await broadcast()
                    await maybe_start_match()
            
            if data["type"] == "shoot":
                shooter_ws = ws
                target_name = data["user"]

                shooter = None
                for name, d in users.items():
                    if d["ws"] == shooter_ws:
                        shooter = name
                        break

                target_ws = users[target_name]["ws"]

                if target_ws:
                    await target_ws.send(json.dumps({
                        "type": "hit",
                        "from": shooter
                    }))

                    print(f"{target_name} was shot by {shooter}")
                    shoot_player(shooter, target_name)
                    await broadcast()
    except ConnectionClosed as exc:
        user_label = username if username else "unknown-user"
        print(f"connection closed for {user_label}: code={exc.code}, reason={exc.reason}")

    finally:
        global match_started
        if username and username in users:
            print("left:", username)
            del users[username]
            match_started = False

        await broadcast()

async def main():
    print(f"starting websocket server on ws://{SERVER_HOST}:{SERVER_PORT}")
    async with websockets.serve(handler, SERVER_HOST, SERVER_PORT):
        await asyncio.Future()

asyncio.run(main())
