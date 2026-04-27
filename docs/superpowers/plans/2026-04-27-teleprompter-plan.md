# Web Teleprompter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a static teleprompter web app that fetches markdown scripts from GitHub, scrolls them on a black screen, and supports remote control from a second device.

**Architecture:** Vanilla HTML/CSS/JS, no build step, hosted on GitHub Pages. Two pages: `index.html` (script selection + teleprompter view) and `remote.html` (remote control). Cross-device sync via Supabase Realtime broadcast channels.

**Tech Stack:** Vanilla JS (ES modules via `<script type="module">`), Supabase JS client (CDN), qrcode-generator (CDN), GitHub REST API, GitHub Pages hosting.

---

## File Map

| File | Responsibility |
|---|---|
| `index.html` | Main page shell — loads CSS + JS modules, contains both the selection screen and teleprompter screen as sections |
| `remote.html` | Remote control page — standalone, loads CSS + sync module |
| `css/style.css` | All styles for both pages — black theme, controls, responsive layout |
| `js/markdown.js` | Exports `stripMarkdown(text)` — regex-based markdown-to-plain-text |
| `js/github.js` | Exports `listScripts(owner, repo)` and `fetchScript(owner, repo, filename)` — GitHub API calls with sessionStorage cache |
| `js/teleprompter.js` | Exports `Teleprompter` class — scrolling engine, timer, controls, touch gestures |
| `js/sync.js` | Exports `createRoom()`, `joinRoom(code)`, `sendCommand(cmd)`, `onState(cb)`, `onCommand(cb)` — Supabase Realtime wrapper |
| `js/qr.js` | Exports `renderQR(text, canvas)` — thin wrapper around qrcode-generator library |
| `js/app.js` | Main entry point — screen routing, wires together all modules, event handlers |
| `scripts/example.md` | Sample teleprompter script for testing |

---

### Task 1: Project Scaffolding & Sample Script

**Files:**
- Create: `index.html`
- Create: `remote.html`
- Create: `css/style.css`
- Create: `js/app.js`
- Create: `js/markdown.js`
- Create: `js/github.js`
- Create: `js/teleprompter.js`
- Create: `js/sync.js`
- Create: `js/qr.js`
- Create: `scripts/example.md`
- Create: `.gitignore`

- [ ] **Step 1: Create `.gitignore`**

```
.superpowers/
.DS_Store
```

- [ ] **Step 2: Create the sample script**

Create `scripts/example.md`:

```markdown
# Product Launch Keynote

Welcome everyone to today's presentation. I'm excited to share our latest updates with you.

First, let's talk about what we've accomplished this quarter. The team has been working incredibly hard on delivering features that matter to our customers.

We shipped three major features that our customers have been asking for. The response has been overwhelmingly positive, with a 40% increase in daily active users.

Looking ahead, we have an ambitious roadmap for the next quarter. Let me walk you through the highlights and show you what's coming next.

Our focus will be on performance improvements, expanding into two new markets, and deepening our integration partnerships.

We believe these investments will position us strongly for the second half of the year. Now let me dive into each of these areas in more detail.

The first area is performance. Our engineering team has identified three key bottlenecks that, once resolved, will cut page load times in half.

The second area is market expansion. We've done extensive research and identified strong demand in both the European and Asian markets.

Thank you for your time and attention. I'm happy to take questions.
```

- [ ] **Step 3: Create `index.html` shell**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Teleprompter</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <!-- Screen 1: Script Selection & Setup -->
    <div id="selection-screen" class="screen active">
        <div class="selection-container">
            <h1 class="app-title">TELEPROMPTER</h1>
            <p class="app-subtitle">Select a script to begin</p>

            <!-- Repo config -->
            <div class="config-section">
                <label class="config-label">GitHub Repository</label>
                <div class="repo-input-row">
                    <input type="text" id="repo-input" class="repo-input" placeholder="owner/repo">
                    <button id="load-btn" class="btn-load">Load</button>
                </div>
                <p class="config-hint">Reads from <code>scripts/</code> folder</p>
            </div>

            <!-- Script list -->
            <div id="script-list-section" class="script-list-section">
                <label class="config-label">Scripts</label>
                <div id="script-list" class="script-list">
                    <p class="empty-message" id="empty-message">Enter a repository and tap Load</p>
                </div>
            </div>

            <!-- Settings -->
            <div class="settings-section">
                <label class="config-label">Settings</label>

                <div class="setting-row">
                    <div class="setting-info">
                        <div class="setting-name">Scroll Speed</div>
                        <div class="setting-hint">Words per minute</div>
                    </div>
                    <div class="setting-control">
                        <button class="btn-adjust" data-setting="speed" data-dir="-1">&#8722;</button>
                        <span class="setting-value" id="speed-value">150</span>
                        <button class="btn-adjust" data-setting="speed" data-dir="1">+</button>
                    </div>
                </div>

                <div class="setting-row">
                    <div class="setting-info">
                        <div class="setting-name">Countdown Timer</div>
                        <div class="setting-hint">Alert when time runs out</div>
                    </div>
                    <div class="setting-control">
                        <button class="btn-adjust" data-setting="timer" data-dir="-1">&#8722;</button>
                        <span class="setting-value" id="timer-value">5:00</span>
                        <button class="btn-adjust" data-setting="timer" data-dir="1">+</button>
                    </div>
                </div>

                <div class="setting-row">
                    <div class="setting-info">
                        <div class="setting-name">Font Size</div>
                        <div class="setting-hint">Adjust for distance</div>
                    </div>
                    <div class="setting-control">
                        <button class="btn-adjust" data-setting="fontSize" data-dir="-1">A</button>
                        <span class="setting-value" id="fontSize-value">32</span>
                        <button class="btn-adjust" data-setting="fontSize" data-dir="1">A</button>
                    </div>
                </div>
            </div>

            <!-- Start button -->
            <button id="start-btn" class="btn-start" disabled>&#9654; Start Teleprompter</button>

            <!-- Remote control link -->
            <div class="remote-section">
                <button id="remote-link-btn" class="btn-remote">Open Remote Control</button>
                <p class="config-hint">Share link or scan QR to control from another device</p>
                <canvas id="qr-canvas" class="qr-canvas hidden"></canvas>
                <p id="room-code-display" class="room-code hidden"></p>
            </div>
        </div>
    </div>

    <!-- Screen 2: Teleprompter View -->
    <div id="teleprompter-screen" class="screen">
        <!-- Timer -->
        <div id="timer-display" class="timer-display">0:00</div>

        <!-- Guide line -->
        <div class="guide-line"></div>

        <!-- Fade overlays -->
        <div class="fade-top"></div>
        <div class="fade-bottom"></div>

        <!-- Scrolling text -->
        <div id="text-container" class="text-container">
            <div id="text-content" class="text-content"></div>
        </div>

        <!-- Bottom control bar -->
        <div id="control-bar" class="control-bar">
            <div class="control-left">
                <button id="play-pause-btn" class="btn-control">&#9208;</button>
                <button id="restart-btn" class="btn-control">&#10226;</button>
            </div>
            <div class="control-center">
                <label class="speed-label">SPEED</label>
                <input type="range" id="speed-slider" class="speed-slider" min="50" max="400" value="150">
            </div>
            <div class="control-right">
                <span id="progress-display" class="progress-display">0%</span>
            </div>
        </div>
    </div>

    <script type="module" src="js/app.js"></script>
