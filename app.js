/**
 * Web Teleprompter – app.js
 *
 * State machine:
 *   setup  ──► prompting (play) ──► paused ──► prompting (play) ──► setup
 *
 * Scroll is driven by requestAnimationFrame; speed is pixels-per-second.
 */

(function () {
  'use strict';

  /* ── DOM refs ── */
  const setupScreen      = document.getElementById('setup-screen');
  const prompterScreen   = document.getElementById('prompter-screen');
  const scriptInput      = document.getElementById('script-input');
  const startBtn         = document.getElementById('start-btn');
  const backBtn          = document.getElementById('back-btn');
  const playPauseBtn     = document.getElementById('play-pause-btn');
  const mirrorBtn        = document.getElementById('mirror-btn');
  const fullscreenBtn    = document.getElementById('fullscreen-btn');
  const controlsBar      = document.getElementById('controls-bar');
  const prompterText     = document.getElementById('prompter-text');
  const prompterViewport = document.getElementById('prompter-viewport');

  const fontSizeSetup    = document.getElementById('font-size-setup');
  const fontSizeLabel    = document.getElementById('font-size-label');
  const fontSizePrompter = document.getElementById('font-size-prompter');
  const fontSizePLabel   = document.getElementById('font-size-prompter-label');

  const speedSetup       = document.getElementById('speed-setup');
  const speedLabel       = document.getElementById('speed-label');
  const speedPrompter    = document.getElementById('speed-prompter');
  const speedPLabel      = document.getElementById('speed-prompter-label');

  const mirrorSetup      = document.getElementById('mirror-setup');

  /* ── Constants ── */
  const SPEED_MULTIPLIER    = 30;  // pixels-per-second per speed unit (30–300 px/s range)
  const CONTROLS_HIDE_DELAY = 3000; // ms before controls bar auto-hides during playback

  /* ── State ── */
  let isPlaying   = false;
  let isMirrored  = false;
  let fontSize    = 40;      // px
  let speed       = 3;       // 1–10 range value
  let scrollY     = 0;       // current scroll position in px
  let lastTime    = null;
  let rafId       = null;
  let hideTimer   = null;

  /* pixels-per-second for a given speed value (1–10) */
  function pxPerSec(s) {
    return s * SPEED_MULTIPLIER;
  }

  /* ── Setup screen controls ── */
  fontSizeSetup.addEventListener('input', () => {
    fontSize = parseInt(fontSizeSetup.value, 10);
    fontSizeLabel.textContent = fontSize + 'px';
    // keep prompter slider in sync
    fontSizePrompter.value = fontSize;
    fontSizePLabel.textContent = fontSize + 'px';
  });

  speedSetup.addEventListener('input', () => {
    speed = parseInt(speedSetup.value, 10);
    speedLabel.textContent = speed;
    speedPrompter.value = speed;
    speedPLabel.textContent = speed;
  });

  mirrorSetup.addEventListener('change', () => {
    isMirrored = mirrorSetup.checked;
    applyMirror();
  });

  startBtn.addEventListener('click', startPrompter);

  /* ── Prompter controls ── */
  fontSizePrompter.addEventListener('input', () => {
    fontSize = parseInt(fontSizePrompter.value, 10);
    fontSizePLabel.textContent = fontSize + 'px';
    fontSizeSetup.value = fontSize;
    fontSizeLabel.textContent = fontSize + 'px';
    applyFontSize();
  });

  speedPrompter.addEventListener('input', () => {
    speed = parseInt(speedPrompter.value, 10);
    speedPLabel.textContent = speed;
    speedSetup.value = speed;
    speedLabel.textContent = speed;
  });

  playPauseBtn.addEventListener('click', togglePlayPause);

  backBtn.addEventListener('click', exitPrompter);

  mirrorBtn.addEventListener('click', () => {
    isMirrored = !isMirrored;
    mirrorSetup.checked = isMirrored;
    applyMirror();
  });

  fullscreenBtn.addEventListener('click', toggleFullscreen);

  document.addEventListener('fullscreenchange', updateFullscreenBtn);

  /* ── Keyboard shortcuts ── */
  document.addEventListener('keydown', (e) => {
    if (prompterScreen.classList.contains('active')) {
      if (e.code === 'Space') {
        e.preventDefault();
        togglePlayPause();
      } else if (e.code === 'ArrowUp') {
        e.preventDefault();
        speed = Math.min(10, speed + 1);
        syncSpeedControls();
      } else if (e.code === 'ArrowDown') {
        e.preventDefault();
        speed = Math.max(1, speed - 1);
        syncSpeedControls();
      } else if (e.code === 'Escape') {
        if (document.fullscreenElement) {
          document.exitFullscreen();
        } else {
          exitPrompter();
        }
      } else if (e.code === 'KeyM') {
        isMirrored = !isMirrored;
        mirrorSetup.checked = isMirrored;
        applyMirror();
      }
    }
  });

  /* Mouse movement shows controls bar temporarily */
  prompterScreen.addEventListener('mousemove', showControlsTemporarily);
  prompterScreen.addEventListener('touchstart', showControlsTemporarily, { passive: true });

  /* ── Core functions ── */

  function startPrompter() {
    const text = scriptInput.value.trim();
    if (!text) {
      scriptInput.focus();
      scriptInput.placeholder = '⚠ Please enter your script first…';
      return;
    }

    // Populate prompter text
    prompterText.textContent = text;

    // Apply current settings
    applyFontSize();
    applyMirror();
    syncSpeedControls();
    syncFontSizeControls();

    // Reset scroll
    scrollY = 0;
    prompterText.style.transform = 'translateY(0)';

    // Switch screens
    setupScreen.classList.remove('active');
    prompterScreen.classList.add('active');

    // Start playing
    isPlaying = false;
    play();
  }

  function exitPrompter() {
    pause();
    if (document.fullscreenElement) {
      document.exitFullscreen().catch(() => {});
    }
    prompterScreen.classList.remove('active');
    setupScreen.classList.add('active');
  }

  function play() {
    isPlaying = true;
    lastTime = null;
    playPauseBtn.textContent = '⏸ Pause';
    playPauseBtn.classList.remove('paused');
    rafId = requestAnimationFrame(scrollStep);
  }

  function pause() {
    isPlaying = false;
    playPauseBtn.textContent = '▶ Play';
    playPauseBtn.classList.add('paused');
    if (rafId) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
  }

  function togglePlayPause() {
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  function scrollStep(timestamp) {
    if (!isPlaying) return;

    if (lastTime === null) {
      lastTime = timestamp;
    }

    const delta = (timestamp - lastTime) / 1000; // seconds
    lastTime = timestamp;

    scrollY += pxPerSec(speed) * delta;

    // Clamp: stop at end of text
    const maxScroll = prompterText.scrollHeight - prompterViewport.clientHeight;
    if (scrollY >= maxScroll) {
      scrollY = maxScroll;
      prompterText.style.transform = `translateY(${-scrollY}px)`;
      pause();
      return;
    }

    prompterText.style.transform = `translateY(${-scrollY}px)`;
    rafId = requestAnimationFrame(scrollStep);
  }

  /* ── Helpers ── */

  function applyFontSize() {
    prompterText.style.fontSize = fontSize + 'px';
  }

  function applyMirror() {
    prompterText.classList.toggle('mirrored', isMirrored);
    mirrorBtn.style.background = isMirrored
      ? 'rgba(0,196,125,0.3)'
      : 'rgba(255,255,255,0.1)';
  }

  function syncSpeedControls() {
    speedPrompter.value = speed;
    speedPLabel.textContent = speed;
    speedSetup.value = speed;
    speedLabel.textContent = speed;
  }

  function syncFontSizeControls() {
    fontSizePrompter.value = fontSize;
    fontSizePLabel.textContent = fontSize + 'px';
    fontSizeSetup.value = fontSize;
    fontSizeLabel.textContent = fontSize + 'px';
  }

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      prompterScreen.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen().catch(() => {});
    }
  }

  function updateFullscreenBtn() {
    fullscreenBtn.textContent = document.fullscreenElement
      ? '⛶ Exit Full'
      : '⛶ Fullscreen';
  }

  function showControlsTemporarily() {
    controlsBar.classList.remove('hidden');
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => {
      if (isPlaying) {
        controlsBar.classList.add('hidden');
      }
    }, CONTROLS_HIDE_DELAY);
  }

  /* Prevent controls bar from auto-hiding when hovering over it */
  controlsBar.addEventListener('mouseenter', () => clearTimeout(hideTimer));
  controlsBar.addEventListener('mouseleave', showControlsTemporarily);
})();
