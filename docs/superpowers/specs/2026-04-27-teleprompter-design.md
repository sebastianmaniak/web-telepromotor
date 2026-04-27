# Web Teleprompter — Design Spec

## Overview

A static web app that displays teleprompter scripts on a black screen with smooth scrolling. Scripts are stored as markdown files in a GitHub repo's `scripts/` folder and fetched at runtime. The app runs on phones and tablets, supports configurable scroll speed, a countdown timer, and remote control from a second device.

Hosted on GitHub Pages — no backend, no build step, zero cost.

## Screens

### 1. Script Selection & Setup

The landing screen. Shows:

- **GitHub repo field** — defaults to `sebastianmaniak/web-telepromotor`, user can change it. Persisted in `localStorage`.
- **Script list** — fetched via GitHub API (`GET /repos/:owner/:repo/contents/scripts`). Each entry shows:
  - Script name (filename without `.md`, title-cased)
  - Word count and estimated read time (calculated after fetching content)
- **Settings panel:**
  - **Scroll speed** — words per minute, adjustable with +/- buttons. Default: 150 WPM. Range: 50–400.
  - **Countdown timer** — minutes:seconds, adjustable with +/- buttons. Default: 5:00. Range: 0:30–30:00. Increments by 30 seconds.
  - **Font size** — pixel size of teleprompter text. Default: 32px. Range: 20–64.
- **Start button** — loads the selected script into the teleprompter view.
- **Remote control link** — generates a room code, shows a QR code and shareable URL for the remote control page.

All settings persist in `localStorage` between sessions.

### 2. Teleprompter View

Full-screen black background with white text scrolling upward.

- **Text rendering** — markdown syntax stripped (headings, bold, italic, lists, links removed), displayed as plain large white text. Paragraph breaks preserved as spacing.
- **Reading guide line** — a subtle red horizontal line at ~1/3 from the top of the screen, marking the current reading position.
- **Text fading** — text above and below the guide line gradually fades (via CSS gradient overlays) to focus attention on the current line.
- **Countdown timer** — displayed in the top-right corner with a semi-transparent background. Counts down from the set duration. Pulses red when under 30 seconds. Flashes when it hits 0:00.
- **Bottom control bar** — semi-transparent overlay at the bottom with:
  - Play/pause toggle button
  - Restart button (returns to top)
  - Speed slider (adjustable during playback)
  - Progress indicator (percentage read)
- **Auto-hide controls** — the control bar and timer fade out after 3 seconds of no interaction. Tap anywhere to show them again.
- **Touch gestures:**
  - Tap: show/hide controls
  - Swipe up/down: manually scroll (overrides auto-scroll temporarily)

### 3. Remote Control View (`remote.html`)

A separate page optimized for phone use. Accessed by scanning a QR code or opening a shared URL.

- **Connection status** — green dot when connected, red when disconnected, with auto-reconnect.
- **Script info** — current script name, percentage read, time remaining on countdown.
- **Large play/pause button** — centered, easy to tap without looking.
- **Speed control** — large +/- buttons with current WPM displayed.
- **Quick actions:**
  - Restart — return to beginning of script
  - Font size +/- — adjust the teleprompter's text size
  - Flip — mirror the text horizontally (for use with a beam splitter / mirror teleprompter setup)

## Technical Architecture

### Hosting

GitHub Pages, served from the repo root on the `main` branch. No build step required.

### Script Loading

1. Fetch the file list: `GET https://api.github.com/repos/{owner}/{repo}/contents/scripts`
2. For each `.md` file, fetch raw content: `GET https://raw.githubusercontent.com/{owner}/{repo}/main/scripts/{filename}`
3. Strip markdown syntax client-side using regex (no library needed for plain-text output):
   - Remove `#` heading prefixes
   - Remove `**`, `*`, `__`, `_` formatting markers
   - Remove `[text](url)` links, keep text
   - Remove `- ` and `* ` list markers
   - Remove code blocks and inline code backticks
   - Preserve blank lines as paragraph breaks
