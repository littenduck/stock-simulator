# Stock Simulator — 开发总规划（单人工作室 + Claude Code）

> 版本：v0.1（2026-11-11）。
> 调研日期：2026-11-11。Token 数为粗略估算，用于排预算，不是承诺。

## 0. 结论先行

- **引擎推荐：Godot 4.x（4.6 / 4.7）**。MIT 协议、免费、无分成，2D UI 很强，GodotSteam 插件成熟，全部是文本文件（.gd / .tscn / .tres），Claude Code 可直接读写。
- **架构推荐：架构 A（Godot 一体化 + 数据驱动）**，等第一版跑通后再按需要把行情引擎拆成独立模块（架构 C）。
- **PokeBonk 的技术栈：Three.js + Vite（纯网页）**。适合网页小游戏，不是上 Steam 卖钱的最佳选择。
- **最少角色：1 人身兼 6 个角色**；其中开发类角色最少 2 个（玩法/系统程序 + UI/工具程序）。

## 1. 游戏引擎排行（★ 越多 = 越好且越适合一人工作室）

| # | 引擎 | 语言 | 开源 | 适合本游戏 | 上 Steam | 和 Claude Code 配合 | 评分 |
|---|---|---|---|---|---|---|---|
| 1 | Godot 4 | GDScript / C# | MIT | 2D UI、图表、经营模拟都强 | GodotSteam 成熟 | 场景/脚本都是文本 | ★★★★★ |
| 2 | Web 栈（TypeScript + PixiJS/Phaser + Tauri/Electron 打包） | TS | MIT | 图表库多（如 lightweight-charts） | 需套壳；Vampire Survivors 早期就是 Phaser+Electron | Claude 最熟的领域 | ★★★★☆ |
| 3 | Unity 6 | C# | 否 | 能做，但对纯 UI 游戏偏重 | 最成熟 | 场景是 YAML，AI 难改；需开编辑器 | ★★★★☆ |
| 4 | Defold | Lua | 源码开放（Defold License） | 2D 轻量，包体小 | 支持 | 文本工程，但资料少 | ★★★☆☆ |
| 5 | LÖVE (Love2D) | Lua | zlib | 纯代码，UI 要自己写 | 可以，需自己打包 | 纯代码，AI 好写 | ★★★☆☆ |
| 6 | GameMaker | GML | 否 | 2D 好，UI 一般 | 支持 | 工程文件较乱 | ★★★☆☆ |
| 7 | Ren'Py | Python | MIT | 只适合剧情/对话为主 | 支持 | 文本好改 | ★★☆☆☆ |
| 8 | Bevy | Rust | MIT/Apache | 无编辑器，UI 弱，版本变动大 | 可以 | Rust 编译慢、反复改 | ★★☆☆☆ |
| 9 | Unreal 5 | C++ / 蓝图 | 否（源码可见） | 杀鸡用牛刀 | 支持 | 蓝图是二进制 | ★☆☆☆☆ |
| 10 | O3DE / Stride | C++ / C# | 开源 | 3D 向，社区小 | 可以 | 资料少 | ★☆☆☆☆ |

## 2. 调研：Godot、PokeBonk、宝可梦同人游戏

### Godot
- 4.6（2026-01）：默认 Jolt 物理、新 Modern 编辑器主题、IK、LibGodot（可当库嵌入）。
- 4.7（2026-06）：网页导出默认 WASM SIMD，新增 wasm64。
- 对本游戏关键：Control 节点做 UI、Theme 统一外观、Resource（.tres）存公司/事件数据、GUT 做单元测试、`godot --headless` 可在命令行跑测试和导出 —— Claude Code 能闭环。

### PokeBonk
- 作者 Charcher（X: @ImCharcher），Megabonk 式 3D 割草 + 关都 151 只宝可梦，免费网页游戏，作者自称借助 AI 做 3D 模型（Blender）。
- **技术栈（我直接查了 pokebonk.com 的网页文件）：Vite 打包 + Three.js（WebGLRenderer）**，没有用 Unity/Godot。
- 对你是否合适：
  - 好处：Three.js 网页即开即玩，适合做宣传 Demo。
  - 坏处：Three.js 只是渲染库，存档、UI、音频、输入、打包都要自己写；上 Steam 要套 Electron/Tauri。
  - **上 Steam：PokeBonk 本身不能上**。宝可梦是任天堂/TPC 的 IP，同人游戏只能免费、随时可能被下架；Steam 收费发售必然侵权。你的游戏要用原创公司、原创角色。

