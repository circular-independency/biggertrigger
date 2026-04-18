# TriggerRoyale MVP Documentation

This repository now contains the merged MVP for the project:

- `flutter_app`
  The real player-facing app. It owns the lobby UI, settings UI, registration capture flow, gameplay HUD, websocket client, and the Flutter bridge to the native Android vision module.
- `socket_server`
  The authoritative websocket server. It owns the shared lobby state, ready state, embedding sync distribution, HP updates, eliminations, and winner resolution.
- `TriggerRoyale`
  The original standalone Android vision sandbox where the native Kotlin vision pipeline was developed and validated before integration.

The working gameplay loop is:

1. players join the shared lobby
2. each player captures registration photos
3. the local device generates embeddings with the native Android vision module
4. embeddings are uploaded to the websocket server
5. the server broadcasts the full embedding registry back to all players
6. every device imports the same registry into its local native matcher
7. the host starts the match
8. each phone shows the native camera preview inside Flutter
9. pressing `FIRE` runs the native `shoot()` pipeline
10. a hit result is sent to the server
11. the server updates HP, eliminations, and winner state for everyone in real time

## High-level architecture

### Flutter app

Important files:

- `flutter_app/lib/logic/game_session_controller.dart`
  Single source of truth for the app session. Owns websocket lifecycle, authoritative state mirroring, embedding sync, preview lifecycle, and `shoot()` calls.
- `flutter_app/lib/logic/socket_manager.dart`
  Thin websocket transport wrapper.
- `flutter_app/lib/logic/vision_bridge.dart`
  Method-channel wrapper around the Android vision module.
- `flutter_app/lib/pages/lobby_page.dart`
  Dynamic lobby UI connected to the server and registration flow.
- `flutter_app/lib/pages/registration_page.dart`
  Captures 3 registration images using Flutter camera.
- `flutter_app/lib/pages/game_page.dart`
  Uses the native Android texture preview, shows HUD/roster, and sends shots.
- `flutter_app/lib/pages/settings_page.dart`
  Stores username and server URL in shared preferences.

### Native Android vision integration

The Flutter Android host now vendors the native vision module directly under:

- `flutter_app/android/app/src/main/kotlin/com/example/triggerroyale`

The plugin is registered from:

- `flutter_app/android/app/src/main/kotlin/com/example/flutter_app/MainActivity.kt`

Important native behavior:

- `VisionFlutterPlugin` exposes the method channel `com.yourteam.visionmodule/vision`
- `startPreview` returns a Flutter texture id
- `registerPlayer` accepts JPEG bytes from Flutter registration capture
- `shoot` runs the native detect -> crop -> embed -> match pipeline
- embeddings live in native memory and are replaced with the authoritative server registry when sync messages arrive

Native assets required by the plugin are included in:

- `flutter_app/android/app/src/main/assets/efficientdet_lite0.tflite`
- `flutter_app/android/app/src/main/assets/mobilenet_v3_small.tflite`

### Websocket server

Important files:

- `socket_server/server.py`
  Authoritative server for a single shared lobby
- `socket_server/requirements.txt`
  Python dependency list

Protocol summary:

- Client -> Server:
  - `join`
  - `sync_embeddings`
  - `set_ready`
  - `start_game`
  - `shoot`
- Server -> Client:
  - `state`
  - `embeddings_sync`
  - `event`
  - `error`

The server is authoritative for:

- who is in the lobby
- who is host
- who is ready
- which players have synced embeddings
- current match phase
- HP and alive state
- eliminations
- winner resolution

## Lobby and match rules

Current MVP rules:

- one websocket server instance == one shared lobby
- maximum players: 4
- minimum players to start: 2
- only the host can start the match
- every connected player must be:
  - registered
  - ready
- players cannot join while a match is already running
- shot damage is fixed at `25`
- HP starts at `100`
- first match flow is the main supported path

## Embedding sync behavior

This is the critical part of the merged MVP.