</body>
</html>
```

- [ ] **Step 4: Create `remote.html` shell**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Teleprompter Remote</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <div id="remote-screen" class="screen active">
        <div class="remote-container">
            <h1 class="remote-title">Remote Control</h1>
            <p id="connection-status" class="connection-status disconnected">Disconnected</p>

            <!-- Manual room code entry -->
            <div id="room-entry" class="room-entry">
                <input type="text" id="room-input" class="room-input" placeholder="Enter room code" maxlength="6">
                <button id="join-btn" class="btn-load">Join</button>
            </div>

            <!-- Script info -->
            <div id="remote-info" class="remote-info hidden">
                <div class="remote-script-name" id="remote-script-name"></div>
                <div class="remote-progress-text" id="remote-progress-text">0% read</div>
                <div class="remote-progress-bar">
                    <div class="remote-progress-fill" id="remote-progress-fill" style="width:0%"></div>
                </div>
            </div>

            <!-- Big play/pause -->
            <button id="remote-play-pause" class="btn-play-pause hidden">&#9208;</button>

            <!-- Speed control -->
            <div id="remote-speed-section" class="remote-speed-section hidden">
                <label class="config-label">Speed</label>
                <div class="setting-control large">
                    <button id="remote-speed-down" class="btn-adjust large">&#8722;</button>
                    <span class="setting-value large" id="remote-speed-value">150</span>
                    <button id="remote-speed-up" class="btn-adjust large">+</button>
                </div>
                <p class="config-hint">words per minute</p>
            </div>

            <!-- Quick actions -->
            <div id="remote-actions" class="remote-actions hidden">
                <button id="remote-restart" class="btn-action">
                    <span class="action-icon">&#10226;</span>
                    <span class="action-label">Restart</span>
                </button>
                <button id="remote-font-up" class="btn-action">
                    <span class="action-icon">A+</span>
                    <span class="action-label">Font Size</span>
                </button>
                <button id="remote-flip" class="btn-action">
                    <span class="action-icon">&#8644;</span>
                    <span class="action-label">Flip</span>
                </button>
            </div>
        </div>
    </div>

    <script type="module">
        import { joinRoom, sendCommand } from './js/sync.js';

        const params = new URLSearchParams(window.location.search);
        const roomCode = params.get('room');

        const connectionStatus = document.getElementById('connection-status');
        const roomEntry = document.getElementById('room-entry');
        const roomInput = document.getElementById('room-input');
        const joinBtn = document.getElementById('join-btn');
        const remoteInfo = document.getElementById('remote-info');
        const remoteScriptName = document.getElementById('remote-script-name');
        const remoteProgressText = document.getElementById('remote-progress-text');
        const remoteProgressFill = document.getElementById('remote-progress-fill');
        const remotePlayPause = document.getElementById('remote-play-pause');
        const remoteSpeedSection = document.getElementById('remote-speed-section');
        const remoteSpeedValue = document.getElementById('remote-speed-value');
        const remoteActions = document.getElementById('remote-actions');

        let currentState = {};

        function showControls() {
            remoteInfo.classList.remove('hidden');
            remotePlayPause.classList.remove('hidden');
            remoteSpeedSection.classList.remove('hidden');
            remoteActions.classList.remove('hidden');
        }

        function updateUI(state) {
            currentState = state;
            if (state.scriptName) remoteScriptName.textContent = state.scriptName;
            if (state.progress !== undefined) {
                const pct = Math.round(state.progress * 100);
                remoteProgressText.textContent = pct + '% read · ' + (state.timerDisplay || '0:00') + ' remaining';
                remoteProgressFill.style.width = pct + '%';
            }
            if (state.speed) remoteSpeedValue.textContent = state.speed;
            remotePlayPause.textContent = state.playing ? '⏸' : '▶';
        }

        function connect(code) {
            roomEntry.classList.add('hidden');
            connectionStatus.textContent = 'Connecting...';
            connectionStatus.className = 'connection-status connecting';

            joinRoom(code, {
                onState: (state) => {
                    connectionStatus.textContent = 'Connected';
                    connectionStatus.className = 'connection-status connected';
                    showControls();
                    updateUI(state);
                },
                onDisconnect: () => {
                    connectionStatus.textContent = 'Disconnected';
                    connectionStatus.className = 'connection-status disconnected';
                }
            });
        }

        if (roomCode) {
            connect(roomCode);
        }

        joinBtn.addEventListener('click', () => {
            const code = roomInput.value.trim().toUpperCase();
            if (code.length === 6) connect(code);
        });

        remotePlayPause.addEventListener('click', () => {
            sendCommand({ type: currentState.playing ? 'pause' : 'play' });
        });

        document.getElementById('remote-speed-down').addEventListener('click', () => {
            sendCommand({ type: 'set-speed', value: Math.max(50, (currentState.speed || 150) - 10) });
        });

        document.getElementById('remote-speed-up').addEventListener('click', () => {
            sendCommand({ type: 'set-speed', value: Math.min(400, (currentState.speed || 150) + 10) });
        });

        document.getElementById('remote-restart').addEventListener('click', () => {
            sendCommand({ type: 'restart' });
        });

        document.getElementById('remote-font-up').addEventListener('click', () => {
            sendCommand({ type: 'set-font-size', value: (currentState.fontSize || 32) + 2 });
        });

        document.getElementById('remote-flip').addEventListener('click', () => {
            sendCommand({ type: 'flip' });
        });
    </script>
</body>
</html>
```

- [ ] **Step 5: Create placeholder JS modules**

Create `js/markdown.js`:

```js
export function stripMarkdown(text) {
    return text;
}
```

Create `js/github.js`:

```js
export async function listScripts(owner, repo) {
    return [];
}

export async function fetchScript(owner, repo, filename) {
    return '';
}
```

Create `js/teleprompter.js`:

```js
export class Teleprompter {
    constructor(container, options) {
        this.container = container;
    }
}
```

Create `js/sync.js`:

```js
export function createRoom() {
    return 'ABC123';
}

export function joinRoom(code, callbacks) {}

export function sendCommand(cmd) {}

export function onState(cb) {}

export function onCommand(cb) {}
```

Create `js/qr.js`:

```js
export function renderQR(text, canvas) {}
```

Create `js/app.js`:

```js
import { listScripts, fetchScript } from './github.js';
import { stripMarkdown } from './markdown.js';
import { Teleprompter } from './teleprompter.js';
import { createRoom, onCommand } from './sync.js';
import { renderQR } from './qr.js';

console.log('Teleprompter app loaded');
```

