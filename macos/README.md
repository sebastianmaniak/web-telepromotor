# Teleprompter Overlay

Native macOS glass teleprompter. Reads `scripts/*.md` from this repo (or any `.md` file) and scrolls SAY / DRAW on a transparent always-on-top overlay.

## Requirements

- macOS 14+
- Xcode CLT / Swift 5.9+

## Test

```bash
cd macos
swift test
```

(`swift test` needs full Xcode for XCTest. Core behavior is also exercised by `swift build`.)

## Run

```bash
cd macos
swift run TeleprompterOverlay
```

A teleprompter icon appears in the menu bar (no Dock tile). Pick a script. Space play/pauses. Mouse move shows the HUD. While playing with the HUD hidden, clicks pass through to the app behind.

If global hotkeys do not work while another app is focused, grant Input Monitoring or Accessibility to the `swift` / `TeleprompterOverlay` binary under System Settings → Privacy & Security.

## Manual QA

1. Overlay is transparent over Safari or OBS.
2. Playing + HUD hidden: clicks reach the app behind.
3. Mouse move or Space shows the HUD; clicks hit the HUD.
4. After ~3s idle while playing, HUD hides and click-through returns.
5. Menu lists `scripts/*.md`; Open file… loads a file outside the repo.
6. SAY is large/white; DRAW is smaller, dim, orange.
7. Esc hides HUD, then hides overlay; menu-bar extra remains.
