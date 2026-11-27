import React, { useEffect, useState } from 'react';
import { Hub } from './components/Hub';
import { GAMES, GameId, getDailyGame } from './data/games';
import { CorsiGame } from './games/CorsiGame';
import { DotsGame } from './games/DotsGame';
import { HanoiGame } from './games/HanoiGame';
import { NBackGame } from './games/NBackGame';
import { RuleShiftGame } from './games/RuleShiftGame';
import { RunningSpanGame } from './games/RunningSpanGame';
import { SchulteGame } from './games/SchulteGame';
import { SelfOrderGame } from './games/SelfOrderGame';
import { StroopGame } from './games/StroopGame';
import { SwitchGame } from './games/SwitchGame';
import { TrackGame } from './games/TrackGame';

function resolveInitialGame(): GameId | null {
  const params = new URLSearchParams(window.location.search);
  const gameParam = params.get('game') as GameId | null;
  if (gameParam && GAMES.some((g) => g.id === gameParam)) {
    return gameParam;
  }
  if (params.get('autostart') === '1') {
    return getDailyGame().id;
  }
  return null;
}

export const App: React.FC = () => {
  const [activeGame, setActiveGame] = useState<GameId | null>(resolveInitialGame);

  useEffect(() => {
    if (activeGame === null) {
      document.body.dataset.state = 'title';
    }
  }, [activeGame]);

  const handleBack = () => setActiveGame(null);

  if (!activeGame) {
    return <Hub onSelectGame={setActiveGame} />;
  }

  switch (activeGame) {
    case 'stroop':
      return <StroopGame onBack={handleBack} />;
    case 'schulte':
      return <SchulteGame onBack={handleBack} />;
    case 'track':
      return <TrackGame onBack={handleBack} />;
    case 'nback':
      return <NBackGame onBack={handleBack} />;
    case 'corsi':
      return <CorsiGame onBack={handleBack} />;
    case 'selforder':
      return <SelfOrderGame onBack={handleBack} />;
    case 'runningspan':
      return <RunningSpanGame onBack={handleBack} />;
    case 'dots':
      return <DotsGame onBack={handleBack} />;
    case 'switch':
      return <SwitchGame onBack={handleBack} />;
    case 'ruleshift':
      return <RuleShiftGame onBack={handleBack} />;
    case 'hanoi':
      return <HanoiGame onBack={handleBack} />;
  }
};

export default App;
