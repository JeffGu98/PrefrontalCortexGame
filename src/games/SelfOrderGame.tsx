import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell, ProgressGate } from '../components/GameShell';
import { selfOrderShuffledSlots, selfOrderSlotRects } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const START_SET = 4;
const MIN_SET = 4;
const MAX_SET = 12;
const ROUND_SECS = 60.0;
const FLASH_OK_MS = 140;
const MOVE_MS = 220;
const INPUT_GAP_MS = 400;
const REVEAL_MS = 850;
const TOKEN_BG = '#1a2740';

const TOKENS: { shape: number; color: string; name: string }[] = [
  { shape: 0, color: '#ff5d73', name: '红圆' },
  { shape: 1, color: '#5d9bff', name: '蓝方' },
  { shape: 2, color: '#4ade80', name: '绿三角' },
  { shape: 3, color: '#ffd75d', name: '黄菱形' },
  { shape: 4, color: '#ff8a3d', name: '橙十字' },
  { shape: 5, color: '#c084fc', name: '紫星' },
  { shape: 6, color: '#2ee8d0', name: '青环' },
  { shape: 7, color: '#ff7ab6', name: '粉六边形' },
  { shape: 8, color: '#b8f25a', name: '嫩绿箭头' },
  { shape: 9, color: '#e8edff', name: '白月牙' },
  { shape: 10, color: '#fb7185', name: '玫红叉' },
  { shape: 11, color: '#38bdf8', name: '天蓝窄菱' },
];

const HELP_TEXT =
  '画面上有一组不同的图案。每次点一个还没点过的；点完后同样的图案会换位置，再点下一个没点过的。\n' +
  '不要靠位置记——每次都会换位。点到已经点过的，这一轮结束，图案数减一。全部点完则加一。\n' +
  '和积木跨度不同：那里是按给定顺序复述，这里要自己记住点过哪些。一局约 60 秒。不承诺变聪明。';

type Phase = 'PICK' | 'PLAY' | 'WAIT' | 'OVER';

interface SelfOrderSave {
  score: number;
  set: number;
}