- [ ] **Step 6: Verify the shell loads in browser**

Run: `python3 -m http.server 8080`

Open `http://localhost:8080` in a browser. Verify console shows "Teleprompter app loaded" with no errors. The page will be unstyled but should show the raw HTML elements.

- [ ] **Step 7: Commit**

```bash
git add .gitignore scripts/example.md index.html remote.html css/style.css js/markdown.js js/github.js js/teleprompter.js js/sync.js js/qr.js js/app.js
git commit -m "feat: scaffold project with HTML shells and placeholder modules"
```

---

### Task 2: CSS Styling — Black Theme & Responsive Layout

**Files:**
- Modify: `css/style.css`

- [ ] **Step 1: Write all CSS**

```css
/* === Reset & Base === */
*, *::before, *::after {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

html, body {
    height: 100%;
    background: #000;
    color: #fff;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    overflow: hidden;
    -webkit-tap-highlight-color: transparent;
}

.hidden {
    display: none !important;
}

/* === Screen routing === */
.screen {
    display: none;
    width: 100%;
    height: 100%;
}

.screen.active {
    display: block;
}

/* === Selection Screen === */
.selection-container {
    max-width: 480px;
    margin: 0 auto;
    padding: 24px;
    height: 100%;
    overflow-y: auto;
}

.app-title {
    text-align: center;
    font-size: 24px;
    font-weight: 600;
    letter-spacing: 2px;
    margin-bottom: 4px;
}

.app-subtitle {
    text-align: center;
    font-size: 13px;
    color: #666;
    margin-bottom: 32px;
}

/* Config sections */
.config-section,
.script-list-section,
.settings-section,
.remote-section {
    margin-bottom: 24px;
}

.config-label {
    display: block;
    font-size: 11px;
    color: #888;
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 8px;
}

.config-hint {
    font-size: 11px;
    color: #555;
    margin-top: 6px;
}

.config-hint code {
    color: #888;
    background: rgba(255, 255, 255, 0.06);
    padding: 2px 6px;
    border-radius: 3px;
}

/* Repo input */
.repo-input-row {
    display: flex;
    gap: 8px;
}

.repo-input {
    flex: 1;
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 8px;
    padding: 10px 14px;
    font-size: 14px;
    color: #ccc;
    outline: none;
}

.repo-input:focus {
    border-color: rgba(74, 158, 255, 0.5);
}

.btn-load {
    background: rgba(74, 158, 255, 0.2);
    color: #4a9eff;
    border: none;
    padding: 10px 16px;
    border-radius: 8px;
    font-size: 14px;
    cursor: pointer;
}

.btn-load:active {
    background: rgba(74, 158, 255, 0.35);
}

/* Script list */
.script-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.script-item {
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
    padding: 16px;
    cursor: pointer;
    transition: border-color 0.15s;
}

.script-item:active,
.script-item.selected {
    background: rgba(74, 158, 255, 0.12);
    border-color: rgba(74, 158, 255, 0.3);
}

.script-item-name {
    font-size: 16px;
    font-weight: 500;
}

.script-item-meta {
    font-size: 12px;
    color: #888;
    margin-top: 4px;
}

.empty-message {
    color: #555;
    font-size: 14px;
    text-align: center;
    padding: 20px;
}

/* Settings */
.settings-section {
    background: rgba(255, 255, 255, 0.06);
    border-radius: 12px;
    padding: 20px;
}

.settings-section .config-label {
    margin-bottom: 16px;
}

.setting-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
}

.setting-row:last-child {
    margin-bottom: 0;
}

.setting-name {
    font-size: 14px;
}

.setting-hint {
    font-size: 11px;
    color: #666;
}

.setting-control {
    display: flex;
    align-items: center;
    gap: 12px;
}

.btn-adjust {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.1);
    border: none;
    color: #fff;
    font-size: 18px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
}

.btn-adjust:active {
    background: rgba(255, 255, 255, 0.2);
}

.setting-value {
    font-size: 20px;
    font-weight: 600;
    min-width: 48px;
    text-align: center;
}

/* Start button */
.btn-start {
    display: block;
    width: 100%;
    background: #4a9eff;
    border: none;
    border-radius: 12px;
    padding: 16px;
    font-size: 18px;
    font-weight: 600;
    color: #fff;
    cursor: pointer;
    margin-bottom: 16px;
}

.btn-start:disabled {
    background: #333;
    color: #666;
    cursor: not-allowed;
}

.btn-start:not(:disabled):active {
    background: #3a8eef;
}

/* Remote section */
.remote-section {
    text-align: center;
}

.btn-remote {
    background: none;
    border: none;
    color: #4a9eff;
    font-size: 14px;
    cursor: pointer;
    padding: 8px;
}

.qr-canvas {
    margin: 16px auto;
    display: block;
    border-radius: 8px;
}

.room-code {
    font-size: 24px;
    font-weight: 700;
    letter-spacing: 4px;
    color: #4a9eff;
    margin-top: 8px;
}

/* === Teleprompter Screen === */
#teleprompter-screen {
    position: relative;
    overflow: hidden;
}

.timer-display {
    position: absolute;
    top: 12px;
    right: 16px;
    z-index: 10;
    background: rgba(255, 255, 255, 0.1);
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 14px;
    color: #aaa;
    transition: opacity 0.3s;
}

.timer-display.warning {
    color: #ff4444;
    animation: pulse 1s ease-in-out infinite;
}

.timer-display.expired {
    background: rgba(255, 0, 0, 0.3);
    color: #ff4444;
    animation: flash 0.5s ease-in-out infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}

@keyframes flash {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.2; }
}

.guide-line {
    position: absolute;
    top: 33%;
    left: 0;
    right: 0;
    height: 2px;
    background: rgba(255, 80, 80, 0.5);
    z-index: 5;
    pointer-events: none;
}

.fade-top {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 25%;
    background: linear-gradient(to bottom, rgba(0, 0, 0, 0.9), transparent);
    z-index: 4;
    pointer-events: none;
}

.fade-bottom {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 35%;
    background: linear-gradient(to top, rgba(0, 0, 0, 0.95), transparent);
    z-index: 4;
    pointer-events: none;
}

.text-container {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    overflow: hidden;
}

.text-content {
    padding: 40px 24px;
    padding-top: 33vh;
    font-size: 32px;
    line-height: 1.7;
    color: #fff;
    letter-spacing: 0.3px;
    will-change: transform;
}

.text-content.flipped {
    transform: scaleX(-1);
}

.text-content p {
    margin-bottom: 1em;
}

/* Control bar */
.control-bar {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 10;
    background: linear-gradient(transparent, rgba(0, 0, 0, 0.95));
    padding: 30px 20px 16px;
    display: flex;
    align-items: center;
    transition: opacity 0.3s;
}

.control-bar.auto-hidden {
    opacity: 0;
    pointer-events: none;
}

.timer-display.auto-hidden {
    opacity: 0;
}

.control-left {
    display: flex;
    gap: 12px;
}

.btn-control {
    width: 44px;
    height: 44px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.15);
    border: none;
    color: #fff;
    font-size: 20px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
}

.btn-control:active {
    background: rgba(255, 255, 255, 0.3);
}

.control-center {
    flex: 1;
    margin: 0 16px;
}

.speed-label {
    font-size: 11px;
    color: #888;
    display: block;
    margin-bottom: 4px;
}

.speed-slider {
    width: 100%;
    -webkit-appearance: none;
    appearance: none;
    height: 4px;
    background: rgba(255, 255, 255, 0.2);
    border-radius: 2px;
    outline: none;
}

.speed-slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    width: 20px;
    height: 20px;
    background: #fff;
    border-radius: 50%;
    cursor: pointer;
}

.control-right {
    text-align: right;
}

.progress-display {
    color: #aaa;
    font-size: 14px;
}

/* === Remote Control Screen === */
.remote-container {
    max-width: 400px;
    margin: 0 auto;
    padding: 24px;
    text-align: center;
}

.remote-title {
    font-size: 20px;
    font-weight: 600;
    margin-bottom: 4px;
}

.connection-status {
    font-size: 13px;
    margin-bottom: 24px;
}

.connection-status.connected {
    color: #4aff7f;
}

.connection-status.disconnected {
    color: #ff4444;
}

.connection-status.connecting {
    color: #ffaa00;
}

.room-entry {
    display: flex;
    gap: 8px;
    margin-bottom: 24px;
}

.room-input {
    flex: 1;
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 8px;
    padding: 12px 16px;
    font-size: 18px;
    color: #fff;
    text-align: center;
    letter-spacing: 4px;
    text-transform: uppercase;
    outline: none;
}

.room-input:focus {
    border-color: rgba(74, 158, 255, 0.5);
}

.remote-info {
    background: rgba(255, 255, 255, 0.06);
    border-radius: 12px;
    padding: 14px;
    margin-bottom: 24px;
}

.remote-script-name {
    font-size: 14px;
    font-weight: 500;
}

.remote-progress-text {
    font-size: 12px;
    color: #888;
    margin-top: 4px;
}

.remote-progress-bar {
    height: 3px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 2px;
    margin-top: 10px;
}

.remote-progress-fill {
    height: 100%;
    background: #4a9eff;
    border-radius: 2px;
    transition: width 0.3s;
}

.btn-play-pause {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    background: rgba(74, 158, 255, 0.2);
    border: 2px solid #4a9eff;
    color: #fff;
    font-size: 36px;
    cursor: pointer;
    margin: 0 auto 24px;
    display: flex;
    align-items: center;
    justify-content: center;
}

.btn-play-pause:active {
    background: rgba(74, 158, 255, 0.4);
}

.remote-speed-section {
    background: rgba(255, 255, 255, 0.06);
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 16px;
}

.setting-control.large {
    justify-content: center;
    gap: 20px;
}

.btn-adjust.large {
    width: 48px;
    height: 48px;
    font-size: 24px;
}

.setting-value.large {
    font-size: 28px;
    min-width: 64px;
}

.remote-actions {
    display: flex;
    gap: 8px;
}

.btn-action {
    flex: 1;
    background: rgba(255, 255, 255, 0.06);
    border: none;
    border-radius: 12px;
    padding: 14px;
    color: #fff;
    cursor: pointer;
    text-align: center;
}

.btn-action:active {
    background: rgba(255, 255, 255, 0.12);
}

.action-icon {
    display: block;
    font-size: 20px;
    margin-bottom: 4px;
}

.action-label {
    display: block;
    font-size: 11px;
    color: #888;
}
```

