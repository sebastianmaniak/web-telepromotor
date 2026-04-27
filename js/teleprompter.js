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
