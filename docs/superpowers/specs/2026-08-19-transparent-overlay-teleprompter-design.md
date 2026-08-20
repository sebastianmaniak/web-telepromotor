# Transparent Overlay Teleprompter — Design Spec

## Overview

A native macOS overlay that turns the markdown files in this repo’s `scripts/` folder (or any `.md` file on disk) into a full-screen, always-on-top, see-through teleprompter.

The presenter looks through the glass at a camera or lightboard. Spoken lines (`SAY`) are large white scrolling text. Production cues (`DRAW` and bracketed stage directions) are smaller, dimmer, and accent-colored. While playing, mouse clicks pass through to OBS, the camera app, or anything behind. Moving the mouse or pressing a hotkey reveals a compact HUD; after three seconds idle while playing, the HUD hides and click-through returns.

This is a desktop companion to the existing GitHub Pages teleprompter. The web app stays as-is for phones, tablets, and the Supabase remote. The overlay does not fetch GitHub, does not use Supabase, and does not talk to `remote.html`.

Minimum OS: macOS 14 Sonoma. Personal tool — not App Store sandboxed.

## Product decisions

| Decision | Choice |
|---|---|
| Window | Full-screen transparent overlay, always on top |
| Click-through | Hybrid: through while playing + HUD hidden; interactive when HUD is up |
| Script rendering | SAY large; DRAW / stage directions smaller and quieter |
| Script sources | `scripts/` list by default, plus Open file… |
| Stack | Native Swift / SwiftUI + AppKit window |
| Scope vs web app | Separate binary; no shared runtime |

## Screens

### 1. Menu bar extra

A small teleprompter icon in the menu bar. The app is a menu-bar extra: no Dock tile while running, no main window besides the overlay.

Clicking the icon shows:

- List of `.md` files from the resolved `scripts/` folder. Each row: display name (filename without `.md`, hyphens/underscores to spaces, title-cased), word count of spoken (`say`) text only.
- **Open file…** — standard open panel, `.md` files.
- **Start** / **Pause** — enabled when a script is loaded. If the overlay is hidden and a script is loaded, this is **Show overlay**.
- **Timer** — duration in 30-second steps, range 0:30–30:00, default 5:00. Same role as the web app: informational, not a hard stop.
- **Choose scripts folder…** — used when the app is not running from this repo and there is no saved folder bookmark.
- Quit.

Picking a script loads it and shows the overlay with the HUD visible (not yet playing).

### 2. Overlay (playing, HUD hidden)

Borderless, shadowless, full-screen on **one** display: the screen that contained the mouse cursor when the overlay was shown. Clear background. Does not appear in the Dock or as a normal Cmd-Tab app while the HUD is hidden.

- **SAY** — large white text, centered, scrolling upward.
- **DRAW / stage directions** — smaller, lower opacity, orange accent (`#ff6b00`, matching the lightboard notes).
- **Segment titles** (`## …`) — tiny labels above the blocks they belong to.
- Preamble, production-notes section, and non-action bracket notes are not shown.
- Red reading line at 33% from the top of the screen.
- Soft fade above and below the line so the current region is the readable one.
- Timer and progress live only in the HUD, so they do not sit on the recording.

Mouse clicks pass through. Global hotkeys still work while the overlay is visible.

### 3. Control HUD (interactive)

A compact bar at the bottom of the overlay:

- Play / pause
- Restart (scroll and timer back to zero)
- Speed (WPM)
- Font size
- Progress %
- Timer remaining
- Script name
- Close overlay (hides the glass, does not quit the menu-bar app)

While the HUD is up, the overlay consumes mouse events. If playing, 3 seconds with no mouse or key activity hides the HUD and restores click-through. Pause keeps the HUD up.

## Hotkeys

Registered only while the overlay is visible. Unregistered when the overlay is hidden so Space is not stolen from other apps.

| Key | Action |
|---|---|
| Space | Play / pause |
| ↑ / ↓ | Speed ±10 WPM (clamp 50–400) |
| + / − | Font size ±2 px (clamp 20–64) |
| R | Restart |
| Esc | Hide HUD if visible; if HUD already hidden, hide overlay |

Mouse move (global monitor) also reveals the HUD.

## Architecture

SwiftUI draws the glass. AppKit owns the window — SwiftUI cannot do a real transparent, always-on-top, click-through overlay.

Code lives in this repo under `macos/`. The existing web app (`index.html`, `js/`, `css/`) is untouched.

