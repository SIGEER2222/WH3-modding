# web_progress — 战锤3 战役存档进度仪表盘

解析《全面战争：战锤3》战役存档（`.save`），在本机网页展示当前战役进度：回合、季节、玩家派系、金库、军团/单位/角色数量、全派系金库与兵力排行、玩家军队构成、外交战争状态、已加载 MOD 列表；并可**跨存档差分构建战役时间线**（宣战/停战、派系灭亡、军力剧变等事件流 + 玩家与主要对手的兴衰曲线）。

**中文化（schema ≥5）**：派系、单位、地区、省份、战役、任务、装备、角色名等均经 `bilingual/localisation__.loc_CN.tsv` 解析为中文显示（MOD 内容无官方译名时回退原 key）；并额外加载 `gamedata/db` 的 `main_units`/`land_units` 表，给出每单位的人数、费用、维持费、等级与估算战力。**LLM 决策简报**：`GET /api/brief?id=<存档>&format=md` 直接产出中文 Markdown 战况简报（军队编制/战力/位置、外交态势、全球战争、任务、领土、近期事件），页面有"生成简报/复制全文"按钮；不加 `format` 返回结构化 JSON。

**只读工具**：不写入、不修改存档文件。

## 启动

```bat
C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe web_progress\server.py
```

浏览器打开 <http://127.0.0.1:8321>。

- 默认存档目录 `%APPDATA%\The Creative Assembly\Warhammer3\save_games`，可用 `--save-dir <路径>` 覆盖；端口用 `--port`。
- 首次解析一个存档约 10~15 秒（2700 万节点的 ESF 树）；结果按"文件名+大小+mtime"缓存到 `cache/`，之后秒开。
- 存档轮换产生的旧缓存不会自动清理，需要时可手动清空 `cache/`。

命令行直接解析单个存档（输出 JSON 摘要）：

```bat
python -m web_progress.parse_save <存档路径> [输出.json]
```

## 界面内容

- 概览：回合数、季节、战役（如帝国争霸 Immortal Empires）、游戏版本、玩家派系、保存时间。
- 指标卡：金库 / 军团数 / 总单位数 / 角色数 / 存活派系 / 地图地区 / MOD 数。
- 派系金库排行 Top 12、兵力（单位数）Top 12，玩家派系绿色高亮。
- 玩家军团：军团名/将领名/所在省份（或最近地区）、估算战力与维持费、单位中文名+当前/最大兵力（单体单位显示 HP）+经验。
- 角色：类型（领主/工程师/法师…）、等级、最近地区名。
- 玩家领土：地区名、城镇等级、建筑中文名。
- 当前战争与外交：交战对象（含态度值）、同盟/条约/附庸关系，全部中文名。
- **战役时间线**（跨存档差分，见下）：单位数/金库曲线（玩家 + 军力前 5 对手）、事件流、兴衰概要。

## 战役时间线（跨存档差分）

存档**只保存状态、不记录逐场战斗日志**（动作日志记录在存档中为空壳），所以事件由相邻存档差分推导：

| 事件 | 推导依据 |
|---|---|
| 宣战 / 停战（玩家） | 玩家 `OLD_DIPLOMACY_RELATIONSHIP` 立场变化 |
| 派系灭亡 / 出现 | 活跃度判定（单位+军团+角色>0）翻转 |
| 军力骤减 / 激增、军团被歼 / 扩充 | 派系总单位数（≤−25 / ≥+40）与军团数（≤−3 / ≥+4）骤变 |
| 角色折损 / 玩家角色增减 | 派系角色数（≤−3）/ 玩家角色数任何变化 |
| 建筑建成 / 失去 | 区域建筑 key 集合差分（易主也会触发，相当于征服信号） |
| 装备获得 / 失去 | 玩家 ancillary key 差分 |
| 任务发布 / 状态变化 | 玩家 mission 状态串（ACTIVE/SUCCEEDED/FAILED/CANCELLED） |
| 魔法风暴生成 / 消散 | STORM 列表差分 |

- **战役会话**：存档文件名数字 = 回合号+会话 ID，同一战役的重开档自动按会话分组；面板下拉切换，默认展示存档最多的一档。
- 展示：编年史事件流（类型过滤 + 只看玩家相关 + 上回战况置顶）与**章节战报**（按 10 回合聚合，含各类事件计数）两种视图；曲线图（玩家 + 军力前 5 对手的单位数、玩家金库）。
- 快照侧新增卡片：任务与胜利目标（状态标注）、玩家装备库、世界状态。
- `crisis.triggered` 字段实测语义未定（为 `[0, True]`），不作为事件。
- 逐场战斗的伤亡明细（哪支部队打死多少人）**不在存档中**，无法提供。
- `FACTION_ECONOMICS`/`ECONOMICS_DATA` 数组除首值=金库外语义未完全核验，简报中标注「估计值，未经游戏内核对」。
- 军团"估算战力"= 各单位 `multiplayer_cost` 合计（近似自动分），非官方公式。

