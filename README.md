# Web Teleprompter

A simple, free teleprompter web app. Black screen, scrolling text, configurable speed and timer. Control from a second device.

Live: https://sebastianmaniak.github.io/web-telepromotor/

The same `scripts/*.md` files are also pulled live by **SebbyCorp Notepad** on the reMarkable 2.

## Adding Scripts

Put markdown files in the `scripts/` folder:

    scripts/
      my-speech.md
      keynote.md

Push to GitHub. The web app and the tablet both load them automatically.

### Section buttons (reMarkable + iPhone remote)

Any `## Heading` in a script becomes a jump button on the phone remote (`http://172.16.10.212`). Spoken lines are `>` quotes. After you push a change, reopen the script on the tablet so it re-fetches.

```markdown
# Talk title          ← not a button
## Production notes   ← skipped (meta)
## The Hook           ← phone button
> Here's the first thing I say.
## The Big Idea       ← phone button
> Here's the next beat.
```

- `## SEGMENT 1 — The Hook` still works; the `SEGMENT ` prefix is stripped so the button reads `1 - The Hook`.
- Skipped headings: Production notes, Timing budget, Things to get right, anything with “checklist”.
- `# Title` and YouTube / Title-options tails are not buttons.

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
