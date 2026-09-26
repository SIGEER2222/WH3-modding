# Codex 工作规则

适用范围：本文件所在目录及其所有子目录。

## 项目身份

本工作区用于《全面战争：战锤3》MOD 制作。它目前包含本地 RPFM 工具和一份战锤3 MOD development 指南 skill，不是普通应用程序源码仓库。

当前项目结构约定：

- `assets/image/`：用户维护的图片和美术素材；默认只引用，不整理、不清理。
- `mod_files/`：MOD 打包前的可维护源文件目录。
- `mod_output/`：打包后的 `.pack` 等输出产物；不纳入版本管理。
- `workshop_release/`：Steam Workshop 发布用文件；文本描述默认使用 Steam BBCode。
- `bilingual/`、`gamedata/` 与 `rpfm-v5.0.6-x86_64-pc-windows-msvc/`：只读参考资料或本地工具，默认不修改。
- `.devin/skills/`：Devin 项目级 skill（如 `tabbit` 浏览器自动化的本机对接说明）。
- `references/`：本地 MOD/英雄/美术参考样例（已纳入版本管理），仅引用。
- `manual_edit/`：用户手工 Blender 修权工作目录（`.blend` 大文件，已被 `.gitignore` 忽略）；默认只引用/追加，不整理、不清理。
- `scratch/`：临时/实验性文件目录，默认被 `.gitignore` 忽略。一次性脚本、调试输出、截图、中间导出、`_bak`、`db_binary` 等备份/生成产物应放在这里；需要长期保留的再移入 `tools/` 或对应 MOD 源目录。

## 工作区卫生（禁止在根目录乱拉屎）

- **仓库根目录禁止新增任何临时文件/目录**。一次性脚本、调试/探查脚本、预览图、渲染输出、中间导出、备份一律直接写进 `scratch/`（可建子目录分组），不允许先丢根目录"回头再收拾"。
- 根目录只允许：治理文件（`AGENTS.md`/`README.md`/`LICENSE`/`.gitignore`/`.gitattributes`）和上文已登记的顶级目录。新增顶级目录前必须先在本文件和 `docs/PROJECT_STRUCTURE.md` 登记职责，否则视为垃圾移入 `scratch/`。
- `_tmp_*`、`_preview/`、`_work_*/` 等临时命名只允许出现在 `scratch/` 内；`.gitignore` 已加 `/_tmp_*`、`/_preview/`、`/_work_*/` 兜底，但被忽略不等于允许——发现根目录出现此类项一律挪进 `scratch/` 并修正来源脚本的路径。
- `tools/` 只放可复用脚本；脚本自身的输出、下载物、中间体放 `tools/_<name>/`（`tools/_*/` 已整体忽略）或 `scratch/`。
- 写完脚本/跑完任务后自查：`git status` 里不允许出现根目录新增未跟踪垃圾文件。

## 必读上下文

处理本项目任务前，先读取：

1. `.codex/project_context.md`（只保留当前状态与持久事实；2026-09-25 前的按日排障/部署叙事归档在 `.codex/project_context_history.md`，按需查阅，不必每次读）
2. `warhammer-mod-development_generic/SKILL.md`
3. 任务相关的 `warhammer-mod-development_generic/references/*.md`
4. 必要时读取 `docs/PROJECT_STRUCTURE.md` 和 `docs/RPFM_USAGE.md`
5. `.workbuddy/memory/codex_project_context.md`（与 `.codex/project_context.md` 是同一份文件的硬链接，WorkBuddy/CodeBuddy 会话直接读这条路径即可拿到同一份记忆）

如果当前会话已经加载了 `warhammer-mod-development` skill，仍以本项目内 `warhammer-mod-development_generic/` 作为可维护源副本。

## 默认不要改动

- 不要修改、格式化或清理 `rpfm-v5.0.6-x86_64-pc-windows-msvc/`，除非用户明确要求更新 RPFM 工具。
- 不要把 RPFM 的 `.dll`、`.exe`、Qt 插件或资源文件当作项目代码分析对象。
- 不要把一次性测试 Pack、游戏日志、大型原版导出文件默认写入指南规则。
- 启动游戏必须使用 `E:\Code\wyccc-warhammer-mod-manager`（Mod Manager），禁止直接使用 Steam 链接或绕过 Mod Manager 启动；默认加载最近战役存档直接继续游戏。
- 所有 MOD 的顺序、启用、禁用一律通过 Mod Manager 管理；当前使用的程序集名为《全合集》。**注意：wh3mm 的真实加载顺序存在 `%APPDATA%\WycccModManager\state.db` 的 `playset_items` 表（playset_id + mod_id + position）里，不是 `config.json` 的 `presets[].mods` 数组**——改 config.json 的 preset 列表只影响管理器 UI 的"预设"功能，不影响实际启动顺序。脚本直改时备份 state.db 并按 `steam:<wsid>:<pack>` / `local:data:<hash>` 的 mod_id 重排 position。
- 能自动完成的操作不要要求用户手动执行；只有 Codex 确实无法完成的步骤才允许列出，并说明具体原因和需要用户做什么。

## MOD 开发规则

