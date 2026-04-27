import { listScripts, fetchScript } from './github.js';
import { stripMarkdown } from './markdown.js';
import { Teleprompter } from './teleprompter.js';
import { createRoom, onCommand } from './sync.js';
import { renderQR } from './qr.js';

console.log('Teleprompter app loaded');
