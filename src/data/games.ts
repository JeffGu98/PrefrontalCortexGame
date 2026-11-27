export type GameId =
  | 'stroop'
  | 'schulte'
  | 'track'
  | 'nback'
  | 'corsi'
  | 'selforder'
  | 'runningspan'
  | 'dots'
  | 'switch'
  | 'ruleshift'
  | 'hanoi';

export interface GameEntry {
  id: GameId;
  title: string;
  func: string;
  group: string;
  built: boolean;
}

export const GAMES: GameEntry[] = [
  { id: 'stroop', title: '反向色字', func: '抑制控制 · 干扰', group: '抑制控制', built: true },
  { id: 'schulte', title: '舒尔特方格', func: '专注 · 视觉搜索', group: '注意', built: true },
  { id: 'track', title: '追踪异色球', func: '注意 · 追踪', group: '注意', built: true },
  { id: 'nback', title: 'N-Back', func: '工作记忆 · 更新', group: '工作记忆', built: true },
  { id: 'corsi', title: '积木跨度', func: '工作记忆 · 空间序列', group: '工作记忆', built: true },
  { id: 'selforder', title: '各点一次', func: '工作记忆 · 自我监控', group: '工作记忆', built: true },
  { id: 'runningspan', title: '末项记', func: '工作记忆 · 末项更新', group: '工作记忆', built: true },
  { id: 'dots', title: '看点数', func: '工作记忆 · 瞬时', group: '工作记忆', built: true },
  { id: 'switch', title: '任务切换', func: '认知灵活性 · 线索切换', group: '认知灵活性', built: true },
  { id: 'ruleshift', title: '规则变了', func: '认知灵活性 · 规则推断', group: '认知灵活性', built: true },
  { id: 'hanoi', title: '汉诺塔', func: '计划 · 前瞻', group: '计划', built: true },
];

export function todayKey(date: Date = new Date()): string {
  const y = String(date.getFullYear()).padStart(4, '0');
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Deterministic daily index matching Hub.gd _daily_index */
export function dailyIndex(count: number, key: string = todayKey()): number {
  if (count <= 0) return 0;
  let h = 0;
  for (let i = 0; i < key.length; i++) {
    h = (Math.imul(h, 31) + key.charCodeAt(i)) & 0x7fffffff;
  }
  h = (h ^ (h >>> 16)) & 0x7fffffff;
  return h % count;
}

export function getDailyGame(date: Date = new Date()): GameEntry {
  const built = GAMES.filter((g) => g.built);
  return built[dailyIndex(built.length, todayKey(date))];
}
