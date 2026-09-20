# czx_bridge

WH3 ↔ 外部进程桥接 MOD（独立工程，定位类似 RimWorld 的 RimTalk）。

- 定位：游戏内 Lua agent + 外部 daemon 的双向数据桥；**不做战术决策**，只搬运状态与指令。
- 首个消费方：`czx_battle_tactical_commander`（v2+）；其它：仪表盘、直播 overlay、未来 LLM 指挥官、回放分析。
- 分级能力：T1 遥测广播（`out()` 日志，零依赖可做）→ T2 指令摄入（取决于 `io.open` 可用性探测）→ T3 微操级外部控制（不做）。
- 关键未知：battle Lua 沙箱 `io`/`os` 开放程度——决定架构上限，probe 第一优先。

## 目录

```text
czx_bridge/
├── README.md   ← 本文件
├── content/               ← 内容源（编辑这些，不改生成物）
│   ├── personas/*.json    ← 领主人设卡（SillyTavern chara_card_v2 格式 + extensions.czx 游戏键）
│   ├── lore_wh3.json      ← 世界观书（lorebook：派系/机制/地名/恩怨条目）
│   └── talk_lines.json    ← 台本条目（kind=line，事件 keys→台词）
├── tools/
│   ├── gen_talk.py         ← JSON → script/czx_talk_data.lua（含 lint：字段/禁写/重复键/超长）
│   ├── test_talk.py        ← 选择器参考实现 + 场景测试（16 用例）
│   └── check_lua_syntax.py ← 生成物括号/字符串平衡校验（无 lua 环境的轻量检查）
├── script/
│   ├── czx_talk_data.lua           ← 生成物：CZX_PERSONA / CZX_LORE / CZX_TALK
│   ├── _lib/mod/czx_talk_engine.lua← 引擎：tag→选择→冷却轮转→渲染分发（双上下文共用）
│   ├── battle/mod/czx_talk_battle.lua   ← 战斗钩子：轮询单位状态→事件
│   └── campaign/mod/czx_talk_campaign.lua ← 战役钩子：宣战/城易手/事务官/回合末
├── app/                   ← **独立外部应用（不依赖游戏）**
│   ├── bridge_daemon.py   ← **T1 daemon**：tail 游戏目录 czx_bridge_telemetry.jsonl → 解析状态/事件流（v0.1 已建）
│   ├── engine.py          ← 选择器+prompt 组装器（台本/lore/persona 全离线跑）
│   ├── llm.py             ← OpenAI 兼容后端适配（CZX_LLM_BASE/KEY/MODEL；无 key 时台本兜底）
│   ├── talk_app.py        ← CLI：list / fire / chat / demo / prompt
│   ├── sim_campaign.py    ← 战役模拟器：15 派系世界状态机，跑到统一（100+ 回合/5000+ 事件）
│   ├── server.py          ← Web UI：localhost:8787 战史 feed 页面 + /api/feed 轮询 API
│   ├── scenarios/*.json   ← 剧本文件（事件序列回放）
│   └── out/*.jsonl        ← 模拟产出的事件日志
└── notes/                 ← 设计与参考文档（索引见 notes/README.md）

> **桥 agent 的 pack 源在 `mod_files/zzz_czx_bridge/`**（本目录保持纯工程：app/content/notes/tools
> 不进 pack）。2026-09-16 v0.1：T1 遥测 agent（`script/battle/mod/czx_bridge.lua`，io.open 写
> JSONL，只读零控制）+ `app/bridge_daemon.py` 已建并部署到 `data\zzz_czx_bridge.pack`（未入
> playset，Mod Manager 勾选即启用）。io.open 双向可用性已由 RLH/AI General/MCT/CA 官方脚本实证，
> 见 notes/design_bridge_architecture.md §2 证据更新块。
```

```bash
cd app
python talk_app.py list                              # 20 人设 / 30+ 事件类型 / 30 lore
python talk_app.py demo scenarios/eight_peaks.json   # 剧本回放
python talk_app.py fire --event war_declared --speaker malekith --target-race high_elf
python talk_app.py prompt --event battle_start --speaker thorgrim   # 预览 LLM prompt
python talk_app.py chat malekith                     # 与领主对话（需 LLM 后端）
python sim_campaign.py --seed 1                      # 全程战役模拟（~105 回合 / ~6000 事件）
python server.py                                     # Web UI：http://localhost:8787（回放日志）
python server.py --live                              # 实时模式：sim 跑在后台，前端流式出新事件
```

工作流：改 `content/*.json` → `python tools/gen_talk.py` 重新生成 → `python tools/test_talk.py` 跑用例 → `python tools/check_lua_syntax.py script/<file>.lua` 校验。打包时 `czx_talk_data.lua` + `czx_talk_engine.lua` 放 `script/_lib/mod/`（双上下文加载），battle/campaign 钩子各归各位。

**待实测清单**（首次进游戏必须探测的 `[需验证]` 项）：battle_manager 获取方式、`bm:callback` 自调度、`infotext_manager` 文本注入、`uicomponent SetText`、事件名（FactionDeclaresWar/RegionFactionChangeEvent/CharacterCharacterTargetAction/PooledResourceChanged）、`character:character_subtype_key()`、`army:is_player_controlled()`、`os.time` 在 battle 沙箱可用性。

与 czx 的关系：czx 的决策核心保持纯 Lua、不依赖 bridge；bridge 是增强件，没它 czx 照常运行。
