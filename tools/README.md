# tools/ 可复用脚本速查

游戏侧排查（崩溃/加载顺序/pack 取证）一律先跑 `wh3diag.py`，不要再手写
一次性解析脚本；"某 key/路径/loc 在哪定义、被谁引用/遮蔽" 一律先查
`wh3index.py`（SQLite 索引，`tools/_index/index.sqlite`）。
其余脚本按任务选用。除 `compat --emit`（写 mod_files/）
与 `collect`（写仓库 scratch/）外均只读，不写游戏目录/AppData。

## wh3diag.py —— WH3 运行时排查 CLI

Windows Python313 与 WSL python3 均可运行（自动映射 `X:\` ↔ `/mnt/x/`；
环境变量覆盖：`WH3_GAME_ROOT`/`WH3_APPDATA`/`RPFM_SCHEMA_WH3`）。
pack 参数写裸文件名即可（自动在 `data\` → 工坊 `1142710\*\` → `mod_output\`
顺序解析，大小写不敏感兜底）。

| 子命令 | 回答的问题 | 例 |
|---|---|---|
| `paths` | 当前解析到哪些游戏目录 | `wh3diag.py paths` |
| `ls <pack> [--grep] [--raw]` | pack 里有哪些文件；索引路径原始字节（查不可见字符） | `wh3diag.py ls zzz_psw_merged.pack` |
| `meta <pack>` | PFH5 头、依赖块、`*.rpfm_reserved`、路径分隔符统计 | `wh3diag.py meta zzz_psw_merged.pack` |
| `cat <pack> <内部路径> [--lines A-B] [--hex N]` | 提取包内文件内容/hexdump | `wh3diag.py cat zzz_psw_merged.pack "script/campaign/mod/psw_天赋.lua" --lines 2000-2012` |
| `which <子串> [--exact] [--scope data\|ws\|out\|all] [--playset]` | 哪些 pack 提供某内部路径/文件（同路径遮蔽排查）；`--playset` 只在播放集内按加载序列出并标胜者 | `wh3diag.py which hud_campaign.twui.xml --playset` |
| `db <pack> [--match SUB] [--rows N]` | 按 `schema_wh3.ron` 解码 pack 内 DB 表为字段对齐的行 | `wh3diag.py db zzz_psw_merged.pack --match advice` |
| `scriptlog [--marker PAT] [--tail N] [--glob PAT] [--ui]` | 各 `script_log_*.txt` 的加载数/最后枚举文件/marker 命中；自动标注「148B stub = 崩在枚举前」「枚举截断 = 崩在加载中段」；`--ui` 列 `[ui]` click dump 序列 + SCRIPT ERROR 跨度 + 最后 click 组件 | `wh3diag.py scriptlog --marker psw_guard --tail 10` |
| `grep <正则> [--scope used\|data\|ws\|out\|all] [--ext SUF] [-i]` | 按**内容**搜包内文件（默认 used_mods.txt 全量包的 `.lua`/`.twui.xml`）：找 SimulateLClick/组件 id/API 调用出自哪个包 | `wh3diag.py grep "SimulateLClick" --scope used` |
| `usedmods [--file NAME] [--grep PAT] [--diff OTHER]` | `used_mods.txt`/`bisect_mods.txt` 等清单的 mod 顺序与集合对比 | `wh3diag.py usedmods --grep psw` |
| `compat <pack> [--dep PACK]... [--emit FIX]` | 9.x 兼容审计：旧版 DB 表（版本错位+新列清单）、悬空外键（对照原版键域，给出已知改名建议）、过期 twui 拷贝判定（stale-copy/rewrite/tweak）；`--emit` 把补丁源写到 `mod_files/<FIX>/`（TSV 重编码+改名+按主键去重+twui 原版遮蔽+notes/依赖/预览图） | `wh3diag.py compat "Imperial Arbiter.pack" --emit czx_ia_90fix` |
| `crashes [--last N] [--dump MDMP] [--regs] [--stack]` | `crash_report\D*.mdmp` 一览：异常码、故障地址→模块+偏移（`Warhammer3.exe+0x1a0be3b` 签名）、params、上下文寄存器、`.stack.txt` 符号链；命中内置签名判定表时行下打 `==>` 提示（按录制时 build 的偏移，大版本更新后漂移） | `wh3diag.py crashes --last 10 --stack` |
| `events [--hours N] [--app]` | OOM 闸门：System Event 2004（虚拟内存耗尽，含 WH3 commit 峰值字节数）、`--app` 加列 WER 1000/1001；末尾列存活 WH3 进程**含启动时间与命令行**（区分用户启动/autotest；并发干扰检查） | `wh3diag.py events --hours 30` |
| `recent [--hours N] [--top N]` | 「最近更新优先」嫌疑清单：pack 区（data\/工坊/mod_output）与 AppData 区分开列、按 mtime 倒序，crash_report/temp/logs 等崩溃会话输出物自动略去——崩溃回归先查这里，禁止盲二分 | `wh3diag.py recent --hours 10 --top 12` |
| `triage [--hours N] [--last N]` | **一键分诊入口**：recent + crashes 签名分布 + scriptlog phase/ui + Event 2004 + 存活进程 + AppData 判据（bad_mods 刷新判定 + prefs `minimise_memory_usage`/`gfx_*` 危险档 + **挂载进度** modified.log `Mod:` vs used_mods 差异=崩在挂载期 + `no_clean_exit` 留痕 + **state.db 比 used_mods 新**=playset 启动后被改 + **最新存档 build 戳 vs exe 版本**=跨版本存档）；dump↔log 双向互近配对 + Event2004 ±秒差（≤60s 同刻=OOM 嫌疑）；recent/events 窗口自动对齐当前崩溃簇起点（6h 静默分簇） | `wh3diag.py triage --hours 10 --last 6` |
| `collect [--last N]` | **冻结现场**（A/B 前必跑）：复制 used_mods.txt/state.db/prefs/滚动日志+最近 script_log 到 `scratch/crash_<ts>/`，附 dump 签名与 Event2004 manifest——这些 mutable 文件会被后续启动原地覆盖 | `wh3diag.py collect --last 8` |
| `saveinfo <名|stem>` | **存档写入版本指纹**：`.save` 元数据区的 `vX.Y.Z Build…`/`Patch_X_Y` 戳 vs 当前 exe FileVersion——跨版本存档（旧档读不回=§10.38 world-restore 空指针族）一条命令判定；裸名/词干自动解析 save_games 最新匹配 | `wh3diag.py saveinfo 伊泰恩_自动保存.5` |

`compat` 说明（流程细节见 `references/crash_and_load_order_diagnostics.md` §10.32）：

- 原版基线 = `data\*.pack` 中**不含** `*.rpfm_reserved` 的包（自动排除已部署的自建包）；悬空引用键域 = 原版键 ∪ 本包 ∪ `--dep` 声明的依赖包。
- 新版列默认值与 9.0 已知键改名表维护在 `wh3diag.py` 顶部 `COMPAT_NEWCOL_DEFAULTS` / `COMPAT_KEY_RENAMES`——新补丁季发现新改名就往这里加。
- `--emit` 产物是纯源码骨架：改名/遮蔽需人工确认后 `build_pack.py <FIX> --deploy`。
- 判定 `stale-copy` 的 twui 是"过期原版拷贝"（遮蔽了新 UI）；`rewrite` 是作者真改写（保留）。+mod_only/-van_only 行数是辅助证据。
- **须 Windows Python313**（compressed 条目要 zstandard；WSL 下条目不解压会全报 DECODE-FAIL）。中文表名在 GBK 终端显示为乱码属正常，写入文件的内部路径是正确 UTF-8。

典型归因链（对应 `references/crash_and_load_order_diagnostics.md` §一 首查顺序）：

0. **`triage`**——崩溃归因第一步一律先跑它，一次覆盖下面 1–4 的门面证据；
1. `events` 先查 Event 2004：命中即 OOM 定案（别再二分 pack）；同时看有无并发 WH3 进程；
2. `crashes` 拿签名（`0xc0000005`/`0xc0000409` + exe 偏移）；
3. `scriptlog` 看崩在哪个阶段（stub=pack/DB 加载期；截断=脚本枚举中段；完整=运行时）；满枚举仍崩时 `scriptlog --ui` 看崩溃前最后的 click 组件与错误跨度；
4. `recent` 列最近更新嫌疑（mtime），回归先查新改的包/缓存；
5. `grep` 按内容找点击/引用来源（SimulateLClick、组件 id、API），`which --playset` 按播放集加载序找遮蔽胜者；
6. `which`/`ls`/`meta`/`db` 对嫌疑 pack 做取证；
7. `usedmods --diff` 对比二分清单。

注意：`used_mods.txt` 在**游戏根目录**（不是 AppData/data）；`mp_log.txt` 时钟为 UTC（本地 UTC+8）；script_log 内 `<Xs>` 是引擎秒数。

## wh3index.py —— 工作区内容索引（"X 定义在哪" 毫秒级反查）

把 `mod_files/` 源码 TSV、`gamedata/`、`bilingual/`、全部 pack
（data\/工坊/mod_output，mod 包含 DB 行键+loc+文本内容）预索引进
`tools/_index/index.sqlite`。**build 须 Windows Python313**（pack 压缩
条目要 zstandard）；查询任意 python。首建 ~40s，增量 ~6s（mtime 判变）。

| 子命令 | 回答的问题 | 例 |
|---|---|---|
| `build [--full] [--packs\|--src]` | 增量建/刷新索引 | `wh3index.py build` |
| `status [--stale]` | 索引规模、盘上新增/消失的 pack | |
| `find <子串>` | 一把搜：主键+外键引用+loc key+内部路径+包/mod 名 | `wh3index.py find psw_horde_primary` |
| `path <内部路径> [--exact] [--playset]` | 谁提供该文件；`--playset` 按 used_mods 序标 `WINS(靠前遮蔽)` | `wh3index.py path hud_campaign.twui.xml --playset` |
| `key <子串> [--table T] [--playset]` | 该主键谁定义（`--playset` 行冲突标 `WINS(靠后行胜出)`）+ **references 段**：哪些行的外键列引用了它（悬空引用排查） | `wh3index.py key wh3_dlc29_vmp_raise_dead_faction` |
| `table <子串>` | 哪些来源碰了这张表、各写多少行 | `wh3index.py table mercenary` |
| `loc <子串> [--text]` | loc key（或文本）→ 语言/文本/出处 | `wh3index.py loc 天廷龙弩手 --text` |
| `grep <正则> [--ext .lua]` | 已存文本内容搜索（mod 源码 + mod 包内 lua/xml/txt） | `wh3index.py grep "SimulateLClick" --ext lua` |
| `pack <名子串>` / `mod <名>` | 单包/单源码目录概览（目录分布+表行数+loc 数） | `wh3index.py pack psw_merged` |
| `show <key> [--table T] [--diff]` | 整行字段值（按行号回源文件/解码 pack 取真实值）；`--diff` 只列多来源间值不同的列——**改数值**看"谁改了哪列、改成什么" | `wh3index.py show wh3_main_cth_art_grand_cannon_0 --table land_units --diff` |
| `links <key> [--depth N]` | 外键 BFS 接线图：unit→group→pool→faction/settlement——**"扩充到别的派系"** 直接看现有接法和要补的 junction 行 | `wh3index.py links wh3_dlc29_vmp_raise_dead_faction` |
| `cols <table> [--ver N]` | 表字段清单：类型、`*`主键、`→target` 外键（改 TSV 前对照列） | `wh3index.py cols mercenary_pool_to_groups` |

判据提醒：`key`/`path` 的 `--playset` 读 `used_mods.txt`（最近启动清单），
非实时 state.db；CA 原版包只索引内部路径（行内容走 `gamedata/` src=`vanilla`）。
`show`/`links` 的行内容按需回源读取，不依赖索引新鲜度里的行值。

## wh3catalogue.py —— 无头「单位图鉴」（合并后生效面板）

复用 Mod Manager 后端 `load_catalogue()`，按 state.db 当前 playset 顺序
合并（原版垫底 + 启用 pack/自动 Movie Pack + 已保存单位修改），输出与
启动器「单位图鉴」一致的数据：**改了兵种表后看最终生效值走这里**
（wh3index `show --diff` 回答"谁改了哪列"，本工具回答"合并完玩家看到什么"）。

| 用法 | 说明 | 例 |
|---|---|---|
| `wh3catalogue.py` | playset/来源数/单位数/缺失文件摘要 | |
| `wh3catalogue.py <unit_key>` | 单单位面板 JSON：`source_chain` 标胜出 pack、`edited` 标有无单位修改覆盖 | `wh3catalogue.py czx_dgm_agumon` |
| `wh3catalogue.py <子串>` | 无精确命中时列前 20 个模糊匹配 | |
| `wh3catalogue.py --stats <子串>` | 批量紧凑面板 TSV：men/hp/armour/shield/攻防/武器/远程/速度/质量/费用，一次加载全出 | `wh3catalogue.py --stats dgm_` |

**须 Windows Python313**（backend 依赖 Pillow/zstandard）。环境变量覆盖：
`WH3_GAME_ROOT`/`WH3_WMM_ROOT`/`WH3_WMM_APPDATA`。注意面板是 DB 基础值，
不含游戏内兵力规模、战役加成与战斗临时效果；领主/英雄两页分组与文化
徽记仅 UI 侧逻辑，本工具直接给平铺单位列表。

## 其他工具

| 脚本 | 用途 |
|---|---|
| `build_pack.py <mod> [--deploy]` | `mod_files/` → `mod_output/*.pack`（PFH5）→ 部署进 playset；**须 Windows Python313** |
| `sync_pack_to_source.py <pack> <mod>` | 部署包反解回 `mod_files/` 源布局（DB→TSV、loc→tsv、其余原样） |
| `export_gamedata.py` | 原版 pack → `gamedata/`、`bilingual/`；库函数含 `iter_pack_index`/`read_pack_header`/`read_pack_payload`/`decode_db_table`/`parse_loc`/`load_schema` |
| `bisect_pack.py` | 生成二分用 modlist |
| `verify_playset_files.py` | 校验 playset 引用的 pack 文件都在 |
| `audit_dangling_refs.py` | 扫源 TSV/表间悬空引用 |
| `digimon_model_templates.py` + `digimon_model_templates.json` | 数码宝贝五类通用母骨架、动作槽位、权重保护和环境探针定义 |
| `audit_digimon_templates.py` | 只读审计 104 个实例的角色覆盖、附件链拓扑和映射证据 |
| `digimon_template_regression.py` | 五类代表模型的绑定/动作/环境回归清单 |
| `blender_environment_probe.py` | 对真实绑定 GLB 生成平地、斜坡、障碍物环境探针 PNG/JSON |
| `annotate_digimon_templates.py` | 给既有 `digimon_batch` 报告补模板元数据 |
| `set_memory_safe_prefs.py [--level 2\|1] [--dry]` | OOM 时压 `preferences.script.txt` 画质/内存档（游戏关闭后跑） |
| `launch_wh3_via_wmm.py` | 经 Mod Manager 后端拉起游戏（唯一允许的启动方式） |
| `rpfm_ws_client.ps1 <cmds.json> <out>` | 驱动 `rpfm_server.exe` websocket 做 RPFM 诊断 |
| `session_leader.py --root <dir> [--once] [--dry-run]` | Devin 会话 leader 轮巡：读 `sessions.db`+字节锁判状态，唤醒持久 leader 会话做进度总结，对"已停"会话 `devin -r -p` 派发后续任务；白名单任务板 `_session_leader/board.json`（空板=只观察不派发）；**须 Windows Python313** |
| `schema/schema_wh3.ron` | RPFM DB schema 仓库副本（wh3diag db 的兜底来源） |

一次性脚本/中间产物不要放这里——进 `scratch/`（见根 `AGENTS.md` 卫生条款）。
