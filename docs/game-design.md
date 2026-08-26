# 游戏设计摘录（街机小游戏）

> 本文是从公开的游戏设计论文、教程和演讲里**抽取、转写成可执行原则**的参考文档，不是本项目的产品规格。
>
> 产品规格（一个游戏一种功能、诚实文案、清单里有哪些关）见 [design.md](design.md)。
>
> 用这些原则扫过当前十关之后的问题和改法，见 [improvements.md](improvements.md)。
>
> 本文回答的是另一件事：**怎样把一关做成好玩、能进心流的游戏**。棉花糖被换掉，依据就在这里。

---

## 0. 怎么用

改关或加关时，先过 [design.md](design.md) 第 1 节的产品原则和检查单，再用本文的模型解释「为什么不好玩」和「改哪一层」。

两份文档打架时：

- **产品身份**听 `design.md`（不混装范式、不吹牛、Android 等）
- **手感**听本文（空等、随机成败、难度不涨 → 不收）

下文是综述，不是原文拷贝。关键出处列在文末。

---

## 1. 先分清三层：MDA

Hunicke、LeBlanc、Zubek（2004）《MDA: A Formal Approach to Game Design and Game Research》：游戏可以拆成三层。

| 层 | 是什么 | 谁先看见 |
| --- | --- | --- |
| **Mechanics 机制** | 规则、按钮、数值、算法。设计师能直接改的东西 | 设计师 |
| **Dynamics 动态** | 规则碰上真人之后跑出来的行为：节奏、赌、连击、卡关 | 对局过程 |
| **Aesthetics 体验** | 玩家实际感到的：紧张、掌握、无聊、不公平 | 玩家 |

设计师从机制往下做；玩家从体验往上玩。只加规则、不演一遍，看不见动态，也就调不到体验。

LeBlanc 把含糊的「好玩」拆成八种体验（原文 taxonomy of fun）。一种游戏通常只主打其中两到四种，不必全要。

| # | 体验 | 原文说法 | 玩家在享受什么 |
| --- | --- | --- | --- |
| 1 | **Sensation** | Game as sense-pleasure | 视听触的快感：打击感、闪光、音效 |
| 2 | **Fantasy** | Game as make-believe | 假装成为别人 / 进入另一个世界 |
| 3 | **Narrative** | Game as drama | 被故事推着走，想知道接下来 |
| 4 | **Challenge** | Game as obstacle course | 克服障碍、掌握难事、再来一把 |
| 5 | **Fellowship** | Game as social framework | 和别人一起玩、同队、对线 |
| 6 | **Discovery** | Game as uncharted territory | 去没去过的地方、揭开未知 |
| 7 | **Expression** | Game as self-discovery | 自我表达：捏人、建造、留下自己的痕迹 |
| 8 | **Submission** | Game as pastime | 进入一套仪式、消磨时间、放松地待着 |

对本合集最相关的是 **Challenge** 和 **Sensation**：短时的专注、差一点就能过、对错要打在身上。Fantasy / Narrative / Fellowship / Discovery / Expression 不是主目标。Submission（无目的地耗着）和心流要求的「一直有事做」容易打架，不能当设计目标。

**用法：** 改关时先问「这一关要玩家感到什么」（本项目默认：短时的专注 + 差一点就能过），再倒推机制。不要先堆规则再希望它自己变好玩。

