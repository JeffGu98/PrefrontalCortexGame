import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell, ProgressGate } from '../components/GameShell';
import { calcStroopPoints, generateStroopTrial, StroopTrial } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const LIVES = 3;
const SCORE_MISS = 10;
const TIME_START = 2.5;
const TIME_MIN = 0.9;
const TIME_STEP = 0.08;
const TIME_RECOVER = 0.05;
const SPEED_EVERY = 4;
const CONGRUENT_RATIO = 0.12;
const INTER_TRIAL_MS = 350;
const BURST_CUTOFF = 1.1;
const HINT_IDLE = '点选项上的字，对上题目字的颜色';

const HELP_TEXT =
  '中央是有颜色的字。多数时候字义和字体颜色不同，偶有相同。点下面写着「字体颜色」的按钮。\n' +
  '简单：选项灰底黑字，位置每题仍会变。困难：选项底色是干扰，不要对色块。\n' +
  '每题从 2.5 秒起，连对会加快（约每 4 连 −0.08 秒，下限约 0.9 秒）；点错略放慢。超时或点错扣一命并 −10 分。';

type Phase = 'GATE' | 'PLAY' | 'OVER';

interface StroopGameProps {
  onBack: () => void;
}

export const StroopGame: React.FC<StroopGameProps> = ({ onBack }) => {
  const [phase, setPhase] = useState<Phase>('GATE');
  const [easyMode, setEasyMode] = useState(true);
  const [score, setScore] = useState(0);
  const [lives, setLives] = useState(LIVES);
  const [streak, setStreak] = useState(0);
  const [bestScore, setBestScore] = useState(() => loadJSON('stroop_best', { score: 0 }).score);
  const [trialLimit, setTrialLimit] = useState(TIME_START);
  const [trial, setTrial] = useState<StroopTrial | null>(null);
  const [waiting, setWaiting] = useState(false);
  const [wordHighlight, setWordHighlight] = useState<string | null>(null);
  const [wrongIndex, setWrongIndex] = useState<number | null>(null);
  const [hint, setHint] = useState({ text: '选这一局的难度', color: '#7f8ba6' });
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const timerBarRef = useRef<HTMLDivElement>(null);
  const timeLeftRef = useRef(TIME_START);
  const trialLimitRef = useRef(TIME_START);
  const phaseRef = useRef<Phase>('GATE');
  const waitingRef = useRef(false);
  const pausedRef = useRef(false);
  const easyModeRef = useRef(true);
  const scoreRef = useRef(0);
  const livesRef = useRef(LIVES);
  const streakRef = useRef(0);
  const bestStreakRef = useRef(0);
  const bestScoreRef = useRef(bestScore);
  const gapTimerRef = useRef<number | null>(null);
  const burstIdRef = useRef(0);

  phaseRef.current = phase;
  waitingRef.current = waiting;
  pausedRef.current = paused;
  easyModeRef.current = easyMode;
  bestScoreRef.current = bestScore;

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const clearGap = () => {
    if (gapTimerRef.current !== null) {
      window.clearTimeout(gapTimerRef.current);
      gapTimerRef.current = null;
    }
  };

  const spawnTrial = useCallback((isEasy: boolean) => {
    const next = generateStroopTrial(isEasy, CONGRUENT_RATIO);
    setTrial(next);
    setWaiting(false);
    waitingRef.current = false;
    setWordHighlight(null);
    setWrongIndex(null);
    timeLeftRef.current = trialLimitRef.current;
    if (timerBarRef.current) {
      timerBarRef.current.style.width = '100%';
      timerBarRef.current.style.backgroundColor = '#8ab4ff';
    }
    setHint({ text: HINT_IDLE, color: '#7f8ba6' });
  }, []);

  const endGame = useCallback(() => {
    clearGap();
    setPhase('OVER');
    phaseRef.current = 'OVER';
    setWaiting(true);
    waitingRef.current = true;
    if (timerBarRef.current) {
      timerBarRef.current.style.width = '0%';
    }
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    let nextBest = bestScoreRef.current;
    if (isBest) {
      nextBest = finalScore;
      setBestScore(nextBest);
      bestScoreRef.current = nextBest;
      saveJSON('stroop_best', { score: nextBest });
    }
    const parts = [`最佳连击 ${bestStreakRef.current}`];
    if (nextBest > 0) parts.push(`历史最佳 ${nextBest}`);
    if (isBest && finalScore > 0) parts.push('新纪录');
    setHint({ text: parts.join(' · '), color: '#ffd75d' });
  }, []);

  const scheduleNextTrial = useCallback(() => {
    clearGap();
    gapTimerRef.current = window.setTimeout(() => {
      if (phaseRef.current !== 'PLAY') return;
      spawnTrial(easyModeRef.current);
    }, INTER_TRIAL_MS);
  }, [spawnTrial]);

  const applyMiss = useCallback(
    (reason: string) => {
      streakRef.current = 0;
      setStreak(0);
      const nextLimit = Math.min(TIME_START, trialLimitRef.current + TIME_RECOVER);
      trialLimitRef.current = nextLimit;
      setTrialLimit(nextLimit);
      const nextLives = livesRef.current - 1;
      livesRef.current = nextLives;
      setLives(nextLives);
      const nextScore = Math.max(0, scoreRef.current - SCORE_MISS);
      scoreRef.current = nextScore;
      setScore(nextScore);

      const missText = `${reason} · −${SCORE_MISS}`;
      setHint({ text: missText, color: '#ff5d73' });
      if (nextLimit > BURST_CUTOFF) {
        triggerBurst(missText, '#ff5d73');
      }
      if (nextLives <= 0) {
        endGame();
      } else {
        scheduleNextTrial();
      }
    },
    [endGame, scheduleNextTrial, triggerBurst]
  );

  const startPlay = useCallback(
    (isEasy: boolean) => {
      clearGap();
      setEasyMode(isEasy);
      easyModeRef.current = isEasy;
      setPhase('PLAY');
      phaseRef.current = 'PLAY';
      scoreRef.current = 0;
      livesRef.current = LIVES;
      streakRef.current = 0;
      bestStreakRef.current = 0;
      trialLimitRef.current = TIME_START;
      setScore(0);
      setLives(LIVES);
      setStreak(0);
      setTrialLimit(TIME_START);
      setBurst(null);
      spawnTrial(isEasy);
    },
    [spawnTrial]
  );

  const handleChoice = (name: string, idx: number) => {
    if (phaseRef.current !== 'PLAY' || waitingRef.current || !trial || pausedRef.current) return;
    setWaiting(true);
    waitingRef.current = true;
    if (name === trial.correctName) {
      const nextStreak = streakRef.current + 1;
      streakRef.current = nextStreak;
      setStreak(nextStreak);
      if (nextStreak > bestStreakRef.current) {
        bestStreakRef.current = nextStreak;
      }
      let nextLimit = trialLimitRef.current;
      if (nextStreak > 0 && nextStreak % SPEED_EVERY === 0) {
        nextLimit = Math.max(TIME_MIN, nextLimit - TIME_STEP);
        trialLimitRef.current = nextLimit;
        setTrialLimit(nextLimit);
      }
      const pts = calcStroopPoints(timeLeftRef.current, nextLimit, nextStreak);
      scoreRef.current += pts;
      setScore(scoreRef.current);
      setWordHighlight('#4ade80');
      setHint({ text: `+${pts}`, color: '#4ade80' });
      if (nextLimit > BURST_CUTOFF) {
        triggerBurst(`+${pts}`, '#4ade80');
      }
      scheduleNextTrial();
    } else {
      setWrongIndex(idx);
      applyMiss('点错了');
    }
  };

  useEffect(() => {
    let rafId = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (phaseRef.current === 'PLAY' && !waitingRef.current && !pausedRef.current) {
        timeLeftRef.current -= dt;
        if (timeLeftRef.current <= 0) {
          timeLeftRef.current = 0;
          waitingRef.current = true;
          setWaiting(true);
          if (timerBarRef.current) timerBarRef.current.style.width = '0%';
          applyMiss('超时');
        } else if (timerBarRef.current) {
          const ratio = Math.max(0, Math.min(1, timeLeftRef.current / Math.max(trialLimitRef.current, 0.01)));
          timerBarRef.current.style.width = `${ratio * 100}%`;
          timerBarRef.current.style.backgroundColor = ratio < 0.25 ? '#ff5d73' : '#8ab4ff';
        }
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(rafId);
      clearGap();
    };
  }, [applyMiss]);

  return (
    <GameShell
      title="反向色字"
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
        <div
          className="tabular-nums mt-0.5 text-[17px]"
          style={{ color: phase === 'GATE' ? '#8ab4ff' : '#ff8f9d' }}
        >
          {phase === 'GATE'
            ? '选简单或困难'
            : `生命 ${lives}/${LIVES} · ${easyMode ? '简单' : '困难'} · 每题 ${trialLimit.toFixed(2)} 秒`}
        </div>
      </div>

      {phase === 'GATE' ? (
        <ProgressGate
          body={'这一局要简单还是困难？\n简单：选项灰底黑字，位置仍会变。\n困难：选项底色是干扰。'}
          continueText="简单"
          freshText="困难"
          onContinue={() => startPlay(true)}
          onFresh={() => startPlay(false)}
        />
      ) : (
        <div className="mt-4 flex min-h-0 flex-1 flex-col items-center">
          {/* Stimulus Panel */}
          <div className="flex h-[210px] w-full items-center justify-center rounded-[14px] bg-[#1a2740]">
            <span
              className="text-[116px] font-bold leading-none transition-colors"
              style={{
                color:
                  phase === 'OVER'
                    ? '#e8edff'
                    : wordHighlight ?? trial?.inkColor ?? '#e8edff',
              }}
            >
              {phase === 'OVER' ? '结束' : trial?.wordName ?? ''}
            </span>
          </div>

          {/* Hint */}
          <div
            className="mt-3 min-h-[28px] text-center text-[17px] font-medium"
            style={{ color: hint.color }}
          >
            {hint.text}
          </div>

          {/* Timer Bar */}
          <div className="mt-2 h-3 w-full max-w-[400px] overflow-hidden rounded-full bg-[#1a2740]">
            <div
              ref={timerBarRef}
              className="h-full rounded-full bg-[#8ab4ff]"
              style={{ width: phase === 'OVER' ? '0%' : '100%' }}
            />
          </div>

          {/* 2x2 Choice Buttons */}
          {phase === 'PLAY' && trial && (
            <div className="mt-5 grid w-full grid-cols-2 gap-4">
              {trial.choices.map((c, idx) => (
                <button
                  key={`${c.name}-${idx}`}
                  type="button"
                  disabled={waiting}
                  onClick={() => handleChoice(c.name, idx)}
                  className="flex h-[132px] items-center justify-center rounded-[12px] text-[42px] font-bold text-[#0d1220] transition-transform active:scale-90"
                  style={{
                    backgroundColor: wrongIndex === idx ? '#ff5d73' : c.bg,
                  }}
                >
                  {c.name}
                </button>
              ))}
            </div>
          )}

          {phase === 'OVER' && (
            <div className="mt-8 flex w-full max-w-[260px] flex-col gap-3">
              <button
                type="button"
                data-start="true"
                onClick={() => startPlay(easyMode)}
                className="h-[60px] w-full rounded-[12px] bg-[#1a2740] text-[22px] font-medium text-[#e8edff] transition-colors hover:bg-[#243656]"
              >
                重新开始
              </button>
              <button
                type="button"
                onClick={() => {
                  setPhase('GATE');
                  setHint({ text: '选这一局的难度', color: '#7f8ba6' });
                }}
                className="h-[52px] w-full rounded-[12px] bg-[#152034] text-[18px] text-[#8ab4ff] transition-colors hover:bg-[#1e2d47]"
              >
                切换难度（当前：{easyMode ? '简单' : '困难'}）
              </button>
            </div>
          )}
        </div>
      )}
    </GameShell>
  );
};
