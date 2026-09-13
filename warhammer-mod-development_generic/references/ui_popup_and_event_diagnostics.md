# 战役弹窗排错："Placeholder Body" 卡死弹窗

适用场景：游戏已进入战役，点击某个按钮/触发某事件后，弹出**正文只显示 "Placeholder Body"** 且无法关闭的模态框。这不是启动崩溃，也不是 Bad Mods 校验问题——是**脚本触发的 advice/dilemma 缺少 DB 记录或本地化**。

## 一、先分清弹窗类型

| 触发 API | 需要的 DB 记录 | 正文 loc key 约定 |
|---|---|---|
| `cm:show_advice(key)` | `advice_threads_tables` 行 `thread=key` + `advice_levels_tables` 行 `advice_thread=key` | `advice_levels_onscreen_text_<advice_levels.key>` |
| `cm:trigger_dilemma(key)` | `dilemmas_tables` + `cdir_events_dilemma_choice_details_tables` + `cdir_events_dilemma_option_junctions_tables` | `dilemmas_localised_title_<key>` 等 |
| `im:add_infotext(key)` | `advice_info_texts_tables` 行 `key=key` | `advice_info_texts_localised_text_<key>` |
| `cm:show_message_event` | `cdir_events_incident_*` 系列 | `event_feed_strings_text_<key>` |

**"Placeholder Body" 是引擎的兜底正文**：当 advice/dilemma 的 DB 记录找不到、或对应 loc key 缺失时出现。弹窗无关闭按钮时整个游戏被卡死，只能强退。

## 二、定位是哪个脚本触发的

1. 先问用户点了哪个按钮（面板按钮/事件卡/回合按钮），或在 `logs\modified.log`、`script_error_log*.txt` 找最后执行的 MOD。
2. 全量扫启用 pack 里的 `show_advice(`、`trigger_dilemma(`、`add_infotext(`、`show_message_event(`、`text_pointer` 调用点。
3. 对每个调用点的 key，检查是否有对应 DB 记录。**记录缺失 = 直接命中**。key 只出现在脚本和 loc 里、而没有任何 `advice_threads`/`advice_levels` 行，就是本病。

## 三、`show_advice` 完整链路（以 PSW 为例）

`cm:show_advice("psw_chaichu_done", true, false, nil, 0, 5)` 需要三层记录全部存在：

1. `advice_threads_tables`：`thread=psw_chaichu_done`, `game_expansion_key=warhammer3`（v1 表，两列）。
2. `advice_levels_tables`：`key=<唯一数字>`，`advice_thread=psw_chaichu_done`，其余字段照抄同包已工作行（`Scripted`×3、`advisor_name=advice_lmyx`、`force_2d_portrait=true`、`audio_clip=n` 等，v5 表 24 列）。
3. loc：`advice_levels_onscreen_text_<advice_levels.key的数字>` = 正文文本。

**注意 loc key 约定极易搞错** `[实测/需随版本复查]`：

- advice 正文用 `advice_levels_onscreen_text_<数字key>`（key 是 `advice_levels.key` 的数字值）
- **不是** `advice_info_text_<thread>`——`advice_info_text_*` 前缀属于 infotext 面板（`advice_info_texts_tables` + `add_infotext`），两者完全不同
- advisor 头像 `advisor_name` 需在 `advisors_tables` 有记录（可复用同 MOD 已注册的头像 key，如 `advice_lmyx`）
- `advice_levels.key` 是 StringU8 但约定为数字字符串；取 `zlib.crc32(thread)&0x7fffffff` 之类稳定值，并确认不与 vanilla `gamedata/db/advice_levels_tables` 及同包既有 key 冲突

## 四、dilemma / incident 弹窗的最小校验清单

`cm:trigger_dilemma(key)` 卡死或显示占位文本时，逐项查：

- `dilemmas_tables` 有 `key` 行；
- `cdir_events_dilemma_choice_details_tables` 至少有一行 `choice_key` 属于该 dilemma；
- `cdir_events_dilemma_option_junctions_tables` 把 choice 关联到 dilemma（`option_key`/`dilemma_key`）；
- 每行的 `option` 序号连续、loc key（`dilemmas_localised_title_` / `cdir_events_dilemma_choice_details_localised_*`）存在；
- 若脚本有 follow-up dilemma/payload，`cdir_events_dilemma_payloads_tables` 行不能悬空；
- 多个 MOD 都覆盖 `ui\campaign ui\dilemma.twui.xml` 时，生效者由加载顺序决定（靠前 pack 胜出，见 `crash_and_load_order_diagnostics.md`）；UI 模板被换成不兼容版本也会把正常 dilemma 渲染成占位框。

## 五、实测案例（2026-09-12，PSW 合并包）

`zzz_psw_merged.pack` 的 `psw_06_chaichu.lua`（拆除天赋功能）在拆除成功后调用 `cm:show_advice("psw_chaichu_done")`，但合并包只有脚本 + `text\psw_chaichu.loc`（且 loc 用了错误的 `advice_info_text_` 前缀），**没有任何 advice_threads/advice_levels 记录** → 点击确认拆除按钮后立即弹出不可关闭的 "Placeholder Body"。

修复：在 `mod_files/zzz_psw_merged/db/` 新增 `advice_threads_tables/zzz_psw_chaichu.tsv` + `advice_levels_tables/zzz_psw_chaichu.tsv`（克隆 `advice_psw_tf_ex_yhzl_1` 行，key=`1214413929`），loc 追加 `advice_levels_onscreen_text_1214413929`，重建 pack。

教训：**新增 `show_advice` 调用时，loc 文件和 DB 记录必须一起加**；只写 loc 或只写脚本都会产出卡死弹窗。排查时 grep `show_advice\(` 然后反查 `advice_threads` 是最快路径。
