import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell } from '../components/GameShell';
import { dotRadiusFor, Point2D, randInt, scatterDots } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const ROUND_TIME = 60.0;
const READY_TIME = 1.0;
const FLASH_TIME_START = 0.6;
const FLASH_TIME_MIN = 0.35;
const FLASH_STEP = 0.02;
const COUNT_MIN = 4;
const COUNT_MAX_START = 12;
const SCORE_EXACT = 10;
const SCORE_CLOSE = 5;
const FEEDBACK_CORRECT = 0.7;
const FEEDBACK_WRONG = 1.8;
const CLEAR_TIME = 0.2;
const MAX_DIGITS = 3;

const HELP_TEXT =
  '圆点会短暂闪过，消失后用底部键盘输入你看到的数量。\n' +
  '完全正确得分最高；只差 1 个也有一半分。一局 60 秒。\n' +
  '进场先有一秒准备。闪现时键盘会变淡，消失后再输入。';

type Phase = 'READY' | 'FLASH' | 'INPUT' | 'FEEDBACK' | 'CLEAR' | 'OVER';

interface DotsGameProps {
  onBack: () => void;
}

export const DotsGame: React.FC<DotsGameProps> = ({ onBack }) => {
  const [phase, setPhase] = useState<Phase>('READY');
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [bestScore, setBestScore] = useState(() => loadJSON('dots_best', { score: 0 }).score);
  const [timeDisplay, setTimeDisplay] = useState('准备');
  const [status, setStatus] = useState({ text: '看准闪过的点数', color: '#7f8ba6' });
  const [typed, setTyped] = useState('');
  const [trueCount, setTrueCount] = useState(0);
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);
  const flashBarRef = useRef<HTMLDivElement>(null);

  const phaseRef = useRef<Phase>('READY');
  const pausedRef = useRef(false);
  const timeLeftRef = useRef(ROUND_TIME);
  const readyLeftRef = useRef(READY_TIME);
  const flashTimeRef = useRef(FLASH_TIME_START);
  const flashLeftRef = useRef(0);
  const feedbackLeftRef = useRef(0);
  const clearLeftRef = useRef(0);
  const countMaxRef = useRef(COUNT_MAX_START);
  const trueCountRef = useRef(0);
  const scoreRef = useRef(0);
  const streakRef = useRef(0);
  const bestScoreRef = useRef(bestScore);
  const pointsRef = useRef<Point2D[]>([]);
  const radiusRef = useRef(12);
  const fillRef = useRef('#8ab4ff');
  const showingRef = useRef(false);
  const burstIdRef = useRef(0);
  const lastSecRef = useRef(-1);

  pausedRef.current = paused;
  bestScoreRef.current = bestScore;

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const drawCanvas = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (w <= 0 || h <= 0) return;
    if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    if (!showingRef.current) return;
    ctx.fillStyle = fillRef.current;
    ctx.strokeStyle = '#e8edff';
    ctx.lineWidth = 2;
    for (const p of pointsRef.current) {
      ctx.beginPath();
      ctx.arc(p.x, p.y, radiusRef.current, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
  }, []);

  const newTrial = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    const el = panelRef.current;
    const w = el?.clientWidth || 360;
    const h = el?.clientHeight || 220;
    const count = randInt(COUNT_MIN, countMaxRef.current);
    const r = dotRadiusFor(count, w, h);
    const pts = scatterDots(count, w, h, r);
    pointsRef.current = pts;
    radiusRef.current = r;
    fillRef.current = '#8ab4ff';
    showingRef.current = true;
    trueCountRef.current = pts.length;
    setTrueCount(pts.length);
    setTyped('');
    phaseRef.current = 'FLASH';
    setPhase('FLASH');
    flashLeftRef.current = flashTimeRef.current;
    if (flashBarRef.current) flashBarRef.current.style.width = '100%';
    setStatus({ text: '看清楚点数', color: '#7f8ba6' });
    drawCanvas();
  }, [drawCanvas]);

  const startRound = useCallback(() => {
    scoreRef.current = 0;
    streakRef.current = 0;
    timeLeftRef.current = ROUND_TIME;
    flashTimeRef.current = FLASH_TIME_START;
    countMaxRef.current = COUNT_MAX_START;
    readyLeftRef.current = READY_TIME;
    lastSecRef.current = -1;
    showingRef.current = false;
    setScore(0);
    setStreak(0);
    setTyped('');
    setBurst(null);
    phaseRef.current = 'READY';
    setPhase('READY');
    setTimeDisplay('准备');
    const best = bestScoreRef.current;
    setStatus({
      text: best > 0 ? `看准闪过的点数 · 最佳 ${best}` : '看准闪过的点数',
      color: '#7f8ba6',
    });
    drawCanvas();
  }, [drawCanvas]);

  const endRound = useCallback(() => {
    phaseRef.current = 'OVER';
    setPhase('OVER');
    timeLeftRef.current = 0;
    setTimeDisplay('剩余 0 秒');
    showingRef.current = false;
    drawCanvas();
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    let nextBest = bestScoreRef.current;
    if (isBest) {
      nextBest = finalScore;
      setBestScore(nextBest);
      bestScoreRef.current = nextBest;
      saveJSON('dots_best', { score: nextBest });
    }
    const suffix = isBest ? ' · 新纪录！' : nextBest > 0 ? ` · 最佳 ${nextBest}` : '';
    setStatus({ text: `时间到 · 得分 ${finalScore}${suffix}`, color: '#ffd75d' });
  }, [drawCanvas]);

  const handleConfirm = useCallback(
    (currentTyped: string) => {
      if (phaseRef.current !== 'INPUT' || currentTyped.length === 0) return;
      const guess = Number.parseInt(currentTyped, 10);
      const actual = trueCountRef.current;
      const err = Math.abs(guess - actual);
      let resultColor = '#ff5d73';
      if (err === 0) {
        streakRef.current += 1;
        setStreak(streakRef.current);
        scoreRef.current += SCORE_EXACT + Math.min(streakRef.current, 10) * 2;
        setScore(scoreRef.current);
        if (flashTimeRef.current > FLASH_TIME_MIN + 0.0001) {
          flashTimeRef.current = Math.max(FLASH_TIME_MIN, flashTimeRef.current - FLASH_STEP);
        } else {
          countMaxRef.current += 1;
        }
        resultColor = '#4ade80';
        setStatus({ text: `正好！　实际 ${actual}`, color: resultColor });
        triggerBurst('正好！', resultColor);
      } else if (err === 1) {
        scoreRef.current += SCORE_CLOSE;
        setScore(scoreRef.current);
        resultColor = '#ffd75d';
        setStatus({ text: `接近　·　实际 ${actual}`, color: resultColor });
        triggerBurst('接近', resultColor);
      } else {
        streakRef.current = 0;
        setStreak(0);
        if (countMaxRef.current > COUNT_MAX_START) {
          countMaxRef.current -= 1;
        } else {
          flashTimeRef.current = Math.min(FLASH_TIME_START, flashTimeRef.current + FLASH_STEP);
        }
        setStatus({ text: `看岔了　·　实际 ${actual}`, color: resultColor });
        triggerBurst('看岔了', resultColor);
      }
      fillRef.current = resultColor;
      showingRef.current = true;
      drawCanvas();
      phaseRef.current = 'FEEDBACK';
      setPhase('FEEDBACK');
      feedbackLeftRef.current = err === 0 ? FEEDBACK_CORRECT : FEEDBACK_WRONG;
    },
    [drawCanvas, triggerBurst]
  );

  const handleKey = useCallback(
    (key: string) => {
      if (phaseRef.current !== 'INPUT' || pausedRef.current) return;
      if (key === '删除') {
        setTyped((t) => t.slice(0, -1));
      } else if (key === '确定') {
        setTyped((curr) => {
          handleConfirm(curr);
          return curr;
        });
      } else {
        setTyped((t) => (t.length >= MAX_DIGITS ? t : t + key));
      }
    },
    [handleConfirm]
  );

  useEffect(() => {
    startRound();
  }, [startRound]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (phaseRef.current !== 'INPUT' || pausedRef.current) return;
      if (e.key >= '0' && e.key <= '9') {
        handleKey(e.key);
      } else if (e.key === 'Backspace') {
        handleKey('删除');
      } else if (e.key === 'Enter') {
        handleKey('确定');
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [handleKey]);

  useEffect(() => {
    const ro = new ResizeObserver(() => drawCanvas());
    if (panelRef.current) ro.observe(panelRef.current);
    return () => ro.disconnect();
  }, [drawCanvas]);

  useEffect(() => {
    let rafId = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (!pausedRef.current && phaseRef.current !== 'OVER') {
        const p = phaseRef.current;
        if (p === 'READY') {
          readyLeftRef.current -= dt;
          if (readyLeftRef.current <= 0) newTrial();
        } else if (p === 'FEEDBACK') {
          feedbackLeftRef.current -= dt;
          if (feedbackLeftRef.current <= 0) {
            phaseRef.current = 'CLEAR';
            setPhase('CLEAR');
            clearLeftRef.current = CLEAR_TIME;
            showingRef.current = false;
            drawCanvas();
            setStatus({ text: '下一题', color: '#7f8ba6' });
          }
        } else if (p === 'CLEAR') {
          clearLeftRef.current -= dt;
          if (clearLeftRef.current <= 0) newTrial();
        } else {
          timeLeftRef.current -= dt;
          const sec = Math.ceil(Math.max(timeLeftRef.current, 0));
          if (sec !== lastSecRef.current) {
            lastSecRef.current = sec;
            setTimeDisplay(`剩余 ${sec} 秒`);
          }
          if (timeLeftRef.current <= 0) {
            endRound();
          } else if (p === 'FLASH') {
            flashLeftRef.current -= dt;
            if (flashBarRef.current) {
              const ratio = Math.max(0, Math.min(1, flashLeftRef.current / flashTimeRef.current));
              flashBarRef.current.style.width = `${ratio * 100}%`;
            }
            if (flashLeftRef.current <= 0) {
              showingRef.current = false;
              drawCanvas();
              phaseRef.current = 'INPUT';
              setPhase('INPUT');
              setStatus({ text: '输入你看到的数量', color: '#7f8ba6' });
            }
          }
        }
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, [drawCanvas, endRound, newTrial]);

  const inputDisplay =
    phase === 'FLASH' || phase === 'READY' || phase === 'CLEAR'
      ? '·'
      : phase === 'FEEDBACK'
        ? String(trueCount)
        : typed || '—';

  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '删除', '0', '确定'];

  return (
    <GameShell
      title="看点数"
      helpText={HELP_TEXT}
      onBack={onBack}
      onPauseChange={setPaused}
      burst={burst}
      gameState={phase === 'OVER' ? 'gameover' : 'playing'}
    >
      <div className="shrink-0 text-center">
        <div className="tabular-nums text-[22px] font-medium text-[#e8edff]">
          得分 {score}　连击 {streak}
        </div>
        <div className="tabular-nums text-[18px] text-[#8ab4ff]">{timeDisplay}</div>
        <div className="mt-0.5 text-[16px]" style={{ color: status.color }}>
          {status.text}
        </div>
      </div>

      {/* Dot Canvas Panel */}
      <div
        ref={panelRef}
        className="relative mt-3 min-h-[200px] flex-1 overflow-hidden rounded-[14px] transition-colors"
        style={{ backgroundColor: phase === 'FEEDBACK' ? '#152034' : '#1a2740' }}
      >
        {phase === 'FLASH' && (
          <div
            ref={flashBarRef}
            className="absolute top-0 left-0 h-1 bg-[#8ab4ff]"
            style={{ width: '100%' }}
          />
        )}
        <canvas
          ref={canvasRef}
          data-testid="dots-canvas"
          className="h-full w-full"
        />
        {phase === 'READY' && (
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center text-[20px] font-medium text-[#7f8ba6]">
            准备…
          </div>
        )}
        {phase === 'OVER' && (
          <div className="absolute inset-0 flex items-center justify-center">
            <button
              type="button"
              data-start="true"
              onClick={startRound}
              className="h-[60px] w-[220px] rounded-[12px] bg-[#4ade80] text-[22px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
            >
              再来一局
            </button>
          </div>
        )}
      </div>

      {/* Input Display */}
      <div className="tabular-nums my-2 text-center text-[42px] font-bold leading-none text-[#e8edff]">
        {inputDisplay}
      </div>

      {/* Keypad */}
      <div
        className="grid shrink-0 grid-cols-3 gap-2.5 transition-opacity"
        style={{ opacity: phase === 'INPUT' ? 1 : 0.42 }}
      >
        {keys.map((k) => {
          const isConfirm = k === '确定';
          return (
            <button
              key={k}
              type="button"
              disabled={phase !== 'INPUT'}
              onClick={() => handleKey(k)}
              className={`h-[58px] rounded-[10px] text-[22px] font-semibold transition-colors ${
                isConfirm
                  ? 'bg-[#4ade80] text-[#0d1220] hover:bg-[#62ea94] active:bg-[#38c46c]'
                  : 'bg-[#1a2740] text-[#e8edff] hover:bg-[#243656] active:bg-[#131d31]'
              }`}
            >
              {k}
            </button>
          );
        })}
      </div>
    </GameShell>
  );
};