```
macos/
  TeleprompterOverlay/
    App                  # Menu-bar extra, no Dock tile
    OverlayWindow        # NSWindow: transparent, always-on-top, click-through
    OverlayView          # SAY / DRAW / fades / guide line
    ControlHUD           # Bottom bar
    TeleprompterEngine   # Play/pause, WPM → px/s, scroll, timer
    ScriptParser         # .md → [Block]
    ScriptStore          # scripts/ listing, open panel, bookmarks
    Hotkeys              # Register/unregister while overlay visible
```

| Piece | Does | Depends on |
|---|---|---|
| `OverlayWindow` | Borderless clear `NSWindow`, `level = .floating`, `collectionBehavior` includes `.canJoinAllSpaces` and `.fullScreenAuxiliary`, `hasShadow = false`, `ignoresMouseEvents` toggled with HUD | AppKit |
| `TeleprompterEngine` | Display-link tick, WPM math, clamp at end, timer | None |
| `ScriptParser` | Bytes → `[Block]` | None |
| `ScriptStore` | Folder listing, security-scoped bookmark, open panel | Foundation |
| `OverlayView` | Renders blocks + fades + guide | Engine + parser types |
| `ControlHUD` | Controls bound to engine | Engine |
| `Hotkeys` | Carbon/AppKit hotkeys + global mouse-move monitor | OverlayWindow |

Window flags:

- `isOpaque = false`, `backgroundColor = .clear`
- `styleMask = [.borderless, .fullSizeContentView]`
- `isMovableByWindowBackground = false`
- Nonactivating so showing the overlay does not steal focus from OBS or the camera app
- While playing and HUD hidden: `ignoresMouseEvents = true`
- HUD visible: `ignoresMouseEvents = false`

The overlay is pinned to a single display. Unplugging that display moves it to the main display.

## Script parser

Input: UTF-8 markdown. Output: ordered `[Block]`.

```text
enum Block {
  segment(title: String)
  say(text: String)
  draw(text: String)
}
```

### Format A — labeled lightboard (`agent-registry.md`)

1. Drop everything before the first `##` heading (title, target runtime, “Production notes (read first)”).
2. `##` headings become `segment(title)`. Horizontal rules (`---`) are ignored.
3. A line matching `**DRAW…**` starts a `draw` block that runs until the next `**SAY:**`, `**DRAW…**`, or heading. Keep the location prefix (`DRAW (left third):`).
4. `**SAY:**` starts spoken text until the next DRAW, heading, or EOF. Blank lines split `say` paragraphs.
5. Strip remaining markdown to plain text: `**bold**` / `__bold__`, `*italic*` / `_italic_`, `[label](url)` keeps `label`, backticks dropped, list markers dropped.

### Format B — bracket stage directions (`virtual-mcp.md`)

Used when the file has **no** `**SAY:**` / `**DRAW:**` markers.

- A paragraph that is entirely `[…]` and whose first word is an action (`Draw`, `Write`, `Tap`, `Circle`, `Erase`, `Point`, `Underline`, `Label`, and case-insensitive variants) → `draw`, brackets removed.
- A paragraph that is entirely `[…]` but is not an action (cold-open notes, “Standard opener”) → dropped.
- All other paragraphs → `say`, markdown stripped as in Format A.
- Lines like `Panel 1 — the problem` that are not headings and not brackets → `say`.

### Format C — plain script (`example.md`)

No `**SAY:**` / `**DRAW:**` and no action brackets: the whole body after optional `#` title line is `say` paragraphs split on blank lines. Matches the current web teleprompter.

A file that parses to zero `say` and zero `draw` blocks is an error (see Error handling). Overlay does not open.

Word count for the menu is the word count of `say` blocks only.

## Data flow

1. **Launch** — menu-bar extra only. Overlay off. `ScriptStore` resolves the scripts folder (see Script store) and lists `*.md`.
2. **Pick a script** (menu or Open file…) — read file → parse → engine reset (scroll 0, timer = duration). Overlay shown, HUD visible, click-through off, not playing.
3. **Play** — display-link ticks. WPM converts to pixels/second using the same model as `js/teleprompter.js`: average word length 5, line height = fontSize × 1.7, characters per line from viewport width / (fontSize × 0.5), then lines per second × line height. HUD auto-hides after 3 seconds → `ignoresMouseEvents = true`.
4. **Mouse move (global) or hotkey** — HUD on, click-through off. Speed / font / restart write into the engine; the view observes scroll and settings.
5. **Pause** — tick and timer stop. HUD stays up. Click-through off.
6. **Restart** — scroll and timer to zero; play/pause state unchanged.
7. **Esc / Close overlay** — overlay hidden, engine paused, hotkeys unregistered. Menu bar stays. Picking another script replaces the block list and starts at the top.
8. **End of script** — scroll clamps; engine auto-pauses; HUD shown.

