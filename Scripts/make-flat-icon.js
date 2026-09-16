// Renders the 1024x1024 app icon as a PNG, with no image libraries.
// A timetable grid on a blue gradient, one cell lit up as "now".

const fs = require("fs");
const zlib = require("zlib");

const SIZE = 1024;
const SS = 2; // supersampling factor per axis, for smooth corners

// --- geometry -------------------------------------------------------------

const MARGIN = 196;
const GAP = 40;
const COLS = 2;
const ROWS = 3;
const AREA = SIZE - MARGIN * 2;
const CELL_W = (AREA - GAP * (COLS - 1)) / COLS;
const CELL_H = (AREA - GAP * (ROWS - 1)) / ROWS;
const RADIUS = 34;

// The lit cell: second row, first column.
const HIGHLIGHT = { row: 1, col: 0 };

const cells = [];
for (let r = 0; r < ROWS; r++) {
  for (let c = 0; c < COLS; c++) {
    cells.push({
      x: MARGIN + c * (CELL_W + GAP),
      y: MARGIN + r * (CELL_H + GAP),
      w: CELL_W,
      h: CELL_H,
      lit: r === HIGHLIGHT.row && c === HIGHLIGHT.col,
    });
  }
}

function insideRoundedRect(px, py, r) {
  const { x, y, w, h } = r;
  if (px < x || py < y || px > x + w || py > y + h) return false;
  const dx = Math.min(px - x, x + w - px);
  const dy = Math.min(py - y, y + h - py);
  if (dx >= RADIUS || dy >= RADIUS) return true;
  const cx = dx < RADIUS ? RADIUS - dx : 0;
  const cy = dy < RADIUS ? RADIUS - dy : 0;
  return cx * cx + cy * cy <= RADIUS * RADIUS;
}

// --- colour ---------------------------------------------------------------

const BG_TOP = [11, 42, 77];      // #0B2A4D
const BG_BOTTOM = [26, 106, 178]; // #1A6AB2
const CELL_TINT = [255, 255, 255];
const CELL_ALPHA = 0.2;
const LIT = [255, 192, 67];       // #FFC043

const mix = (a, b, t) => a + (b - a) * t;

function background(x, y) {
  // Diagonal so the icon has some life at small sizes.
  const t = Math.min(1, Math.max(0, (x * 0.35 + y * 0.65) / SIZE));
  return [
    mix(BG_TOP[0], BG_BOTTOM[0], t),
    mix(BG_TOP[1], BG_BOTTOM[1], t),
    mix(BG_TOP[2], BG_BOTTOM[2], t),
  ];
}

// --- render ---------------------------------------------------------------

const raw = Buffer.alloc((SIZE * 3 + 1) * SIZE);
let p = 0;

for (let y = 0; y < SIZE; y++) {
  raw[p++] = 0; // PNG filter: none
  for (let x = 0; x < SIZE; x++) {
    let r = 0, g = 0, b = 0;
    for (let sy = 0; sy < SS; sy++) {
      for (let sx = 0; sx < SS; sx++) {
        const px = x + (sx + 0.5) / SS;
        const py = y + (sy + 0.5) / SS;
        let [cr, cg, cb] = background(px, py);

        for (const cell of cells) {
          if (!insideRoundedRect(px, py, cell)) continue;
          if (cell.lit) {
            cr = LIT[0]; cg = LIT[1]; cb = LIT[2];
          } else {
            cr = mix(cr, CELL_TINT[0], CELL_ALPHA);
            cg = mix(cg, CELL_TINT[1], CELL_ALPHA);
            cb = mix(cb, CELL_TINT[2], CELL_ALPHA);
          }
          break;
        }
        r += cr; g += cg; b += cb;
      }
    }
    const n = SS * SS;
    raw[p++] = Math.round(r / n);
    raw[p++] = Math.round(g / n);
    raw[p++] = Math.round(b / n);
  }
}

// --- PNG container --------------------------------------------------------

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([length, body, crc]);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8;  // bit depth
ihdr[9] = 2;  // colour type 2 = truecolour, no alpha (required by the App Store)
ihdr[10] = 0; // deflate
ihdr[11] = 0; // adaptive filtering
ihdr[12] = 0; // no interlace

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr),
  chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
  chunk("IEND", Buffer.alloc(0)),
]);

const out = process.argv[2];
fs.writeFileSync(out, png);
console.log(`wrote ${out}  ${SIZE}x${SIZE}  ${(png.length / 1024).toFixed(1)} KB  no alpha channel`);