- [ ] **Step 2: Open in browser and verify**

Run: `python3 -m http.server 8080`

Open `http://localhost:8080`. Verify:
- Black background, white text, dark theme throughout
- Selection screen is laid out correctly: title, repo input, script list area, settings, start button
- Settings +/- buttons are visible and touch-friendly
- Open `http://localhost:8080/remote.html` — verify remote control layout renders correctly

- [ ] **Step 3: Commit**

```bash
git add css/style.css
git commit -m "feat: add complete CSS styling with black theme and responsive layout"
```

---

### Task 3: Markdown Stripping Module

**Files:**
- Modify: `js/markdown.js`

- [ ] **Step 1: Implement `stripMarkdown`**

Replace the contents of `js/markdown.js` with:

```js
export function stripMarkdown(text) {
    return text
        .replace(/^#{1,6}\s+/gm, '')
        .replace(/```[\s\S]*?```/g, '')
        .replace(/`([^`]+)`/g, '$1')
        .replace(/!\[([^\]]*)\]\([^)]+\)/g, '')
        .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
        .replace(/(\*\*|__)(.*?)\1/g, '$2')
        .replace(/(\*|_)(.*?)\1/g, '$2')
        .replace(/~~(.*?)~~/g, '$1')
        .replace(/^>\s+/gm, '')
        .replace(/^[-*+]\s+/gm, '')
        .replace(/^\d+\.\s+/gm, '')
        .replace(/^---+$/gm, '')
        .replace(/\n{3,}/g, '\n\n')
        .trim();
}
```

- [ ] **Step 2: Test in browser console**

Open `http://localhost:8080`, then in the browser console:

```js
import('./js/markdown.js').then(m => {
    const test = '# Heading\n\nSome **bold** and *italic* text.\n\n- List item\n- Another [link](http://example.com)\n\n`code` here';
    console.log(m.stripMarkdown(test));
});
```

Expected output:
```
Heading

Some bold and italic text.

List item
Another link

code here
```

- [ ] **Step 3: Commit**

```bash
git add js/markdown.js
git commit -m "feat: implement markdown stripping to plain text"
```

---

### Task 4: GitHub API Module

**Files:**
- Modify: `js/github.js`

- [ ] **Step 1: Implement `listScripts` and `fetchScript`**

Replace the contents of `js/github.js` with:

