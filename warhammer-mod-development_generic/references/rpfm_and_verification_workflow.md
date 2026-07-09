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

### 打包方式选择

需要从源文件生成 `.pack` 时，先询问用户选择：

1. 手动打包：用户用 RPFM UI 导入 `mod_files/<MOD名>/`，Codex 提供源文件、导入路径和检查清单。
2. 自动打包：Codex 调用 RPFM/脚本生成 `mod_output/<mod_name>.pack`，并执行导入、保存、diagnostics 与回归核对。

默认不直接自动打包。自动打包通常更耗时，因为需要过 RPFM diagnostics、检查旧功能 marker，并清理临时校验文件。

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

### TSV 导入/导出

推荐先从 RPFM 导出同表样例，再用该样例作为模板。

原因：

- 不同表版本、列顺序、列类型可能随游戏更新变化。
- 表的内部 path 是否带扩展名、空值格式等容易因工具版本不同而有细节差异。
- RPFM 导出的样例最接近当前工具期望格式。

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
