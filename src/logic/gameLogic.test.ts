import test from 'node:test';
import assert from 'node:assert/strict';
import { GAMES, dailyIndex, todayKey } from '../data/games';
import {
  buildRuleShiftTrial,
  buildRunningSpanStream,
  calcStroopPoints,
  canMoveHanoiDisk,
  derange,
  generateSchulteGrid,
  generateStroopTrial,
  hanoiMoveLimit,
  hanoiOptimal,
  makeCorsiSequence,
  pickNBackPosition,
  scatterDots,
  selfOrderColumns,
  selfOrderShuffledSlots,
  selfOrderSlotRects,
  solveHanoi,
  switchCorrectSide,
} from './gameLogic';

test('Hub registry has 11 unique built games and deterministic dailyIndex', () => {
  assert.equal(GAMES.length, 11);
  const ids = new Set(GAMES.map((g) => g.id));
  assert.equal(ids.size, 11);
  assert.ok(GAMES.every((g) => g.built));
  const idxA = dailyIndex(11, '2026-11-26');
  const idxB = dailyIndex(11, '2026-11-26');
  assert.equal(idxA, idxB);
  assert.ok(idxA >= 0 && idxA < 11);
  assert.match(todayKey(new Date(2026, 10, 26)), /^2026-11-26$/);
});

test('Stroop derangement and trial generation respect ink/word rules', () => {
  for (let i = 0; i < 20; i++) {
    const d = derange(4);
    assert.equal(d.length, 4);
    assert.ok(d.every((v, idx) => v !== idx));
  }
  const hard = generateStroopTrial(false, 0);
  assert.equal(hard.congruent, false);
  assert.notEqual(hard.wordName, hard.correctName);
  assert.equal(hard.choices.length, 4);
  assert.ok(hard.choices.some((c) => c.name === hard.correctName));
  assert.equal(calcStroopPoints(2.5, 2.5, 3), 10 + 5 + 6);
});

test('Schulte grid contains exact 1..N^2 permutation', () => {
  const g5 = generateSchulteGrid(5);
  assert.equal(g5.length, 25);
  assert.deepEqual([...g5].sort((a, b) => a - b), Array.from({ length: 25 }, (_, i) => i + 1));
});

test('Dots Bridson scatter keeps all points inside bounds', () => {
  const pts = scatterDots(10, 360, 260, 11);
  assert.equal(pts.length, 10);
  for (const p of pts) {
    assert.ok(p.x >= 11 && p.x <= 349);
    assert.ok(p.y >= 11 && p.y <= 249);
  }
});

test('N-Back match detection works before and after N steps', () => {
  const early = pickNBackPosition([2], 2);
  assert.equal(early.isMatch, false);
  const forcedMatch = pickNBackPosition([4, 7], 2, 9, 1.0);
  assert.equal(forcedMatch.pos, 4);
  assert.equal(forcedMatch.isMatch, true);
  const forcedDiff = pickNBackPosition([4, 7], 2, 9, 0.0);
  assert.notEqual(forcedDiff.pos, 4);
  assert.equal(forcedDiff.isMatch, false);
});

test('Switch evaluator maps odd/even and low/high correctly', () => {
  assert.equal(switchCorrectSide(0, 3), 0);
  assert.equal(switchCorrectSide(0, 8), 1);
  assert.equal(switchCorrectSide(1, 2), 0);
  assert.equal(switchCorrectSide(1, 9), 1);
});

test('Hanoi optimal count, 1.5x limit, move rules, and solver', () => {
  assert.equal(hanoiOptimal(3), 7);
  assert.equal(hanoiMoveLimit(3), 11);
  assert.equal(hanoiOptimal(6), 63);
  const steps = solveHanoi(3);
  assert.equal(steps.length, 7);
  assert.equal(canMoveHanoiDisk([[3, 2], [1], []], 0, 1), false);
  assert.equal(canMoveHanoiDisk([[3, 2], [1], []], 1, 0), true);
  assert.equal(canMoveHanoiDisk([[3, 2], [1], []], 0, 2), true);
});

test('Corsi sequence avoids immediate repeats', () => {
  const seq = makeCorsiSequence(8);
  assert.equal(seq.length, 8);
  for (let i = 1; i < seq.length; i++) {
    assert.notEqual(seq[i], seq[i - 1]);
  }
});

test('RuleShift creates 3 choices each matching stim on exactly one dimension', () => {
  for (const rule of [0, 1, 2] as const) {
    const { stim, choices, correctPile } = buildRuleShiftTrial(rule);
    assert.equal(choices.length, 3);
    assert.ok(correctPile >= 0 && correctPile < 3);
    for (const c of choices) {
      const matches =
        (c.color === stim.color ? 1 : 0) +
        (c.shape === stim.shape ? 1 : 0) +
        (c.count === stim.count ? 1 : 0);
      assert.equal(matches, 1);
    }
    const keys = ['color', 'shape', 'count'] as const;
    assert.equal(choices[correctPile][keys[rule]], stim[keys[rule]]);
  }
});

test('RunningSpan stream ends with exact target and avoids immediate repeats', () => {
  const { stream, target } = buildRunningSpanStream(4, 1, 3);
  assert.ok(stream.length >= 5 && stream.length <= 7);
  assert.deepEqual(target, stream.slice(stream.length - 4));
  for (let i = 1; i < stream.length; i++) {
    assert.notEqual(stream[i], stream[i - 1]);
  }
});

test('SelfOrder grid columns, non-overlapping slots, and shuffle movement', () => {
  assert.equal(selfOrderColumns(4), 2);
  assert.equal(selfOrderColumns(6), 3);
  assert.equal(selfOrderColumns(8), 4);
  assert.equal(selfOrderColumns(9), 3);
  assert.equal(selfOrderColumns(12), 4);
  const rects = selfOrderSlotRects(8, 400);
  assert.equal(rects.length, 8);
  for (const r of rects) {
    assert.ok(r.x >= -0.01 && r.y >= -0.01 && r.x + r.size <= 400.01 && r.y + r.size <= 400.01);
  }
  const prev = [0, 1, 2, 3, 4, 5];
  const next = selfOrderShuffledSlots(6, prev);
  const moved = next.filter((v, i) => v !== prev[i]).length;
  assert.ok(moved >= 3);
});