Settings persisted in `UserDefaults`: WPM (default 150, 50–400), font size (default 32, 20–64), timer duration seconds (default 300, 30–1800), last script path, scripts-folder bookmark. HUD timeout is 3 seconds and is not configurable in v1.

## Script store

Resolve the `scripts/` folder in this order:

1. Security-scoped bookmark from the last successful Open / “Choose scripts folder”.
2. Else, if the executable is running from this git repo (Xcode / `swift run`), `scripts/` at the repo root.
3. Else, menu shows “No scripts found” and **Open file…** / **Choose scripts folder…**.

The app is not sandboxed in v1, so reading the repo folder does not need a bookmark. Bookmarks are still saved so a relocated app keeps working.

Open file… can load a `.md` from anywhere. That path is remembered as last script; it does not have to live in `scripts/`.

## Scrolling engine

- `CVDisplayLink` or `CADisplayLink` (macOS 14+) for the tick.
- `scrollY` applied as a y-offset on the text stack (layer transform), GPU-backed.
- Pause cancels the link; resume continues from current `scrollY`.
- Manual drag on the text (only while HUD is up / click-through off) adjusts `scrollY`; auto-scroll stays paused until Play.
- Max scroll = content height − 33% of viewport (reading line). Reaching it pauses.

Timer: 1-second ticks, runs only while playing (matches the current web implementation, not the original web spec). At 0:00 it stays at 0:00 and flashes in the HUD. Scrolling does not stop.

## Error handling

| Situation | Behavior |
|---|---|
| `scripts/` missing or empty | Menu: “No scripts found” plus Open file…. Overlay does not open. |
| File unreadable | Alert from the menu extra; last-used path cleared. Overlay stays closed, or keeps an already-loaded script. |
| Zero SAY/DRAW blocks | Alert “Nothing to read in this file.” Overlay does not start. |
| Open panel cancelled | No change. |
| Global mouse / hotkeys blocked by macOS | One-shot menu notice pointing at System Settings → Privacy & Security → Input Monitoring / Accessibility. Overlay still works: click the menu-bar icon → Show overlay to get the HUD. Mouse-reveal and Space-while-unfocused do not work until permission is granted. |
| Display unplugged | Overlay moves to the main display. |
| Timer 0:00 | Flash in HUD only. Scroll continues. |
| Very long scripts | Render all blocks. No virtualization in v1. |

## Testing

Automated (no UI):

- **Parser fixtures**
  - `scripts/agent-registry.md` — preamble dropped; segments present; SAY vs DRAW split; bold stripped inside SAY.
  - `scripts/virtual-mcp.md` — `[Draw …]` / `[Write …]` / `[Tap …]` / `[Circle …]` are `draw`; spoken paragraphs are `say`; `[Optional cold open …]` dropped.
  - `scripts/example.md` — no markers → all `say`.
  - Empty file and heading-only file → zero content blocks (error path).
- **Engine**
  - Play / pause / restart.
  - Higher WPM → more pixels per second.
  - Scroll clamps at end and auto-pauses.
  - Timer counts down only while playing.

Manual, on a real Mac, required before calling v1 done:

1. Overlay is transparent over a browser or OBS.
2. While playing with HUD hidden, clicks reach the app behind.
3. Mouse move or Space shows the HUD; clicks then hit the HUD, not the app behind.
4. After ~3 seconds idle while playing, HUD hides and click-through returns.
5. Menu lists `scripts/*.md`; Open file… loads a file outside the repo.
6. SAY is large/white; DRAW is smaller, dim, orange.
7. Esc hides HUD, then hides overlay; menu-bar extra remains.

No XCUITest suite in v1. Window flags need a real display.

## Out of scope (v1)

- GitHub fetch / GitHub Pages overlay
- Phone remote / Supabase
- Editing scripts in the app
- Multi-display spanning
- Mirror / flip (beam splitter) — web app already has this
- PWA / iPhone / iPad
- App Sandbox / App Store
- Script virtualization for huge files
- Customizable hotkeys UI (defaults only)
- Click-through while paused

## File map (repo)

```
web-telepromotor/
├── macos/                          # this app
│   └── TeleprompterOverlay/
├── scripts/                        # shared with the web app
├── index.html                      # existing web app (unchanged)
├── js/ css/ remote.html            # unchanged
└── docs/superpowers/specs/
    ├── 2026-04-27-teleprompter-design.md
    └── 2026-08-19-transparent-overlay-teleprompter-design.md
```
