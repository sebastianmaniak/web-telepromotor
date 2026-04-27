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

    showScreen('teleprompter');

    state.teleprompter.load(plainText, scriptName);
    state.teleprompter.setupTouchHandlers();
    state.teleprompter.play();
    resetAutoHide();
}

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
