import React, { useEffect, useState } from 'react';

export interface BurstState {
  id: number;
  text: string;
  color: string;
}

interface GameShellProps {
  title: string;
  helpText: string;
  onBack: () => void;
  paused?: boolean;
  onPauseChange?: (paused: boolean) => void;
  burst?: BurstState | null;
  gameState?: 'playing' | 'paused' | 'gameover';
  children: React.ReactNode;
}

export const GameShell: React.FC<GameShellProps> = ({
  title,
  helpText,
  onBack,
  onPauseChange,
  burst,
  gameState = 'playing',
  children,
}) => {
  const [helpOpen, setHelpOpen] = useState(false);

  const openHelp = () => {
    setHelpOpen(true);
    onPauseChange?.(true);
  };

  const closeHelp = () => {
    setHelpOpen(false);
    onPauseChange?.(false);
  };

  useEffect(() => {
    document.body.dataset.state = helpOpen ? 'paused' : gameState;
  }, [helpOpen, gameState]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        if (helpOpen) {
          closeHelp();
        } else {
          onBack();
        }
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [helpOpen, onBack]);

  return (
    <div className="relative mx-auto flex h-full w-full max-w-[520px] flex-col overflow-hidden bg-[#0d1220] text-[#e8edff] select-none">
      {/* Top Bar matching GameBase.gd */}
      <header className="relative z-30 flex h-[72px] shrink-0 items-center justify-between px-4 pt-2">
        <button
          type="button"
          onClick={onBack}
          className="flex h-12 min-w-[96px] items-center justify-center rounded-[10px] bg-[#1a2740] px-4 text-[18px] font-medium text-[#e8edff] transition-colors hover:bg-[#243656] active:bg-[#131d31]"
        >
          &lt; 返回
        </button>

        <h1 className="pointer-events-none truncate px-2 text-center text-[28px] font-semibold tracking-tight text-[#e8edff]">
          {title}
        </h1>

        <button
          type="button"
          aria-label="玩法说明"
          onClick={() => (helpOpen ? closeHelp() : openHelp())}
          className="flex h-12 w-12 items-center justify-center rounded-[10px] bg-[#1a2740] text-[22px] font-semibold text-[#e8edff] transition-colors hover:bg-[#243656] active:bg-[#131d31]"
        >
          ?
        </button>
      </header>

      {/* Main Game Content */}
      <main className="relative flex min-h-0 flex-1 flex-col px-4 pb-5">
        {children}
      </main>

      {/* Burst Feedback Overlay matching GameBase._burst_feedback */}
      {burst && (
        <div key={burst.id} className="pointer-events-none absolute inset-0 z-40 flex items-center justify-center">
          <div
            className="animate-burst-wash absolute inset-0"
            style={{ backgroundColor: burst.color }}
          />
          <div
            className="animate-burst-pop px-6 text-center text-[52px] font-bold leading-tight whitespace-pre-line"
            style={{
              color: burst.color,
              textShadow:
                '0 0 12px #0d1220, 3px 3px 0 #0d1220, -3px -3px 0 #0d1220, 3px -3px 0 #0d1220, -3px 3px 0 #0d1220',
            }}
          >
            {burst.text}
          </div>
        </div>
      )}

      {/* Help Modal matching GameBase._build_help_overlay */}
      {helpOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label={`${title} 玩法`}
          className="absolute inset-0 z-50 flex items-center justify-center bg-black/65 px-6"
          onClick={closeHelp}
        >
          <div
            className="flex max-h-[76%] w-full max-w-[440px] flex-col rounded-[14px] bg-[#1a2740] p-6 shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-center text-[26px] font-semibold text-[#e8edff]">玩法</h2>
            <p className="mt-1 text-center text-[15px] text-[#8ab4ff]">{title}</p>
            <div className="mt-4 flex-1 overflow-y-auto whitespace-pre-line text-[18px] leading-relaxed text-[#e8edff]">
              {helpText}
            </div>
            <button
              type="button"
              onClick={closeHelp}
              className="mt-5 h-14 w-full shrink-0 rounded-[10px] bg-[#4ade80] text-[20px] font-semibold text-[#0d1220] transition-colors hover:bg-[#60e893] active:bg-[#38c46c]"
            >
              知道了
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

interface ProgressGateProps {
  body: string;
  continueText: string;
  freshText: string;
  onContinue: () => void;
  onFresh: () => void;
}

export const ProgressGate: React.FC<ProgressGateProps> = ({
  body,
  continueText,
  freshText,
  onContinue,
  onFresh,
}) => {
  return (
    <div className="flex flex-1 flex-col items-center justify-center px-3 py-6">
      <div className="flex min-h-[180px] w-full items-center justify-center rounded-[14px] bg-[#152034] px-6 py-6 text-center text-[20px] leading-relaxed whitespace-pre-line text-[#e8edff]">
        {body}
      </div>
      <button
        type="button"
        data-start="true"
        onClick={onContinue}
        className="mt-4 h-[68px] w-full rounded-[12px] bg-[#4ade80] text-[24px] font-semibold text-[#0d1220] transition-colors hover:bg-[#62ea94] active:bg-[#38c46c]"
      >
        {continueText}
      </button>
      <button
        type="button"
        onClick={onFresh}
        className="mt-3 h-[60px] w-full rounded-[12px] bg-[#1a2740] text-[22px] font-medium text-[#e8edff] transition-colors hover:bg-[#243656] active:bg-[#131d31]"
      >
        {freshText}
      </button>
    </div>
  );
};
