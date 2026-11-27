import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell, ProgressGate } from '../components/GameShell';
import { buildRunningSpanStream } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const START_SPAN = 2;
const MIN_SPAN = 2;
const MAX_SPAN = 7;
const ROUND_SECS = 60.0;
const LIT_START = 750;
const LIT_MIN = 500;
const GAP_BETWEEN_MS = 180;
const READY_GAP_MS = 400;
const INPUT_GAP_MS = 400;

const HELP_TEXT =
  '屏幕中间会一条条闪过数字（1–9）。整串看完后，只按顺序点出最后 N 个（从较早到较晚）。\n' +
  '前面的要主动丢掉——这和积木跨度（整段复述）、N-Back（是否与 N 步前相同）都不一样。\n' +
  '全对末项数 +1，点错 −1。一局约 60 秒。不承诺变聪明。';

type Phase = 'PICK' | 'SHOW' | 'INPUT' | 'GAP' | 'OVER';

interface RunningSpanSave {
  score: number;
  span: number;
}

interface RunningSpanGameProps {
  onBack: () => void;
}

export const RunningSpanGame: React.FC<RunningSpanGameProps> = ({ onBack }) => {
  const initialSave = loadJSON<RunningSpanSave>('running_span_best', { score: 0, span: START_SPAN });
  const [phase, setPhase] = useState<Phase>(initialSave.span > START_SPAN ? 'PICK' : 'SHOW');
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [span, setSpan] = useState(START_SPAN);
  const [bestSpan, setBestSpan] = useState(initialSave.span);
  const [roundLeftSec, setRoundLeftSec] = useState(Math.ceil(ROUND_SECS));
  const [stimText, setStimText] = useState('');
  const [stimBg, setStimBg] = useState('#1a2740');
  const [stimColor, setStimColor] = useState('#e8edff');
  const [padStates, setPadStates] = useState<Record<number, 'ok' | 'bad'>>({});
  const [hint, setHint] = useState({
    text: '数字会一条条闪过。只要记住最后 N 个，按从早到晚的顺序点出来',
    color: '#7f8ba6',
  });
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
  const targetRef = useRef<number[]>([]);
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
    const clamped = Math.max(MIN_SPAN, Math.min(MAX_SPAN, nextSpan));
    bestScoreRef.current = nextScore;
    bestSpanRef.current = clamped;
    setBestSpan(clamped);
    saveJSON<RunningSpanSave>('running_span_best', { score: nextScore, span: clamped });
  }, []);

  const endGame = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    clearTimers();
    runTokenRef.current += 1;
    phaseRef.current = 'OVER';
    setPhase('OVER');
    acceptingRef.current = false;
    setStimText('结束');
    setStimColor('#e8edff');
    setStimBg('#1a2740');
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    const nextBestScore = isBest ? finalScore : bestScoreRef.current;
    const nextBestSpan = Math.max(bestSpanRef.current, sessionBestSpanRef.current);
    persist(nextBestScore, nextBestSpan);

    const parts = ['时间到', `本局最长末项 ${sessionBestSpanRef.current}`];
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
    const litMs = Math.max(LIT_MIN, LIT_START - (LIT_START - LIT_MIN) * Math.min(1, streakRef.current / 8));
    const { stream, target } = buildRunningSpanStream(spanRef.current, 1, 3);
    targetRef.current = target;
    setPadStates({});
    setStimText('');
    setStimBg('#1a2740');
    phaseRef.current = 'SHOW';
    setPhase('SHOW');
    setHint({ text: `看数字… 只要最后 ${spanRef.current} 个`, color: '#8ab4ff' });

    if (!(await waitMs(READY_GAP_MS, token))) return;
    for (const d of stream) {
      setStimText(String(d));
      setStimColor('#e8edff');
      setStimBg('#152034');
      if (!(await waitMs(litMs, token))) return;
      setStimText('');
      setStimBg('#12192a');
      if (!(await waitMs(GAP_BETWEEN_MS, token))) return;
    }
    phaseRef.current = 'INPUT';
    setPhase('INPUT');
    acceptingRef.current = true;
    setStimText('？');
    setStimColor('#ffd75d');
    setStimBg('#1a2740');
    setHint({ text: `按从早到晚点出最后 ${spanRef.current} 个`, color: '#e8edff' });
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
      setPadStates({});
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
      setStimText('');
      setPadStates({});
      if (roundLeftRef.current <= 0) {
        endGame();
        return;
      }
      void startTrial();
    }, INPUT_GAP_MS);
    timersRef.current.push(id);
  }, [endGame, startTrial]);

  const handlePad = (digit: number) => {
    if (phaseRef.current !== 'INPUT' || !acceptingRef.current || pausedRef.current) return;
    const expect = targetRef.current[inputIRef.current];
    if (digit === expect) {
      setPadStates((prev) => ({ ...prev, [digit]: 'ok' }));
      inputIRef.current += 1;
      if (inputIRef.current >= targetRef.current.length) {
        acceptingRef.current = false;
        streakRef.current += 1;
        setStreak(streakRef.current);
        sessionBestSpanRef.current = Math.max(sessionBestSpanRef.current, spanRef.current);
        if (spanRef.current > bestSpanRef.current) {
          persist(bestScoreRef.current, spanRef.current);
        }
        const pts = 10 + spanRef.current * 5 + Math.min(streakRef.current, 8) * 2;
        scoreRef.current += pts;
        setScore(scoreRef.current);
        setHint({ text: `全对 +${pts} · 末项 ${spanRef.current}`, color: '#4ade80' });
        triggerBurst(`+${pts}`, '#4ade80');
        spanRef.current = Math.min(spanRef.current + 1, MAX_SPAN);
        setSpan(spanRef.current);
        afterTrial();
      } else {
        setHint({ text: `${inputIRef.current} / ${targetRef.current.length}`, color: '#4ade80' });
        const id = window.setTimeout(() => {
          setPadStates((prev) => {
            const next = { ...prev };
            if (next[digit] === 'ok') delete next[digit];
            return next;
          });
        }, 140);
        timersRef.current.push(id);
      }
    } else {
      acceptingRef.current = false;
      setPadStates((prev) => ({ ...prev, [digit]: 'bad' }));
      streakRef.current = 0;
      setStreak(0);
      setHint({ text: `错了 · 应是 ${targetRef.current.join(' ')}`, color: '#ff5d73' });
      triggerBurst('错', '#ff5d73');
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
    let lastSec = Math.ceil(ROUND_SECS);
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      const p = phaseRef.current;
      if (!pausedRef.current && p !== 'PICK' && p !== 'OVER') {
        roundLeftRef.current -= dt;
        const sec = Math.ceil(Math.max(roundLeftRef.current, 0));
        if (sec !== lastSec) {
          lastSec = sec;
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
      title="末项记"
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
          末项 {span}　历史最长 {bestSpan}
        </div>
        <div className="mt-1 min-h-[28px] text-[16px]" style={{ color: hint.color }}>
          {hint.text}
        </div>
      </div>

      {phase === 'PICK' ? (
        <ProgressGate
          body={`历史最长末项 ${bestSpan}。\n这一局从 ${bestSpan} 继续，还是从 ${START_SPAN} 重来？`}
          continueText={`从末项 ${bestSpan} 继续`}
          freshText={`从头开始（末项 ${START_SPAN}）`}
          onContinue={() => beginRound(bestSpan)}
          onFresh={() => beginRound(START_SPAN)}
        />
      ) : (
        <div className="mt-3 flex min-h-0 flex-1 flex-col items-center">
          {/* Stimulus Display */}
          <div
            className="flex h-[170px] w-full items-center justify-center rounded-[14px] transition-colors"
            style={{ backgroundColor: stimBg }}
          >
            <span
              className="tabular-nums text-[104px] font-bold leading-none"
              style={{ color: stimColor }}
            >
              {stimText}
            </span>
          </div>

          {/* 1-9 Pad */}
          <div
            className="mt-4 grid w-full max-w-[360px] grid-cols-3 gap-3 transition-opacity"
            style={{ opacity: phase === 'INPUT' ? 1 : 0.45 }}
          >
            {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => {
              const st = padStates[n];
              const bg = st === 'ok' ? '#4ade80' : st === 'bad' ? '#ff5d73' : '#1a2740';
              const fg = st === 'ok' ? '#0d1220' : '#e8edff';
              return (
                <button
                  key={n}
                  type="button"
                  disabled={phase !== 'INPUT'}
                  onClick={() => handlePad(n)}
                  className="tabular-nums h-[76px] rounded-[12px] text-[32px] font-semibold transition-colors"
                  style={{ backgroundColor: bg, color: fg }}
                >
                  {n}
                </button>
              );
            })}
          </div>

          {phase === 'OVER' && (
            <button
              type="button"
              data-start="true"
              onClick={() => beginRound(span)}
              className="mt-5 h-[56px] w-[220px] rounded-[12px] bg-[#4ade80] text-[22px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
            >
              重新开始
            </button>
          )}
        </div>
      )}
    </GameShell>
  );
};