- 示例前缀 `custom_` 只用于模板；真实 MOD 应使用唯一短前缀。
- 默认在 `script/campaign/mod/<prefix>_<feature>.lua` 写自定义 Lua，避免覆盖原版脚本。
- 默认在 `db/<table_name>/!!<prefix>_<feature>.tsv` 新增最小必要行，避免复制整张原版表。
- 默认在 `mod_files/<MOD名>/` 下维护具体 MOD 源文件。
- 默认禁止把 `data__` 作为 MOD 表文件名；只有用户明确要求整表替代时才允许，并标注 `[高风险整表替代]`。
- `core:add_listener` 必须使用 5 参数签名。
- DB TSV 默认使用“列名行 -> 元数据行 -> 数据行”结构。
- 本地化 Loc key 必须按原版同表同字段示例确认，不套单一模板。
- 不确定的 API、scope、表版本、Loc key 或 UI 路径必须标注 `[需验证]`。
- 需要打包 MOD 时，默认由 Codex 自动完成全流程，不再询问：`tools/build_pack.py <mod名> --deploy` 一步完成 生成 `mod_output/<mod名>.pack` → 复制到游戏 `data\` → 备份 `state.db` → upsert `user_mod_data`（alias+notes）→ 将 `local:data:<路径sha256[:18]>` 插入当前 playset（并同步 `enabled_order:<game>`）。**须用 Windows Python313 运行**（`C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe`）——脚本硬编码 `E:\` 路径，WSL python3 会在 deploy 阶段 FileNotFoundError。改名重打用 `--deploy-name <新名>.pack --replace <旧mod_id>`。本地纯本地化补丁用同名 loc 整文件遮蔽时须排在被汉化包**之前**（靠前胜出）。仅当用户明确说要自己用 RPFM 打包时，才停在源文件并给操作清单。
- 需要准备 Workshop 文案时，使用 Steam 支持的 BBCode 格式，不使用 Markdown 作为最终发布格式。
- 每个 MOD（含本地自用 MOD）必须带介绍与预览图：`mod_files/<MOD名>/notes/pack_notes.txt` 一句话功能说明（build_pack 打进 pack 内 `notes.rpfm_reserved`，**缺失/为空直接拒绝打包**），`mod_files/<MOD名>/notes/alias.txt` Mod Manager 显示名（`--deploy` 时缺失直接失败，可用 `--alias` 覆盖），`mod_files/<MOD名>/preview.png` 预览图（部署时以 `<部署包名>.png` 放 `data\` 供 Mod Manager 显示）。缺失时随打包流程补齐。
- 补丁型 MOD（修复/汉化/覆盖其他 MOD 的 pack）必须在 `mod_files/<MOD名>/notes/dependencies.txt` 声明依赖的 pack 文件名（每行一个，写**实际部署/工坊包名**，`#` 开头为注释）。build_pack 会把它写进 PFH5 头依赖块和 `dependencies_manager_v2.rpfm_reserved`，Mod Manager 据此提示缺失依赖并可一键依赖排序（依赖方/补丁排前，靠前胜出）。未声明依赖的补丁在目标包缺失或顺序错误时会静默失效，难以排查。
- 本地包的 `description` 只来自工坊缓存，`user_mod_data` 的 `alias`+`notes` 是 Mod Manager 显示名称/说明的唯一来源——`build_pack.py --deploy` 已自动写入，禁止绕开脚本手工部署后漏写。mod_id = `local:data:<sha256(规范化包路径)[:18]>`，改名换路径会导致旧记录失效需重写。

## 排查入口（问题形态 → 工具）

游戏侧排查**先跑 `tools/wh3diag.py`**（只读；Windows Python313 与 WSL python3 均可；pack 写裸文件名自动解析 data\/工坊/mod_output），不要手写一次性 pack/mdmp 解析脚本：

| 问题形态 | 命令 |
|---|---|
| 崩溃归因：dump 签名/异常码/故障模块偏移 | `wh3diag.py crashes [--last N] [--stack] [--regs]` |
| 崩在哪个阶段（148B stub=枚举前；截断=加载中段；谁最后加载） | `wh3diag.py scriptlog [--marker <标识>] [--tail N]` |
| "某文件/表到底被哪个 pack 提供"、同路径遮蔽 | `wh3diag.py which <子串> [--exact]` |
| pack 里有什么/索引原始字节/头与依赖/rpfm_reserved | `wh3diag.py ls\|meta <pack>` |
| 包内 DB 行是否解码正常（对照 schema） | `wh3diag.py db <pack> [--match <子串>]` |
| 提取包内单文件内容（比对两版本某行） | `wh3diag.py cat <pack> <内部路径> [--lines A-B]` |
| used_mods/bisect 清单顺序与集合对比 | `wh3diag.py usedmods [--grep] [--diff]` |
| 大版本兼容审计（旧版表/悬空外键/过期 twui）+ 一键生成补丁源 | `wh3diag.py compat <pack> [--dep 依赖] [--emit <补丁名>]`（须 Windows Python313） |
| 启动二分排错 | `tools/bisect_pack.py`（纪律见 references §七；9.0 起 `game_startup_mode battle` autotest 已废，改前端拉起二分，见 §10.31） |
| OOM 判据与降档 | references §10.19；`tools/set_memory_safe_prefs.py` |

详细用法：`tools/README.md`。

## 反馈驱动指南更新规则

当用户提出新需求、指出错误、提供 RPFM diagnostics、游戏日志或实测反馈，并且该信息可复用于后续 WH3 MOD 开发时，Codex 应在同一任务中更新 development 指南。

更新位置：

- 高层原则或常用流程：`warhammer-mod-development_generic/SKILL.md`
- 详细规则：对应的 `warhammer-mod-development_generic/references/*.md`
- 维护过程说明：`docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md`
- 变更记录：`warhammer-mod-development_generic/CHANGELOG.md`

更新要求：

- 不把单次实测改写成绝对规则；实测经验标注 `[实测/需随版本复查]`。
- 如果反馈来自错误日志或诊断信息，保留触发条件和修正后的判断方法。
- 如果是用户个人偏好或某个具体 MOD 的约定，只写入项目上下文或该 MOD 文档，不提升为通用 skill 规则。
- 修改指南后检查相关链接、示例和术语是否仍一致。
