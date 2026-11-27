import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell, ProgressGate } from '../components/GameShell';
import { generateSchulteGrid } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const MIN_SIZE = 5;
const MAX_SIZE = 7;
const BREATH_SIZE = 4;
const NEXT_BOARD_GAP_MS = 700;

const HELP_TEXT =
  '格子里随机排着数字。从 1 开始按顺序点，越快越好。点错会闪红并计入失误，但不用从头来。第一次点击开始计时。\n' +
  '点完 5×5 会上 6×6，再上 7×7。每升一档前会插一局轻松的 4×4「呼吸关」，点完再继续变难。格子不会在中途换位。\n' +
  '做到哪一档会记住。再进时选继续最新一档，或从 5×5 重来。';

interface SchulteSave {
  size: number;
  best4: number;
  best5: number;
  best6: number;
  best7: number;
}

const DEFAULT_SAVE: SchulteSave = {
  size: MIN_SIZE,
  best4: -1,
  best5: -1,
  best6: -1,
  best7: -1,
};

interface SchulteGameProps {
  onBack: () => void;
}

export const SchulteGame: React.FC<SchulteGameProps> = ({ onBack }) => {
  const [save, setSave] = useState<SchulteSave>(() => loadJSON('schulte_best', DEFAULT_SAVE));
  const [phase, setPhase] = useState<'GATE' | 'PLAY'>(() =>
    loadJSON('schulte_best', DEFAULT_SAVE).size > MIN_SIZE ? 'GATE' : 'PLAY'
  );
  const [gridSize, setGridSize] = useState(MIN_SIZE);
  const [breathMode, setBreathMode] = useState(false);
  const [afterBreathSize, setAfterBreathSize] = useState(-1);
  const [numbers, setNumbers] = useState<number[]>(() => generateSchulteGrid(MIN_SIZE));
  const [nextNum, setNextNum] = useState(1);
  const [started, setStarted] = useState(false);
  const [finished, setFinished] = useState(false);
  const [mistakes, setMistakes] = useState(0);
  const [wrongCell, setWrongCell] = useState<number | null>(null);
  const [finishBanner, setFinishBanner] = useState<{ text: string; color: string } | null>(null);
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const timeDisplayRef = useRef<HTMLDivElement>(null);
  const elapsedRef = useRef(0);
  const startedRef = useRef(false);
  const finishedRef = useRef(false);
  const pausedRef = useRef(false);
  const boardIdRef = useRef(0);
  const timerRef = useRef<number | null>(null);
  const burstIdRef = useRef(0);

  startedRef.current = started;
  finishedRef.current = finished;
  pausedRef.current = paused;

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const persistSave = useCallback((next: SchulteSave) => {
    setSave(next);
    saveJSON('schulte_best', next);
  }, []);

  const bestKeyFor = (sz: number): keyof SchulteSave => {
    if (sz === 4) return 'best4';
    if (sz === 6) return 'best6';
    if (sz === 7) return 'best7';
    return 'best5';
  };

  const startBoardRaw = useCallback(
    (sz: number, isBreath: boolean, nextAfter: number) => {
      if (timerRef.current !== null) {
        window.clearTimeout(timerRef.current);
        timerRef.current = null;
      }
      boardIdRef.current += 1;
      setPhase('PLAY');
      setGridSize(sz);
      setBreathMode(isBreath);
      setAfterBreathSize(nextAfter);
      setNumbers(generateSchulteGrid(sz));
      setNextNum(1);
      setStarted(false);
      setFinished(false);
      setMistakes(0);
      setWrongCell(null);
      setFinishBanner(null);
      elapsedRef.current = 0;
      if (timeDisplayRef.current) {
        timeDisplayRef.current.textContent = '时间  0.00 秒';
      }
      if (!isBreath) {
        setSave((prev) => {
          const updated = { ...prev, size: Math.min(MAX_SIZE, Math.max(MIN_SIZE, Math.max(prev.size, sz))) };
          saveJSON('schulte_best', updated);
          return updated;
        });
      }
    },
    []
  );

  const handleCellClick = (num: number, idx: number) => {
    if (phase !== 'PLAY' || finished || paused) return;
    if (!started) {
      setStarted(true);
      startedRef.current = true;
    }
    if (num < nextNum) return;
    if (num === nextNum) {
      const total = gridSize * gridSize;
      const upcoming = nextNum + 1;
      setNextNum(upcoming);
      if (upcoming > total) {
        setFinished(true);
        finishedRef.current = true;
        setStarted(false);
        startedRef.current = false;
        const elapsed = elapsedRef.current;
        const key = bestKeyFor(gridSize);
        const prevBest = save[key];
        const isBest = prevBest < 0 || elapsed < prevBest;
        const nextSave: SchulteSave = { ...save };
        if (isBest) nextSave[key] = elapsed;

        const sizeLabel = `${gridSize}×${gridSize}`;
        const suffix = isBest ? ' · 新纪录' : '';
        const myBoardId = boardIdRef.current;

        if (breathMode) {
          persistSave(nextSave);
          setFinishBanner({
            text: `呼吸关 ${sizeLabel} 完成 ${elapsed.toFixed(2)} 秒（点错 ${mistakes}）${suffix}`,
            color: '#8ab4ff',
          });
          triggerBurst('轻松一下', '#8ab4ff');
          timerRef.current = window.setTimeout(() => {
            if (boardIdRef.current !== myBoardId) return;
            const target = afterBreathSize >= MIN_SIZE ? afterBreathSize : MAX_SIZE;
            startBoardRaw(target, false, -1);
          }, NEXT_BOARD_GAP_MS);
        } else {
          const nextSize = gridSize < MAX_SIZE ? gridSize + 1 : MAX_SIZE;
          nextSave.size = Math.max(nextSave.size, nextSize);
          persistSave(nextSave);
          setFinishBanner({
            text: `${sizeLabel} 完成 ${elapsed.toFixed(2)} 秒（点错 ${mistakes}）${suffix}`,
            color: isBest ? '#ffd75d' : '#4ade80',
          });
          triggerBurst(sizeLabel, isBest ? '#ffd75d' : '#4ade80');
          timerRef.current = window.setTimeout(() => {
            if (boardIdRef.current !== myBoardId) return;
            startBoardRaw(BREATH_SIZE, true, nextSize);
          }, NEXT_BOARD_GAP_MS);
        }
      }
    } else {
      setMistakes((m) => m + 1);
      setWrongCell(idx);
      window.setTimeout(() => {
        setWrongCell((curr) => (curr === idx ? null : curr));
      }, 280);
    }
  };

  useEffect(() => {
    let rafId = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (startedRef.current && !finishedRef.current && !pausedRef.current) {
        elapsedRef.current += dt;
        if (timeDisplayRef.current) {
          timeDisplayRef.current.textContent = `时间  ${elapsedRef.current.toFixed(2)} 秒`;
        }
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(rafId);
      if (timerRef.current !== null) window.clearTimeout(timerRef.current);
    };
  }, []);

  const total = gridSize * gridSize;
  const bestForGrid = save[bestKeyFor(gridSize)];
  const tag = breathMode ? '呼吸关 ' : '';
  let statusText = '';
  let statusColor = '#7f8ba6';
  if (phase === 'GATE') {
    statusText = '选这一局从哪档开始';
  } else if (finishBanner) {
    statusText = finishBanner.text;
    statusColor = finishBanner.color;
  } else if (!started) {
    const head = `${tag}${gridSize}×${gridSize}  下一个 1／${total}`;
    if (breathMode) {
      statusText = `${head} · 轻松一局后再变难`;
    } else if (bestForGrid > 0) {
      statusText = `${head} · 最佳 ${bestForGrid.toFixed(2)} 秒`;
    } else {
      statusText = `${head} · 按顺序点击`;
    }
  } else {
    statusColor = '#8ab4ff';
    statusText = `${tag}${gridSize}×${gridSize}  下一个 ${nextNum}／${total}${mistakes > 0 ? ` · 点错 ${mistakes}` : ''}`;
  }

  return (
    <GameShell
      title="舒尔特方格"
      helpText={HELP_TEXT}
      onBack={onBack}
      onPauseChange={setPaused}
      burst={burst}
      gameState="playing"
    >
      <div className="shrink-0 text-center">
        <div ref={timeDisplayRef} className="tabular-nums text-[24px] font-medium text-[#e8edff]">
          {phase === 'GATE' ? '时间  —' : '时间  0.00 秒'}
        </div>
        <div className="mt-1 text-[17px]" style={{ color: statusColor }}>
          {statusText}
        </div>
      </div>

      {phase === 'GATE' ? (
        <ProgressGate
          body={`上次做到 ${save.size}×${save.size}。\n这一局进最新一档，还是从 5×5 重来？`}
          continueText={`进入最新一关（${save.size}×${save.size}）`}
          freshText="从头开始（5×5）"
          onContinue={() => startBoardRaw(save.size, false, -1)}
          onFresh={() => {
            const reset = { ...save, size: MIN_SIZE };
            persistSave(reset);
            startBoardRaw(MIN_SIZE, false, -1);
          }}
        />
      ) : (
        <div className="mt-5 flex min-h-0 flex-1 flex-col items-center justify-start">
          <div
            className="grid aspect-square w-full max-w-[460px] gap-2"
            style={{ gridTemplateColumns: `repeat(${gridSize}, minmax(0, 1fr))` }}
          >
            {numbers.map((num, idx) => {
              const done = num < nextNum;
              const isWrong = wrongCell === idx;
              return (
                <button
                  key={`${boardIdRef.current}-${idx}`}
                  type="button"
                  disabled={done}
                  onClick={() => handleCellClick(num, idx)}
                  className="tabular-nums flex items-center justify-center rounded-[10px] font-semibold transition-all duration-150"
                  style={{
                    fontSize: gridSize >= 7 ? '18px' : gridSize === 6 ? '22px' : '26px',
                    backgroundColor: isWrong
                      ? '#ff5d73'
                      : done
                        ? '#132034'
                        : '#1a2740',
                    color: done ? '#4a6a8f' : '#e8edff',
                    border: done ? '1px solid rgba(74,222,128,0.28)' : '1px solid transparent',
                  }}
                >
                  {num}
                </button>
              );
            })}
          </div>

          <button
            type="button"
            onClick={() => {
              if (breathMode) {
                startBoardRaw(BREATH_SIZE, true, afterBreathSize);
              } else if (finished && gridSize < MAX_SIZE) {
                startBoardRaw(gridSize + 1, false, -1);
              } else {
                startBoardRaw(gridSize, false, -1);
              }
            }}
            className="mt-6 h-[56px] w-[220px] rounded-[12px] bg-[#1a2740] text-[20px] font-medium text-[#e8edff] transition-colors hover:bg-[#243656]"
          >
            重新开始
          </button>
        </div>
      )}
    </GameShell>
  );
};
