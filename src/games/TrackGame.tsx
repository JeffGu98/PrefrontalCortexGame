import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell, ProgressGate } from '../components/GameShell';
import { shuffleArray } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const LIVES = 3;
const START_BALLS = 6;
const MAX_BALLS = 12;
const HIGHLIGHT_TIME = 1.5;
const HIGHLIGHT_MIN = 0.9;
const MOVE_MIN = 4.0;
const MOVE_MAX = 8.0;
const PICK_TIME = 3.0;
const SCORE_ALL = 20;
const MAX_ODD = 5;
const AXIS_DEAD = Math.PI / 9;

const SAME = '#8ab4ff';
const ODD = '#ffd75d';
const PICK = '#4ade80';
const WRONG = '#ff5d73';

const HELP_TEXT =
  '开始时若干球里会有黄色异色球，先记住。\n' +
  '随后全部变成蓝色并乱动，停下后在约 3 秒内点出异色球再按确定。\n' +
  '全对 +20 并加球；满 12 球后改为更多异色或更小的球，不再加长移动。点错、漏选或超时扣一命。\n' +
  '做到哪一档会记住。再进时选继续最新一关，或从 6 个球重来。';

type Phase = 'GATE' | 'READY' | 'HIGHLIGHT' | 'MOVE' | 'PICK' | 'FEEDBACK' | 'OVER';

interface Ball {
  x: number;
  y: number;
  vx: number;
  vy: number;
  r: number;
}

interface TrackSave {
  score: number;
  balls: number;
}

interface TrackGameProps {
  onBack: () => void;
}