```js
const CACHE_PREFIX = 'teleprompter_';

export async function listScripts(owner, repo) {
    const cacheKey = CACHE_PREFIX + 'list_' + owner + '_' + repo;
    const cached = sessionStorage.getItem(cacheKey);
    if (cached) return JSON.parse(cached);

    const url = 'https://api.github.com/repos/' + encodeURIComponent(owner) + '/' + encodeURIComponent(repo) + '/contents/scripts';
    const res = await fetch(url);

    if (res.status === 403) {
        throw new Error('GitHub API rate limit reached. Try again in a few minutes.');
    }
    if (res.status === 404) {
        throw new Error('Repository or scripts/ folder not found. Make sure the repo is public and has a scripts/ directory.');
    }
    if (!res.ok) {
        throw new Error('GitHub API error: ' + res.status);
    }

    const files = await res.json();
    const scripts = files
        .filter(f => f.name.endsWith('.md'))
        .map(f => ({
            filename: f.name,
            name: f.name.replace(/\.md$/, '').replace(/[-_]/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
            downloadUrl: f.download_url
        }));

    sessionStorage.setItem(cacheKey, JSON.stringify(scripts));
    return scripts;
}

export async function fetchScript(owner, repo, filename) {
    const cacheKey = CACHE_PREFIX + 'script_' + owner + '_' + repo + '_' + filename;
    const cached = sessionStorage.getItem(cacheKey);
    if (cached) return cached;

    const url = 'https://raw.githubusercontent.com/' + encodeURIComponent(owner) + '/' + encodeURIComponent(repo) + '/main/scripts/' + encodeURIComponent(filename);
    const res = await fetch(url);

    if (!res.ok) {
        throw new Error('Failed to fetch script: ' + res.status);
    }

    const text = await res.text();
    sessionStorage.setItem(cacheKey, text);
    return text;
}

export function wordCount(text) {
    return text.split(/\s+/).filter(w => w.length > 0).length;
}

export function estimateReadTime(words, wpm) {
    const rate = wpm || 150;
    const minutes = Math.ceil(words / rate);
    return '~' + minutes + ' min read';
}
```

- [ ] **Step 2: Test in browser console**

Open `http://localhost:8080`, then in the browser console:

```js
import('./js/github.js').then(async m => {
    const scripts = await m.listScripts('sebastianmaniak', 'web-telepromotor');
    console.log('Scripts:', scripts);
    if (scripts.length > 0) {
        const content = await m.fetchScript('sebastianmaniak', 'web-telepromotor', scripts[0].filename);
        console.log('Content:', content.substring(0, 200));
        console.log('Words:', m.wordCount(content));
    }
});
```

Expected: array with at least `example.md` entry (once pushed to GitHub). If repo isn't pushed yet, test with any public repo that has a `scripts/` folder, or verify the 404 error message is clear.

- [ ] **Step 3: Commit**

```bash
git add js/github.js
git commit -m "feat: implement GitHub API module with caching"
```

---

### Task 5: Teleprompter Scrolling Engine

**Files:**
- Modify: `js/teleprompter.js`

- [ ] **Step 1: Implement the `Teleprompter` class**

Replace the contents of `js/teleprompter.js` with:

```js
export class Teleprompter {
    constructor(container, contentEl, options) {
        options = options || {};
        this.container = container;
        this.contentEl = contentEl;
        this.speed = options.speed || 150;
        this.fontSize = options.fontSize || 32;
        this.timerDuration = options.timerDuration || 300;
        this.onStateChange = options.onStateChange || function() {};

        this.playing = false;
        this.flipped = false;
        this.scrollY = 0;
        this.animFrameId = null;
        this.lastTimestamp = null;
        this.timerRemaining = this.timerDuration;
        this.timerInterval = null;
        this.touchStartY = 0;
        this.touchScrolling = false;
        this.touchTimeout = null;
        this.scriptName = '';
        this.totalHeight = 0;
        this.viewportHeight = 0;

        this.contentEl.style.fontSize = this.fontSize + 'px';
    }

    load(text, scriptName) {
        this.scriptName = scriptName;
        this.scrollY = 0;

        while (this.contentEl.firstChild) {
            this.contentEl.removeChild(this.contentEl.firstChild);
        }

        var paragraphs = text.split(/\n\n+/);
        for (var i = 0; i < paragraphs.length; i++) {
            var trimmed = paragraphs[i].trim();
            if (!trimmed) continue;
            var p = document.createElement('p');
            p.textContent = trimmed;
            this.contentEl.appendChild(p);
        }

        this.contentEl.style.transform = 'translateY(0px)';
        this.totalHeight = this.contentEl.scrollHeight;
        this.viewportHeight = this.container.clientHeight;
    }

    play() {
        if (this.playing) return;
        this.playing = true;
        this.lastTimestamp = null;
        var self = this;
        this.animFrameId = requestAnimationFrame(function(t) { self._tick(t); });
        this._startTimer();
        this._broadcastState();
    }

    pause() {
        this.playing = false;
        if (this.animFrameId) {
            cancelAnimationFrame(this.animFrameId);
            this.animFrameId = null;
        }
        this._stopTimer();
        this._broadcastState();
    }

    restart() {
        this.pause();
        this.scrollY = 0;
        this.contentEl.style.transform = 'translateY(0px)';
        this.timerRemaining = this.timerDuration;
        this._broadcastState();
    }

    setSpeed(wpm) {
        this.speed = Math.max(50, Math.min(400, wpm));
        this._broadcastState();
    }

    setFontSize(px) {
        this.fontSize = Math.max(20, Math.min(64, px));
        this.contentEl.style.fontSize = this.fontSize + 'px';
        this.totalHeight = this.contentEl.scrollHeight;
        this._broadcastState();
    }

    toggleFlip() {
        this.flipped = !this.flipped;
        this.contentEl.classList.toggle('flipped', this.flipped);
        this._broadcastState();
    }

    setTimerDuration(seconds) {
        this.timerDuration = seconds;
        this.timerRemaining = seconds;
        this._broadcastState();
    }

    getProgress() {
        var maxScroll = this.totalHeight - this.viewportHeight * 0.33;
        if (maxScroll <= 0) return 1;
        return Math.min(1, Math.max(0, this.scrollY / maxScroll));
    }

    getTimerDisplay() {
        var mins = Math.floor(this.timerRemaining / 60);
        var secs = this.timerRemaining % 60;
        return mins + ':' + (secs < 10 ? '0' : '') + secs;
    }

    getState() {
        return {
            playing: this.playing,
            speed: this.speed,
            fontSize: this.fontSize,
            progress: this.getProgress(),
            timerDisplay: this.getTimerDisplay(),
            timerRemaining: this.timerRemaining,
            scriptName: this.scriptName,
            flipped: this.flipped,
            scrollY: this.scrollY
        };
    }

    applyCommand(cmd) {
        switch (cmd.type) {
            case 'play': this.play(); break;
            case 'pause': this.pause(); break;
            case 'restart': this.restart(); break;
            case 'set-speed': this.setSpeed(cmd.value); break;
            case 'set-font-size': this.setFontSize(cmd.value); break;
            case 'flip': this.toggleFlip(); break;
        }
    }

    setupTouchHandlers() {
        var self = this;

        this.container.addEventListener('touchstart', function(e) {
            self.touchStartY = e.touches[0].clientY;
            self.touchScrolling = false;
        }, { passive: true });

        this.container.addEventListener('touchmove', function(e) {
            var deltaY = self.touchStartY - e.touches[0].clientY;
            if (Math.abs(deltaY) > 10) {
                self.touchScrolling = true;
                if (self.playing) {
                    cancelAnimationFrame(self.animFrameId);
                    self.animFrameId = null;
                }
                self.scrollY = Math.max(0, self.scrollY + deltaY);
                self.contentEl.style.transform = 'translateY(-' + self.scrollY + 'px)';
                self.touchStartY = e.touches[0].clientY;
                clearTimeout(self.touchTimeout);
            }
        }, { passive: true });

        this.container.addEventListener('touchend', function() {
            if (self.touchScrolling && self.playing) {
                self.touchTimeout = setTimeout(function() {
                    self.lastTimestamp = null;
                    self.animFrameId = requestAnimationFrame(function(t) { self._tick(t); });
                }, 2000);
            }
        }, { passive: true });
    }

    destroy() {
        this.pause();
        clearTimeout(this.touchTimeout);
    }

    _tick(timestamp) {
        if (!this.playing) return;

        if (!this.lastTimestamp) {
            this.lastTimestamp = timestamp;
            var self = this;
            this.animFrameId = requestAnimationFrame(function(t) { self._tick(t); });
            return;
        }

        var elapsed = (timestamp - this.lastTimestamp) / 1000;
        this.lastTimestamp = timestamp;

        var avgWordLength = 5;
        var lineHeight = this.fontSize * 1.7;
        var charsPerLine = Math.floor(this.container.clientWidth / (this.fontSize * 0.5));
        var wordsPerLine = Math.max(1, charsPerLine / avgWordLength);
        var linesPerSecond = (this.speed / 60) / wordsPerLine;
        var pixelsPerSecond = linesPerSecond * lineHeight;

        this.scrollY += pixelsPerSecond * elapsed;

        var maxScroll = this.totalHeight - this.viewportHeight * 0.33;
        if (this.scrollY >= maxScroll) {
            this.scrollY = maxScroll;
            this.pause();
        }

        this.contentEl.style.transform = 'translateY(-' + this.scrollY + 'px)';
        var self = this;
        this.animFrameId = requestAnimationFrame(function(t) { self._tick(t); });
    }

    _startTimer() {
        if (this.timerInterval) return;
        var self = this;
        this.timerInterval = setInterval(function() {
            if (self.timerRemaining > 0) {
                self.timerRemaining--;
                self._broadcastState();
            }
        }, 1000);
    }

    _stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }

    _broadcastState() {
        this.onStateChange(this.getState());
    }
}
```

