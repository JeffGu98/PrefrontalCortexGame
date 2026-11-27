export type Rng = () => number;

export function shuffleArray<T>(items: T[], rng: Rng = Math.random): T[] {
  const arr = [...items];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

export function randInt(min: number, max: number, rng: Rng = Math.random): number {
  return min + Math.floor(rng() * (max - min + 1));
}

/** Derangement of 0..n-1 so no index stays in place (Stroop.gd _derange) */
export function derange(n: number, rng: Rng = Math.random): number[] {
  const idx = Array.from({ length: n }, (_, i) => i);
  for (let attempt = 0; attempt < 32; attempt++) {
    const cand = shuffleArray(idx, rng);
    if (cand.every((v, i) => v !== i)) return cand;
  }
  if (n >= 2) {
    const out = [...idx];
    const tmp = out[0];
    out[0] = out[1];
    out[1] = tmp;
    return out;
  }
  return idx;
}

export interface StroopColor {
  name: string;
  color: string;
}

export const STROOP_COLORS: StroopColor[] = [
  { name: '红', color: '#ff5d73' },
  { name: '蓝', color: '#5d9bff' },
  { name: '绿', color: '#4ade80' },
  { name: '黄', color: '#ffd75d' },
];

export interface StroopTrial {
  wordName: string;
  inkColor: string;
  correctName: string;
  congruent: boolean;
  choices: { name: string; bg: string }[];
}

export function generateStroopTrial(
  easyMode: boolean,
  congruentRatio = 0.12,
  rng: Rng = Math.random
): StroopTrial {
  const inkIdx = Math.floor(rng() * STROOP_COLORS.length);
  const congruent = rng() < congruentRatio;
  let wordIdx = inkIdx;
  if (!congruent) {
    const offset = Math.floor(rng() * (STROOP_COLORS.length - 1)) + 1;
    wordIdx = (inkIdx + offset) % STROOP_COLORS.length;
  }
  const namesOrder = shuffleArray([0, 1, 2, 3], rng);
  const bgs = derange(STROOP_COLORS.length, rng);
  const choices = namesOrder.map((nameIdx) => ({
    name: STROOP_COLORS[nameIdx].name,
    bg: easyMode ? '#c5cdd8' : STROOP_COLORS[bgs[nameIdx]].color,
  }));
  return {
    wordName: STROOP_COLORS[wordIdx].name,
    inkColor: STROOP_COLORS[inkIdx].color,
    correctName: STROOP_COLORS[inkIdx].name,
    congruent,
    choices,
  };
}

export function calcStroopPoints(timeLeft: number, trialLimit: number, streak: number): number {
  const timeBonus = Math.floor((timeLeft / Math.max(trialLimit, 0.01)) * 5);
  return 10 + timeBonus + Math.min(streak, 10) * 2;
}

/** Schulte grid permutation 1..size^2 */
export function generateSchulteGrid(size: number, rng: Rng = Math.random): number[] {
  const total = size * size;
  const nums = Array.from({ length: total }, (_, i) => i + 1);
  return shuffleArray(nums, rng);
}

/** Bridson Poisson-disc point scatter (Dots.gd) */
export interface Point2D {
  x: number;
  y: number;
}

export function dotRadiusFor(count: number, width: number, height: number): number {
  const usable = Math.max((width - 48) * (height - 48), 1);
  const r = Math.sqrt(usable / Math.max(count, 1)) / 6.5;
  return Math.max(9, Math.min(14, r));
}

export function scatterDots(
  count: number,
  width: number,
  height: number,
  radius: number,
  rng: Rng = Math.random
): Point2D[] {
  let inset = radius + 14 + 2 + 4;
  let uw = width - inset * 2;
  let uh = height - inset * 2;
  if (uw < radius * 2 || uh < radius * 2) {
    inset = radius + 6;
    uw = Math.max(width - inset * 2, 2);
    uh = Math.max(height - inset * 2, 2);
  }
  if (uw <= radius || uh <= radius) {
    return [{ x: width * 0.5, y: height * 0.5 }];
  }

  const ideal = Math.sqrt((uw * uh) / Math.max(count, 1));
  let minDist = Math.max(radius * 3.8, ideal * 0.78);
  const floorDist = radius * 3.2;

  const bridson = (dist: number): Point2D[] => {
    const cell = dist / Math.SQRT2;
    const gw = Math.max(Math.ceil(uw / cell), 1);
    const gh = Math.max(Math.ceil(uh / cell), 1);
    const grid = new Int32Array(gw * gh).fill(-1);
    const points: Point2D[] = [];
    const put = (p: Point2D, idx: number) => {
      const gx = Math.max(0, Math.min(gw - 1, Math.floor((p.x - inset) / cell)));
      const gy = Math.max(0, Math.min(gh - 1, Math.floor((p.y - inset) / cell)));
      grid[gy * gw + gx] = idx;
    };
    const isOpen = (p: Point2D) => {
      const gx = Math.max(0, Math.min(gw - 1, Math.floor((p.x - inset) / cell)));
      const gy = Math.max(0, Math.min(gh - 1, Math.floor((p.y - inset) / cell)));
      for (let iy = Math.max(gy - 2, 0); iy < Math.min(gy + 3, gh); iy++) {
        for (let ix = Math.max(gx - 2, 0); ix < Math.min(gx + 3, gw); ix++) {
          const id = grid[iy * gw + ix];
          if (id >= 0) {
            const dx = p.x - points[id].x;
            const dy = p.y - points[id].y;
            if (dx * dx + dy * dy < dist * dist) return false;
          }
        }
      }
      return true;
    };

    const first: Point2D = { x: inset + rng() * uw, y: inset + rng() * uh };
    points.push(first);
    put(first, 0);
    const active = [0];

    while (points.length < count && active.length > 0) {
      const ai = Math.floor(rng() * active.length);
      const origin = points[active[ai]];
      let placed = false;
      for (let t = 0; t < 30; t++) {
        const ang = rng() * Math.PI * 2;
        const rad = dist * (1 + rng());
        const cand: Point2D = {
          x: origin.x + Math.cos(ang) * rad,
          y: origin.y + Math.sin(ang) * rad,
        };
        if (cand.x < inset || cand.y < inset || cand.x > inset + uw || cand.y > inset + uh) {
          continue;
        }
        if (!isOpen(cand)) continue;
        put(cand, points.length);
        active.push(points.length);
        points.push(cand);
        placed = true;
        break;
      }
      if (!placed) active.splice(ai, 1);
    }
    return points;
  };

  for (let pass = 0; pass < 10; pass++) {
    const pts = bridson(minDist);
    if (pts.length >= count) return pts.slice(0, count);
    if (minDist <= floorDist + 0.5) break;
    minDist = Math.max(floorDist, minDist * 0.9);
  }

  // Dart fill fallback
  const points: Point2D[] = [];
  let attempts = 0;
  while (points.length < count && attempts < count * 400) {
    attempts++;
    const p: Point2D = { x: inset + rng() * uw, y: inset + rng() * uh };
    const ok = points.every((q) => Math.hypot(p.x - q.x, p.y - q.y) >= floorDist);
    if (ok) points.push(p);
  }
  while (points.length < count) {
    points.push({ x: inset + rng() * uw, y: inset + rng() * uh });
  }
  return points;
}

/** N-Back position picker (NBack.gd _pick_position) */
export function pickNBackPosition(
  history: number[],
  nLevel: number,
  cellCount = 9,
  matchRatio = 0.3,
  rng: Rng = Math.random
): { pos: number; isMatch: boolean } {
  if (history.length < nLevel) {
    return { pos: Math.floor(rng() * cellCount), isMatch: false };
  }
  const target = history[history.length - nLevel];
  if (rng() < matchRatio) {
    return { pos: target, isMatch: true };
  }
  let pick = Math.floor(rng() * (cellCount - 1));
  if (pick >= target) pick += 1;
  return { pos: pick, isMatch: false };
}

/** Switch rule evaluator (Switch.gd) */
export type SwitchRule = 0 | 1; // 0 = ODD_EVEN, 1 = HIGH_LOW

export function switchCorrectSide(rule: SwitchRule, num: number): 0 | 1 {
  if (rule === 0) return num % 2 === 1 ? 0 : 1;
  return num < 5 ? 0 : 1;
}

/** Hanoi helpers (Hanoi.gd) */
export function hanoiOptimal(n: number): number {
  return (1 << n) - 1;
}

export function hanoiMoveLimit(n: number, overFactor = 1.5): number {
  return Math.ceil(hanoiOptimal(n) * overFactor);
}

export function canMoveHanoiDisk(pegs: number[][], from: number, to: number): boolean {
  if (from === to || pegs[from].length === 0) return false;
  const moving = pegs[from][pegs[from].length - 1];
  const dest = pegs[to];
  if (dest.length > 0 && moving > dest[dest.length - 1]) return false;
  return true;
}

export function solveHanoi(n: number, src = 0, dst = 2, aux = 1): [number, number][] {
  const out: [number, number][] = [];
  const rec = (k: number, s: number, d: number, a: number) => {
    if (k <= 0) return;
    if (k === 1) {
      out.push([s, d]);
      return;
    }
    rec(k - 1, s, a, d);
    out.push([s, d]);
    rec(k - 1, a, d, s);
  };
  rec(n, src, dst, aux);
  return out;
}

/** Corsi sequence generator (no immediate repeat) */
export function makeCorsiSequence(span: number, cellCount = 9, rng: Rng = Math.random): number[] {
  const seq: number[] = [];
  let last = -1;
  for (let i = 0; i < span; i++) {
    let pick = Math.floor(rng() * cellCount);
    let guard = 0;
    while (pick === last && guard < 8) {
      pick = Math.floor(rng() * cellCount);
      guard++;
    }
    seq.push(pick);
    last = pick;
  }
  return seq;
}

/** RuleShift card & 3-pile builder (with shuffled pile positions so position cannot be cheesed) */
export interface RuleCard {
  color: number;
  shape: number;
  count: number;
}

export function buildRuleShiftTrial(
  rule: 0 | 1 | 2,
  rng: Rng = Math.random
): { stim: RuleCard; choices: RuleCard[]; correctPile: number } {
  const stim: RuleCard = {
    color: Math.floor(rng() * 3),
    shape: Math.floor(rng() * 3),
    count: Math.floor(rng() * 3),
  };
  const keys: (keyof RuleCard)[] = ['color', 'shape', 'count'];
  const byDim: { dim: number; card: RuleCard }[] = [0, 1, 2].map((dim) => {
    const c: RuleCard = { ...stim };
    for (let other = 0; other < 3; other++) {
      if (other === dim) continue;
      const cur = c[keys[other]];
      const vals = [0, 1, 2].filter((v) => v !== cur);
      c[keys[other]] = vals[Math.floor(rng() * vals.length)];
    }
    return { dim, card: c };
  });
  const shuffled = shuffleArray(byDim, rng);
  const correctPile = shuffled.findIndex((item) => item.dim === rule);
  return {
    stim,
    choices: shuffled.map((item) => item.card),
    correctPile,
  };
}

/** RunningSpan stream & target builder (RunningSpan.gd) */
export function buildRunningSpanStream(
  span: number,
  extraMin = 1,
  extraMax = 3,
  rng: Rng = Math.random
): { stream: number[]; target: number[] } {
  const extra = randInt(extraMin, extraMax, rng);
  const total = span + extra;
  const stream: number[] = [];
  let last = -1;
  for (let i = 0; i < total; i++) {
    let pick = randInt(1, 9, rng);
    let guard = 0;
    while (pick === last && guard < 8) {
      pick = randInt(1, 9, rng);
      guard++;
    }
    stream.push(pick);
    last = pick;
  }
  const target = stream.slice(stream.length - span);
  return { stream, target };
}

/** SelfOrder helpers (SelfOrder.gd) */
export function selfOrderColumns(n: number): number {
  if (n <= 4) return 2;
  if (n === 8) return 4;
  if (n <= 9) return 3;
  return 4;
}

export interface SlotRect {
  x: number;
  y: number;
  size: number;
}

export function selfOrderSlotRects(n: number, side: number): SlotRect[] {
  const cols = selfOrderColumns(n);
  const rows = Math.ceil(n / cols);
  const gap = 12;
  const cell = Math.min((side - gap * (cols - 1)) / cols, (side - gap * (rows - 1)) / rows);
  const gridW = cols * cell + gap * (cols - 1);
  const gridH = rows * cell + gap * (rows - 1);
  const originX = (side - gridW) / 2;
  const originY = (side - gridH) / 2;
  const out: SlotRect[] = [];
  for (let i = 0; i < n; i++) {
    const r = Math.floor(i / cols);
    const c = i % cols;
    const rowCount = r < rows - 1 ? cols : n - r * cols;
    const rowW = rowCount * cell + gap * (rowCount - 1);
    const xOff = (gridW - rowW) / 2;
    out.push({
      x: originX + xOff + c * (cell + gap),
      y: originY + r * (cell + gap),
      size: cell,
    });
  }
  return out;
}

export function selfOrderShuffledSlots(
  n: number,
  previous: number[],
  rng: Rng = Math.random
): number[] {
  const base = Array.from({ length: n }, (_, i) => i);
  if (n <= 1) return base;
  for (let attempt = 0; attempt < 16; attempt++) {
    const ids = shuffleArray(base, rng);
    let moved = 0;
    if (previous.length === n) {
      for (let i = 0; i < n; i++) {
        if (ids[i] !== previous[i]) moved++;
      }
    } else {
      moved = n;
    }
    if (moved >= Math.max(Math.floor(n / 2), 1)) return ids;
  }
  if (previous.length === n && n >= 2) {
    const out = [...previous];
    const tmp = out[0];
    out[0] = out[1];
    out[1] = tmp;
    return out;
  }
  return base;
}
