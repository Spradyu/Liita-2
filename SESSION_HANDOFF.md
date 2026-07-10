# Liita — Project State & Handoff

> A snapshot of where the app stands, for the next session. This pairs with
> `CLAUDE.md` (architecture, mesh protocol, crypto, hard constraints, and
> conventions) — read that first. This document covers the current feature
> state, the roadmap, the game system, and how to build and test.

---

## What Liita is

Liita is an **offline, peer-to-peer messaging and gaming app** for nearby
phones, connected over a **Bluetooth Low Energy (BLE) mesh**. No internet,
WiFi, cell signal, or server is involved — phones discover each other over BLE
and relay data device-to-device across the mesh. It's built for environments
where people are physically close but cut off from the internet: flights,
trains, festivals, remote areas.

**Platform:** Android only. Flutter/Dart UI (Riverpod state, GoRouter routing,
SQLite via `sqflite`), with a native **Kotlin** BLE engine bridged over
platform channels. iOS is not started.

---

## Architecture (brief — full detail in `CLAUDE.md`)

Three layers:

1. **Flutter UI** (`lib/features/`) — reactive screens that watch Riverpod
   providers backed by database streams.
2. **The bridge** (`lib/core/services/mesh_service*.dart`) — the Dart↔native
   platform-channel boundary.
3. **Native mesh engine** (`android/.../kotlin/com/liita/liita/`) — runs in an
   Android **foreground service** (survives backgrounding). Each phone
   simultaneously advertises, scans, runs a GATT server, and acts as a GATT
   client — every phone is both sender and receiver.

**Central router:** `lib/core/controllers/app_controller.dart` parses every
incoming `MeshPacket` and dispatches it by payload type to the right handler
(wave, match, chat, lounge, game, photo, etc.).

**Mesh delivery:** controlled flooding with TTL + deduplication. Unicast
payloads (wave / waveAccept / text / game / photo chunks) are delivered
reliably via an app-level acknowledge-and-retransmit layer; broadcast (lounge)
and profile sync are best-effort.

**Crypto:** private chat is end-to-end encrypted (ECDH P-256 handshake →
AES-256-GCM). The public Lounge is intentionally unencrypted (broadcast to
everyone in range). Keys live in secure storage.

---

## Feature state

| Feature | State |
|---|---|
| Radar (peer discovery) | Working |
| Wave / Match (mutual connect) | Working |
| Private chat (E2EE) | Working |
| Lounge (public broadcast) | Working |
| Profile photo sync | Working — a peer's photo transfers over the mesh on match and is cached locally thereafter |
| In-app + system notifications (wave / match) | Working |
| Radar card persistence (waved peers) | Working |
| Tic-Tac-Toe | Working |
| Connect Four | Working |
| Cabin Trivia | Implemented; reliability pass pending |
| Word Chain / Battleship | Placeholder ("Coming Soon") |
| End Flight Session (full local reset + new identity) | Working |
| Clean uninstall (no data restored on reinstall) | Working |
| iOS | Not started |

---

## The game system

Games are peer-to-peer over the mesh. To add or understand a game, the pieces
are (see `CLAUDE.md` for the canonical checklist):

- **`lib/core/models/game_message.dart`** — the `GameType` enum (`ticTacToe`,
  `trivia`, `connectFour`) and `GameMessage` (`gameId`, `gameType`, `type`,
  `payload`). `type` is one of invite / accept / decline / move / question /
  answer / result / end.
- **`lib/core/providers/game_provider.dart`** — each game has its own state
  class + `StateNotifier` (`ticTacToeProvider`, `triviaGameProvider`,
  `connectFourProvider`).
- **`lib/core/controllers/app_controller.dart`** — `_handleGame()` routes by
  `gameType` to `_handleTicTacToe` / `_handleTrivia` / `_handleConnectFour`.
- **Screen** in `lib/features/games/`, **route** in `lib/router.dart` (game
  boards are full-screen routes, outside the tab shell), and an entry in **both**
  game pickers (`games_screen.dart` and `matches_screen.dart`) plus the
  invite-accept handler in `home_shell.dart`.

Turn-based games (Tic-Tac-Toe, Connect Four) send each move to the peer, who
applies it to an identically-ordered board.

---

## Roadmap

1. **Broader edge-case and load testing** of all features on real devices
   (many peers, extended sessions, many packets in flight).
2. **Cabin Trivia reliability.**
3. **More games** (Word Chain, Battleship).
4. **Security / legal compliance** review.
5. **iOS** — a native CoreBluetooth rebuild (the BLE layer is native Android,
   not portable), then feature parity.
6. **Launch prep.**

---

## Build & test

- **Analyze:** `flutter analyze` — expect "No issues found" (a few pre-existing
  SPM plugin infos on build are harmless).
- **Build:** `flutter build apk --release` (or `--debug`) →
  `build/app/outputs/flutter-apk/app-release.apk`.
- **Devices:** real testing needs 2–3 physical Android phones — **BLE does not
  work on emulators**, and `flutter analyze` passing means it compiles, not that
  mesh behavior is correct. Always validate mesh changes on hardware.
- **adb** (Android SDK platform-tools). Package id: `com.liita.app`.
  - Install: `adb -s <serial> install -r <apk>` — note `-r` **keeps app data**
    (it's an in-place update). A real `adb uninstall com.liita.app` (or
    uninstalling from the launcher) wipes it.
  - Launch: `adb -s <serial> shell monkey -p com.liita.app -c android.intent.category.LAUNCHER 1`.
  - Logs: `adb -s <serial> logcat` — native mesh logs are tagged around
    `LiitaBLE`.
- **Background mesh:** the mesh runs in a foreground service with a persistent
  "Liita Mesh Active" notification. Backgrounding (Home) keeps it running (so
  others can still discover you); swiping the app away from Recents stops it.

---

## Conventions

- Match the existing dark neumorphic theming via `AppColors` / `NeuDark`
  (`lib/core/theme/app_theme.dart`). No emoji in the UI.
- Run `flutter analyze` after changes; keep the tree clean.
- Prefer small, surgical diffs over rewrites.
- The native mesh files are load-bearing — change them deliberately and
  re-verify discovery on hardware (see the DO-NOT-BREAK list in `CLAUDE.md`).

---

## Git

- Branch: `main`. Remotes: **`origin`** = `github.com/Spradyu/Liita-2`
  (primary) and **`liita`** = `github.com/liita-og/Liita` (kept in sync).
- `CLAUDE.md` is kept locally and is gitignored (not published).