- [ ] **Step 2: Verify the module loads**

Open `http://localhost:8080`, then in the browser console:

```js
import('./js/teleprompter.js').then(m => {
    console.log('Teleprompter class:', typeof m.Teleprompter);
});
```

Expected: `Teleprompter class: function`

- [ ] **Step 3: Commit**

```bash
git add js/teleprompter.js
git commit -m "feat: implement teleprompter scrolling engine with timer and touch"
```

---

### Task 6: Supabase Realtime Sync Module

**Files:**
- Modify: `js/sync.js`

**Prerequisite:** A Supabase project must be created at supabase.com. Get the project URL and anon key from Settings > API.

- [ ] **Step 1: Implement sync module**

Replace the contents of `js/sync.js` with:

```js
var SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
var SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';

var supabase = null;
var channel = null;
var currentRoomCode = null;

async function getClient() {
    if (supabase) return supabase;
    var mod = await import('https://esm.sh/@supabase/supabase-js@2');
    supabase = mod.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    return supabase;
}

function generateRoomCode() {
    var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var code = '';
    for (var i = 0; i < 6; i++) {
        code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
}

export async function createRoom() {
    var client = await getClient();
    currentRoomCode = generateRoomCode();

    channel = client.channel('room:' + currentRoomCode, {
        config: { broadcast: { self: false } }
    });

    await channel.subscribe();
    return currentRoomCode;
}

export async function joinRoom(code, callbacks) {
    var client = await getClient();
    currentRoomCode = code.toUpperCase();

    channel = client.channel('room:' + currentRoomCode, {
        config: { broadcast: { self: false } }
    });

    channel.on('broadcast', { event: 'state' }, function(payload) {
        if (callbacks.onState) callbacks.onState(payload.payload);
    });

    var status = await channel.subscribe();
    if (status === 'CHANNEL_ERROR' && callbacks.onDisconnect) {
        callbacks.onDisconnect();
    }

    return channel;
}

export function broadcastState(state) {
    if (!channel) return;
    channel.send({
        type: 'broadcast',
        event: 'state',
        payload: state
    });
}

export function sendCommand(cmd) {
    if (!channel) return;
    channel.send({
        type: 'broadcast',
        event: 'command',
        payload: cmd
    });
}

export function onCommand(callback) {
    if (!channel) return;
    channel.on('broadcast', { event: 'command' }, function(payload) {
        callback(payload.payload);
    });
}

export function getRoomCode() {
    return currentRoomCode;
}

export function disconnect() {
    if (channel) {
        channel.unsubscribe();
        channel = null;
    }
    currentRoomCode = null;
}
```

- [ ] **Step 2: Verify the module loads**

Open `http://localhost:8080`, then in the browser console:

```js
import('./js/sync.js').then(m => {
    console.log('createRoom:', typeof m.createRoom);
    console.log('joinRoom:', typeof m.joinRoom);
});
```

Expected: both log `function`. (Full sync testing requires the Supabase project to be configured — test end-to-end in Task 9.)

- [ ] **Step 3: Commit**

```bash
git add js/sync.js
git commit -m "feat: implement Supabase Realtime sync module"
```

---

### Task 7: QR Code Module

**Files:**
- Modify: `js/qr.js`

- [ ] **Step 1: Implement QR code wrapper**

Replace the contents of `js/qr.js` with:

```js
var qrLib = null;

async function loadLib() {
    if (qrLib) return qrLib;
    qrLib = await import('https://esm.sh/qrcode-generator@1.4.4');
    return qrLib;
}

export async function renderQR(text, canvas) {
    var lib = await loadLib();
    var qr = lib.default(0, 'M');
    qr.addData(text);
    qr.make();

    var moduleCount = qr.getModuleCount();
    var cellSize = Math.floor(200 / moduleCount);
    var size = cellSize * moduleCount;

    canvas.width = size;
    canvas.height = size;
    canvas.style.width = size + 'px';
    canvas.style.height = size + 'px';

    var ctx = canvas.getContext('2d');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, size, size);

    ctx.fillStyle = '#000000';
    for (var row = 0; row < moduleCount; row++) {
        for (var col = 0; col < moduleCount; col++) {
            if (qr.isDark(row, col)) {
                ctx.fillRect(col * cellSize, row * cellSize, cellSize, cellSize);
            }
        }
    }
}
```

- [ ] **Step 2: Test in browser console**

Open `http://localhost:8080`, then in the browser console:

```js
import('./js/qr.js').then(async m => {
    const canvas = document.createElement('canvas');
    document.body.appendChild(canvas);
    await m.renderQR('https://example.com', canvas);
    console.log('QR rendered, size:', canvas.width);
});
```

Expected: A QR code appears on the page, console logs the size.

- [ ] **Step 3: Commit**

