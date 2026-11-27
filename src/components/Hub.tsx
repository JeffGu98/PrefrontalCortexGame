import React, { useEffect } from 'react';
import { GAMES, GameEntry, GameId, getDailyGame, todayKey } from '../data/games';
import { loadJSON, saveJSON } from '../utils/storage';

interface HubProps {
  onSelectGame: (id: GameId) => void;
}

interface DailyRecord {
  playedDate: string;
}

export const Hub: React.FC<HubProps> = ({ onSelectGame }) => {
  const daily = getDailyGame();
  const today = todayKey();
  const dailyRec = loadJSON<DailyRecord>('daily', { playedDate: '' });
  const playedToday = dailyRec.playedDate === today;

  useEffect(() => {
    document.body.dataset.state = 'title';
  }, []);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Enter' || e.key === ' ') {
        if (document.activeElement?.tagName === 'BUTTON') return;
        e.preventDefault();
        handleOpenDaily();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [daily.id]);

  const handleOpenDaily = () => {
    saveJSON<DailyRecord>('daily', { playedDate: today });
    onSelectGame(daily.id);
  };

  // Group games preserving exact Hub.gd order
  const sections: { group: string; items: GameEntry[] }[] = [];
  for (const game of GAMES) {
    const last = sections[sections.length - 1];
    if (!last || last.group !== game.group) {
      sections.push({ group: game.group, items: [game] });
    } else {
      last.items.push(game);
    }
  }

  const readyCount = GAMES.filter((g) => g.built).length;

  return (
    <div className="mx-auto flex h-full w-full max-w-[520px] flex-col bg-[#0d1220] text-[#e8edff]">
      <header className="shrink-0 px-6 pt-10 pb-4 text-center">
        <h1 className="text-[34px] font-bold tracking-tight text-[#e8edff]">前额叶训练场</h1>
        <p className="mt-1.5 text-[15px] text-[#7f8ba6]">
          每个游戏练一种执行功能 · {readyCount} / {GAMES.length} 可玩
        </p>
      </header>

      <main className="min-h-0 flex-1 overflow-y-auto px-6 pb-8">
        {/* Daily Training Card */}
        <button
          type="button"
          data-start="true"
          onClick={handleOpenDaily}
          className="mb-3 flex w-full flex-col items-start rounded-[12px] bg-[#243552] px-5 py-4 text-left transition-colors hover:bg-[#2d4266] active:bg-[#1c2b44]"
        >
          <div className="flex items-center gap-2.5">
            <span className="text-[14px] font-semibold text-[#ffd75d]">今日一练</span>
            {playedToday && <span className="text-[13px] text-[#7f8ba6]">今日已练</span>}
          </div>
          <span className="mt-1 text-[24px] font-semibold text-[#e8edff]">{daily.title}</span>
          <span className="mt-0.5 text-[14px] text-[#8ab4ff]">{daily.func}</span>
        </button>

        {/* Grouped Game List */}
        <div className="flex flex-col gap-2.5">
          {sections.map((section) => (
            <section key={section.group} className="mt-2 flex flex-col gap-2.5">
              <h2 className="px-0.5 text-[14px] font-medium text-[#8ab4ff]">{section.group}</h2>
              {section.items.map((game) => (
                <button
                  key={game.id}
                  type="button"
                  disabled={!game.built}
                  onClick={() => onSelectGame(game.id)}
                  className={`flex min-h-[82px] w-full items-center justify-between rounded-[12px] px-5 py-3 text-left transition-colors ${
                    game.built
                      ? 'bg-[#1a2740] hover:bg-[#243656] active:bg-[#141e33]'
                      : 'cursor-not-allowed bg-[#12192a]'
                  }`}
                >
                  <div className="flex flex-col">
                    <span
                      className={`text-[22px] font-semibold ${
                        game.built ? 'text-[#e8edff]' : 'text-[#5a6478]'
                      }`}
                    >
                      {game.title}
                    </span>
                    <span
                      className={`mt-0.5 text-[14px] ${
                        game.built ? 'text-[#8ab4ff]' : 'text-[#4a5568]'
                      }`}
                    >
                      {game.func}
                    </span>
                  </div>
                  {!game.built && (
                    <span className="text-[14px] text-[#5a6478]">即将推出</span>
                  )}
                </button>
              ))}
            </section>
          ))}
        </div>
      </main>
    </div>
  );
};