4. GitHub API rate limit: 60 requests/hour for unauthenticated. Sufficient for this use case. Cache fetched scripts in `sessionStorage` to minimize API calls.

### Scrolling Engine

- Uses `requestAnimationFrame` for smooth 60fps scrolling.
- Speed is calculated from WPM: estimate average characters visible on screen, convert WPM to pixels-per-frame.
- The text container uses `transform: translateY()` for GPU-accelerated scrolling.
- Pausing stops the animation loop. Resuming continues from the current position.
- Manual scroll (touch drag) temporarily pauses auto-scroll, resumes after 2 seconds of no touch.

### Countdown Timer

- `setInterval` at 1-second ticks.
- Runs independently of scroll — the timer counts down whether scrolling is paused or not.
- Visual states:
  - Normal: white text on semi-transparent background
  - Warning (under 30s): red text, gentle pulse animation
  - Expired (0:00): flashing red background, stays at 0:00

### Remote Control Sync (Supabase Realtime)

- **Service:** Supabase Realtime (free tier: 200 concurrent connections, 2M messages/month).
- **Room model:** When the teleprompter starts, it generates a 6-character alphanumeric room code. The remote control page accepts this code (embedded in the URL or entered manually).
- **Channel:** Both devices subscribe to a Supabase Realtime channel named `room:{code}`.
- **State synced via broadcast messages:**
  - `state` — play/pause, current scroll position, speed, font size, flip
  - `command` — from remote to teleprompter: play, pause, set-speed, restart, set-font-size, flip
- **Flow:**
  1. Teleprompter creates room, broadcasts its state every 2 seconds (heartbeat)
  2. Remote joins room, receives current state, renders controls
  3. Remote sends commands, teleprompter receives and applies them
  4. Teleprompter broadcasts updated state after each change
- **Supabase project:** A single free Supabase project must be created at supabase.com before implementation. The anon key and project URL are embedded in `js/sync.js` as constants. This is safe — the anon key only grants access to Realtime broadcast (no database tables are used).

### QR Code

- Generated client-side using `qrcode-generator` (~4KB, no dependencies).
- Encodes: `https://{github-pages-url}/remote.html?room={code}`
- Displayed as a canvas element on the script selection screen.

## File Structure

```
web-telepromotor/
├── index.html              # Main app (selection + teleprompter)
├── remote.html             # Remote control page
├── css/
│   └── style.css           # All styles
├── js/
│   ├── app.js              # Main app logic, screen routing
│   ├── teleprompter.js     # Scrolling engine, timer, controls
│   ├── github.js           # GitHub API: list scripts, fetch content
│   ├── markdown.js         # Strip markdown to plain text
│   ├── sync.js             # Supabase Realtime: room creation, join, messaging
│   └── qr.js               # QR code generation
├── scripts/                # Teleprompter scripts (user's markdown files)
│   └── example.md          # Sample script
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-04-27-teleprompter-design.md
└── README.md
```

## Dependencies

All loaded via CDN (no npm, no build step):

- **Supabase JS client** (`@supabase/supabase-js`) — for Realtime sync
- **qrcode-generator** — for QR code rendering

No other external dependencies.

## Edge Cases

- **GitHub API rate limit hit:** Show a message suggesting the user wait or enter a GitHub token (stored in `localStorage`).
- **No scripts in repo:** Show a helpful message explaining the `scripts/` folder convention with a link to create a file.
- **Remote disconnects:** Auto-reconnect with exponential backoff. Show disconnected status on remote UI.
- **Timer expires while scrolling:** Timer flashes but scrolling continues — the timer is informational, not a hard stop.
- **Very long scripts:** Virtualize rendering if needed (only render text near the viewport). For V1, render all text and rely on `transform` performance.
- **Mirror/flip mode:** CSS `transform: scaleX(-1)` on the text container for beam-splitter setups.

## Out of Scope (V1)

- User authentication / GitHub OAuth
- Editing scripts in the app
- Multiple simultaneous remote controls (one remote per session)
- Offline support / PWA
- Text-to-speech
- Script version history