## API

| 端点 | 说明 |
|---|---|
| `GET /api/saves` | 存档列表（新→旧） |
| `GET /api/summary?id=<存档>` | schema5 摘要 + `*_cn` 中文字段 + `names` 映射表 |
| `GET /api/timeline[?session=<key>]` | 时间线状态/数据（事件含 `text_cn`） |
| `GET /api/timeline/build[?limit=N]` | 后台重建时间线 |
| `GET /api/brief?id=<存档>[&format=md]` | LLM 简报：JSON 或中文 Markdown（事件限同会话、≤该回合、最近 15 条） |
| `GET /api/army?id=<存档>&i=<军团序号>` | 该军团兵种卡 + 加成解析（基础值/加成明细/最终值，数据源=当前 playset 合并 DB） |
| `GET /api/icon?name=<pack内路径>` | 单位图标 PNG（Mod Manager 资产索引，含工坊包） |

## 文件结构

```
web_progress/
├── server.py          # 标准库 HTTP 服务 + 缓存 + 时间线后台构建（无第三方依赖）
├── parse_save.py      # CLI：解析单个存档输出 JSON
├── timeline.py        # 跨存档差分：快照 + 事件推导 + 曲线序列
├── parser/
│   ├── esf.py         # ESF CBAB/CAAB 读取器（结构遍历 + 值收集钩子 + 组边界回调）
│   └── campaign.py    # CAMPAIGN_SAVE_GAME 树 → 战役摘要（含玩家外交表）
├── gamedb.py          # 按 Mod Manager 当前 playset 合并生效 DB（fingerprint 缓存）
├── bonuscalc.py       # 效果包→scope→bonus_value→单位面板 解析与加成计算
├── static/            # 仪表盘页面（原生 JS + SVG 图表，无构建步骤）
└── cache/             # 解析结果与时间线缓存（git 忽略）
```

## 存档格式笔记（实测于 WH3 v9.0.x，需随版本复查）

- `.save` = 外层 ESF（magic `CBAB`）+ 内层完整 ESF（CAMPAIGN_SAVE_GAME 树）以 LZMA1 压缩存于 `COMPRESSED_DATA` 记录：`[u32 解压后大小][5B props+dict][裸 LZMA1 流]`，重排成标准 alone 头即可用 `lzma.FORMAT_ALONE` 解压。
- 字符串表：记录名 **u16 长度前缀**（与 RPFM 文档的 u8 不同，已对真实字节核验）；UTF-16/UTF-8 值串为 u32 长度 + u32 索引。
- 关键字段路径（内层树）：
  - `SAVE_GAME_HEADER` 直接基本值槽位：`[0]` 玩家派系 key、`[1]` 领袖肖像、`[2]/[3]` 回合数、`[4]` 季节(UTF-16)、`[6]` 玩家派系显示名、`[8]` 存档名、`[9]` 战役 id、`[11]` 版本串；子记录 `mod_history_block_name` 每组 4 值 = [pack 名, id, …]。
  - `WORLD/FACTION_ARRAY/FACTION`：直接值 `[1]` 派系 key（数组序=派系索引）；`FACTION_ECONOMICS` 首值 = 金库；`ARMY_ARRAY/MILITARY_FORCE` 数军队、`UNIT_CONTAINER/UNITS_ARRAY/UNIT` 数单位、`CHARACTER_ARRAY/CHARACTER` 数角色。
  - 玩家角色：`CHARACTER` 直接值 `[1]` 类型串、`[4]` 等级候选；`LOCOMOTABLE` 首 `COORD_2D` 为地图坐标。
  - 玩家外交：`FACTION/OLD_DIPLOMACY_MANAGER/OLD_DIPLOMACY_RELATIONSHIP` 每嵌套组对应一个其他派系，组内基本值 `[0]` 对方派系索引、`[2]` 立场（`neutral`/`war`/`master`…）、`[8]/[9]` 态度类数值；**每组有两个立场槽位且不对称**（实测 9 战 vs 1），取 `[2]` 为玩家对对方的立场。FACTION_ACTION_LOG_BLOCK / UNIT_HISTORY / WAR_CONTRACTS_SYSTEM 在实测存档中均为空壳。
