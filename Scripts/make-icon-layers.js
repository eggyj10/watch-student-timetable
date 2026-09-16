// Renders the transparent foreground layers for the Icon Composer .icon bundle.
// Same geometry as the flat appiconset icon, but split into two layers so the
// system can light them independently.

const fs = require("fs");
const zlib = require("zlib");

const SIZE = 1024;
const SS = 4; // heavier supersampling: these edges are the whole design

const MARGIN = 196;
const GAP = 40;
const COLS = 2;
const ROWS = 3;
const AREA = SIZE - MARGIN * 2;
const CELL_W = (AREA - GAP * (COLS - 1)) / COLS;
const CELL_H = (AREA - GAP * (ROWS - 1)) / ROWS;
const RADIUS = 34;
const HIGHLIGHT = { row: 1, col: 0 };

function cellsFor(which) {
  const out = [];
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const lit = r === HIGHLIGHT.row && c === HIGHLIGHT.col;
      if (which === "lit" && !lit) continue;
      if (which === "plain" && lit) continue;
      out.push({
        x: MARGIN + c * (CELL_W + GAP),
        y: MARGIN + r * (CELL_H + GAP),
        w: CELL_W,
        h: CELL_H,
      });
    }
  }
  return out;
}

function inside(px, py, r) {
  const { x, y, w, h } = r;
  if (px < x || py < y || px > x + w || py > y + h) return false;
  const dx = Math.min(px - x, x + w - px);
  const dy = Math.min(py - y, y + h - py);
  if (dx >= RADIUS || dy >= RADIUS) return true;
  const cx = dx < RADIUS ? RADIUS - dx : 0;
  const cy = dy < RADIUS ? RADIUS - dy : 0;
  return cx * cx + cy * cy <= RADIUS * RADIUS;
}

// --- PNG with alpha -------------------------------------------------------

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

const crc32 = (buf) => {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function writeRGBA(path, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(SIZE, 0);
  ihdr.writeUInt32BE(SIZE, 4);
  ihdr[8] = 8;
  ihdr[9] = 6; // truecolour with alpha
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(rgba, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
  fs.writeFileSync(path, png);
  return png.length;
}

function render(path, which, colour, alpha) {
  const cells = cellsFor(which);
  const raw = Buffer.alloc((SIZE * 4 + 1) * SIZE);
  let p = 0;
  for (let y = 0; y < SIZE; y++) {
    raw[p++] = 0;
    for (let x = 0; x < SIZE; x++) {
      let cov = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const px = x + (sx + 0.5) / SS;
          const py = y + (sy + 0.5) / SS;
          if (cells.some((c) => inside(px, py, c))) cov++;
        }
      }
      cov /= SS * SS;
      // Straight (unpremultiplied) alpha: colour stays constant, coverage
      // drives alpha, so edges antialias against whatever is behind.
      raw[p++] = colour[0];
      raw[p++] = colour[1];
      raw[p++] = colour[2];
      raw[p++] = Math.round(cov * alpha * 255);
    }
  }
  const bytes = writeRGBA(path, raw);
  console.log(`${path}  ${SIZE}x${SIZE} RGBA  ${(bytes / 1024).toFixed(1)} KB  ${cells.length} tile(s)`);
}

const dir = process.argv[2];
render(`${dir}/grid.png`, "plain", [255, 255, 255], 0.9);
render(`${dir}/now.png`, "lit", [255, 192, 67], 1.0);