### 近期热门宝可梦同人游戏（参考做法，不参考 IP）
- Pokémon Prisme（做了 13 年，2026-01 发布）、Pokémon SoulStones 2、Insurgence、Xenoverse、Sage。
- 大多用 **RPG Maker XP + Pokémon Essentials**，或 ROM hack。共同点：免费、靠社区，常被任天堂发律师函。

## 3. 推荐的 Claude Code 工具（前五）

1. **Bash + Godot 命令行（`godot --headless`）**：跑 GUT 测试、导出 Windows/macOS/Linux 包、跑行情平衡脚本。这是自动化的核心。
2. **Godot MCP 服务器（社区版 godot-mcp）**：让 Claude 启动编辑器、运行场景、读报错输出。没有的话第 1 项也能替代。
3. **子代理 / Workflow（多代理并行）**：例如同时生成 50 家虚构公司数据、复查平衡、写测试。适合大批量内容。
4. **浏览器预览 + 截图（内置浏览器 / Chrome）**：导出 Web 版后让 Claude 自己点 UI、截图验证；也用来查 Steamworks 文档。
5. **git / gh + GitHub Actions + steamcmd**：版本管理、自动构建、自动上传 Steam 测试分支。
   （加分：Figma MCP / 图像生成做 UI 草图与图标。）

## 4. 角色拆分（经验丰富的游戏开发视角）

| 角色 | 是否开发类 | 职责 | 一人工作室最低要求 |
|---|---|---|---|
| 制作人 / 发行 | 否 | 范围、排期、Steam 页面、宣传、预算 | 必须（你自己） |
| 游戏设计师 | 否 | 核心循环、经济系统、难度曲线、数值 | 必须（你 + Claude） |
| 玩法 / 系统程序 | **是** | 行情引擎、交易、存档、事件 | **必须** |
| UI / 工具程序 | **是** | 图表、交易面板、菜单、设置、Steam 接入 | **必须** |
| 美术 / UI 设计 | 否 | 风格、图标、字体、动效 | 可外包或用素材包 |
| 音频 | 否 | 音效、背景音乐 | 素材包即可 |
| QA / 测试 | 半开发 | 自动化测试 + 人工试玩 | Claude 跑自动化，你试玩 |

**最少角色：6 个（QA 合并到程序）；开发类角色最少 2 个**，可由你一个人加 Claude Code 担任。

## 5. 游戏组件与 Token 估算（按架构 A）

Token = Claude Code 读代码 + 写代码 + 来回修改的总量（含上下文，缓存命中部分不全额计费）。

| 组件 | 内容 | 估算 Token |
|---|---|---|
| 1. 行情模拟引擎 | 随机游走 / GBM、板块联动、新闻事件冲击、种子可复现 | 3–5M |
| 2. 交易系统 | 市价/限价单、手续费、持仓、盈亏、（可选）做空/杠杆 | 2–4M |
| 3. 游戏进程 | 时间推进、关卡/年份、目标、解锁、结局 | 2–3M |
| 4. 内容数据 | 虚构公司、行业、新闻事件、角色对话 | 2–4M |
| 5. UI | K 线图、盘口、资产页、菜单、设置、教程 | 5–8M |
| 6. 存档 / 设置 / 本地化 | 存档读档、中英双语 | 1–2M |
| 7. 音频与手感 | 音效接入、动效、震屏、数字跳动 | 1–2M |
| 8. Steam 接入 | GodotSteam、成就、云存档、统计、打包上传 | 1–2M |
| 9. 测试与平衡 | GUT 单元测试、自动模拟 1000 局看数值 | 3–5M |
| 10. 修 bug / 打磨 | 试玩反馈修改 | 5–10M |
| **合计** | | **约 25–45M** |

## 6. 三种架构

### 架构 A：Godot 一体化 + 数据驱动 ★★★★★（推荐）

```
┌──────────────────── Godot 项目 ────────────────────┐
│  UI 层 (Control 场景)                               │
│   K线图 · 下单面板 · 资产页 · 新闻 · 菜单            │
│        ▲ signal              │ 调用                 │
│  游戏层 (Autoload 单例)                             │
│   GameClock · Portfolio · OrderBook · EventDirector │
│        ▲                     │                      │
│  模拟层 (纯 GDScript，不依赖节点)                    │
│   MarketSim (种子随机) · PriceModel · NewsEffects   │
│        ▲                                            │
│  数据层 (.tres / JSON)：公司 · 行业 · 事件 · 关卡    │
│  平台层：SaveSystem · Settings · GodotSteam         │
└─────────────────────────────────────────────────────┘
```
- 投入：**约 3–5 个月业余时间（或 8–12 周全职）**
- Claude Code：约 **80–120 次会话**，**25–45M tokens**
- 开发角色：**2 个**（玩法/系统 + UI/工具），你一人兼任
- 优点：最简单、工具链全在一处、导出三平台一键完成
- 缺点：GDScript 性能一般（股票游戏够用）

