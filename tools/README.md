# tools/ 可复用脚本速查

游戏侧排查（崩溃/加载顺序/pack 取证）一律先跑 `wh3diag.py`，不要再手写
一次性解析脚本；其余脚本按任务选用。除注明外均只读。

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
| `which <子串> [--exact] [--scope data\|ws\|out\|all]` | 哪些 pack 提供某内部路径/文件（同路径遮蔽排查） | `wh3diag.py which psw_天赋.lua --exact` |
| `db <pack> [--match SUB] [--rows N]` | 按 `schema_wh3.ron` 解码 pack 内 DB 表为字段对齐的行 | `wh3diag.py db zzz_psw_merged.pack --match advice` |
| `scriptlog [--marker PAT] [--tail N] [--glob PAT]` | 各 `script_log_*.txt` 的加载数/最后枚举文件/marker 命中；自动标注「148B stub = 崩在枚举前」「枚举截断 = 崩在加载中段」 | `wh3diag.py scriptlog --marker psw_guard --tail 10` |
| `usedmods [--file NAME] [--grep PAT] [--diff OTHER]` | `used_mods.txt`/`bisect_mods.txt` 等清单的 mod 顺序与集合对比 | `wh3diag.py usedmods --grep psw` |
| `compat <pack> [--dep PACK]... [--emit FIX]` | 9.x 兼容审计：旧版 DB 表（版本错位+新列清单）、悬空外键（对照原版键域，给出已知改名建议）、过期 twui 拷贝判定（stale-copy/rewrite/tweak）；`--emit` 把补丁源写到 `mod_files/<FIX>/`（TSV 重编码+改名+按主键去重+twui 原版遮蔽+notes/依赖/预览图） | `wh3diag.py compat "Imperial Arbiter.pack" --emit czx_ia_90fix` |
| `crashes [--last N] [--dump MDMP] [--regs] [--stack]` | `crash_report\D*.mdmp` 一览：异常码、故障地址→模块+偏移（`Warhammer3.exe+0x1a0be3b` 签名）、params、上下文寄存器、`.stack.txt` 符号链 | `wh3diag.py crashes --last 10 --stack` |

`compat` 说明（流程细节见 `references/crash_and_load_order_diagnostics.md` §10.32）：

- 原版基线 = `data\*.pack` 中**不含** `*.rpfm_reserved` 的包（自动排除已部署的自建包）；悬空引用键域 = 原版键 ∪ 本包 ∪ `--dep` 声明的依赖包。
- 新版列默认值与 9.0 已知键改名表维护在 `wh3diag.py` 顶部 `COMPAT_NEWCOL_DEFAULTS` / `COMPAT_KEY_RENAMES`——新补丁季发现新改名就往这里加。
- `--emit` 产物是纯源码骨架：改名/遮蔽需人工确认后 `build_pack.py <FIX> --deploy`。
- 判定 `stale-copy` 的 twui 是"过期原版拷贝"（遮蔽了新 UI）；`rewrite` 是作者真改写（保留）。+mod_only/-van_only 行数是辅助证据。
- **须 Windows Python313**（compressed 条目要 zstandard；WSL 下条目不解压会全报 DECODE-FAIL）。中文表名在 GBK 终端显示为乱码属正常，写入文件的内部路径是正确 UTF-8。

典型归因链（对应 `references/crash_and_load_order_diagnostics.md`）：

1. `crashes` 拿签名（`0xc0000005`/`0xc0000409` + exe 偏移）；
2. `scriptlog` 看崩在哪个阶段（stub=pack/DB 加载期；截断=脚本枚举中段；完整=运行时）；
3. `which`/`ls`/`meta`/`db` 对嫌疑 pack 做取证；
4. `usedmods --diff` 对比二分清单。

## 其他工具

| 脚本 | 用途 |
|---|---|
| `build_pack.py <mod> [--deploy]` | `mod_files/` → `mod_output/*.pack`（PFH5）→ 部署进 playset；**须 Windows Python313** |
| `sync_pack_to_source.py <pack> <mod>` | 部署包反解回 `mod_files/` 源布局（DB→TSV、loc→tsv、其余原样） |
| `export_gamedata.py` | 原版 pack → `gamedata/`、`bilingual/`；库函数含 `iter_pack_index`/`read_pack_header`/`read_pack_payload`/`decode_db_table`/`parse_loc`/`load_schema` |
| `bisect_pack.py` | 生成二分用 modlist |
| `verify_playset_files.py` | 校验 playset 引用的 pack 文件都在 |
| `audit_dangling_refs.py` | 扫源 TSV/表间悬空引用 |
| `set_memory_safe_prefs.py [--level 2\|1] [--dry]` | OOM 时压 `preferences.script.txt` 画质/内存档（游戏关闭后跑） |
| `launch_wh3_via_wmm.py` | 经 Mod Manager 后端拉起游戏（唯一允许的启动方式） |
| `rpfm_ws_client.ps1 <cmds.json> <out>` | 驱动 `rpfm_server.exe` websocket 做 RPFM 诊断 |
| `schema/schema_wh3.ron` | RPFM DB schema 仓库副本（wh3diag db 的兜底来源） |

一次性脚本/中间产物不要放这里——进 `scratch/`（见根 `AGENTS.md` 卫生条款）。
