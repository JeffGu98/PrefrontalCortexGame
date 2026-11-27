import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell, ProgressGate } from '../components/GameShell';
import { makeCorsiSequence } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const CELL_COUNT = 9;
const START_SPAN = 3;
const MIN_SPAN = 2;
const MAX_SPAN = 9;
const ROUND_SECS = 60.0;
const LIT_MS = 550;
const GAP_BETWEEN_MS = 180;
const READY_GAP_MS = 450;
const INPUT_GAP_MS = 350;

const DIM = '#1a2740';
const LIT = '#8ab4ff';
const OK = '#4ade80';
const BAD = '#ff5d73';

const HELP_TEXT =
  '九个方块会按顺序亮一下。看清顺序后，按同样的顺序点回去。\n' +
  '点对继续；点错这一轮结束，跨度减一（最少 2）。整段都对则跨度加一（最多 9）。\n' +
  '一局约 60 秒。练的是记住空间位置的先后顺序，不是反应速度。不承诺变聪明。';

type Phase = 'PICK' | 'SHOW' | 'INPUT' | 'GAP' | 'OVER';

interface CorsiSave {
  score: number;
  span: number;
}

interface CorsiGameProps {
  onBack: () => void;
}

export const CorsiGame: React.FC<CorsiGameProps> = ({ onBack }) => {
  const initialSave = loadJSON<CorsiSave>('corsi_best', { score: 0, span: START_SPAN });
  const [phase, setPhase] = useState<Phase>(initialSave.span > START_SPAN ? 'PICK' : 'SHOW');
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [span, setSpan] = useState(START_SPAN);
  const [bestSpan, setBestSpan] = useState(initialSave.span);
  const [roundLeftSec, setRoundLeftSec] = useState(Math.ceil(ROUND_SECS));
  const [cellColors, setCellColors] = useState<string[]>(() => Array(CELL_COUNT).fill(DIM));
  const [hint, setHint] = useState({ text: '看方块点亮的顺序，再按同样顺序点回去', color: '#7f8ba6' });
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const phaseRef = useRef<Phase>(phase);
  const pausedRef = useRef(false);
  const roundLeftRef = useRef(ROUND_SECS);
  const spanRef = useRef(START_SPAN);
  const scoreRef = useRef(0);
  const streakRef = useRef(0);
  const bestScoreRef = useRef(initialSave.score);
  const bestSpanRef = useRef(initialSave.span);
  const sessionBestSpanRef = useRef(START_SPAN);
  const seqRef = useRef<number[]>([]);
  const inputIRef = useRef(0);
  const acceptingRef = useRef(false);
  const runTokenRef = useRef(0);
  const timersRef = useRef<number[]>([]);
  const burstIdRef = useRef(0);

  pausedRef.current = paused;

  const clearTimers = () => {
    for (const id of timersRef.current) window.clearTimeout(id);
    timersRef.current = [];
  };

  const waitMs = (ms: number, token: number) =>
    new Promise<boolean>((resolve) => {
      const id = window.setTimeout(() => {
        resolve(runTokenRef.current === token && phaseRef.current !== 'OVER');
      }, ms);
      timersRef.current.push(id);
    });

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const persist = useCallback((nextScore: number, nextSpan: number) => {
    const clampedSpan = Math.max(MIN_SPAN, Math.min(MAX_SPAN, nextSpan));
    bestScoreRef.current = nextScore;
    bestSpanRef.current = clampedSpan;
    setBestSpan(clampedSpan);
    saveJSON<CorsiSave>('corsi_best', { score: nextScore, span: clampedSpan });
  }, []);

  const endGame = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    clearTimers();
    runTokenRef.current += 1;
    phaseRef.current = 'OVER';
    setPhase('OVER');
    acceptingRef.current = false;
    setCellColors(Array(CELL_COUNT).fill(DIM));
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    const nextBestScore = isBest ? finalScore : bestScoreRef.current;
    const nextBestSpan = Math.max(bestSpanRef.current, sessionBestSpanRef.current);
    persist(nextBestScore, nextBestSpan);

    const parts = ['时间到', `本局最长跨度 ${sessionBestSpanRef.current}`];
    if (nextBestScore > 0) parts.push(`历史最佳 ${nextBestScore}`);
    if (isBest && finalScore > 0) parts.push('新纪录');
    setHint({ text: parts.join(' · '), color: '#ffd75d' });
  }, [persist]);

  const startTrial = useCallback(async () => {
    if (phaseRef.current === 'OVER') return;
    clearTimers();
    runTokenRef.current += 1;
    const token = runTokenRef.current;
    acceptingRef.current = false;
    inputIRef.current = 0;
    const seq = makeCorsiSequence(spanRef.current, CELL_COUNT);
    seqRef.current = seq;
    setCellColors(Array(CELL_COUNT).fill(DIM));
    phaseRef.current = 'SHOW';
    setPhase('SHOW');
    setHint({ text: '看顺序…', color: '#8ab4ff' });

    if (!(await waitMs(READY_GAP_MS, token))) return;
    for (const idx of seq) {
      setCellColors((prev) => prev.map((c, i) => (i === idx ? LIT : c)));
      if (!(await waitMs(LIT_MS, token))) return;
      setCellColors((prev) => prev.map((c, i) => (i === idx ? DIM : c)));
      if (!(await waitMs(GAP_BETWEEN_MS, token))) return;
    }
    phaseRef.current = 'INPUT';
    setPhase('INPUT');
    acceptingRef.current = true;
    setHint({ text: '按同样顺序点', color: '#e8edff' });
  }, []);

  const beginRound = useCallback(
    (startSpan: number) => {
      clearTimers();
      runTokenRef.current += 1;
      spanRef.current = Math.max(MIN_SPAN, Math.min(MAX_SPAN, startSpan));
      setSpan(spanRef.current);
      scoreRef.current = 0;
      streakRef.current = 0;
      sessionBestSpanRef.current = spanRef.current;
      roundLeftRef.current = ROUND_SECS;
      setScore(0);
      setStreak(0);
      setRoundLeftSec(Math.ceil(ROUND_SECS));
      setBurst(null);
      phaseRef.current = 'SHOW';
      setPhase('SHOW');
      void startTrial();
    },
    [startTrial]
  );

  const afterTrial = useCallback(() => {
    phaseRef.current = 'GAP';
    setPhase('GAP');
    acceptingRef.current = false;
    runTokenRef.current += 1;
    const token = runTokenRef.current;
    const id = window.setTimeout(() => {
      if (runTokenRef.current !== token || phaseRef.current === 'OVER') return;
      setCellColors(Array(CELL_COUNT).fill(DIM));
      if (roundLeftRef.current <= 0) {
        endGame();
        return;
      }
      void startTrial();
    }, INPUT_GAP_MS);
    timersRef.current.push(id);
  }, [endGame, startTrial]);

  const handleCellClick = (index: number) => {
    if (phaseRef.current !== 'INPUT' || !acceptingRef.current || pausedRef.current) return;
    const expect = seqRef.current[inputIRef.current];
    if (index === expect) {
      setCellColors((prev) => prev.map((c, i) => (i === index ? OK : c)));
      inputIRef.current += 1;
      if (inputIRef.current >= seqRef.current.length) {
        acceptingRef.current = false;
        streakRef.current += 1;
        setStreak(streakRef.current);
        sessionBestSpanRef.current = Math.max(sessionBestSpanRef.current, spanRef.current);
        if (spanRef.current > bestSpanRef.current) {
          persist(bestScoreRef.current, spanRef.current);
        }
        const pts = 10 + spanRef.current * 4 + Math.min(streakRef.current, 8) * 2;
        scoreRef.current += pts;
        setScore(scoreRef.current);
        setHint({ text: `全对 +${pts} · 跨度 ${spanRef.current}`, color: OK });
        triggerBurst(`+${pts}`, OK);
        spanRef.current = Math.min(spanRef.current + 1, MAX_SPAN);
        setSpan(spanRef.current);
        afterTrial();
      } else {
        setHint({ text: `${inputIRef.current} / ${seqRef.current.length}`, color: OK });
        const id = window.setTimeout(() => {
          if (phaseRef.current === 'INPUT') {
            setCellColors((prev) => prev.map((c, i) => (i === index ? DIM : c)));
          }
        }, 140);
        timersRef.current.push(id);
      }
    } else {
      acceptingRef.current = false;
      setCellColors((prev) => prev.map((c, i) => (i === index ? BAD : c)));
      streakRef.current = 0;
      setStreak(0);
      setHint({ text: '顺序错了', color: BAD });
      triggerBurst('错', BAD);
      spanRef.current = Math.max(spanRef.current - 1, MIN_SPAN);
      setSpan(spanRef.current);
      afterTrial();
    }
  };

  useEffect(() => {
    if (phase === 'SHOW') {
      beginRound(START_SPAN);
    }
    return () => clearTimers();
  }, []);

  useEffect(() => {
    let rafId = 0;
    let last = performance.now();
    let lastShown = Math.ceil(ROUND_SECS);
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      const p = phaseRef.current;
      if (!pausedRef.current && p !== 'PICK' && p !== 'OVER') {
        roundLeftRef.current -= dt;
        const sec = Math.ceil(Math.max(roundLeftRef.current, 0));
        if (sec !== lastShown) {
          lastShown = sec;
          setRoundLeftSec(sec);
        }
        if (roundLeftRef.current <= 0) {
          roundLeftRef.current = 0;
          endGame();
        }
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, [endGame]);

  return (
    <GameShell
      title="积木跨度"
      helpText={HELP_TEXT}
      onBack={onBack}
      onPauseChange={setPaused}
      burst={burst}
      gameState={phase === 'OVER' ? 'gameover' : 'playing'}
    >
      <div className="shrink-0 text-center">
        <div className="tabular-nums text-[22px] font-medium text-[#e8edff]">
          得分 {score}　连对 {streak}
        </div>
        <div className="tabular-nums text-[18px] text-[#ffd75d]">剩余 {roundLeftSec} 秒</div>
        <div className="tabular-nums text-[24px] font-semibold text-[#8ab4ff]">
          跨度 {span}　历史最长 {bestSpan}
        </div>
        <div className="mt-1 min-h-[28px] text-[17px]" style={{ color: hint.color }}>
          {hint.text}
        </div>
      </div>

      {phase === 'PICK' ? (
        <ProgressGate
          body={`历史最长跨度 ${bestSpan}。\n这一局从跨度 ${bestSpan} 继续，还是从 ${START_SPAN} 重来？`}
          continueText={`从跨度 ${bestSpan} 继续`}
          freshText={`从头开始（跨度 ${START_SPAN}）`}
          onContinue={() => beginRound(bestSpan)}
          onFresh={() => beginRound(START_SPAN)}
        />
      ) : (
        <div className="mt-5 flex min-h-0 flex-1 flex-col items-center">
          <div className="grid aspect-square w-full max-w-[380px] grid-cols-3 gap-3.5">
            {cellColors.map((bg, idx) => (
              <button
                key={idx}
                type="button"
                aria-label={`方块 ${idx + 1}`}
                disabled={phase !== 'INPUT'}
                onClick={() => handleCellClick(idx)}
                className="rounded-[14px] transition-colors duration-100"
                style={{ backgroundColor: bg }}
              />
            ))}
          </div>

          {phase === 'OVER' && (
            <button
              type="button"
              data-start="true"
              onClick={() => beginRound(span)}
              className="mt-8 h-[60px] w-[220px] rounded-[12px] bg-[#1a2740] text-[22px] font-medium text-[#e8edff] transition-colors hover:bg-[#243656]"
            >
              重新开始
            </button>
          )}
        </div>
      )}
    </GameShell>
  );
};