When a player finishes registration:

1. Flutter captures 3 JPEG images
2. Flutter sends those bytes to native `registerPlayer`
3. native vision generates embeddings for that player
4. Flutter exports that player’s embeddings from native memory
5. Flutter sends that registry fragment to the websocket server
6. the server stores it and broadcasts the full registry to everyone
7. every client clears native registrations and imports the full registry snapshot

That guarantees every device uses the same embedding registry before and during the match.

## Local development setup

### 1. Python server

From the repo root:

```powershell
cd socket_server
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python server.py
```

Default server address:

- `ws://0.0.0.0:8765`

Environment variables:

- `TRIGGER_HOST`
- `TRIGGER_PORT`
- `TRIGGER_MAX_PLAYERS`
- `TRIGGER_DAMAGE`

### 2. Flutter app

Open `flutter_app`.

If building from source, you need a valid Flutter SDK installation and a generated:

- `flutter_app/android/local.properties`

with a valid:

- `flutter.sdk=...`

The Android app also requires the normal Android SDK configuration.

Important Android integration details already handled in code:

- minSdk lowered to `26`
- native model assets bundled into Flutter Android app
- CameraX + MediaPipe dependencies added to Flutter Android host
- custom native plugin registered from `MainActivity`

## How 4 people can download and play this game

This is the intended playtest flow.

### Before the session

1. One person acts as the host computer operator.
2. That person runs `socket_server/server.py` on a laptop connected to the same Wi‑Fi network as the phones.
3. Find the laptop’s LAN IP address.
   Example: `192.168.1.20`
4. Build the Android APK from `flutter_app` and share the same APK with all 4 players.
5. Install the APK on all 4 Android phones.

### On every phone

1. Open the app.
2. Go to `SETTINGS`.
3. Enter a unique username.
4. Enter the websocket server URL using the host laptop’s LAN IP.
   Example: `ws://192.168.1.20:8765`
5. Save settings.

### Joining the lobby

1. Each player taps `DEPLOY`.
2. All 4 players should appear in the same lobby.
3. The first player who joined becomes the host.

### Registration

Each player must complete registration before the match starts.

1. Tap `CAPTURE & READY`.
2. Another player helps by aiming the phone’s back camera at the registering player.
3. Capture 3 clear full-body shots.
4. Tap `SYNC PLAYER`.
5. Wait for the lobby to show that the player is registered/ready.

Repeat until all 4 players are ready.

### Starting the match

1. Once everyone is ready, the host sees `START MATCH`.
2. The host taps `START MATCH`.
3. All devices transition into the gameplay screen.

### During the match

1. Aim the crosshair at another player.
2. Tap `FIRE`.
3. The native Android vision module identifies the target locally.
4. A successful target id is sent to the server.
5. The server updates HP for everybody.
6. When a player reaches `0 HP`, they are eliminated.
7. When only one player remains alive, the server declares the winner.

## Known MVP limitations

- Android is the intended target platform for the merged app.
- There is currently only one shared lobby per server.
- Players cannot join a match already in progress.
- Registration capture is manual and assumes another player helps take the 3 photos.
- Matching quality depends heavily on lighting, framing, and registration image quality.
- This is an MVP focused on correctness of the loop, not perfect recognition accuracy.

## Verification status

Verified in this workspace:

- `socket_server/server.py` passes `python -m py_compile`
- the native standalone Android vision project in `TriggerRoyale` had already been building before this merge step

Not fully verified in this workspace:

- full Flutter build / test run

Reason:

- there is no confirmed Flutter SDK path available in this workspace right now, so the generated Flutter Android project cannot be built here until `flutter.sdk` is configured locally

## Recommended next checks

Once a Flutter SDK is available on the machine:

1. run `flutter pub get` inside `flutter_app`
2. run `flutter test`
3. run `flutter build apk` or `flutter run`
4. start the Python server
5. test with 2 phones first
6. then do a full 4-player LAN playtest
