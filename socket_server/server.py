"""Authoritative websocket server for the TriggerRoyale MVP.

This server intentionally keeps the protocol small and explicit:

- `join`
- `sync_embeddings`
- `set_ready`
- `start_game`
- `shoot`

Every important state change is reflected back to clients through:

- `state`
- `embeddings_sync`
- `event`
- `error`
"""

from __future__ import annotations

import asyncio
import json
import os
from typing import Any

import websockets

HOST = os.getenv("TRIGGER_HOST", "0.0.0.0")
PORT = int(os.getenv("TRIGGER_PORT", "8765"))
MAX_PLAYERS = int(os.getenv("TRIGGER_MAX_PLAYERS", "4"))
SHOT_DAMAGE = int(os.getenv("TRIGGER_DAMAGE", "25"))

players: dict[str, dict[str, Any]] = {}
embedding_registry: dict[str, list[list[float]]] = {}
phase = "lobby"
winner_id: str | None = None


def host_id() -> str | None:
    return next(iter(players), None) if players else None


def alive_player_ids() -> list[str]:
    return [
        player_id
        for player_id, player in players.items()
        if player["alive"]
    ]


def build_state_payload() -> dict[str, Any]:
    return {
        "type": "state",
        "phase": phase,
        "hostId": host_id(),
        "winnerId": winner_id,
        "players": [
            {
                "id": player_id,
                "hp": player["hp"],
                "alive": player["alive"],
                "ready": player["ready"],
                "registered": player["registered"],
            }
            for player_id, player in players.items()
        ],
    }


def build_embeddings_payload() -> dict[str, Any]:
    return {
        "type": "embeddings_sync",
        "registry": embedding_registry,
    }


async def safe_send(ws: Any, payload: dict[str, Any]) -> None:
    try:
        await ws.send(json.dumps(payload))
    except Exception:
        # Closed sockets are cleaned up by the handler's finally block.
        pass


async def broadcast(payload: dict[str, Any]) -> None:
    if not players:
        return

    await asyncio.gather(
        *(safe_send(player["ws"], payload) for player in list(players.values())),
        return_exceptions=True,
    )


async def broadcast_state() -> None:
    await broadcast(build_state_payload())


async def broadcast_embeddings() -> None:
    await broadcast(build_embeddings_payload())


async def broadcast_event(kind: str, message: str, **extra: Any) -> None:
    payload = {"type": "event", "kind": kind, "message": message, **extra}
    await broadcast(payload)


async def send_error(ws: Any, code: str, message: str) -> None:
    await safe_send(
        ws,
        {
            "type": "error",
            "code": code,
            "message": message,
        },
    )


def can_start_game() -> bool:
    return (
        len(players) >= 2
        and all(player["ready"] for player in players.values())
        and all(player["registered"] for player in players.values())
    )


def sync_player_embeddings(username: str, registry_fragment: dict[str, Any]) -> bool:
    embeddings = registry_fragment.get(username)
    if not isinstance(embeddings, list) or not embeddings:
        return False

    cleaned_embeddings: list[list[float]] = []
    for embedding in embeddings:
        if not isinstance(embedding, list) or not embedding:
            continue
        cleaned_embeddings.append([float(value) for value in embedding])

    if not cleaned_embeddings:
        return False

    embedding_registry[username] = cleaned_embeddings
    players[username]["registered"] = True
    return True


def resolve_winner_if_needed() -> str | None:
    global phase
    global winner_id

    alive_ids = alive_player_ids()
    if phase != "in_game" or len(alive_ids) > 1:
        return None

    winner_id = alive_ids[0] if alive_ids else None
    phase = "finished"
    return winner_id


def reset_match_state_if_empty() -> None:
    global phase
    global winner_id

    if players:
        return

    phase = "lobby"
    winner_id = None
    embedding_registry.clear()


async def handle_join(ws: Any, data: dict[str, Any]) -> str | None:
    username = str(data.get("username", "")).strip()
    if len(username) < 3:
        await send_error(ws, "INVALID_USERNAME", "Username must be at least 3 characters.")
        await ws.close()
        return None

    if phase != "lobby":
        await send_error(ws, "MATCH_IN_PROGRESS", "Wait for the current match to finish.")
        await ws.close()
        return None

    if username in players:
        await send_error(ws, "USERNAME_TAKEN", f"Username '{username}' is already in use.")
        await ws.close()
        return None

    if len(players) >= MAX_PLAYERS:
        await send_error(ws, "LOBBY_FULL", f"Lobby already has {MAX_PLAYERS} players.")
        await ws.close()
        return None

    players[username] = {
        "ws": ws,
        "hp": 100,
        "alive": True,
        "ready": False,
        "registered": False,
    }

    await broadcast_state()
    await broadcast_embeddings()
    await broadcast_event("player_joined", f"{username} joined the lobby.", playerId=username)
    return username