export const TrackGame: React.FC<TrackGameProps> = ({ onBack }) => {
  const initialSave = loadJSON<TrackSave>('track_best', { score: 0, balls: START_BALLS });
  const [phase, setPhase] = useState<Phase>(initialSave.balls > START_BALLS ? 'GATE' : 'READY');
  const [score, setScore] = useState(0);
  const [lives, setLives] = useState(LIVES);
  const [streak, setStreak] = useState(0);
  const [ballCount, setBallCount] = useState(initialSave.balls);
  const [latestBalls, setLatestBalls] = useState(initialSave.balls);
  const [beyondCap, setBeyondCap] = useState(0);
  const [hint, setHint] = useState({ text: '记住黄色的球', color: '#7f8ba6' });
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const arenaRef = useRef<HTMLDivElement>(null);

  const phaseRef = useRef<Phase>(phase);
  const pausedRef = useRef(false);
  const phaseLeftRef = useRef(1.0);
  const pulseRef = useRef(0);
  const ballsRef = useRef<Ball[]>([]);
  const targetsRef = useRef<Set<number>>(new Set());
  const pickedRef = useRef<Set<number>>(new Set());
  const scoreRef = useRef(0);
  const livesRef = useRef(LIVES);
  const streakRef = useRef(0);
  const ballCountRef = useRef(initialSave.balls);
  const latestBallsRef = useRef(initialSave.balls);
  const beyondCapRef = useRef(0);
  const bestScoreRef = useRef(initialSave.score);
  const burstIdRef = useRef(0);
  const lastPickTextRef = useRef('');

  pausedRef.current = paused;

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const persist = useCallback((nextScore: number, nextBalls: number) => {
    const clamped = Math.max(START_BALLS, Math.min(MAX_BALLS, nextBalls));
    bestScoreRef.current = nextScore;
    latestBallsRef.current = clamped;
    setLatestBalls(clamped);
    saveJSON<TrackSave>('track_best', { score: nextScore, balls: clamped });
  }, []);

  const drawBalls = useCallback(() => {
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
    ctx.fillStyle = '#12192a';
    ctx.fillRect(0, 0, w, h);

    const p = phaseRef.current;
    ballsRef.current.forEach((b, i) => {
      let col = SAME;
      let lw = 2;
      if (p === 'HIGHLIGHT' && targetsRef.current.has(i)) {
        col = ODD;
        lw = 3 + Math.sin(pulseRef.current * 8) * 1.5;
      } else if (p === 'PICK' && pickedRef.current.has(i)) {
        col = PICK;
      } else if (p === 'FEEDBACK') {
        if (targetsRef.current.has(i)) col = ODD;
        if (pickedRef.current.has(i) && !targetsRef.current.has(i)) col = WRONG;
      }
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2);
      ctx.fillStyle = col;
      ctx.fill();
      ctx.lineWidth = lw;
      ctx.strokeStyle = '#e8edff';
      ctx.stroke();
    });
  }, []);

  const beginHighlight = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    const bc = ballCountRef.current;
    const beyond = beyondCapRef.current;
    const baseOdd = bc <= 7 ? 1 : bc <= 10 ? 2 : 3;
    const oddCount = Math.min(Math.min(baseOdd + beyond, MAX_ODD), Math.max(bc - 1, 1));
    const el = arenaRef.current;
    const w = el?.clientWidth || 360;
    const h = el?.clientHeight || 380;
    const r = Math.max(12, Math.min(22, 22 - (bc - 6) * 0.8 - beyond * 1.2));
    const speedScale = Math.min(1, w / 660); // scale pixel speed smoothly to viewport width

    const nextBalls: Ball[] = [];
    for (let i = 0; i < bc; i++) {
      const x = r + 8 + Math.random() * Math.max(w - r * 2 - 16, r);
      const y = r + 8 + Math.random() * Math.max(h - r * 2 - 16, r);
      const quad = Math.floor(Math.random() * 4);
      const span = Math.PI * 0.5 - AXIS_DEAD * 2;
      const ang = quad * Math.PI * 0.5 + AXIS_DEAD + Math.random() * span;
      const spd = (240 + Math.random() * 140) * Math.max(0.65, speedScale);
      nextBalls.push({ x, y, vx: Math.cos(ang) * spd, vy: Math.sin(ang) * spd, r });
    }
    ballsRef.current = nextBalls;
    const idxs = shuffleArray(Array.from({ length: bc }, (_, i) => i));
    targetsRef.current = new Set(idxs.slice(0, oddCount));
    pickedRef.current = new Set();

    phaseRef.current = 'HIGHLIGHT';
    setPhase('HIGHLIGHT');
    phaseLeftRef.current = Math.max(
      HIGHLIGHT_MIN,
      HIGHLIGHT_TIME - (bc - START_BALLS) * 0.05 - beyond * 0.08
    );
    pulseRef.current = 0;
    setHint({ text: `记住黄色的 ${oddCount} 个`, color: '#ffd75d' });
    drawBalls();
  }, [drawBalls]);

  const endGame = useCallback(() => {
    phaseRef.current = 'OVER';
    setPhase('OVER');
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    if (isBest) {
      persist(finalScore, latestBallsRef.current);
    }
    const suffix = isBest
      ? ' · 新纪录！'
      : bestScoreRef.current > 0
        ? ` · 最佳 ${bestScoreRef.current}`
        : '';
    setHint({ text: `结束 · 得分 ${finalScore}${suffix}`, color: '#ffd75d' });
  }, [persist]);

  const handleConfirm = useCallback(
    (timedOut = false) => {
      if (phaseRef.current !== 'PICK') return;
      if (timedOut) {
        pickedRef.current.clear();
      }
      const picked = pickedRef.current;
      const targets = targetsRef.current;
      let allGood = picked.size === targets.size;
      if (allGood) {
        for (const t of targets) {
          if (!picked.has(t)) {
            allGood = false;
            break;
          }
        }
      }
      phaseRef.current = 'FEEDBACK';
      setPhase('FEEDBACK');
      phaseLeftRef.current = 1.1;
      if (allGood) {
        streakRef.current += 1;
        scoreRef.current += SCORE_ALL;
        setStreak(streakRef.current);
        setScore(scoreRef.current);
        if (ballCountRef.current < MAX_BALLS) {
          ballCountRef.current += 1;
          setBallCount(ballCountRef.current);
          persist(bestScoreRef.current, ballCountRef.current);
        } else {
          beyondCapRef.current += 1;
          setBeyondCap(beyondCapRef.current);
        }
        setHint({ text: `全对  +${SCORE_ALL}`, color: '#4ade80' });
        triggerBurst(`全对  +${SCORE_ALL}`, '#4ade80');
      } else {
        streakRef.current = 0;
        livesRef.current -= 1;
        setStreak(0);
        setLives(livesRef.current);
        const msg = timedOut ? '超时' : '有出入';
        setHint({ text: msg, color: '#ff5d73' });
        triggerBurst(msg, '#ff5d73');
      }
      drawBalls();
      if (livesRef.current <= 0) {
        endGame();
      }
    },
    [drawBalls, endGame, persist, triggerBurst]
  );

  const startRound = useCallback(
    (startBallCount: number) => {
      ballCountRef.current = startBallCount;
      setBallCount(startBallCount);
      scoreRef.current = 0;
      livesRef.current = LIVES;
      streakRef.current = 0;
      beyondCapRef.current = 0;
      setScore(0);
      setLives(LIVES);
      setStreak(0);
      setBeyondCap(0);
      setBurst(null);
      ballsRef.current = [];
      pickedRef.current.clear();
      phaseRef.current = 'READY';
      setPhase('READY');
      phaseLeftRef.current = 1.0;
      setHint({
        text: bestScoreRef.current > 0 ? `记住黄色的球 · 最佳 ${bestScoreRef.current}` : '记住黄色的球',
        color: '#7f8ba6',
      });
      persist(bestScoreRef.current, startBallCount);
      drawBalls();
    },
    [drawBalls, persist]
  );

  const handleCanvasPointer = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (phaseRef.current !== 'PICK' || pausedRef.current) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    let hit = -1;
    let best = 1e9;
    ballsRef.current.forEach((b, i) => {
      const d = Math.hypot(x - b.x, y - b.y);
      if (d <= b.r + 12 && d < best) {
        best = d;
        hit = i;
      }
    });
    if (hit < 0) return;
    if (pickedRef.current.has(hit)) {
      pickedRef.current.delete(hit);
    } else {
      pickedRef.current.add(hit);
    }
    drawBalls();
  };

  useEffect(() => {
    if (phase === 'READY' && ballsRef.current.length === 0) {
      startRound(ballCountRef.current);
    }
  }, []);

  useEffect(() => {
    const ro = new ResizeObserver(() => drawBalls());
    if (arenaRef.current) ro.observe(arenaRef.current);
    return () => ro.disconnect();
  }, [drawBalls]);

  useEffect(() => {
    let rafId = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (!pausedRef.current && phaseRef.current !== 'GATE' && phaseRef.current !== 'OVER') {
        pulseRef.current += dt;
        const p = phaseRef.current;
        if (p === 'MOVE') {
          const w = arenaRef.current?.clientWidth || 360;
          const h = arenaRef.current?.clientHeight || 380;
          for (const b of ballsRef.current) {
            b.x += b.vx * dt;
            b.y += b.vy * dt;
            if (b.x < b.r) {
              b.x = b.r;
              b.vx = Math.abs(b.vx);
            } else if (b.x > w - b.r) {
              b.x = w - b.r;
              b.vx = -Math.abs(b.vx);
            }
            if (b.y < b.r) {
              b.y = b.r;
              b.vy = Math.abs(b.vy);
            } else if (b.y > h - b.r) {
              b.y = h - b.r;
              b.vy = -Math.abs(b.vy);
            }
          }
          phaseLeftRef.current -= dt;
          if (phaseLeftRef.current <= 0) {
            phaseRef.current = 'PICK';
            setPhase('PICK');
            phaseLeftRef.current = PICK_TIME;
            pickedRef.current.clear();
            lastPickTextRef.current = '';
          }
          drawBalls();
        } else if (p === 'PICK') {
          phaseLeftRef.current -= dt;
          if (phaseLeftRef.current <= 0) {
            handleConfirm(true);
          } else {
            const label = `点出异色球 · ${Math.max(phaseLeftRef.current, 0).toFixed(1)} 秒`;
            if (label !== lastPickTextRef.current) {
              lastPickTextRef.current = label;
              setHint({ text: label, color: '#8ab4ff' });
            }
          }
        } else if (p === 'HIGHLIGHT') {
          phaseLeftRef.current -= dt;
          drawBalls();
          if (phaseLeftRef.current <= 0) {
            phaseRef.current = 'MOVE';
            setPhase('MOVE');
            const ballsForTime = Math.min(ballCountRef.current, MAX_BALLS);
            const base = Math.max(MOVE_MIN, Math.min(MOVE_MAX, MOVE_MIN + (ballsForTime - START_BALLS) * 0.5));
            const factor = Math.max(1, Math.ceil((15 - ballsForTime) / 2));
            // Keep web rounds crisp while preserving scaling
            phaseLeftRef.current = Math.min(base * factor, 10.0);
            setHint({ text: '盯住它们', color: '#7f8ba6' });
          }
        } else if (p === 'READY' || p === 'FEEDBACK') {
          phaseLeftRef.current -= dt;
          if (phaseLeftRef.current <= 0 && livesRef.current > 0) {
            beginHighlight();
          }
        }
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, [beginHighlight, drawBalls, handleConfirm]);

  return (
    <GameShell
      title="追踪异色球"
      helpText={HELP_TEXT}
      onBack={onBack}
      onPauseChange={setPaused}
      burst={burst}
      gameState={phase === 'OVER' ? 'gameover' : 'playing'}
    >
      <div className="shrink-0 text-center">
        <div className="tabular-nums text-[22px] font-medium text-[#e8edff]">
          得分 {score}　连击 {streak}　球 {ballCount}
          {beyondCap > 0 ? `＋${beyondCap}` : ''}
        </div>
        <div
          className="tabular-nums mt-0.5 text-[17px]"
          style={{ color: phase === 'GATE' ? '#8ab4ff' : '#ff8f9d' }}
        >
          {phase === 'GATE' ? `上次做到 ${latestBalls} 个球` : `生命 ${lives}/${LIVES}`}
        </div>
      </div>

      {phase === 'GATE' ? (
        <ProgressGate
          body={`上次做到 ${latestBalls} 个球。\n这一局进最新一关，还是从 6 个球重来？`}
          continueText={`进入最新一关（${latestBalls} 个球）`}
          freshText="从头开始（6 个球）"
          onContinue={() => startRound(latestBalls)}
          onFresh={() => startRound(START_BALLS)}
        />
      ) : (
        <div className="mt-3 flex min-h-0 flex-1 flex-col items-center">
          <div
            ref={arenaRef}
            className="relative min-h-[260px] w-full flex-1 overflow-hidden rounded-[14px] bg-[#12192a]"
          >
            <canvas
              ref={canvasRef}
              data-testid="track-canvas"
              onPointerDown={handleCanvasPointer}
              className="h-full w-full cursor-pointer"
            />
            {phase === 'READY' && (
              <div className="pointer-events-none absolute inset-0 flex items-center justify-center text-[20px] font-medium text-[#7f8ba6]">
                准备…
              </div>
            )}
          </div>

          <div className="mt-3 min-h-[28px] text-center text-[17px]" style={{ color: hint.color }}>
            {hint.text}
          </div>

          <div className="mt-3 shrink-0">
            {phase === 'OVER' ? (
              <button
                type="button"
                data-start="true"
                onClick={() => startRound(ballCount)}
                className="h-[64px] w-[240px] rounded-[12px] bg-[#4ade80] text-[22px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
              >
                重新开始
              </button>
            ) : (
              <button
                type="button"
                disabled={phase !== 'PICK'}
                onClick={() => handleConfirm(false)}
                className="h-[64px] w-[240px] rounded-[12px] bg-[#4ade80] text-[24px] font-semibold text-[#0d1220] transition-opacity"
                style={{ opacity: phase === 'PICK' ? 1 : 0.4 }}
              >
                确定
              </button>
            )}
          </div>
        </div>
      )}
    </GameShell>
  );
};
