# OpenClaw Companion

Flutter companion app for the OpenClaw gateway.

Current scope:

- operator-side gateway session only
- persisted manual endpoint + auth config
- persisted device identity, cached device tokens, and TLS fingerprints
- local Bonjour/mDNS discovery
- first-use TLS trust prompt for `wss://` endpoints
- sessions list, chat history, chat send, live chat/event feed

Node mode is intentionally not included yet.

## Run

```sh
flutter pub get
flutter run -d macos
```

Linux:

```sh
flutter pub get
flutter run -d linux
```

## SDK dependency

The app pulls the Dart SDK directly from GitHub:

```yaml
openclaw_gateway:
  git:
    url: https://github.com/mukhtharcm/openclaw-gateway-dart.git
    ref: main
```

If you want to hack on both locally, switch that dependency to a sibling path:

```yaml
openclaw_gateway:
  path: ../openclaw_gateway
```

## First connect

You can connect in three ways:

1. Paste a setup code JSON or base64 setup code.
2. Enter a manual `ws://` or `wss://` gateway URL.
3. Pick a discovered local gateway from the discovery list.

For `wss://` connections, the app will show a trust prompt the first time it
sees a gateway fingerprint and then pin it for later reconnects.
