# PrefrontalCortexGame · 前额叶训练场

一个 Godot 4 认知训练游戏合集：hub 首页 + 10 个独立小游戏，每个游戏对应一种真实存在的认知科学任务范式（Stroop、舒尔特方格、N-Back 等），练的是前额叶执行功能的某一个具体侧面。

**诚实原则**：游戏只练「该能力在游戏内的熟练度」，不承诺迁移到现实、不承诺变聪明。文案中不使用「修复大脑」「激活 CEO」这类话术。

## 运行

- 引擎：Godot 4.7+（纯 GDScript，无外部依赖，无需 .NET）
- 用 Godot 编辑器打开本目录，F5 运行
- 竖屏 720×1280 基准（`canvas_items` 拉伸），面向移动端，桌面可直接测试
- Android 安装包见 [Releases](https://github.com/JeffGu98/PrefrontalCortexGame/releases)（旁加载 APK）
- iOS 需要本机安装 Xcode 并配置 Apple 开发者签名，当前 Release 不提供 IPA

## 结构

```
prefrontal-cortex-game/
├── project.godot          # 入口 Hub.tscn，竖屏显示配置
├── scenes/                # 每个场景 = 根 Control + 挂脚本，节点树全部由代码构建
│   ├── Hub.tscn           # 首页菜单
│   ├── Stroop.tscn        # 反向色字
│   ├── Schulte.tscn       # 舒尔特方格
│   ├── Dots.tscn          # 看点数
│   ├── GoNoGo.tscn        # 反向反应
│   └── StopSignal.tscn    # 红灯停
├── scripts/
│   ├── GameBase.gd        # 所有游戏的共享脚手架（背景/返回/标题）
│   ├── Hub.gd             # 菜单：GAMES 数组注册所有游戏
│   ├── Stroop.gd
│   ├── Schulte.gd
│   ├── Dots.gd
│   ├── GoNoGo.gd
│   └── StopSignal.gd
└── docs/design.md         # ★ 完整设计 + 交接文档（先读这个）
```

## 继续开发

阅读 [docs/design.md](docs/design.md)，其中包含：

- 项目理念与认知科学依据（为什么是这 10 个游戏）
- 架构决策与代码规范
- **如何新增一个游戏**（五步流程 + 代码模板）
- 全部 10 个游戏的实现规格（含未实现的 5 个，数值建议已给出）
- 验证流程与当前已知问题