原文：[AAAI 论文页](https://aaai.org/papers/ws04-04-001-mda-a-formal-approach-to-game-design-and-game-research/) · [维基概述](https://en.wikipedia.org/wiki/MDA_framework)

---

## 2. 心流：技能贴着挑战走

Csíkszentmihályi《心流》（1990）把「完全沉浸、时间变快」描述成一种可设计的状态。游戏行业用得最多的是那张图：

```
挑战 ↑
     │  焦虑
     │     ╱ 心流通道
     │    ╱
     │   ╱
     │  无聊
     └──────────→ 技能
```

技能明显高于挑战 → 无聊。挑战明显高于技能 → 焦虑。两者都高、且大致匹配 → 心流。

进心流常见条件（各家计数 8 或 9，核心重叠）：

1. 目标清楚
2. 反馈立刻、不含糊
3. 挑战和技能匹配，并随熟练度上移
4. 能专心做这一件事（少打断、少空等）
5. 感到「我做得成」，失败也知道为什么

教育游戏研究（Kiili 等，2012）把同一套用到「既要学又要玩」：没有心流，学习关往往也留不住人。本项目不承诺迁移到现实，但**局内**仍要满足这些条件，否则关卡只是测验。

**难度不能直线上涨。** 业界常见做法是锯齿 / 波浪：紧一段、松一段。松的那段不是浪费，是让玩家感到「我变强了」，再迎下一波。一直卡在 100% 能力边缘会疲劳。

**用法：**

- 熟了以后题必须变难（时限缩短、干扰变多、盘数增加……）
- 错了可以略放宽，对了再收紧——动态难度的轻量版
- 局与局之间允许一口「好过」的气，不要整局都是峰值
- 空等、看说明书、看答案过久，都会把人从通道里推出去

延伸：[心流与游戏（Game Developer）](https://www.gamedeveloper.com/design/gameplay-flow-designing-for-player-immersion) · [Game Design Skills：Flow](https://gamedesignskills.com/game-design/game-flow/)

---

## 3. 游戏在教模式：技能原子

Raph Koster《A Theory of Fun for Game Design》（2004）：**好玩 ≈ 大脑在学新模式**。模式一旦被彻底掌握，同一套循环就会变无聊。所以游戏必须持续给出「还没吃透」的变体。

Daniel Cook《The Chemistry of Game Design》（2007，Lost Garden / Gamasutra）把学习拆成可画的回路——**技能原子**：

1. **Action** 玩家做一个动作
2. **Simulation** 规则改了状态
3. **Feedback** 画面 / 声音 / 震动告诉玩家发生了什么
4. **Modeling** 玩家更新「我刚才做对了什么」的心智模型

多个原子串成技能链。前一个技能喂给后一个。玩家看不了太远，只追近处那一口「好像有用」的新技能。

两个失败信号：

- **早期 burnout**：第一个动作没学会，后面整条链废掉（教程过陡、规则没讲清）
- **后期 burnout**：学会了，但没有下一个更有用的技能，于是连基础操作也不想再做（难度封顶、永远同一档）

**用法：**

- 每一关只需要一条短链：看见刺激 → 做选择 → 立刻知道对错 → 下一题略难一点
- 反馈必须绑在动作上。只改分数、屏幕上没变化，原子断了
- 规则说明不能替代「做一次就懂」。能玩中学会的，不要先读三段字
- 封顶之后必须还有下一档，否则熟练玩家会 burnout

原文：[The Chemistry of Game Design](https://www.gamedeveloper.com/design/the-chemistry-of-game-design) · Koster：[A Theory of Fun PDF 摘录](https://www.raphkoster.com/gaming/atof/theoryoffun.pdf)

---

## 4. 有意思的决定

Sid Meier（GDC 2012 等）：游戏是一串**有意思的决定**。没意思的决定同样耗脑，却没有满足感，应该删掉。

有意思，通常要同时满足：

- 选项不是一个明显碾压另一个
- 选项也不是完全等价（否则随便点）
- 玩家能根据当前局面做**知情**选择
- 选了会改变后面发生的事

他还有两条工程口诀：

- **Double it or cut it in half**：调数值先翻倍或腰斩，10% 微调看不出差别
- **One good game is better than two great games**（Covert Action 规则）：两个半成品核心互相抢注意力，不如一个完整核心

**用法：**

- 每一拍玩家都在做一个决定（点哪、冲不冲、记不记），而不是点一下然后旁观
- 纯运气决定胜负（随机落空、玩家无法读出风险）不是有意思的决定
- 两个范式叠在同一关，等于两个游戏抢一个屏幕

来源：[GDC 2012 报道](https://www.gamedeveloper.com/design/gdc-2012-sid-meier-on-how-to-see-games-as-sets-of-interesting-decisions) · [Firaxis 同事整理的 Meier 规则](https://www.gamedeveloper.com/game-platforms/analysis-sid-meier-s-key-design-lessons)

---

## 5. 反馈要「多汁」，但先要可读

独立圈把过量、即时、绑在操作上的反馈叫 **juice**（Gray 等 *How to Prototype a Game in Under 7 Days*；Game Maker's Toolkit 后来做了综述）。一碰就晃、就响、就喷粒子，让游戏「活」。

研究侧提醒：juice 的前提是**动作和结果绑得清楚**。特效很大但看不出为什么赢/输，会削弱掌控感。

本项目已经用 `_burst_feedback` 做全屏大字 + 色闪，方向对：对错不能只靠一行小灰字。

**用法：**

- 对：立刻、够大、和操作同一拍
- 错：立刻，并且能看出错在哪（点错了 / 超时 / 大盘压小盘）
- 不要用 2 秒过场庆祝每一次正确——那是在拆心流
- juice 加强「这一关在练的那一下」，不要盖住信息

延伸：[GMTK：Game Feel and Juice](https://www.youtube.com/watch?v=216_5nu4aVQ)

---

## 6. 从体验往回看：Schell 的透镜

Jesse Schell《The Art of Game Design: A Book of Lenses》：设计不是一条公式，而是用很多组问题从不同角度看同一关。对本合集最有用的几面：

- **Essential Experience**：我想让玩家感到什么？中间那三秒必须发生什么？
- **Flow**：目标、反馈、技能-挑战是否同时成立？
- **Challenge**：失败是否公平？玩家是否知道下一次怎么做得更好？
- **Toy / 操作本身**：剥掉分数和故事，点下去还爽不爽？
- **Skill vs Chance**：胜负有多少是技术、多少是骰子？
- **Iteration**：好玩是玩出来的，不是写在纸上的

**用法：** 改完一关，用这些问题口头过一遍，比再加一个系统有用。

---

## 7. 抽成十条（做关时用）

1. **先定体验，再写规则。**（MDA：从 Aesthetics 倒推 Mechanics）
2. **玩家永远知道这一拍要干什么。**（心流：清晰目标）
3. **每个动作立刻有可读的反馈。**（心流 + 技能原子）
4. **一直有事做。** 空等、看条、等随机，都是把人从通道里推出去。
5. **难度贴着熟练度涨，并且可以回落一点。** 直线上涨或永远同一档都会失败。
6. **失败是技术问题，能看懂、能再试。** 纯运气淘汰不是挑战。
7. **一关一个核心决定。** 两个「伟大构想」叠在一起，两个都弱。
8. **教会靠玩，不靠说明书。** 说明是补丁；第一局就要能形成技能原子。
9. **调参要狠。** 怀疑时限太松，先腰斩再微调。
10. **模式被掌握之后必须出现新变体。** 否则大脑会宣布毕业、离开关卡。

---

## 8. 落到本项目这类关

本合集是竖屏、单人、一关一种范式、一局几分钟。上面的理论收成下面这些形状：

| 理论要求 | 在本项目里长什么样 |
| --- | --- |
| 清晰目标 | 标题 + 一行 hint +「?」玩法；开局不要先读完才懂 |
| 即时反馈 | `_burst_feedback`、对错变色、倒计时条；间隔尽量短 |
| 技能-挑战 | 连对加速 / 加盘 / 加球 / 加 N；点错略放宽 |
| 无空等 | 刺激连续出现；看点数那种「对完答案」只能短，不能变成第二局 |
| 有意思的决定 | 每一拍都在点、冲、记、移；不要「点等待然后旁观」 |
| 一种冲突 | Hub 里一关一个 `func`；不要 Flanker 里再塞 N-Back |
| juice | 大字反馈可以有；不要挡住下一题 |
| 知情选择 | 红灯、绿线、中间箭头，规则要能被看见，不能只在内部掷骰 |

**反例（已发生过）：** 延迟折扣要求「忍住不做事」。心流要求「持续做贴着能力上限的事」。范式成立，手感不成立，关卡拿掉。这不是否定心理学实验，是拒绝把它做成空等街机。

汉诺塔是另一类：解谜心流（计划、可见进度），不是红灯停那种连点心流。可以留，但不要用街机的节奏去衡量它。

---

## 9. 来源与延伸

### 论文 / 专著

- Hunicke, LeBlanc, Zubek (2004). *MDA: A Formal Approach to Game Design and Game Research*. [AAAI](https://aaai.org/papers/ws04-04-001-mda-a-formal-approach-to-game-design-and-game-research/)
- Csíkszentmihályi, M. (1990). *Flow: The Psychology of Optimal Experience*
- Koster, R. (2004). *A Theory of Fun for Game Design*. [作者摘录](https://www.raphkoster.com/gaming/atof/theoryoffun.pdf)
- Schell, J. *The Art of Game Design: A Book of Lenses*
- Kiili, de Freitas, Arnab, Lainema (2012). *The Design Principles for Flow Experience in Educational Games*. [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S1877050912008228)

### 教程 / 演讲 / 专栏

- Cook, D. (2007). [The Chemistry of Game Design](https://www.gamedeveloper.com/design/the-chemistry-of-game-design)（技能原子）
- Meier, S. (GDC 2012). [Games as interesting decisions](https://www.gamedeveloper.com/design/gdc-2012-sid-meier-on-how-to-see-games-as-sets-of-interesting-decisions)
- [Sid Meier 的其它口诀（翻倍/腰斩、一个核心）](https://www.gamedeveloper.com/game-platforms/analysis-sid-meier-s-key-design-lessons)
- Game Maker's Toolkit. [Secrets of Game Feel and Juice](https://www.youtube.com/watch?v=216_5nu4aVQ)
- [Gameplay Flow（Game Developer）](https://www.gamedeveloper.com/design/gameplay-flow-designing-for-player-immersion)
- 中文综述：[浅谈游戏设计中「心流」理论的应用](https://zhuanlan.zhihu.com/p/667962177) · [做出来的游戏为何不好玩（心流）](https://news.qq.com/rain/a/20230830A00ZK200)

读这些是为了改关时有共同词汇，不是为了把合集做成「脑力训练理论课」。
