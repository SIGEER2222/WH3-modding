# RPFM 与网页/原版核验工作流

## 外部资料来源

以下资料用于核验本 skill 的通用规则。实际开发时仍应以本地当前游戏版本的原版文件与 RPFM schema 为准。

| 主题 | 来源 |
|---|---|
| RPFM 功能、DB/Loc/TSV、diagnostics | https://frodo45127.github.io/rpfm/ |
| RPFM 入门和 Pack 原理 | https://tw-modding.com/wiki/Tutorial:RPFM_For_Dummies |
| WH3 Campaign 脚本文档索引 | https://chadvandy.github.io/tw_modding_resources/WH3/campaign/campaign_index.html |
| `core:add_listener` 签名 | https://chadvandy.github.io/tw_modding_resources/WH3/campaign/core.html |
| `campaign_manager` / First Tick / FactionTurnStart lookup listeners | https://chadvandy.github.io/tw_modding_resources/WH3/campaign/campaign_manager.html |
| Lua 脚本调用时机教程 | https://tw-modding.com/wiki/Lua:Calling_Scripts |
| Lua 监听器教程 | https://tw-modding.com/wiki/Lua:Commands,_Interfaces_%26_Listeners |
| MOD 冲突/排查 | https://tw-modding.com/wiki/Troubleshooting |

## RPFM 工作流

### 打包方式（默认自动，不询问）

需要从源文件生成 `.pack` 时，默认由 Codex 自动完成全流程：

