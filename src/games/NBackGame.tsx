import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell } from '../components/GameShell';
import { pickNBackPosition } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const CELL_COUNT = 9;
const START_N = 2;
const MIN_N = 2;
const MAX_N = 4;
const SOA = 1.8;
const STIM_TIME = 0.8;
const MATCH_RATIO = 0.3;
const UP_STREAK = 6;
const DOWN_STREAK = 3;
const SCORE_HIT = 10;
const TRIAL_LIMIT = 45;

const HELP_TEXT =
  '3×3 格子会依次亮起一个位置。开局会告诉你当前是几-Back。\n' +
  '2-Back 就是：现在亮的格子，要不要和往前第 2 个相同。前 2 个只看不点。\n' +
  '之后点「相同」或「不同」。答对 +10；一局固定 45 题。连对 6 次升 N，连错 3 次降 N。对错会标在刚亮的格子上。';

type Phase = 'READY' | 'PLAY' | 'OVER';

interface NBackGameProps {
  onBack: () => void;
}

export const NBackGame: React.FC<NBackGameProps> = ({ onBack }) => {
  const [phase, setPhase] = useState<Phase>('READY');
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [wrongStreak, setWrongStreak] = useState(0);
  const [bestScore, setBestScore] = useState(() => loadJSON('nback_best', { score: 0 }).score);
  const [nLevel, setNLevel] = useState(START_N);
  const [scoringDone, setScoringDone] = useState(0);
  const [missCount, setMissCount] = useState(0);
  const [litCell, setLitCell] = useState<number | null>(null);
  const [cellColor, setCellColor] = useState('#8ab4ff');
  const [canAnswer, setCanAnswer] = useState(false);
  const [hint, setHint] = useState({ text: '先看说明，再开始', color: '#7f8ba6' });
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const timerBarRef = useRef<HTMLDivElement>(null);
  const phaseRef = useRef<Phase>('READY');
  const pausedRef = useRef(false);
  const historyRef = useRef<number[]>([]);
  const nLevelRef = useRef(START_N);
  const currentPosRef = useRef(0);
  const isMatchRef = useRef(false);
  const stimElapsedRef = useRef(0);
  const showingRef = useRef(false);
  const answeredRef = useRef(false);
  const scoreRef = useRef(0);
  const streakRef = useRef(0);
  const wrongStreakRef = useRef(0);
  const scoringDoneRef = useRef(0);
  const missCountRef = useRef(0);
  const bestScoreRef = useRef(bestScore);
  const burstIdRef = useRef(0);

  pausedRef.current = paused;
  bestScoreRef.current = bestScore;

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const isScoringNow = () => historyRef.current.length > nLevelRef.current;

  const endGame = useCallback(() => {
    phaseRef.current = 'OVER';
    setPhase('OVER');
    showingRef.current = false;
    setLitCell(null);
    setCanAnswer(false);
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    let nextBest = bestScoreRef.current;
    if (isBest) {
      nextBest = finalScore;
      setBestScore(nextBest);
      bestScoreRef.current = nextBest;
      saveJSON('nback_best', { score: nextBest });
    }
    const suffix = isBest ? ' · 新纪录！' : nextBest > 0 ? ` · 最佳 ${nextBest}` : '';
    setHint({ text: `结束 · 得分 ${finalScore}${suffix}`, color: '#ffd75d' });
  }, []);

  const beginTrial = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    const { pos, isMatch } = pickNBackPosition(historyRef.current, nLevelRef.current, CELL_COUNT, MATCH_RATIO);
    currentPosRef.current = pos;
    isMatchRef.current = isMatch;
    historyRef.current.push(pos);
    stimElapsedRef.current = 0;
    showingRef.current = true;
    answeredRef.current = false;
    setLitCell(pos);
    setCellColor('#8ab4ff');
    const scoring = isScoringNow();
    setCanAnswer(scoring);
    if (scoring) {
      setHint({ text: `和 ${nLevelRef.current} 步前相同吗？`, color: '#7f8ba6' });
    } else {
      const remain = nLevelRef.current - historyRef.current.length;
      setHint({
        text: remain > 0 ? `记住位置 · 还剩 ${remain} 个不判分` : '记住这一个，下一个开始作答',
        color: '#7f8ba6',
      });
    }
  }, []);

  const handleMiss = useCallback(
    (reason: string) => {
      streakRef.current = 0;
      wrongStreakRef.current += 1;
      missCountRef.current += 1;
      scoringDoneRef.current += 1;
      setStreak(0);
      setWrongStreak(wrongStreakRef.current);
      setMissCount(missCountRef.current);
      setScoringDone(scoringDoneRef.current);
      setLitCell(currentPosRef.current);
      setCellColor('#ff5d73');
      setHint({ text: reason, color: '#ff5d73' });
      if (nLevelRef.current > MIN_N && wrongStreakRef.current >= DOWN_STREAK) {
        nLevelRef.current -= 1;
        wrongStreakRef.current = 0;
        setNLevel(nLevelRef.current);
        setWrongStreak(0);
        setHint({ text: `${reason} · 现在要比往前第 ${nLevelRef.current} 个`, color: '#ffd75d' });
      }
      if (scoringDoneRef.current >= TRIAL_LIMIT) {
        endGame();
      }
    },
    [endGame]
  );

  const handleAnswer = useCallback(
    (saidMatch: boolean) => {
      if (phaseRef.current !== 'PLAY' || answeredRef.current || !isScoringNow() || pausedRef.current) return;
      answeredRef.current = true;
      setCanAnswer(false);
      if (saidMatch === isMatchRef.current) {
        streakRef.current += 1;
        wrongStreakRef.current = 0;
        scoreRef.current += SCORE_HIT;
        scoringDoneRef.current += 1;
        setStreak(streakRef.current);
        setWrongStreak(0);
        setScore(scoreRef.current);
        setScoringDone(scoringDoneRef.current);
        setLitCell(currentPosRef.current);
        setCellColor('#4ade80');
        setHint({ text: `对  +${SCORE_HIT}`, color: '#4ade80' });
        if (streakRef.current >= UP_STREAK && nLevelRef.current < MAX_N) {
          nLevelRef.current += 1;
          streakRef.current = 0;
          setNLevel(nLevelRef.current);
          setStreak(0);
          setHint({ text: `现在要比往前第 ${nLevelRef.current} 个`, color: '#ffd75d' });
          triggerBurst(`升到 ${nLevelRef.current}-Back\n记住往前第 ${nLevelRef.current} 个`, '#ffd75d');
        }
        if (scoringDoneRef.current >= TRIAL_LIMIT) {
          endGame();
        }
      } else {
        handleMiss('答错了');
      }
    },
    [endGame, handleMiss, triggerBurst]
  );

  const startRound = useCallback(() => {
    scoreRef.current = 0;
    streakRef.current = 0;
    wrongStreakRef.current = 0;
    scoringDoneRef.current = 0;
    missCountRef.current = 0;
    nLevelRef.current = START_N;
    historyRef.current = [];
    showingRef.current = false;
    answeredRef.current = false;
    phaseRef.current = 'READY';
    setPhase('READY');
    setScore(0);
    setStreak(0);
    setWrongStreak(0);
    setScoringDone(0);
    setMissCount(0);
    setNLevel(START_N);
    setLitCell(null);
    setCanAnswer(false);
    setBurst(null);
    const best = bestScoreRef.current;
    setHint({ text: best > 0 ? `先看说明，再开始 · 最佳 ${best}` : '先看说明，再开始', color: '#7f8ba6' });
  }, []);

  const startPlay = useCallback(() => {
    if (phaseRef.current !== 'READY') return;
    phaseRef.current = 'PLAY';
    setPhase('PLAY');
    beginTrial();
  }, [beginTrial]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (pausedRef.current) return;
      if (phaseRef.current === 'READY' && (e.key === 'Enter' || e.key === ' ')) {
        e.preventDefault();
        startPlay();
        return;
      }
      if (phaseRef.current !== 'PLAY') return;
      if (e.key === 'f' || e.key === 'F' || e.key === 'ArrowLeft') handleAnswer(true);
      if (e.key === 'j' || e.key === 'J' || e.key === 'ArrowRight') handleAnswer(false);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [handleAnswer, startPlay]);

  useEffect(() => {
    let rafId = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (phaseRef.current === 'PLAY' && !pausedRef.current) {
        stimElapsedRef.current += dt;
        const ratio = Math.max(0, Math.min(1, 1 - stimElapsedRef.current / SOA));
        if (timerBarRef.current) {
          timerBarRef.current.style.width = `${ratio * 100}%`;
          timerBarRef.current.style.backgroundColor =
            ratio < 0.2 && isScoringNow() ? '#ff5d73' : '#8ab4ff';
        }
        if (showingRef.current && stimElapsedRef.current >= STIM_TIME) {
          showingRef.current = false;
          if (!answeredRef.current) {
            setLitCell(null);
          }
        }
        if (stimElapsedRef.current >= SOA) {
          if (isScoringNow() && !answeredRef.current) {
            handleMiss('没答');
          }
          if (phaseRef.current === 'PLAY') {
            beginTrial();
          }
        }
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, [beginTrial, handleMiss]);

  return (
    <GameShell
      title="N-Back"
      helpText={HELP_TEXT}
      onBack={onBack}
      onPauseChange={setPaused}
      burst={burst}
      gameState={phase === 'OVER' ? 'gameover' : 'playing'}
    >
      {/* HUD */}
      <div className="shrink-0 text-center">
        <div className="tabular-nums text-[22px] font-medium text-[#e8edff]">
          得分 {score}　连击 {streak}
        </div>
        <div className="tabular-nums text-[17px] text-[#ff8f9d]">
          题 {scoringDone}／{TRIAL_LIMIT}　错 {missCount}
        </div>
        <div className="mt-1 text-[30px] font-bold text-[#ffd75d]">
          {nLevel}-Back　·　往前第 {nLevel} 个
        </div>
        <div className="tabular-nums text-[15px] text-[#8ab4ff]">
          {phase === 'READY'
            ? `一局 ${TRIAL_LIMIT} 题 · 先记住往前第 ${nLevel} 个`
            : `升阶 ${streak}／${UP_STREAK}　连错降阶 ${wrongStreak}／${DOWN_STREAK}`}
        </div>
      </div>

      {/* Main Grid or Brief */}
      <div className="my-3 flex min-h-0 flex-1 items-center justify-center">
        {phase === 'READY' ? (
          <div className="flex aspect-square w-full max-w-[340px] items-center justify-center rounded-[14px] bg-[#1a2740] p-6 text-center text-[19px] leading-relaxed whitespace-pre-line text-[#e8edff]">
            {`当前是 ${nLevel}-Back\n\n请记住往前第 ${nLevel} 个亮过的格子。\n现在亮的位置，要和倒着数第 ${nLevel} 个比是不是同一格。\n\n先看 ${nLevel} 个，不用点。\n从第 ${nLevel + 1} 个开始按「相同」或「不同」。`}
          </div>
        ) : (
          <div className="grid aspect-square w-full max-w-[340px] grid-cols-3 gap-3">
            {Array.from({ length: CELL_COUNT }, (_, idx) => (
              <div
                key={idx}
                className="rounded-[12px] transition-colors duration-100"
                style={{ backgroundColor: litCell === idx ? cellColor : '#1a2740' }}
              />
            ))}
          </div>
        )}
      </div>

      {/* Timer Bar & Hint */}
      {phase === 'PLAY' && (
        <div className="mx-auto mb-2 h-2.5 w-full max-w-[400px] overflow-hidden rounded-full bg-[#1a2740]">
          <div ref={timerBarRef} className="h-full rounded-full bg-[#8ab4ff]" style={{ width: '100%' }} />
        </div>
      )}
      <div className="mb-3 min-h-[26px] text-center text-[17px]" style={{ color: hint.color }}>
        {hint.text}
      </div>

      {/* Action Buttons */}
      <div className="shrink-0">
        {phase === 'READY' ? (
          <button
            type="button"
            data-start="true"
            onClick={startPlay}
            className="mx-auto block h-[84px] w-[260px] rounded-[12px] bg-[#4ade80] text-[26px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
          >
            开始
          </button>
        ) : phase === 'OVER' ? (
          <button
            type="button"
            data-start="true"
            onClick={startRound}
            className="mx-auto block h-[64px] w-[240px] rounded-[12px] bg-[#4ade80] text-[22px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
          >
            重新开始
          </button>
        ) : (
          <div className="grid grid-cols-2 gap-4">
            <button
              type="button"
              disabled={!canAnswer}
              onClick={() => handleAnswer(true)}
              className="h-[96px] rounded-[12px] bg-[#4ade80] text-[28px] font-semibold text-[#0d1220] transition-opacity"
              style={{ opacity: canAnswer ? 1 : 0.4 }}
            >
              相同
            </button>
            <button
              type="button"
              disabled={!canAnswer}
              onClick={() => handleAnswer(false)}
              className="h-[96px] rounded-[12px] bg-[#1a2740] text-[28px] font-semibold text-[#e8edff] transition-opacity"
              style={{ opacity: canAnswer ? 1 : 0.4 }}
            >
              不同
            </button>
          </div>
        )}
      </div>
    </GameShell>
  );
};
