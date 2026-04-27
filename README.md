# Web Teleprompter 🎬

A simple, browser-based teleprompter — no install needed. Just open `index.html` in your browser.

## Features

- **Script editor** — paste or type your script before starting
- **Auto-scroll** — smooth `requestAnimationFrame`-driven scrolling
- **Adjustable speed** (1–10) and **font size** (16–96 px) — tweak live while prompting
- **Mirror mode** — horizontally flips the text for use with a physical beam-splitter/mirror rig
- **Fullscreen** — one click to go fullscreen; press `Escape` to exit
- **Controls auto-hide** — the bar fades after 3 seconds of inactivity so nothing blocks the text
- **Focus guide lines** — subtle horizontal rules to keep your eye on the reading line

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `↑ Arrow` | Increase speed |
| `↓ Arrow` | Decrease speed |
| `M` | Toggle mirror mode |
| `Esc` | Exit fullscreen or return to editor |

## Usage

1. Open `index.html` in any modern browser (Chrome, Firefox, Safari, Edge).
2. Paste your script into the text area.
3. Set your preferred font size and scroll speed.
4. Click **▶ Start Prompting** — scrolling begins immediately.
5. Press **Space** or click **⏸ Pause** to pause/resume at any time.
6. Click **✕ Exit** to return to the editor.

## Files

| File | Purpose |
|------|---------|
| `index.html` | Page structure & screens |
| `style.css` | Dark-mode styling |
| `app.js` | Scroll engine & controls logic |
