import React, { useCallback, useEffect, useRef, useState } from 'react';
import { BurstState, GameShell } from '../components/GameShell';
import { buildRuleShiftTrial, randInt, RuleCard } from '../logic/gameLogic';
import { loadJSON, saveJSON } from '../utils/storage';

const ROUND_SECS = 60.0;
const SWITCH_MIN = 4;
const SWITCH_MAX = 7;
const TRIAL_TIME_START = 3.2;
const TRIAL_TIME_MIN = 1.6;
const TIME_STEP = 0.12;
const INTER_TRIAL_MS = 350;
const SWITCH_ANNOUNCE_MS = 550;

const PALETTE = ['#ff5d73', '#5d9bff', '#4ade80'];
const SHAPES = ['●', '■', '▲'];
const COUNTS = [1, 2, 3];

const HELP_TEXT =
  '上方是一张卡片，有颜色、形状、数量三个特征。下方三堆各只在一个特征上和它对得上。\n' +
  '当前有一条隐藏规则（按颜色 / 按形状 / 按数量），点对上规则的那一堆。\n' +
  '对了几轮后规则会换，只提示「规则变了」，不告诉你换成哪条。\n' +
  '和「任务切换」不同：那里规则用蓝/橙直接标出，这里要自己从对错里推断。\n' +
  '一局约 60 秒。不承诺变聪明。';

type RuleDim = 0 | 1 | 2;
type Phase = 'PLAY' | 'GAP' | 'OVER';

const CardDisplay: React.FC<{ card: RuleCard; large?: boolean }> = ({ card, large }) => {
  const color = PALETTE[card.color] ?? PALETTE[0];
  const glyph = SHAPES[card.shape] ?? SHAPES[0];
  const count = COUNTS[card.count] ?? 1;
  return (
    <div
      className={`flex items-center justify-center gap-2 font-bold leading-none ${
        large ? 'text-[52px]' : 'text-[36px]'
      }`}
      style={{ color }}
    >
      {Array.from({ length: count }, (_, i) => (
        <span key={i}>{glyph}</span>
      ))}
    </div>
  );
};

interface RuleShiftGameProps {
  onBack: () => void;
}