async def handle_embedding_sync(ws: Any, username: str | None, data: dict[str, Any]) -> None:
    if username is None or username not in players:
        await send_error(ws, "NOT_JOINED", "Join the lobby before syncing embeddings.")
        return

    registry_fragment = data.get("registry")
    if not isinstance(registry_fragment, dict):
        await send_error(ws, "INVALID_REGISTRY", "Embeddings payload must be a JSON object.")
        return

    if not sync_player_embeddings(username, registry_fragment):
        await send_error(
            ws,
            "INVALID_REGISTRY",
            "Embeddings payload must contain a non-empty list for the local player.",
        )
        return

    await broadcast_embeddings()
    await broadcast_state()
    await broadcast_event(
        "registration_synced",
        f"{username} synced registration embeddings.",
        playerId=username,
    )


async def handle_ready(ws: Any, username: str | None, data: dict[str, Any]) -> None:
    if username is None or username not in players:
        await send_error(ws, "NOT_JOINED", "Join the lobby before changing ready state.")
        return

    requested_ready = bool(data.get("ready", False))
    if requested_ready and not players[username]["registered"]:
        await send_error(
            ws,
            "REGISTRATION_REQUIRED",
            "You must sync embeddings before readying up.",
        )
        return

    players[username]["ready"] = requested_ready
    await broadcast_state()
    await broadcast_event(
        "ready_updated",
        f"{username} is {'ready' if requested_ready else 'not ready'}.",
        playerId=username,
        ready=requested_ready,
    )


async def handle_start_game(ws: Any, username: str | None) -> None:
    global phase
    global winner_id

    if username is None or username not in players:
        await send_error(ws, "NOT_JOINED", "Join the lobby before starting a match.")
        return

    if username != host_id():
        await send_error(ws, "HOST_ONLY", "Only the lobby host can start the match.")
        return

    if not can_start_game():
        await send_error(
            ws,
            "LOBBY_NOT_READY",
            "Need at least 2 ready players with synced embeddings.",
        )
        return

    phase = "in_game"
    winner_id = None
    for player in players.values():
        player["hp"] = 100
        player["alive"] = True

    await broadcast_state()
    await broadcast_event("game_started", "Match started. Weapons hot.")


async def handle_shoot(ws: Any, username: str | None, data: dict[str, Any]) -> None:
    if username is None or username not in players:
        await send_error(ws, "NOT_JOINED", "Join the lobby before shooting.")
        return

    if phase != "in_game":
        await send_error(ws, "MATCH_NOT_ACTIVE", "The match has not started yet.")
        return

    shooter = players[username]
    if not shooter["alive"]:
        await send_error(ws, "ELIMINATED", "Eliminated players cannot shoot.")
        return

    target_id = str(data.get("targetId", "")).strip()
    if not target_id or target_id not in players:
        await send_error(ws, "UNKNOWN_TARGET", "Shot target does not exist.")
        return

    if target_id == username:
        await send_error(ws, "SELF_HIT_BLOCKED", "You cannot shoot yourself.")
        return

    target = players[target_id]
    if not target["alive"]:
        await send_error(ws, "TARGET_ELIMINATED", "Target is already eliminated.")
        return

    confidence = float(data.get("confidence", 0.0))
    target["hp"] = max(0, target["hp"] - SHOT_DAMAGE)
    if target["hp"] == 0:
        target["alive"] = False

    await broadcast_event(
        "shot_resolved",
        f"{username} hit {target_id} for {SHOT_DAMAGE} damage.",
        shooterId=username,
        targetId=target_id,
        confidence=confidence,
        remainingHp=target["hp"],
    )

    if not target["alive"]:
        await broadcast_event(
            "player_eliminated",
            f"{target_id} was eliminated by {username}.",
            playerId=target_id,
            shooterId=username,
        )

    winner = resolve_winner_if_needed()
    await broadcast_state()

    if winner is not None:
        await broadcast_event(
            "game_finished",
            f"{winner} wins the match.",
            winnerId=winner,
        )


async def handle_disconnect(username: str | None) -> None:
    if username is None or username not in players:
        return

    del players[username]
    embedding_registry.pop(username, None)

    resolved_winner = resolve_winner_if_needed()
    await broadcast_state()
    await broadcast_embeddings()
    await broadcast_event("player_left", f"{username} left the lobby.", playerId=username)

    if resolved_winner is not None:
        await broadcast_event(
            "game_finished",
            f"{resolved_winner} wins the match.",
            winnerId=resolved_winner,
        )

    reset_match_state_if_empty()


async def handler(ws: Any) -> None:
    username: str | None = None

    try:
        async for raw_message in ws:
            try:
                data = json.loads(raw_message)
            except json.JSONDecodeError:
                await send_error(ws, "INVALID_JSON", "Message must be valid JSON.")
                continue

            if not isinstance(data, dict):
                await send_error(ws, "INVALID_PAYLOAD", "Message must be a JSON object.")
                continue

            message_type = data.get("type")
            if message_type == "join":
                username = await handle_join(ws, data)
            elif message_type == "sync_embeddings":
                await handle_embedding_sync(ws, username, data)
            elif message_type == "set_ready":
                await handle_ready(ws, username, data)
            elif message_type == "start_game":
                await handle_start_game(ws, username)
            elif message_type == "shoot":
                await handle_shoot(ws, username, data)
            else:
                await send_error(ws, "UNKNOWN_TYPE", f"Unsupported message type: {message_type}")
    finally:
        await handle_disconnect(username)


async def main() -> None:
    print(f"TriggerRoyale server listening on ws://{HOST}:{PORT}")
    async with websockets.serve(handler, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
