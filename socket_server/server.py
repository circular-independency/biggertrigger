import asyncio
import websockets
import json

SHOT_DAMAGE = 25

users = {}

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
                    "ready": False
                }
                print("joined:", username)
                print("all users:", users.keys())

                await broadcast()
            
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

    finally:
        if username and username in users:
            print("left:", username)
            del users[username]

        await broadcast()

async def main():
    async with websockets.serve(handler, "localhost", 8765):
        await asyncio.Future()

asyncio.run(main())