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