- 派系→地区归属：`REGION` 直接基本值中含拥有者派系 key（按 key 集合匹配，v9.x 实测可用；语义仍建议随版本复查）。
- 玩家军团详情：`MILITARY_FORCE` 子树含军团名（UTF-16）、省份 key、`start_pos_settlements_onscreen_name_settlement:<region>` 位置 key、将领名块（`CHARACTER_NAME_ELEMENT` 各组 = [loc key]→[elem-type,'OTHER'] 配对）；`UNIT` 子树中派系 key 之后的连续整数首对 = 兵力 [当前, 最大]（单体单位为 HP）。

**schema 7 新增（字段语义经 WH3SaveEditor `src/tables.py` 交叉验证）：**

- `FACTION` 首个 u32 = 数值派系 id；外交行 `[0]` 引用的是该 id（优先按 id 映射回派系 key，旧行为是数组序）。
- `MILITARY_FORCE` 头部 u32 = `[force_id, commander_char_id]`；`UNIT` 直接子节点 `uk[4..9]` ≈ `[HP, HP上限, 指挥角色id, ?, rank, xp_f32]`（本实现按 COMMANDER_DETAILS 后窗口等效提取）。
- `CHARACTER` 直接 u32 = `[character_id, family_member_id, force_id, unit_id]`：由此把角色↔所属军队（`force_id`）、军队↔指挥官（`commander_char_id`）关联起来。
- `WORLD/FAMILY_TREE/FAMILY_MEMBER` + `CHARACTER_DETAILS`：玩家角色的技能/特性/装备/效果 bundle；`CAMPAIGN_SKILLS` 末尾三 u32 = `[未分配技能点, 等级, 经验]`。
- `REGION/SETTLEMENT/GARRISON_RESIDENCE` u32 `[8]` = 驻军 `force_id` → 军团标记 `garrison_of`（野战军 vs 城防军区分）。

格式参考 [RPFM](https://github.com/Frodo45127/rpfm)（MIT）`rpfm_lib/src/files/esf/` 与 [WH3SaveEditor](https://github.com/davehornik/WH3SaveEditor) `src/tables.py`；本目录为独立 Python 实现。`scratch/save_parser_research/` 保留了研究用的原型与真实存档 dump。

## 兵种 / 加成面板（schema>=7 存档字段 + 当前 playset 合并 DB）

点击军团行展开兵种卡：每个单位显示 基础值 → 加成明细 → 最终值，加成行可再展开看来源
（bundle 中文名 + 原始效果 + 数值 + 生效条件标注）。

数据流（全部实测于 WH3 v9.0.2 + 重 mod 存档）：

1. **存档侧** `campaign.py` 收集：`FACTION`/`MILITARY_FORCE`/`CHARACTER_DETAILS`/`REGION` 下的
   `CAMPAIGN_EFFECT_BUNDLE`（key + 时长 + `ADDITIONAL_EFFECTS` 内联效果），角色 `TRAITS`/`ANCILLARY_MANAGER`/`CAMPAIGN_SKILLS_BLOCK`，`UNIT` 的 rank/xp。
2. **生效 DB** `gamedb.py`：复用 wyccc-warhammer-mod-manager 后端 `collect_game_data_source_snapshot`
   （原版 data\ + playset 工坊包 + unit_data 存档编辑），全量 schema（`backend/wh3_db_schema_full.json`）按复合主键合并效果/联结表；缓存 `cache/gamedb_<fingerprint>.json`，playset 变更自动重建。
3. **加成计算** `bonuscalc.py`：
   - bundle → `effect_bundles_to_effects_junctions`；存档内联 `ADDITIONAL_EFFECTS` 优先（首个值=当前生效值，重复行=累计簿记）；
   - 角色源：`trait_level_effects`/`character_skill_level_to_effects_junctions`(level≤已学)/`ancillary_to_effects`/成员 bundle；
   - `campaign_effect_scopes` 判定 holder（faction/force/character/region）× target（force→全军, character→仅将领英雄…）× ownership × location（provincewide/regionwide 标条件旗）；
   - effect→bonus_value：basic/record/unit_set(union 去重)/unit_list/unit_class/stat_modifier/能力&属性授予；
   - `BVID_MAP` 分 平加/百分比(乘基值)/抗性点数；经验加成 `unit_experience_bonuses` = value+rate·L+scalar·L(L−1)/2。

**待与游戏内对拍核验**：effect 顺序叠加（现实现 乘区合计→加平加）、scope 的 territory/条件语义、rank 公式系数、法术类 bonus_value 映射（现归入 misc 展示）。