### 架构 B：Web 栈 + 桌面套壳 ★★★★☆

```
┌──────── Tauri / Electron 外壳 (Steam 入口, steamworks.js) ────────┐
│  React / Svelte UI ── lightweight-charts (K线)                    │
│        ▲ 状态 (Zustand)                                           │
│  游戏逻辑 TypeScript：Clock · Portfolio · Orders · Events          │
│        ▲                                                          │
│  模拟核心 TypeScript (Web Worker 中跑)                             │
│  数据 JSON · 存档 (文件系统 / IndexedDB)                          │
└───────────────────────────────────────────────────────────────────┘
```
- 投入：**约 4–6 个月业余时间**
- Claude Code：约 **100–150 次会话**，**35–55M tokens**（套壳、Steam 接入、打包多花）
- 开发角色：**3 个**（前端 UI + 游戏逻辑 + 桌面/发行工程）
- 优点：Claude 最熟悉 TS/React；图表库现成；同一份代码可做网页 Demo（像 PokeBonk）
- 缺点：“像网页不像游戏”的风险；手柄/Steam Deck 适配和包体要额外处理

### 架构 C：独立模拟内核 + Godot 前端 ★★★☆☆

```
┌─ sim-core (C# 类库 或 Rust → GDExtension) ─┐     ┌─ Godot 前端 ─────────┐
│  MarketSim · Orders · Portfolio · Events   │◄───►│  UI · 动效 · 音频    │
│  纯函数、可确定性复现、命令行可跑           │     │  Save · GodotSteam   │
└───────────────┬────────────────────────────┘     └──────────────────────┘
                │
     headless 平衡工具：一次跑 10,000 局 → CSV → 调参
```
- 投入：**约 5–7 个月业余时间**
- Claude Code：约 **130–180 次会话**，**45–70M tokens**
- 开发角色：**3–4 个**（模拟/引擎程序 + 前端/UI + 工具/平衡 + 发行）
- 优点：数值最严谨、测试最方便、以后可做手机版或多人联机
- 缺点：两套语言、两套构建，一人维护负担大 —— 等 A 做出可玩版本后再考虑

### （参考）架构 D：Unity 6 ★★★☆☆
可行但不推荐：场景/预制体难被 AI 直接改，需要你频繁手动开编辑器；约 40–60M tokens，2–3 个开发角色。

## 7. 一步步开发路线

| 阶段 | 时长（业余） | 产出 | Token |
|---|---|---|---|
| 0. 立项 | 1 周 | 一页设计文档：核心循环、目标玩家、对标游戏（如 Stock Market Simulator、Good Company 类经营游戏） | 0.5M |
| 1. 纸面原型 | 1 周 | 用表格/脚本验证“买卖 → 新闻 → 价格变化”好不好玩 | 1M |
| 2. 灰盒原型 | 2–3 周 | Godot 里 1 个市场、5 家公司、能买卖、能结算 | 5M |
| 3. 竖切片 | 3–4 周 | 1 个完整关卡：UI 定稿、音效、存档、教程 | 8M |
| 4. Steam 商店页 | 并行 | 付 $100 Steam Direct、建商店页、收集愿望单 | 1M |
| 5. 内容量产 | 4–6 周 | 公司/事件/关卡批量生成 + 平衡模拟 | 10M |
| 6. Steam 接入 | 1 周 | 成就、云存档、Steam Deck 测试 | 2M |
| 7. Demo / Next Fest | 2 周 | 免费 Demo，参加 Steam 新品节 | 3M |
| 8. 打磨发售 | 2–4 周 | 修 bug、本地化、发售 | 8M |

## 8. Steam 发售注意事项
- Steam Direct 每款 $100；首次发售前商店页需审核，建议发售前 ≥ 2 周公开商店页积累愿望单。
- **（v0.2 已改）** 最早的决定是全部用虚构公司；现在改为真实公司的搞笑改名版 + 真实历史行情，不用 Logo。公开或商业发布前要再确认商标和数据条款（见 `CREDITS.md`、`game-design.md` 5.1）。
- 游戏内货币不可兑现真实资金，不做真实券商接入，避免被认定为金融或博彩产品。
- 不使用任何宝可梦 / 任天堂素材或角色。