1. `python tools/build_pack.py <mod名> --deploy` 一步完成全流程（旧的分步手工流程已废弃）：
   - 打包：`mod_files/<mod名>/` → `mod_output/<mod名>.pack`（PFH5；`text/**/*.loc.tsv` 编码为二进制 loc，`db/<table>/*.tsv` 按元数据行编码，其余路径原样复制）。**`notes/pack_notes.txt` 缺失或为空直接失败**。
   - 部署：复制 `.pack` + 预览 `.png` 到游戏 `data\`（包被运行中游戏锁定时重试 3 次后报错）。
   - 注册：备份 `state.db`（`.bak_deploy_<mod名>`）→ upsert `user_mod_data`（`alias` 取 `notes/alias.txt` 或 `--alias`，**缺失直接失败**；`notes` 取 pack_notes）→ 把 `local:data:<sha256(规范化路径)[:18]>` 插入当前 playset 末尾并同步 `app_state.enabled_order:<game_id>`。
   - 改名换版：`--deploy-name <新名>.pack --replace <旧mod_id>`（包路径变 → mod_id 变 → 旧 user_mod_data/playset 记录失效，必须 replace 重写）。
2. 同路径 loc 遮蔽**靠前胜出**：本地汉化/覆盖补丁必须排在被覆盖包之前。
3. 打包后执行临时反导出检查，检查完删除校验文件，避免后续误打包。

仅当用户明确说要自己用 RPFM 打包时，才停在源文件并提供导入路径与检查清单。

### 新建/修改 DB

1. 打开 RPFM，加载原版 dependencies。
2. 从原版表或用户指定目标 Pack/目标 MOD 表复制结构，不手写未知列。
3. 新建唯一内部表名：`!!custom_<feature>`。
4. 在 `mod_files/<MOD名>/` 维护 TSV，或直接在 RPFM 表格中编辑。
5. 导入 TSV 并保存 Pack 到 `mod_output/`。
6. 运行 diagnostics。
7. 修复 invalid references、missing loc、type mismatch、datacore issues。
8. 游戏内测试。

### Pack 写回与回归核对

当 MOD 工作目录是 TSV/资源源副本、`.pack` 是导出结果时，写回 pack 后不要只检查本轮新增文件 `[实测/需随版本复查]`：

1. 导入新增 TSV 前，若 pack 内目标 DB/Loc 文件不存在，先按 TSV 元数据行创建对应 DB/Loc packed file，再导入 TSV。
2. 若本轮操作可能导致 pack 内旧文件丢失或未同步，优先从工作目录全量重导入 `db/`、`text/db/`、`script/`、`ui/`、`composite_scene/` 等游戏读取路径；不要把 README、`_source/`、临时导出文件或备份图打入 pack。
3. 保存后至少核对旧功能的关键 marker：新增普通单位、精英/RoR 单位、effect/bundle、招募池、脚本入口、Loc 文本、unit card/porthole 资源。
4. 对中文 Loc 不只看 `decode_packed_file` 的 JSON 转义输出；必要时用 RPFM `export_tsv` 反导出后检查中文是否仍正确、旧文本是否仍存在。
5. 执行完临时反导出检查后删除校验文件，避免后续误打包。

### 就地修改 workshop 目录 pack 的备份清理

在 `steamapps/workshop/content/1142710/<wsid>/` 内就地改 pack 时 `[实测/需随版本复查]`：

1. 游戏只加载 `.pack` 后缀文件；`.bak`/`.codex-backup`/`.disabled-*`/`.pre*`/`.orig_*`/`.broken_*` 等带额外后缀的备份不会被加载，纯占空间。
2. 每次就地修改若都留一份同目录备份，大型 MOD 会快速积累（实测 3018964477 一个目录堆了 8 份 1.4G 快照 ≈11G）。
3. 约定：就地修改前确需备份时，备份文件移到本工作区 `scratch/`（或验证新 pack 生效后直接删），不要长期留在 workshop 目录。
4. 定期巡检残留：`find "<workshop>/content/1142710" -type f ! -name '*.pack' ! -name '*.png'`。

### 覆盖式补丁 diagnostics

制作类似汉化补丁的覆盖式 DB 补丁时，补丁 pack 会故意包含与主 MOD 相同 key 的最小覆盖行。RPFM diagnostics 在主包作为依赖/上下文打开后仍可能报告 `DuplicatedCombinedKeys`，这类提示只有在以下条件同时满足时才可视为预期 `[实测/需随版本复查]`：

1. 重复 key 正是本轮计划覆盖的主 MOD key。
2. 诊断列为主键列，例如 `key` 或 `unit`。
3. 没有同时出现 invalid reference、missing file、type mismatch、schema/version 或 TSV 导入错误。
4. 补丁文档中说明该 pack 依赖主 MOD，并记录需要按项目约定放在主 MOD 前面加载以覆盖同 key 行。

如果 `DuplicatedCombinedKeys` 出现在非计划覆盖的表、非目标 key，或伴随其他诊断，应按普通冲突继续排查，不要一概忽略。

### Workshop 发布文本

Steam Workshop 的最终描述文本使用 BBCode，默认放在 `workshop_release/<MOD名>/description.bbcode.txt`。

常用格式：

```text
[h1]标题[/h1]
[b]加粗[/b]
[i]斜体[/i]
[list]
[*]条目
[/list]
[url=https://example.com]链接文字[/url]
```

Markdown 可以作为草稿，但发布前应转换为 Steam 支持的 BBCode，避免标题、列表和链接在 Workshop 页面显示为原始 Markdown。

### Workshop 发布清单

生成 Workshop release 时，按可上传目录整理发布材料 `[实测/需随版本复查]`：

1. 目录默认放在 `workshop_release/<release_version>/<workshop_item_name>/`，其中 `<release_version>` 可沿用项目已有批次目录。
2. 上传文件至少包含 `<pack_name>.pack` 与同名 `<pack_name>.png`。缩略图优先复制 MOD 源目录中已确认的 `thumbnail.png` 或用户指定图片，不从 `assets/` 擅自整理、改名或清理素材。
3. 文案使用 `description.bbcode.txt`，可另放 `release_notes.bbcode.txt` 与 `UPLOAD_FILES.txt`。说明中至少写清：依赖项、加载顺序、主要改动、语言/本地化关系、兼容性和冲突风险。
4. 对汉化补丁、威力加强补丁等 submod/patch，说明必须明确它不是完整主 MOD，并写明需要主 MOD；若它通过同 key 覆盖生效，应记录项目约定的加载顺序。
5. 需要分发压缩包时，可在 release 版本目录生成 `<workshop_item_name>.zip`；压缩包应只包含上传所需文件和说明，不包含源 TSV、README、临时导出或 `_source/`。
6. 生成后核对 `.pack` 与 `mod_output/` 来源文件哈希一致、`.png` 与选定 thumbnail 哈希一致，并检查 zip 条目。
7. `workshop_release/` 与 `mod_output/` 属于生成/发布产物，默认不纳入 git；除非用户明确要求归档发布产物，否则只提交 `mod_files/` 源文件与指南更新。

### TSV 导入/导出

推荐先从 RPFM 导出同表样例，再用该样例作为模板。

原因：

- 不同表版本、列顺序、列类型可能随游戏更新变化。
- 表的内部 path 是否带扩展名、空值格式等容易因工具版本不同而有细节差异。
- RPFM 导出的样例最接近当前工具期望格式。

### 游戏版本更新后的 schema/dependencies 复查

WH3 或 RPFM 更新后，不要只看 MOD 是否能被启动器加载。先把 RPFM 的 schema 与 dependencies/cache 视为两个独立状态检查 `[已查本地配置 / 需随版本复查]`：

1. 记录当前 RPFM 版本、RPFM release 日期、`rpfm_ui.exe`/`rpfm_server.exe` 修改时间，以及 RPFM 配置目录中 `schemas/` 与 `dependencies/` 的最新修改时间。本地常见位置为 `%APPDATA%/FrodoWazEre/rpfm/config/schemas/` 与 `%APPDATA%/FrodoWazEre/rpfm/config/dependencies/`，但不要手工编辑这些缓存。
2. 若 RPFM 官方 release 或 schema 源有更新，先更新 RPFM 或在 RPFM UI 中执行 schema 更新/patch 流程；具体菜单名随 RPFM 版本变化，以当前 UI 为准 `[需验证]`。
3. 若 WH3 游戏本体更新，即使 schema 没变，也要在 RPFM 中重新加载当前 WH3 dependencies/datacore/cache；依赖缓存代表当前游戏数据，旧缓存可能掩盖 removed key、changed key 或新增 DLC 表。
4. `gamedata/` 是本地导出的原版数据快照，不会因 RPFM 刷新 dependencies/cache 自动更新。游戏更新后，如果要继续用本地文件查 DB、脚本、UI 或 Loc，应从当前游戏 pack 重新导出相关范围；小补丁可只导出 MOD 涉及表/脚本/本地化/UI，大版本或 DLC 更新优先全量刷新或保留版本化快照 `[需随版本复查]`。
5. 自动化脚本可以只做“检测和提醒”：比较 RPFM 工具版本、schema/dependencies 缓存时间、Steam 游戏 `data/*.pack` 修改时间、`gamedata/` 导出时间和 MOD 源 TSV 表清单；一旦任一项变新，就标记为需要打开 RPFM 刷新 schema/dependencies、必要时重导出 `gamedata/`，并跑 diagnostics。
6. 依赖刷新后，优先用 RPFM diagnostics 判断 MOD 是否需要兼容：schema/version、type mismatch、invalid reference、missing file、missing loc、banned table、datacore 或 duplicated key 是否出现新增错误。
7. 对 MOD 源 TSV，按表逐项和当前原版/RPFM 导出样例比对元数据行、列名、列数、列顺序和类型。表版本或列结构变了，就需要重导出模板并迁移旧数据；不要只改 metadata 版本号。
8. 对引用原版 key 的行，重新查 donor 链路是否仍存在：单位、武器、projectile、effect、bundle、unit set、招募权限、UI 资源、Loc key、脚本 API。invalid reference 通常比启动器能加载更能说明兼容性问题。
9. **实机不可见时先核对 MOD 是否真的启用**：pack 文件存在于游戏 `data/` 不等于游戏会读取它。检查 wh3mm/当前 preset 的 `mods` 列表中是否存在目标 pack，且 `isEnabled` 不是 `false`；同时确认目标 patch 在主 MOD 之后。启用状态变更后必须重启游戏再测试。
10. 若 RPFM diagnostics 清洁，仍需进游戏做最小回归：自定义单位是否可招募/可见、数值是否生效、头像/兵牌/模型是否正常、Lua 日志是否加载、关键 UI 文本是否显示。

### RPFM Server 5.0.6 WH3 dependencies 缓存实测 `[实测/需随版本复查]`

- `SetGameSelected("warhammer_3", rebuild=true)` 在当前 RPFM 5.0.6 下只会读取 `data/manifest.txt` 中的 ~233 个松散文件，`asskit_tables` 为空，vanilla `.pack` 里的 DB 表不会被解压进 dependencies 缓存。
- `LoadAllCAPackFiles` 能把所有 CA pack 作为独立的 `CA PackFiles` 打开，可查询/导出其中文件，但当前版本 diagnostics 的 reference 解析似乎仍不把它作为依赖参考表使用。
- 因此本环境下大量 `NoReferenceTableNorColumnFoundNoPak` 不能简单当作真正的 invalid reference；应同时用本地 `gamedata/` 和 Python 交叉验证；若 Python 验证引用存在，则判定为 RPFM 缓存假阳性。
- 真实 `InvalidReference`、`FieldWithPathNotFound`、`DuplicatedCombinedKeys`、`OutdatedTable` 等仍有参考价值，但需结合是否为预期覆盖、资源缺失或真实错误。
10. 若只受数据数值平衡影响、无 schema/引用/Lua/UI 错误，可在 Workshop 文案中写“已在 `<游戏版本>` 复查”；若发现结构性变化，发布兼容补丁并记录需要的加载顺序和依赖。

### Startpos / 主菜单初始军队兵牌

优先区分两个目标：

- 只要进战役后的实际开局军队改变：优先用 Lua first tick 小改，避免覆盖 startpos。
- 要让主菜单选择传奇领主详情页的“初始军队”兵牌也提前改变：通常需要改 startpos/前端 CCO 链路，属于高冲突修改。

处理 startpos 时注意：

1. startpos 是战役第 0 回合状态资源，同一战役通常只能有一个有效 startpos；会与 Mixer、IEE/TOW 或其他 startpos mod 高冲突 `[已查外部资料 / 需随版本复查]`。
2. 开局军队相关入口优先查 Assembly Kit raw data 中的 `start_pos_land_units`、`start_pos_starting_general_options`，以及游戏/战役版本中实际存在的 additional units 类表；具体列名、版本和 ID 必须以当前 AK/RPFM schema 为准。
3. RPFM Server 5.0 提供 `build_starpos_get_campaign_ids`、`build_starpos`、`build_starpos_post`、`build_starpos_cleanup` 等工具；本地实测构建前 pack 需要位于游戏 `data/` 目录，且 pack 中需要能让工具识别 campaign id 的战役表数据 `[实测/需随版本复查]`。
4. 若 `build_starpos_post` 在最小探测包或未改动原版数据时也失败，不要把临时生成物当作有效 startpos；应转为检查 RPFM/BOB/Assembly Kit 配置、RPFM UI 报错或 BOB 日志。
5. 能用 Lua 实现的开局微调不应默认升级为 startpos；只有“主菜单卡位必须同步显示”“新增可选传奇领主/派系”等 startpos-bound 目标才值得承担该风险。

### 新建独立可玩派系的验证顺序

1. 先决定范围：第一阶段优先新 faction key + 复用已有 culture/subculture；只有需要独立种族规则时才新增 culture/subculture。当前本地 WH3 快照中，`factions_tables` 通过 `subculture` 接入规则，`cultures_subcultures_tables` 再映射到 `culture`，不能把两个 key 域混写。
2. 先用 donor 建立 DB 最小链：`factions_tables`、`faction_to_faction_groups_junctions_tables`、`start_pos_factions_tables`、`frontend_factions_tables`、`frontend_faction_groups_to_factions_tables`、`frontend_faction_campaign_type_junctions_tables`、`frontend_faction_leaders_tables`，再补同字段 Loc。每张表都从当前原版导出样例确认版本、列顺序和引用。
3. 对目标战役分别核对 `start_pos_factions_tables` 记录、playable/is_major、AI personality/potential、起始资金与顺序，并用 Assembly Kit/RPFM 的当前 startpos 构建流程重新生成 `campaigns/<campaign>/startpos.esf`；仅改 `start_pos_factions` 或仅改 `frontend` 都不能使一个新 faction 真正可选 `[已查原版 DB / 已查外部 startpos 资料 / 需随版本复查]`。
4. 如果是新领主，继续核对 `agent_subtypes`、`faction_agent_permitted_subtypes`、campaign art/uniform、技能树、`faction_starting_general_effects_tables` 和 startpos 角色；如果先复用原版领主，则把新 faction 是否能正确创建、显示和招募作为第一轮验收目标。
5. 如果是新 culture/subculture，额外查 `culture_packs_tables`、`culture_pack_ids_tables`、建筑/招募/占领/科技/agent/feature forest 等所有 culture 外键，并检查 `gamedata/script/campaign/_narrative/wh3_narrative_shared_faction_data.lua` 的 culture-to-narrative 映射。新 culture 缺映射时，原版脚本会记录 warning；不要把 warning 当作可玩性已经完整 `[已查原版脚本]`。
6. 每次只验证一层：先能进派系选择界面，再能开新战役，再核对起始地区/领主/军队/外交，最后才加入独立单位、建筑、科技和机制。若进游戏崩溃，优先回退最近一次 startpos 变更，并查看 BOB/RPFM 日志与最新 `script_log_*.txt`。

### Loc 文本

1. 找到目标 DB 表的 localised 字段。
2. 在原版 Loc 搜同类型 key。
3. 按原版 key 前缀生成自定义 key。
4. 用 RPFM 检查 missing loc。
5. 游戏内查看 UI 是否显示。

## Lua 核验工作流

### API 核验优先级

1. 本地 `gamedata/documentation/script`。
2. 本地 `gamedata/script/campaign/` 原版调用。
3. Chadvandy WH3 文档。
4. TW Modding 社区教程。
5. 实测日志。

如果来源之间冲突，以 `gamedata` 中的当前游戏版本文件和实测日志为准。

### 监听器核验

检查 `core:add_listener`：

```lua
core:add_listener(
    "name",          -- 1 string
    "EventName",     -- 2 string
    condition_or_true,-- 3 function or true
    callback,        -- 4 function
    persistent       -- 5 boolean
)
```

常见错误：

```lua
-- 少 callback
core:add_listener("name", "FactionTurnStart", condition_fn, true)
```

### First Tick 核验

使用原则：

- 访问 campaign object：First Tick 后。
- 新战役和读档都需要：`cm:add_first_tick_callback`。
- 只在新战役一次性执行：`cm:is_new_game()` 分支或 `cm:add_first_tick_callback_new`。
- UI 创建相关：优先考虑 `core:add_ui_created_callback`，不要硬套 campaign First Tick。

## Debug 工作流

### 脚本不生效

1. 日志中是否有文件加载 `out()`？
2. 日志中是否有 First Tick `out()`？
3. 日志中是否有监听器注册完成 `out()`？
4. 事件是否触发？条件函数是否返回 true？
5. 回调中是否报错？
6. 是否被同名 listener remove？
7. 是否使用了 `add_first_tick_callback_new` 导致读档不注册？

### DB 不生效

1. Pack 是否被启动器加载？
2. RPFM dependencies 是否设置正确？
3. RPFM diagnostics 是否有错误？
4. 表名、版本、列名、列顺序是否正确？
5. 主键是否与原版/其他 MOD 冲突？
6. 是否误用 `data__` 造成整表冲突？
7. 是否缺少关联表或本地化？
8. 游戏内是否能通过 UI/数值验证？

### 本地化不显示

1. Loc 文件是否在 `text/db/`。
2. Loc key 是否按原版同表同字段前缀生成。
3. DB 表 localised 字段是否引用 `[hidden]` 或正确 key。
4. RPFM diagnostics 是否报 missing loc。
5. 是否用了真实换行导致 TSV 行断裂。
6. 中文/英文 Loc 是否都在正确位置。

## 冲突判断

| 资源类型 | 冲突重点 | 检查方式 |
|---|---|---|
| DB 表 | 内部表名、同 key 行、data core、同表多 MOD | RPFM diagnostics、全局搜索 key |
| Loc | 同 key 文本覆盖、缺失文本 | RPFM missing loc、游戏 UI |
| Lua | 同名全局函数、同名 listener、覆盖原版脚本 | 日志、grep、唯一 MODULE_KEY |
| UI/XML | 覆盖同路径文件、运行时组件树变化 | RPFM 文件冲突、dump_tree |
| 资源文件 | 同路径替换、依赖缺失 | RPFM diagnostics、游戏内视觉检查 |

## Skill 维护规则

更新本 skill 时：

1. 不要把单次实测经验改写成绝对规则。
2. 不要把“常见 scope”写成“唯一 scope”。
3. 不要把 `!` 写成覆盖开关。
4. 不要推荐 `data__` 作为默认方案。
5. Lua 模板必须能通过 5 参数监听器检查。
6. TSV 模板必须是“列名行 → 元数据行 → 数据行”。
7. 新增 API 必须标明验证状态。
8. 当用户需求或错误反馈暴露出可复用规则缺失时，同步更新 `SKILL.md` 或对应 reference，并更新 `CHANGELOG.md`。
9. 如果反馈来自 RPFM diagnostics、游戏日志或实测结果，记录错误形态、修正方法和验证状态，不直接写成 CA 官方通用规则。

## 启动即崩实测案例（2026-09-12，WH3 当前版本）

实测记录 `[实测/需随版本复查]`：

1. `tools/build_pack.py` 曾把 version=0 的 DB 表头部 flag 字节写成 `0x00`；对照原版 `db.pack` 与 RPFM 产出的 Pack，该字节恒为 `0x01`（version>0 的表同样在分隔标记后写 `0x01`）。flag=0 的 v0 表会导致游戏启动数秒内崩溃，且表现为"包内多张互不相干的小表分别都崩"的假象。修复后所有 v0 表正常加载。
2. `units_to_groupings_military_permissions_tables` 中把 `czx_kerrigan` / `czx_kerrigan_lord`（agent 英雄/领主单位，`land_units.class=com`）加进全部军事编组会导致启动崩溃；原版该表只放行普通部队与 cha_ 系战斗单位行。只保留 5 个普通虫族兵种（移除这两个 agent 单位行）后整包通过。
3. 二分定位方法：`tools/` 下按子集重打测试 Pack（PFH5），经 Mod Manager 最小 playset（仅依赖 Pack + 测试 Pack）启动，观察 `%APPDATA%\The Creative Assembly\Warhammer3\crash_report` 是否新增 .mdmp；存活约 60 秒视为通过。单表隔离测试可能因悬空外键产生假阳性，优先用"全包减一组"（leave-one-out）判定真凶。