```bash
git add js/qr.js
git commit -m "feat: implement QR code generation module"
```

---

### Task 8: Main App Logic — Wire Everything Together

**Files:**
- Modify: `js/app.js`

- [ ] **Step 1: Implement the main app module**

Replace the contents of `js/app.js` with:

```js
import { listScripts, fetchScript, wordCount, estimateReadTime } from './github.js';
import { stripMarkdown } from './markdown.js';
import { Teleprompter } from './teleprompter.js';
import { createRoom, broadcastState, onCommand } from './sync.js';
import { renderQR } from './qr.js';

var DEFAULTS = {
    repo: 'sebastianmaniak/web-telepromotor',
    speed: 150,
    timerSeconds: 300,
    fontSize: 32
};

var state = {
    repo: localStorage.getItem('tp_repo') || DEFAULTS.repo,
    speed: parseInt(localStorage.getItem('tp_speed')) || DEFAULTS.speed,
    timerSeconds: parseInt(localStorage.getItem('tp_timer')) || DEFAULTS.timerSeconds,
    fontSize: parseInt(localStorage.getItem('tp_fontSize')) || DEFAULTS.fontSize,
    selectedScript: null,
    scripts: [],
    teleprompter: null
};

// DOM references — Selection screen
var repoInput = document.getElementById('repo-input');
var loadBtn = document.getElementById('load-btn');
var scriptList = document.getElementById('script-list');
var speedValue = document.getElementById('speed-value');
var timerValue = document.getElementById('timer-value');
var fontSizeValue = document.getElementById('fontSize-value');
var startBtn = document.getElementById('start-btn');
var remoteLinkBtn = document.getElementById('remote-link-btn');
var qrCanvas = document.getElementById('qr-canvas');
var roomCodeDisplay = document.getElementById('room-code-display');

// DOM references — Teleprompter screen
var selectionScreen = document.getElementById('selection-screen');
var teleprompterScreen = document.getElementById('teleprompter-screen');
var textContainer = document.getElementById('text-container');
var textContent = document.getElementById('text-content');
var timerDisplay = document.getElementById('timer-display');
var controlBar = document.getElementById('control-bar');
var playPauseBtn = document.getElementById('play-pause-btn');
var restartBtn = document.getElementById('restart-btn');
var speedSlider = document.getElementById('speed-slider');
var progressDisplay = document.getElementById('progress-display');

function formatTimer(seconds) {
    var m = Math.floor(seconds / 60);
    var s = seconds % 60;
    return m + ':' + (s < 10 ? '0' : '') + s;
}

function saveSettings() {
    localStorage.setItem('tp_repo', state.repo);
    localStorage.setItem('tp_speed', state.speed);
    localStorage.setItem('tp_timer', state.timerSeconds);
    localStorage.setItem('tp_fontSize', state.fontSize);
}

function updateSettingsUI() {
    speedValue.textContent = state.speed;
    timerValue.textContent = formatTimer(state.timerSeconds);
    fontSizeValue.textContent = state.fontSize;
    speedSlider.value = state.speed;
}

function showScreen(name) {
    selectionScreen.classList.toggle('active', name === 'selection');
    teleprompterScreen.classList.toggle('active', name === 'teleprompter');
}

// --- Script Loading ---

function setScriptListMessage(msg) {
    while (scriptList.firstChild) {
        scriptList.removeChild(scriptList.firstChild);
    }
    var p = document.createElement('p');
    p.className = 'empty-message';
    p.textContent = msg;
    scriptList.appendChild(p);
}

async function loadScripts() {
    var parts = state.repo.split('/');
    if (parts.length !== 2) {
        setScriptListMessage('Invalid format. Use owner/repo');
        return;
    }
    var owner = parts[0];
    var repo = parts[1];

    setScriptListMessage('Loading...');
    startBtn.disabled = true;
    state.selectedScript = null;

    try {
        var scripts = await listScripts(owner, repo);
        state.scripts = scripts;

        if (scripts.length === 0) {
            setScriptListMessage('No .md files found in scripts/ folder');
            return;
        }

        while (scriptList.firstChild) {
            scriptList.removeChild(scriptList.firstChild);
        }

        for (var i = 0; i < scripts.length; i++) {
            var script = scripts[i];
            var content = await fetchScript(owner, repo, script.filename);
            var words = wordCount(stripMarkdown(content));
            var readTime = estimateReadTime(words);

            var div = document.createElement('div');
            div.className = 'script-item';
            div.dataset.filename = script.filename;

            var nameDiv = document.createElement('div');
            nameDiv.className = 'script-item-name';
            nameDiv.textContent = script.name;
            div.appendChild(nameDiv);

            var metaDiv = document.createElement('div');
            metaDiv.className = 'script-item-meta';
            metaDiv.textContent = script.filename + ' · ' + words.toLocaleString() + ' words · ' + readTime;
            div.appendChild(metaDiv);

            div.addEventListener('click', (function(filename, el) {
                return function() { selectScript(filename, el); };
            })(script.filename, div));

            scriptList.appendChild(div);
        }
    } catch (err) {
        setScriptListMessage(err.message);
    }
}

function selectScript(filename, el) {
    var items = document.querySelectorAll('.script-item');
    for (var i = 0; i < items.length; i++) {
        items[i].classList.remove('selected');
    }
    el.classList.add('selected');
    state.selectedScript = filename;
    startBtn.disabled = false;
}

// --- Settings Adjustment ---

var settingConfig = {
    speed: { min: 50, max: 400, step: 10, get: function() { return state.speed; }, set: function(v) { state.speed = v; } },
    timer: { min: 30, max: 1800, step: 30, get: function() { return state.timerSeconds; }, set: function(v) { state.timerSeconds = v; } },
    fontSize: { min: 20, max: 64, step: 2, get: function() { return state.fontSize; }, set: function(v) { state.fontSize = v; } }
};

var adjustBtns = document.querySelectorAll('.btn-adjust');
for (var i = 0; i < adjustBtns.length; i++) {
    adjustBtns[i].addEventListener('click', function() {
        var setting = this.dataset.setting;
        var dir = parseInt(this.dataset.dir);
        var cfg = settingConfig[setting];
        if (!cfg) return;
        var newVal = Math.max(cfg.min, Math.min(cfg.max, cfg.get() + dir * cfg.step));
        cfg.set(newVal);
        saveSettings();
        updateSettingsUI();
    });
}

// --- Teleprompter Start ---

async function startTeleprompter() {
    var parts = state.repo.split('/');
    var owner = parts[0];
    var repo = parts[1];

    var rawContent = await fetchScript(owner, repo, state.selectedScript);
    var plainText = stripMarkdown(rawContent);
    var scriptName = state.selectedScript.replace(/\.md$/, '').replace(/[-_]/g, ' ').replace(/\b\w/g, function(c) { return c.toUpperCase(); });

    state.teleprompter = new Teleprompter(textContainer, textContent, {
        speed: state.speed,
        fontSize: state.fontSize,
        timerDuration: state.timerSeconds,
        onStateChange: handleStateChange
    });

    state.teleprompter.load(plainText, scriptName);
    state.teleprompter.setupTouchHandlers();

    showScreen('teleprompter');
    state.teleprompter.play();
    resetAutoHide();
}

// --- Teleprompter UI Updates ---

var autoHideTimeout = null;

function handleStateChange(tpState) {
    timerDisplay.textContent = tpState.timerDisplay;
    timerDisplay.classList.toggle('warning', tpState.timerRemaining <= 30 && tpState.timerRemaining > 0);
    timerDisplay.classList.toggle('expired', tpState.timerRemaining === 0);

    playPauseBtn.textContent = tpState.playing ? '⏸' : '▶';
    speedSlider.value = tpState.speed;
    progressDisplay.textContent = Math.round(tpState.progress * 100) + '%';

    broadcastState(tpState);
}

function resetAutoHide() {
    controlBar.classList.remove('auto-hidden');
    timerDisplay.classList.remove('auto-hidden');
    clearTimeout(autoHideTimeout);
    autoHideTimeout = setTimeout(function() {
        controlBar.classList.add('auto-hidden');
        timerDisplay.classList.add('auto-hidden');
    }, 3000);
}

teleprompterScreen.addEventListener('click', function(e) {
    if (e.target.closest('.control-bar')) return;
    resetAutoHide();
});

// --- Teleprompter Controls ---

playPauseBtn.addEventListener('click', function() {
    if (!state.teleprompter) return;
    if (state.teleprompter.playing) {
        state.teleprompter.pause();
    } else {
        state.teleprompter.play();
    }
    resetAutoHide();
});

restartBtn.addEventListener('click', function() {
    if (!state.teleprompter) return;
    state.teleprompter.restart();
    state.teleprompter.play();
    resetAutoHide();
});

speedSlider.addEventListener('input', function() {
    if (!state.teleprompter) return;
    state.teleprompter.setSpeed(parseInt(speedSlider.value));
    resetAutoHide();
});

// --- Remote Control ---

remoteLinkBtn.addEventListener('click', async function() {
    var code = await createRoom();
    var baseUrl = window.location.href.replace(/\/[^/]*$/, '');
    var remoteUrl = baseUrl + '/remote.html?room=' + code;

    roomCodeDisplay.textContent = code;
    roomCodeDisplay.classList.remove('hidden');
    qrCanvas.classList.remove('hidden');

    await renderQR(remoteUrl, qrCanvas);

    onCommand(function(cmd) {
        if (state.teleprompter) {
            state.teleprompter.applyCommand(cmd);
        }
    });
});

// --- Init ---

repoInput.value = state.repo;
updateSettingsUI();

loadBtn.addEventListener('click', function() {
    state.repo = repoInput.value.trim();
    saveSettings();
    loadScripts();
});

startBtn.addEventListener('click', startTeleprompter);

if (state.repo) {
    loadScripts();
}
```