const TokenShapeSvg: React.FC<{ shape: number; color: string; mark: 'none' | 'picked' | 'bad' }> = ({
  shape,
  color,
  mark,
}) => {
  return (
    <svg viewBox="0 0 100 100" className="h-[74%] w-[74%]">
      {shape === 0 && <circle cx="50" cy="50" r="32" fill={color} />}
      {shape === 1 && <rect x="18" y="18" width="64" height="64" fill={color} />}
      {shape === 2 && <polygon points="50,18 82,78 18,78" fill={color} />}
      {shape === 3 && <polygon points="50,16 84,50 50,84 16,50" fill={color} />}
      {shape === 4 && (
        <>
          <rect x="38" y="18" width="24" height="64" fill={color} />
          <rect x="18" y="38" width="64" height="24" fill={color} />
        </>
      )}
      {shape === 5 && (
        <polygon
          points="50,14 60,38 86,38 65,54 73,80 50,64 27,80 35,54 14,38 40,38"
          fill={color}
        />
      )}
      {shape === 6 && (
        <circle cx="50" cy="50" r="26" fill="none" stroke={color} strokeWidth="14" />
      )}
      {shape === 7 && (
        <polygon points="50,16 80,33 80,67 50,84 20,67 20,33" fill={color} />
      )}
      {shape === 8 && (
        <>
          <polygon points="50,16 80,52 50,48 20,52" fill={color} />
          <rect x="44" y="46" width="12" height="36" fill={color} />
        </>
      )}
      {shape === 9 && (
        <path
          d="M 64 22 A 30 30 0 1 0 64 78 A 22 22 0 1 1 64 22 Z"
          fill={color}
        />
      )}
      {shape === 10 && (
        <>
          <line x1="24" y1="24" x2="76" y2="76" stroke={color} strokeWidth="13" strokeLinecap="round" />
          <line x1="76" y1="24" x2="24" y2="76" stroke={color} strokeWidth="13" strokeLinecap="round" />
        </>
      )}
      {shape === 11 && <polygon points="50,14 69,50 50,86 31,50" fill={color} />}

      {mark === 'picked' && (
        <path
          d="M 64 72 L 73 82 L 88 62"
          fill="none"
          stroke="#4ade80"
          strokeWidth="8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      )}
      {mark === 'bad' && (
        <>
          <line x1="65" y1="65" x2="87" y2="87" stroke="#ffd75d" strokeWidth="8" strokeLinecap="round" />
          <line x1="87" y1="65" x2="65" y2="87" stroke="#ffd75d" strokeWidth="8" strokeLinecap="round" />
        </>
      )}
    </svg>
  );
};

interface SelfOrderGameProps {
  onBack: () => void;
}

export const SelfOrderGame: React.FC<SelfOrderGameProps> = ({ onBack }) => {
  const initialSave = loadJSON<SelfOrderSave>('selforder_best', { score: 0, set: START_SET });
  const [phase, setPhase] = useState<Phase>(initialSave.set > START_SET ? 'PICK' : 'PLAY');
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [setSize, setSetSize] = useState(START_SET);
  const [bestSet, setBestSet] = useState(initialSave.set);
  const [roundLeftSec, setRoundLeftSec] = useState(Math.ceil(ROUND_SECS));
  const [slotOf, setSlotOf] = useState<number[]>(() => selfOrderShuffledSlots(START_SET, []));
  const [flashId, setFlashId] = useState<number | null>(null);
  const [wrongId, setWrongId] = useState<number | null>(null);
  const [pickedList, setPickedList] = useState<number[]>([]);
  const [boardSide, setBoardSide] = useState(340);
  const [hint, setHint] = useState({ text: '每次点一个还没点过的图案；点完后它们会换位置', color: '#7f8ba6' });
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const boardRef = useRef<HTMLDivElement>(null);
  const phaseRef = useRef<Phase>(phase);
  const pausedRef = useRef(false);
  const roundLeftRef = useRef(ROUND_SECS);
  const setSizeRef = useRef(START_SET);
  const scoreRef = useRef(0);
  const streakRef = useRef(0);
  const bestScoreRef = useRef(initialSave.score);
  const bestSetRef = useRef(initialSave.set);
  const sessionBestSetRef = useRef(START_SET);
  const pickedRef = useRef<number[]>([]);
  const slotOfRef = useRef<number[]>(slotOf);
  const acceptingRef = useRef(true);
  const timersRef = useRef<number[]>([]);
  const burstIdRef = useRef(0);

  pausedRef.current = paused;

  const clearTimers = () => {
    for (const id of timersRef.current) window.clearTimeout(id);
    timersRef.current = [];
  };

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const persist = useCallback((nextScore: number, nextSet: number) => {
    const clamped = Math.max(MIN_SET, Math.min(MAX_SET, nextSet));
    bestScoreRef.current = nextScore;
    bestSetRef.current = clamped;
    setBestSet(clamped);
    saveJSON<SelfOrderSave>('selforder_best', { score: nextScore, set: clamped });
  }, []);

  const endGame = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    clearTimers();
    phaseRef.current = 'OVER';
    setPhase('OVER');
    acceptingRef.current = false;
    setFlashId(null);
    setWrongId(null);
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    const nextBestScore = isBest ? finalScore : bestScoreRef.current;
    const nextBestSet = Math.max(bestSetRef.current, sessionBestSetRef.current);
    persist(nextBestScore, nextBestSet);

    const parts = ['时间到', `本局最多一次点完 ${sessionBestSetRef.current} 个`];
    if (nextBestScore > 0) parts.push(`历史最佳 ${nextBestScore}`);
    if (isBest && finalScore > 0) parts.push('新纪录');
    setHint({ text: parts.join(' · '), color: '#ffd75d' });
  }, [persist]);

  const startTrial = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    clearTimers();
    pickedRef.current = [];
    setPickedList([]);
    setFlashId(null);
    setWrongId(null);
    const nextSlots = selfOrderShuffledSlots(setSizeRef.current, []);
    slotOfRef.current = nextSlots;
    setSlotOf(nextSlots);
    phaseRef.current = 'PLAY';
    setPhase('PLAY');
    acceptingRef.current = true;
    setHint({ text: '先点任意一个，之后不要再点它', color: '#8ab4ff' });
  }, []);

  const beginRound = useCallback(
    (startSet: number) => {
      clearTimers();
      setSizeRef.current = Math.max(MIN_SET, Math.min(MAX_SET, startSet));
      setSetSize(setSizeRef.current);
      scoreRef.current = 0;
      streakRef.current = 0;
      sessionBestSetRef.current = setSizeRef.current;
      roundLeftRef.current = ROUND_SECS;
      setScore(0);
      setStreak(0);
      setRoundLeftSec(Math.ceil(ROUND_SECS));
      setBurst(null);
      phaseRef.current = 'PLAY';
      setPhase('PLAY');
      startTrial();
    },
    [startTrial]
  );

  const afterTrial = useCallback(
    (delayMs: number) => {
      phaseRef.current = 'WAIT';
      setPhase('WAIT');
      acceptingRef.current = false;
      const id = window.setTimeout(() => {
        if (phaseRef.current === 'OVER') return;
        if (roundLeftRef.current <= 0) {
          endGame();
          return;
        }
        startTrial();
      }, delayMs);
      timersRef.current.push(id);
    },
    [endGame, startTrial]
  );

  const handleTap = (tokenId: number) => {
    if (phaseRef.current !== 'PLAY' || !acceptingRef.current || pausedRef.current) return;
    acceptingRef.current = false;
    if (pickedRef.current.includes(tokenId)) {
      streakRef.current = 0;
      setStreak(0);
      setWrongId(tokenId);
      setHint({ text: '这个点过了', color: '#ff5d73' });
      triggerBurst('点过了', '#ff5d73');
      setSizeRef.current = Math.max(setSizeRef.current - 1, MIN_SET);
      setSetSize(setSizeRef.current);
      afterTrial(REVEAL_MS);
      return;
    }

    pickedRef.current = [...pickedRef.current, tokenId];
    setPickedList(pickedRef.current);
    setFlashId(tokenId);

    const remaining = setSizeRef.current - pickedRef.current.length;
    if (remaining <= 0) {
      streakRef.current += 1;
      setStreak(streakRef.current);
      sessionBestSetRef.current = Math.max(sessionBestSetRef.current, setSizeRef.current);
      if (setSizeRef.current > bestSetRef.current) {
        persist(bestScoreRef.current, setSizeRef.current);
      }
      const bonus = 10 + setSizeRef.current * 4 + Math.min(streakRef.current, 8) * 2;
      scoreRef.current += bonus;
      setScore(scoreRef.current);
      setHint({ text: `全部点完 +${bonus} · ${setSizeRef.current} 个`, color: '#4ade80' });
      triggerBurst(`+${bonus}`, '#4ade80');
      setSizeRef.current = Math.min(setSizeRef.current + 1, MAX_SET);
      setSetSize(setSizeRef.current);
      afterTrial(INPUT_GAP_MS);
      return;
    }

    scoreRef.current += 4;
    setScore(scoreRef.current);
    setHint({
      text: `已点 ${pickedRef.current.length} / ${setSizeRef.current}  ·  +4`,
      color: '#4ade80',
    });

    const t1 = window.setTimeout(() => {
      if (phaseRef.current !== 'PLAY') return;
      setFlashId(null);
      const nextSlots = selfOrderShuffledSlots(setSizeRef.current, slotOfRef.current);
      slotOfRef.current = nextSlots;
      setSlotOf(nextSlots);
      const t2 = window.setTimeout(() => {
        if (phaseRef.current !== 'PLAY') return;
        acceptingRef.current = true;
        setHint({
          text: `再点一个还没点过的（已点 ${pickedRef.current.length} / ${setSizeRef.current}）`,
          color: '#e8edff',
        });
      }, MOVE_MS);
      timersRef.current.push(t2);
    }, FLASH_OK_MS);
    timersRef.current.push(t1);
  };

  useEffect(() => {
    const updateSize = () => {
      if (boardRef.current) {
        const w = boardRef.current.clientWidth;
        const h = boardRef.current.clientHeight;
        setBoardSide(Math.max(240, Math.min(w, h, 420)));
      }
    };
    updateSize();
    const ro = new ResizeObserver(updateSize);
    if (boardRef.current) ro.observe(boardRef.current);
    return () => ro.disconnect();
  }, [phase]);

  useEffect(() => {
    if (phase === 'PLAY') {
      beginRound(START_SET);
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

  const rects = selfOrderSlotRects(setSize, boardSide);

  return (
    <GameShell
      title="各点一次"
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
          本组 {setSize} 个　历史最多 {bestSet}
        </div>
        <div className="mt-1 min-h-[28px] text-[16px]" style={{ color: hint.color }}>
          {hint.text}
        </div>
      </div>

      {phase === 'PICK' ? (
        <ProgressGate
          body={`历史最多一次点完 ${bestSet} 个。\n这一局从 ${bestSet} 个继续，还是从 ${START_SET} 个重来？`}
          continueText={`从 ${bestSet} 个继续`}
          freshText={`从头开始（${START_SET} 个）`}
          onContinue={() => beginRound(bestSet)}
          onFresh={() => beginRound(START_SET)}
        />
      ) : (
        <div className="mt-3 flex min-h-0 flex-1 flex-col items-center">
          <div ref={boardRef} className="flex w-full flex-1 items-center justify-center">
            <div className="relative" style={{ width: boardSide, height: boardSide }}>
              {Array.from({ length: setSize }, (_, tokenId) => {
                const slot = slotOf[tokenId] ?? tokenId;
                const rect = rects[slot] ?? { x: 0, y: 0, size: 80 };
                const tok = TOKENS[tokenId];
                const isWrong = wrongId === tokenId;
                const isRevealPicked = wrongId !== null && pickedList.includes(tokenId) && !isWrong;
                const bg = isWrong
                  ? '#ff5d73'
                  : flashId === tokenId
                    ? '#4ade80'
                    : isRevealPicked
                      ? '#1c3a2c'
                      : TOKEN_BG;
                const mark: 'none' | 'picked' | 'bad' = isWrong
                  ? 'bad'
                  : isRevealPicked
                    ? 'picked'
                    : 'none';
                return (
                  <button
                    key={tokenId}
                    type="button"
                    aria-label={tok.name}
                    disabled={phase !== 'PLAY'}
                    onClick={() => handleTap(tokenId)}
                    className="absolute flex items-center justify-center rounded-[14px] transition-all duration-200 ease-out"
                    style={{
                      left: rect.x,
                      top: rect.y,
                      width: rect.size,
                      height: rect.size,
                      backgroundColor: bg,
                    }}
                  >
                    <TokenShapeSvg shape={tok.shape} color={tok.color} mark={mark} />
                  </button>
                );
              })}
            </div>
          </div>

          {phase === 'OVER' && (
            <button
              type="button"
              data-start="true"
              onClick={() => beginRound(setSize)}
              className="mt-4 h-[58px] w-[220px] rounded-[12px] bg-[#4ade80] text-[22px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
            >
              重新开始
            </button>
          )}
        </div>
      )}
    </GameShell>
  );
};