export const RuleShiftGame: React.FC<RuleShiftGameProps> = ({ onBack }) => {
  const [phase, setPhase] = useState<Phase>('PLAY');
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [bestScore, setBestScore] = useState(() => loadJSON('ruleshift_best', { score: 0 }).score);
  const [roundLeftSec, setRoundLeftSec] = useState(Math.ceil(ROUND_SECS));
  const [trialLimit, setTrialLimit] = useState(TRIAL_TIME_START);
  const [stim, setStim] = useState<RuleCard>({ color: 0, shape: 0, count: 0 });
  const [choices, setChoices] = useState<RuleCard[]>([]);
  const [pileTints, setPileTints] = useState<(string | null)[]>([null, null, null]);
  const [hint, setHint] = useState({ text: '点与隐藏规则相符的那一堆', color: '#7f8ba6' });
  const [burst, setBurst] = useState<BurstState | null>(null);
  const [paused, setPaused] = useState(false);

  const timerBarRef = useRef<HTMLDivElement>(null);
  const phaseRef = useRef<Phase>('PLAY');
  const pausedRef = useRef(false);
  const waitingRef = useRef(false);
  const ruleRef = useRef<RuleDim>(0);
  const untilSwitchRef = useRef(5);
  const sinceSwitchRef = useRef(0);
  const correctPileRef = useRef(0);
  const scoreRef = useRef(0);
  const streakRef = useRef(0);
  const bestScoreRef = useRef(bestScore);
  const roundLeftRef = useRef(ROUND_SECS);
  const trialLimitRef = useRef(TRIAL_TIME_START);
  const trialLeftRef = useRef(TRIAL_TIME_START);
  const timersRef = useRef<number[]>([]);
  const burstIdRef = useRef(0);

  pausedRef.current = paused;
  bestScoreRef.current = bestScore;

  const clearTimers = () => {
    for (const id of timersRef.current) window.clearTimeout(id);
    timersRef.current = [];
  };

  const triggerBurst = useCallback((text: string, color: string) => {
    burstIdRef.current += 1;
    setBurst({ id: burstIdRef.current, text, color });
  }, []);

  const pickNewRule = useCallback((silent: boolean) => {
    const opts: RuleDim[] = [0, 1, 2];
    const filtered = silent ? opts : opts.filter((r) => r !== ruleRef.current);
    ruleRef.current = filtered[Math.floor(Math.random() * filtered.length)];
    untilSwitchRef.current = randInt(SWITCH_MIN, SWITCH_MAX);
    sinceSwitchRef.current = 0;
  }, []);

  const endGame = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    clearTimers();
    phaseRef.current = 'OVER';
    setPhase('OVER');
    waitingRef.current = true;
    if (timerBarRef.current) timerBarRef.current.style.width = '0%';
    const finalScore = scoreRef.current;
    const isBest = finalScore > bestScoreRef.current;
    let nextBest = bestScoreRef.current;
    if (isBest) {
      nextBest = finalScore;
      setBestScore(nextBest);
      bestScoreRef.current = nextBest;
      saveJSON('ruleshift_best', { score: nextBest });
    }
    const parts = ['时间到'];
    if (nextBest > 0) parts.push(`历史最佳 ${nextBest}`);
    if (isBest && finalScore > 0) parts.push('新纪录');
    setHint({ text: parts.join(' · '), color: '#ffd75d' });
  }, []);

  const newTrial = useCallback(() => {
    if (phaseRef.current === 'OVER') return;
    waitingRef.current = false;
    phaseRef.current = 'PLAY';
    setPhase('PLAY');
    const t = buildRuleShiftTrial(ruleRef.current);
    setStim(t.stim);
    setChoices(t.choices);
    correctPileRef.current = t.correctPile;
    setPileTints([null, null, null]);
    trialLeftRef.current = trialLimitRef.current;
    if (timerBarRef.current) {
      timerBarRef.current.style.width = '100%';
      timerBarRef.current.style.backgroundColor = '#8ab4ff';
    }
    setHint({ text: '点与隐藏规则相符的那一堆', color: '#7f8ba6' });
  }, []);

  const beginGap = useCallback(
    (announceSwitch: boolean) => {
      clearTimers();
      waitingRef.current = true;
      phaseRef.current = 'GAP';
      setPhase('GAP');
      const t1 = window.setTimeout(() => {
        if (phaseRef.current === 'OVER') return;
        if (announceSwitch) {
          setHint({ text: '规则变了', color: '#ffd75d' });
          triggerBurst('规则变了', '#ffd75d');
          const t2 = window.setTimeout(() => {
            if (phaseRef.current === 'OVER') return;
            if (roundLeftRef.current <= 0) {
              endGame();
              return;
            }
            newTrial();
          }, SWITCH_ANNOUNCE_MS);
          timersRef.current.push(t2);
        } else {
          if (roundLeftRef.current <= 0) {
            endGame();
            return;
          }
          newTrial();
        }
      }, INTER_TRIAL_MS);
      timersRef.current.push(t1);
    },
    [endGame, newTrial, triggerBurst]
  );

  const handlePick = (pileIdx: number) => {
    if (phaseRef.current !== 'PLAY' || waitingRef.current || pausedRef.current) return;
    waitingRef.current = true;
    if (pileIdx === correctPileRef.current) {
      streakRef.current += 1;
      sinceSwitchRef.current += 1;
      setStreak(streakRef.current);
      let pts = 10 + Math.min(streakRef.current, 8) * 2;
      if (sinceSwitchRef.current === 1 && scoreRef.current > 0) pts += 10;
      scoreRef.current += pts;
      setScore(scoreRef.current);
      if (streakRef.current > 0 && streakRef.current % 3 === 0) {
        trialLimitRef.current = Math.max(TRIAL_TIME_MIN, trialLimitRef.current - TIME_STEP);
        setTrialLimit(trialLimitRef.current);
      }
      setPileTints([0, 1, 2].map((i) => (i === pileIdx ? '#4ade80' : null)));
      setHint({ text: `+${pts}`, color: '#4ade80' });
      triggerBurst(`+${pts}`, '#4ade80');
      let switched = false;
      if (sinceSwitchRef.current >= untilSwitchRef.current) {
        pickNewRule(false);
        switched = true;
      }
      beginGap(switched);
    } else {
      streakRef.current = 0;
      sinceSwitchRef.current = 0;
      setStreak(0);
      trialLimitRef.current = Math.min(TRIAL_TIME_START, trialLimitRef.current + TIME_STEP * 0.5);
      setTrialLimit(trialLimitRef.current);
      setPileTints(
        [0, 1, 2].map((i) => (i === pileIdx ? '#ff5d73' : i === correctPileRef.current ? '#4ade80' : null))
      );
      setHint({ text: '不对 · 再推断', color: '#ff5d73' });
      triggerBurst('错', '#ff5d73');
      untilSwitchRef.current = randInt(SWITCH_MIN, SWITCH_MAX);
      beginGap(false);
    }
  };

  const restart = useCallback(() => {
    clearTimers();
    scoreRef.current = 0;
    streakRef.current = 0;
    trialLimitRef.current = TRIAL_TIME_START;
    roundLeftRef.current = ROUND_SECS;
    setScore(0);
    setStreak(0);
    setTrialLimit(TRIAL_TIME_START);
    setRoundLeftSec(Math.ceil(ROUND_SECS));
    setBurst(null);
    phaseRef.current = 'PLAY';
    setPhase('PLAY');
    pickNewRule(true);
    newTrial();
  }, [newTrial, pickNewRule]);

  useEffect(() => {
    restart();
    return () => clearTimers();
  }, [restart]);

  useEffect(() => {
    let rafId = 0;
    let last = performance.now();
    let lastSec = Math.ceil(ROUND_SECS);
    const tick = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (!pausedRef.current && phaseRef.current !== 'OVER') {
        roundLeftRef.current -= dt;
        const sec = Math.ceil(Math.max(roundLeftRef.current, 0));
        if (sec !== lastSec) {
          lastSec = sec;
          setRoundLeftSec(sec);
        }
        if (roundLeftRef.current <= 0) {
          roundLeftRef.current = 0;
          endGame();
        } else if (phaseRef.current === 'PLAY' && !waitingRef.current) {
          trialLeftRef.current -= dt;
          const ratio = Math.max(0, Math.min(1, trialLeftRef.current / Math.max(trialLimitRef.current, 0.01)));
          if (timerBarRef.current) {
            timerBarRef.current.style.width = `${ratio * 100}%`;
            timerBarRef.current.style.backgroundColor = ratio < 0.25 ? '#ff5d73' : '#8ab4ff';
          }
          if (trialLeftRef.current <= 0) {
            trialLeftRef.current = 0;
            waitingRef.current = true;
            streakRef.current = 0;
            setStreak(0);
            setHint({ text: '超时', color: '#ff5d73' });
            triggerBurst('超时', '#ff5d73');
            beginGap(false);
          }
        }
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, [beginGap, endGame, triggerBurst]);

  return (
    <GameShell
      title="规则变了"
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
        <div className="tabular-nums text-[16px] text-[#8ab4ff]">每题 {trialLimit.toFixed(1)} 秒</div>
        <div className="mt-1 min-h-[28px] text-[17px]" style={{ color: hint.color }}>
          {hint.text}
        </div>
      </div>

      {/* Stimulus Card */}
      <div className="mt-6 flex flex-1 flex-col items-center justify-center">
        <div className="flex h-[160px] w-[270px] items-center justify-center rounded-[16px] bg-[#152034]">
          <CardDisplay card={stim} large />
        </div>

        <div className="mt-5 h-3 w-full max-w-[420px] overflow-hidden rounded-full bg-[#1a2740]">
          <div ref={timerBarRef} className="h-full rounded-full bg-[#8ab4ff]" style={{ width: '100%' }} />
        </div>
      </div>

      {/* 3 Choice Piles */}
      <div className="mt-auto shrink-0 pt-4">
        {phase === 'OVER' ? (
          <button
            type="button"
            data-start="true"
            onClick={restart}
            className="mx-auto block h-[60px] w-[220px] rounded-[12px] bg-[#4ade80] text-[22px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94]"
          >
            重新开始
          </button>
        ) : (
          <div className="grid grid-cols-3 gap-3">
            {choices.map((card, i) => (
              <button
                key={i}
                type="button"
                aria-label={`规则堆 ${i + 1}`}
                disabled={phase !== 'PLAY'}
                onClick={() => handlePick(i)}
                className="flex h-[136px] items-center justify-center rounded-[12px] bg-[#1a2740] transition-all hover:bg-[#243656] active:scale-95"
                style={{
                  boxShadow: pileTints[i] ? `inset 0 0 0 3px ${pileTints[i]}` : 'none',
                }}
              >
                <CardDisplay card={card} />
              </button>
            ))}
          </div>
        )}
      </div>
    </GameShell>
  );
};
