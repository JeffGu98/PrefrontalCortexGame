import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell } from '../components/GameShell';
import { randInt, switchCorrectSide, SwitchRule } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const LIVES = 3;
const TRIAL_TIME_START = 1.6;
const TRIAL_TIME_MIN = 0.9;
const INTER_TRIAL_MS = 350;
const SCORE_REPEAT = 10;
const SCORE_SWITCH = 20;
const BLUE = '#5d9bff';
const ORANGE = '#ffb35d';

const HELP_TEXT =
  '中央出现 1–9 的数字（没有 5）。上方色块是当前规则：蓝=奇偶，橙=大于/小于 5。\n' +
  '按规则点对应按钮。规则会不时切换；切对了分更高。顶部会提示距下次切换还有几题。\n' +
  '每题开局约 1.6 秒，连对会更快；点错或超时扣命。';

type Phase = 'READY' | 'PLAY' | 'GAP' | 'OVER';

interface SwitchGameProps {
  onBack: () => void;
}

export const SwitchGame: React.FC<SwitchGameProps> = ({ onBack }) => {
  const [phase, setPhase] = useState<Phase>('READY');
  const [score, setScore] = useState(0);
  const [lives, setLives] = useState(LIVES);
  const [streak, setStreak] = useState(0);
  const [bestScore, setBestScore] = useState(() => loadJSON('switch_best', { score: 0 }).score);
  const [rule, setRule] = useState<SwitchRule>(0);
  const [stayLeft, setStayLeft] = useState(2);
  const [num, setNum] = useState<number | null>(null);
  const [numTint, setNumTint] = useState('#e8edff');
  const [hint, setHint] = useState({ text: '先看清蓝/橙规则', color: '#7f8ba6' });
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const timerBarRef = useRef<HTMLDivElement>(null);
  const phaseRef = useRef<Phase>('READY');
  const pausedRef = useRef(false);
  const ruleRef = useRef<SwitchRule>(0);
  const stayLeftRef = useRef(2);
  const isSwitchRef = useRef(false);
  const numRef = useRef(1);
  const scoreRef = useRef(0);
  const livesRef = useRef(LIVES);
  const streakRef = useRef(0);
  const bestScoreRef = useRef(bestScore);
  const trialLimitRef = useRef(TRIAL_TIME_START);
  const trialLeftRef = useRef(TRIAL_TIME_START);
  const gapTimerRef = useRef<number | null>(null);
  const burstIdRef = useRef(0);

  pausedRef.current = paused;
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

  const endGame = useCallback(() => {
    clearGap();
    phaseRef.current = 'OVER';
    setPhase('OVER');
    setNumTint('#e8edff');
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    let nextBest = bestScoreRef.current;
    if (isBest) {
      nextBest = finalScore;
      setBestScore(nextBest);
      bestScoreRef.current = nextBest;
      saveJSON('switch_best', { score: nextBest });
    }
    const suffix = isBest ? ' · 新纪录！' : nextBest > 0 ? ` · 最佳 ${nextBest}` : '';
    setHint({ text: `结束 · 得分 ${finalScore}${suffix}`, color: '#ffd75d' });
  }, []);

  const newTrial = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    phaseRef.current = 'PLAY';
    setPhase('PLAY');
    const t = Math.min(1, Math.max(0, streakRef.current / 10));
    const lim = Math.max(TRIAL_TIME_MIN, TRIAL_TIME_START + (TRIAL_TIME_MIN - TRIAL_TIME_START) * t);
    trialLimitRef.current = lim;
    trialLeftRef.current = lim;
    isSwitchRef.current = false;
    stayLeftRef.current -= 1;
    if (stayLeftRef.current <= 0) {
      ruleRef.current = ruleRef.current === 0 ? 1 : 0;
      stayLeftRef.current = randInt(1, 3);
      isSwitchRef.current = true;
    }
    setRule(ruleRef.current);
    setStayLeft(stayLeftRef.current);
    const nextNum = Math.random() < 0.5 ? randInt(1, 4) : randInt(6, 9);
    numRef.current = nextNum;
    setNum(nextNum);
    setNumTint('#e8edff');
    if (timerBarRef.current) {
      timerBarRef.current.style.width = '100%';
      timerBarRef.current.style.backgroundColor = '#8ab4ff';
    }
    setHint(
      isSwitchRef.current
        ? { text: '规则变了', color: '#ffd75d' }
        : { text: '判断', color: '#7f8ba6' }
    );
  }, []);

  const scheduleNext = useCallback(() => {
    clearGap();
    phaseRef.current = 'GAP';
    setPhase('GAP');
    gapTimerRef.current = window.setTimeout(() => {
      if (phaseRef.current === 'OVER') return;
      newTrial();
    }, INTER_TRIAL_MS);
  }, [newTrial]);

  const applyMiss = useCallback(
    (reason: string) => {
      streakRef.current = 0;
      livesRef.current -= 1;
      setStreak(0);
      setLives(livesRef.current);
      setNumTint('#ff5d73');
      setHint({ text: reason, color: '#ff5d73' });
      triggerBurst(reason, '#ff5d73');
      if (livesRef.current <= 0) {
        endGame();
      } else {
        scheduleNext();
      }
    },
    [endGame, scheduleNext, triggerBurst]
  );

  const handleAnswer = useCallback(
    (side: 0 | 1) => {
      if (phaseRef.current !== 'PLAY' || pausedRef.current) return;
      if (side === switchCorrectSide(ruleRef.current, numRef.current)) {
        const pts = isSwitchRef.current ? SCORE_SWITCH : SCORE_REPEAT;
        streakRef.current += 1;
        scoreRef.current += pts;
        setStreak(streakRef.current);
        setScore(scoreRef.current);
        setNumTint('#4ade80');
        setHint({ text: `+${pts}${isSwitchRef.current ? ' · 切对了' : ''}`, color: '#4ade80' });
        triggerBurst(`+${pts}`, '#4ade80');
        scheduleNext();
      } else {
        applyMiss('点错了');
      }
    },
    [applyMiss, scheduleNext, triggerBurst]
  );

  const startRound = useCallback(() => {
    clearGap();
    scoreRef.current = 0;
    livesRef.current = LIVES;
    streakRef.current = 0;
    ruleRef.current = Math.random() < 0.5 ? 0 : 1;
    stayLeftRef.current = randInt(1, 3);
    isSwitchRef.current = false;
    phaseRef.current = 'READY';
    setPhase('READY');
    setScore(0);
    setLives(LIVES);
    setStreak(0);
    setRule(ruleRef.current);
    setStayLeft(stayLeftRef.current);
    setNum(null);
    setBurst(null);
    const best = bestScoreRef.current;
    setHint({
      text: best > 0 ? `先看清蓝/橙规则 · 最佳 ${best}` : '先看清蓝/橙规则',
      color: '#7f8ba6',
    });
  }, []);

  useEffect(() => {
    startRound();
  }, [startRound]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (pausedRef.current) return;
      if (phaseRef.current === 'READY' && (e.key === 'Enter' || e.key === ' ')) {
        e.preventDefault();
        newTrial();
        return;
      }
      if (phaseRef.current !== 'PLAY') return;
      if (e.key === 'ArrowLeft' || e.key === 'f' || e.key === 'F') handleAnswer(0);
      if (e.key === 'ArrowRight' || e.key === 'j' || e.key === 'J') handleAnswer(1);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [handleAnswer, newTrial]);

  useEffect(() => {
    let rafId = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (phaseRef.current === 'PLAY' && !pausedRef.current) {
        trialLeftRef.current -= dt;
        const ratio = Math.max(0, Math.min(1, trialLeftRef.current / Math.max(trialLimitRef.current, 0.001)));
        if (timerBarRef.current) {
          timerBarRef.current.style.width = `${ratio * 100}%`;
          timerBarRef.current.style.backgroundColor = ratio < 0.25 ? '#ff5d73' : '#8ab4ff';
        }
        if (trialLeftRef.current <= 0) {
          applyMiss('超时');
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

  const ruleBg = rule === 0 ? BLUE : ORANGE;
  const btnBg = rule === 0 ? '#4674bf' : '#bf8646';

  return (
    <GameShell
      title="任务切换"
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
        <div className="tabular-nums mt-0.5 text-[17px] text-[#ff8f9d]">
          {phase === 'READY' || phase === 'OVER'
            ? `生命 ${lives}/${LIVES}`
            : `生命 ${lives}/${LIVES} · 距切换 ${Math.max(stayLeft, 1)} 题`}
        </div>
      </div>

      {/* Rule Banner */}
      <div
        className="mt-4 flex h-[70px] w-full shrink-0 items-center justify-center rounded-[12px] text-[26px] font-bold text-[#0d1220] transition-colors"
        style={{ backgroundColor: ruleBg }}
      >
        {rule === 0 ? '奇偶' : '大于 / 小于 5'}
      </div>

      {/* Center Stimulus or Brief */}
      <div className="my-4 flex min-h-0 flex-1 items-center justify-center">
        {phase === 'READY' ? (
          <div className="flex w-full items-center justify-center rounded-[14px] bg-[#152034] px-6 py-8 text-center text-[20px] leading-relaxed whitespace-pre-line text-[#e8edff]">
            {'上方色块就是当前规则。\n蓝底：判断奇数还是偶数\n橙底：判断大于 5 还是小于 5\n\n规则会换。切对了分更高。\n时间会越来越紧，看清再点开始。'}
          </div>
        ) : (
          <div
            className="tabular-nums text-[128px] font-bold leading-none transition-colors"
            style={{ color: numTint }}
          >
            {phase === 'OVER' ? '结束' : num ?? ''}
          </div>
        )}
      </div>

      {phase !== 'READY' && phase !== 'OVER' && (
        <div className="mx-auto mb-2 h-3 w-full max-w-[400px] overflow-hidden rounded-full bg-[#1a2740]">
          <div ref={timerBarRef} className="h-full rounded-full bg-[#8ab4ff]" style={{ width: '100%' }} />
        </div>
      )}

      <div className="mb-4 min-h-[28px] text-center text-[17px]" style={{ color: hint.color }}>
        {hint.text}
      </div>

      <div className="shrink-0">
        {phase === 'READY' ? (
          <button
            type="button"
            data-start="true"
            onClick={newTrial}
            className="mx-auto block h-[88px] w-[260px] rounded-[12px] bg-[#4ade80] text-[26px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
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
              disabled={phase !== 'PLAY'}
              onClick={() => handleAnswer(0)}
              className="h-[112px] rounded-[12px] text-[26px] font-semibold text-[#e8edff] transition-opacity"
              style={{ backgroundColor: btnBg, opacity: phase === 'PLAY' ? 1 : 0.45 }}
            >
              {rule === 0 ? '奇数' : '小于 5'}
            </button>
            <button
              type="button"
              disabled={phase !== 'PLAY'}
              onClick={() => handleAnswer(1)}
              className="h-[112px] rounded-[12px] text-[26px] font-semibold text-[#e8edff] transition-opacity"
              style={{ backgroundColor: btnBg, opacity: phase === 'PLAY' ? 1 : 0.45 }}
            >
              {rule === 0 ? '偶数' : '大于 5'}
            </button>
          </div>
        )}
      </div>
    </GameShell>
  );
};
