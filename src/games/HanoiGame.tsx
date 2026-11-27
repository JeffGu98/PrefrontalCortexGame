import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell, ProgressGate } from '../components/GameShell';
import { canMoveHanoiDisk, hanoiMoveLimit, hanoiOptimal, solveHanoi } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const MIN_DISKS = 3;
const MAX_DISKS = 6;
const BASE_SCORE = 30;
const OPTIMAL_BONUS = 50;
const OVER_FACTOR = 1.5;
const PEG_NAMES = ['左', '中', '右'];
const DISK_COLORS = ['#ff5d73', '#ffb35d', '#ffd75d', '#4ade80', '#5d9bff', '#c084fc'];

const HELP_TEXT =
  '三根柱子。开始时盘子都在左边，要全部移到右边。\n' +
  '点一下选出顶上的盘，再点目标柱放下。大盘不能压小盘。乱了可以点「复位」，盘子回左柱，本关步数清零，总分保留。\n' +
  '做到哪一关会记住。再进时选继续最新一关，或从 3 盘重来。\n' +
  '最优步数是 2^N−1。只有最优通关才加盘；步数超过最优×1.5 不算过关，必须复位重来。过关后会展示最优路径。练的是计划，不是速度——没有倒计时。';

type Phase = 'PICK' | 'PLAY' | 'WON';

interface HanoiSave {
  score: number;
  disks: number;
}

interface HanoiGameProps {
  onBack: () => void;
}

function makeInitialPegs(n: number): number[][] {
  const left: number[] = [];
  for (let size = n; size >= 1; size--) left.push(size);
  return [left, [], []];
}

function formatOptimalPath(n: number): string {
  const steps = solveHanoi(n, 0, 2, 1);
  const show = steps.slice(0, 15).map(([s, d]) => `${PEG_NAMES[s]}→${PEG_NAMES[d]}`);
  return show.join('、') + (steps.length > 15 ? '…' : '');
}