- [ ] **Step 2: Test full flow in browser**

Run: `python3 -m http.server 8080`

Open `http://localhost:8080`. Verify:
1. Repo field shows `sebastianmaniak/web-telepromotor`, scripts load (once pushed to GitHub)
2. Clicking a script highlights it, enables the Start button
3. Settings +/- buttons change values, persist after page refresh
4. Tapping Start opens the teleprompter view with scrolling text
5. Play/pause, restart, speed slider all work
6. Timer counts down and shows warning/expired states
7. Controls auto-hide after 3 seconds, tap to show

- [ ] **Step 3: Commit**

```bash
git add js/app.js
git commit -m "feat: wire up main app logic with all modules"
```

---

### Task 9: End-to-End Testing & Polish

**Files:**
- Possibly modify: any file for bug fixes

- [ ] **Step 1: Push to GitHub and enable GitHub Pages**

```bash
git push origin main
```

Then go to GitHub repo > Settings > Pages > Source: Deploy from branch > Branch: `main`, folder: `/ (root)` > Save.

Wait ~1 minute for the site to deploy at `https://sebastianmaniak.github.io/web-telepromotor/`.

- [ ] **Step 2: Configure Supabase**

1. Go to `https://supabase.com` and create a free project (or use an existing one)
2. Go to Settings > API > copy the **Project URL** and **anon public** key
3. Update `js/sync.js` — replace `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_ANON_KEY` with the real values
4. Commit and push:

```bash
git add js/sync.js
git commit -m "feat: configure Supabase credentials"
git push origin main
```

- [ ] **Step 3: Test on GitHub Pages**

Open `https://sebastianmaniak.github.io/web-telepromotor/` on a tablet or phone. Verify:
1. Scripts load from the repo
2. Selecting a script and starting works
3. Scrolling is smooth
4. Timer counts down
5. Controls work (pause/play, speed, restart)
6. Controls auto-hide and reappear on tap

- [ ] **Step 4: Test remote control**

1. Open the app on device A (tablet)
2. Tap "Open Remote Control" — QR code and room code appear
3. Scan QR with device B (phone) — or open the URL manually
4. Enter room code on device B if not auto-connected
5. Verify: play/pause from device B controls device A
6. Verify: speed changes on device B reflect on device A
7. Verify: restart from device B works

- [ ] **Step 5: Test edge cases**

1. Enter an invalid repo name — verify clear error message
2. Enter a repo with no `scripts/` folder — verify 404 message
3. Let timer reach 0:00 — verify flash animation, scrolling continues
4. Manually swipe during auto-scroll — verify auto-scroll pauses then resumes
5. Tap "Flip" on remote — verify text mirrors horizontally
6. Refresh page — verify settings persist from localStorage

- [ ] **Step 6: Fix any issues found and commit**

```bash
git add -A
git commit -m "fix: address issues found during end-to-end testing"
git push origin main
```

---

### Task 10: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write README**

Replace `README.md` contents with:

```
# Web Teleprompter

A simple, free teleprompter web app. Black screen, scrolling text, configurable speed and timer. Control from a second device.

Live: https://sebastianmaniak.github.io/web-telepromotor/

## Adding Scripts

Put markdown files in the scripts/ folder:

    scripts/
      my-speech.md
      keynote.md

Push to GitHub. The app loads them automatically.

## Features

- Black screen with smooth scrolling text
- Adjustable scroll speed (words per minute)
- Countdown timer with visual alerts
- Remote control from a second device (phone controls tablet)
- Mirror/flip mode for beam splitter setups
- Works on phones and tablets
- Settings persist between sessions

## Remote Control

1. Open the app on your main device
2. Tap "Open Remote Control"
3. Scan the QR code with your second device
4. Control playback from the second device

## Hosting

Hosted on GitHub Pages. Fork the repo and enable GitHub Pages to run your own.
```

- [ ] **Step 2: Commit and push**

```bash
git add README.md
git commit -m "docs: add README with usage instructions"
git push origin main
```