export const HanoiGame: React.FC<HanoiGameProps> = ({ onBack }) => {
  const initialSave = loadJSON<HanoiSave>('hanoi_best', { score: 0, disks: MIN_DISKS });
  const [phase, setPhase] = useState<Phase>(initialSave.disks > MIN_DISKS ? 'PICK' : 'PLAY');
  const [diskN, setDiskN] = useState(initialSave.disks > MIN_DISKS ? initialSave.disks : MIN_DISKS);
  const [latestDisks, setLatestDisks] = useState(initialSave.disks);
  const [score, setScore] = useState(0);
  const [bestScore, setBestScore] = useState(initialSave.score);
  const [pegs, setPegs] = useState<number[][]>(() => makeInitialPegs(MIN_DISKS));
  const [selectedPeg, setSelectedPeg] = useState<number>(-1);
  const [moves, setMoves] = useState(0);
  const [elapsedSec, setElapsedSec] = useState(0);
  const [mustReset, setMustReset] = useState(false);
  const [shakingDisk, setShakingDisk] = useState<number | null>(null);
  const [hint, setHint] = useState({ text: '把盘子移到右边绿线柱', color: '#7f8ba6' });
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const elapsedRef = useRef(0);
  const phaseRef = useRef<Phase>(phase);
  const pausedRef = useRef(false);
  const burstIdRef = useRef(0);

  phaseRef.current = phase;
  pausedRef.current = paused;

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const persist = useCallback((nextScore: number, nextDisks: number) => {
    const clamped = Math.max(MIN_DISKS, Math.min(MAX_DISKS, nextDisks));
    setBestScore(nextScore);
    setLatestDisks(clamped);
    saveJSON<HanoiSave>('hanoi_best', { score: nextScore, disks: clamped });
  }, []);

  const startLevel = useCallback(
    (n: number) => {
      const clamped = Math.max(MIN_DISKS, Math.min(MAX_DISKS, n));
      setDiskN(clamped);
      setPhase('PLAY');
      setPegs(makeInitialPegs(clamped));
      setSelectedPeg(-1);
      setMoves(0);
      setElapsedSec(0);
      elapsedRef.current = 0;
      setMustReset(false);
      setHint({ text: '把盘子移到右边绿线柱', color: '#7f8ba6' });
      persist(bestScore, clamped);
    },
    [bestScore, persist]
  );

  const handleReset = () => {
    if (phase === 'WON') return;
    setMustReset(false);
    setPhase('PLAY');
    setSelectedPeg(-1);
    setMoves(0);
    setElapsedSec(0);
    elapsedRef.current = 0;
    setPegs(makeInitialPegs(diskN));
    setHint({ text: '已复位 · 盘子回到左柱', color: '#8ab4ff' });
  };

  const handlePegClick = (pegIdx: number) => {
    if (paused) return;
    if (mustReset) {
      setHint({ text: '步数超限 · 请点「复位」重来', color: '#ff5d73' });
      return;
    }
    if (phase !== 'PLAY') return;

    if (selectedPeg < 0) {
      if (pegs[pegIdx].length === 0) return;
      setSelectedPeg(pegIdx);
      setHint({ text: '点目标柱放下', color: '#8ab4ff' });
      return;
    }

    if (pegIdx === selectedPeg) {
      setSelectedPeg(-1);
      setHint({ text: '把盘子移到右边绿线柱', color: '#7f8ba6' });
      return;
    }

    if (!canMoveHanoiDisk(pegs, selectedPeg, pegIdx)) {
      const moving = pegs[selectedPeg][pegs[selectedPeg].length - 1];
      setShakingDisk(moving);
      window.setTimeout(() => setShakingDisk((d) => (d === moving ? null : d)), 180);
      setHint({ text: '大盘不能压小盘', color: '#ff5d73' });
      return;
    }

    const nextPegs = pegs.map((p) => [...p]);
    const moving = nextPegs[selectedPeg].pop()!;
    nextPegs[pegIdx].push(moving);
    const nextMoves = moves + 1;
    setPegs(nextPegs);
    setSelectedPeg(-1);
    setMoves(nextMoves);

    const opt = hanoiOptimal(diskN);
    const lim = hanoiMoveLimit(diskN, OVER_FACTOR);

    if (nextPegs[2].length < diskN) {
      if (nextMoves > lim) {
        setHint({ text: '已超最优×1.5 · 过不了关，建议复位', color: '#ffb35d' });
      } else {
        setHint({ text: '把盘子移到右边绿线柱', color: '#7f8ba6' });
      }
      return;
    }

    if (nextMoves > lim) {
      setMustReset(true);
      setHint({ text: `步数 ${nextMoves} > 最优×1.5（${lim}）· 不算过关，请复位重来`, color: '#ff5d73' });
      triggerBurst('超步数', '#ff5d73');
      return;
    }

    setPhase('WON');
    const clearedN = diskN;
    let gained = clearedN * BASE_SCORE;
    let extra = '';
    const isOptimal = nextMoves <= opt;
    let nextN = diskN;
    if (isOptimal) {
      gained += clearedN * OPTIMAL_BONUS;
      extra = ' · 最优';
      if (diskN < MAX_DISKS) {
        nextN = diskN + 1;
        setDiskN(nextN);
        extra += ' · 下一关加盘';
      }
    } else {
      extra = ' · 非最优，本关通过（不加盘）';
    }
    const nextTotalScore = score + gained;
    setScore(nextTotalScore);
    const nextBest = Math.max(bestScore, nextTotalScore);
    persist(nextBest, nextN);

    const tone = isOptimal ? '#4ade80' : '#ffd75d';
    const pathText = formatOptimalPath(clearedN);
    setHint({ text: `过关 +${gained}${extra}\n最优路径：${pathText}`, color: tone });
    triggerBurst(`过关 +${gained}`, tone);
  };

  useEffect(() => {
    const id = window.setInterval(() => {
      if (phaseRef.current === 'PLAY' && !pausedRef.current) {
        elapsedRef.current += 1;
        setElapsedSec(elapsedRef.current);
      }
    }, 1000);
    return () => window.clearInterval(id);
  }, []);

  const optimal = hanoiOptimal(diskN);
  const limit = hanoiMoveLimit(diskN, OVER_FACTOR);

  return (
    <GameShell
      title="汉诺塔"
      helpText={HELP_TEXT}
      onBack={onBack}
      onPauseChange={setPaused}
      burst={burst}
      gameState={phase === 'WON' ? 'gameover' : 'playing'}
    >
      <div className="shrink-0 text-center">
        <div className="tabular-nums text-[22px] font-medium text-[#e8edff]">得分 {score}</div>
        <div className="tabular-nums mt-0.5 text-[16px] text-[#8ab4ff]">
          {phase === 'PICK'
            ? `上次做到 ${latestDisks} 盘`
            : `${diskN} 盘　步数 ${moves}／最优 ${optimal}（上限 ${limit}）　用时 ${elapsedSec} 秒`}
        </div>
        <div
          className="mt-1 min-h-[48px] whitespace-pre-line text-[15px] leading-snug"
          style={{ color: hint.color }}
        >
          {hint.text}
        </div>
      </div>

      {phase === 'PICK' ? (
        <ProgressGate
          body={`上次做到 ${latestDisks} 盘。\n这一局进最新一关，还是从 3 盘重来？`}
          continueText={`进入最新一关（${latestDisks} 盘）`}
          freshText="从头开始（3 盘）"
          onContinue={() => startLevel(latestDisks)}
          onFresh={() => startLevel(MIN_DISKS)}
        />
      ) : (
        <div className="mt-2 flex min-h-0 flex-1 flex-col items-center">
          {/* 3-Peg Board */}
          <div className="relative flex w-full flex-1 items-end justify-between rounded-[14px] bg-[#12192a]/60 px-2 pb-6 pt-8">
            {/* Base Bar */}
            <div className="pointer-events-none absolute right-4 bottom-4 left-4 h-3.5 rounded bg-[#1a2740]" />

            {[0, 1, 2].map((pegIdx) => {
              const stack = pegs[pegIdx];
              const isSelected = selectedPeg === pegIdx;
              return (
                <button
                  key={pegIdx}
                  type="button"
                  aria-label={`${PEG_NAMES[pegIdx]}柱`}
                  onClick={() => handlePegClick(pegIdx)}
                  className="relative flex h-full flex-1 flex-col items-center justify-end pb-2 focus:outline-none"
                >
                  {/* Goal Green Top Bar on Right Peg */}
                  {pegIdx === 2 && (
                    <div className="pointer-events-none absolute top-1 h-2 w-12 rounded bg-[#4ade80]" />
                  )}
                  {/* Peg Pole */}
                  <div
                    className="pointer-events-none absolute top-4 bottom-2 w-3.5 rounded-t transition-colors"
                    style={{ backgroundColor: isSelected ? '#ffd75d' : '#2a3a58' }}
                  />
                  {/* Disks */}
                  <div className="relative z-10 flex w-full flex-col-reverse items-center gap-1 px-1.5">
                    {stack.map((diskSize, stackIdx) => {
                      const isTop = stackIdx === stack.length - 1;
                      const lifted = isSelected && isTop;
                      const widthPct = 36 + ((diskSize - 1) / Math.max(diskN - 1, 1)) * 58;
                      return (
                        <div
                          key={diskSize}
                          className={`h-7 rounded-[8px] transition-transform duration-150 ${
                            shakingDisk === diskSize ? 'animate-disk-shake' : ''
                          }`}
                          style={{
                            width: `${widthPct}%`,
                            backgroundColor: DISK_COLORS[(diskSize - 1) % DISK_COLORS.length],
                            transform: lifted ? 'translateY(-24px)' : 'translateY(0)',
                          }}
                        />
                      );
                    })}
                  </div>
                </button>
              );
            })}
          </div>

          {/* Bottom Controls */}
          <div className="mt-4 flex w-full flex-col items-center gap-2.5">
            {phase === 'WON' && (
              <button
                type="button"
                data-start="true"
                onClick={() => startLevel(diskN)}
                className="h-[58px] w-[220px] rounded-[12px] bg-[#4ade80] text-[22px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
              >
                下一关
              </button>
            )}
            <button
              type="button"
              disabled={phase === 'WON'}
              onClick={handleReset}
              className="h-[54px] w-[220px] rounded-[12px] text-[20px] font-medium transition-colors"
              style={{
                backgroundColor: mustReset ? '#ff5d73' : '#1a2740',
                color: mustReset ? '#0d1220' : '#e8edff',
                opacity: phase === 'WON' ? 0.4 : 1,
              }}
            >
              {mustReset ? '复位重来' : '复位'}
            </button>
          </div>
        </div>
      )}
    </GameShell>
  );
};
