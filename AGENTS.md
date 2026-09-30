# Codex 工作规则

适用范围：本目录及其全部子目录。本工作区用于《全面战争：战锤3》MOD 制作，不是普通应用源码仓库。

## 开局读取与知识分层

1. 每次任务先读 `.codex/project_context.md`：仅含项目路由与少量持久事实。
2. 涉及 WH3 MOD 制作、打包、RPFM、游戏排障时，再读 `warhammer-mod-development_generic/SKILL.md` 与任务匹配的 `references/*.md`。
3. 涉及当前 playset、本机路径、Workshop、具体 MOD、AI/TTS 或分页文件时，按需读 `.codex/runtime_state.md`，并在操作前查询真实状态。
4. 需要历史崩溃、部署或实测时间线时，按需读 `.codex/project_context_history.md`；不要每次加载。
5. `docs/PROJECT_STRUCTURE.md` 与 `docs/RPFM_USAGE.md` 仅在结构或 RPFM 操作相关时读取。

`.workbuddy/memory/codex_project_context.md` 与主上下文是硬链接；不要重复读取两份。项目内 `warhammer-mod-development_generic/` 是指南的可维护源副本。

## 工作区边界

- `.omp/`：OMP 专用精简项目上下文与项目级配置；不得放任务产物。`mod_files/`：可维护 MOD 源文件；`mod_output/`：打包产物；`workshop_release/`：Workshop 发布材料；`assets/image/`：用户美术素材。
- `gamedata/`、`bilingual/`、`references/` 和 `rpfm-v5.0.6-x86_64-pc-windows-msvc/` 默认只读。不要修改、格式化、清理或移动；不要把 RPFM 二进制当源码分析。
- `manual_edit/` 是用户手工 Blender 工作区：只引用或追加，不整理、不清理。
- 临时脚本、探查、截图、渲染、中间导出、备份、模型缓存全部直接写 `scratch/`；可复用脚本才放 `tools/`，脚本中间产物放 `tools/_<name>/` 或 `scratch/`。
- 仓库根目录禁止新增临时文件或目录。新增顶级目录前必须在本文件和 `docs/PROJECT_STRUCTURE.md` 登记职责。

## 项目硬约束

- 能自动完成的操作不要交给用户；只有确实不可达的步骤才列出，并说明原因。
- 启动游戏必须使用 `E:\Code\wyccc-warhammer-mod-manager`，不得通过 Steam 链接或其他方式绕过；默认继续最近战役存档。
- 游戏自动化/测试只允许操作 `Warhammer3.exe` 自身窗口。禁止对用户其他程序的窗口 `ShowWindow(SW_HIDE)`/`SW_MINIMIZE`、`SetWindowPos` 移出屏幕、透明化、强制置顶遮挡，也禁止 `taskkill` 无关进程（steamwebhelper、gameoverlay 等）。被遮挡时用 `PrintWindow` 或屏幕 DC 截图、`PostMessageW` 发点击。2026-09-26 用户报障"有些程序看不到窗口"即源于旧 scratch 脚本整批隐藏其他窗口，细则见 references §10.41。
- MOD 启用、禁用与排序以 `%APPDATA%\WycccModManager\state.db` 为准。操作前读取 `current_playset_id:warhammer3` 与 `playset_items`，禁止把某个 playset 名称、数量或 position 当永久事实；不要用 `config.json` 的 `presets[].mods` 推断真实加载顺序。
- 修改 `state.db` 前必须备份。部署优先使用 `tools/build_pack.py`，不要手工复制后遗漏 playset、`user_mod_data` 或封面。
- `C:\pagefile.sys` 必须保持系统托管。任何 AI 会话不得自行扩容或改配置；遇到 System Event 2004 先诊断，再询问用户。
- 用户未明确要求整表替代时，禁止用 `data__` 作为 MOD 表文件名；真实 MOD 使用唯一短前缀，`custom_` 仅为模板。
- 不确定的 API、scope、表版本、Loc key、UI 路径或资源链路标注 `[需验证]`，不得凭印象固化。

## 打包、部署与排障

- 默认由 Codex 自动打包并部署；仅当用户明确要求自己用 RPFM 时停在源文件。命令：
  `C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe tools/build_pack.py <mod名> --deploy`
- 改部署名使用 `--deploy-name <新名>.pack --replace <旧mod_id>`。
- 每个 MOD 必须具备 `notes/pack_notes.txt`、`notes/alias.txt` 与 `preview.png`；补丁型 MOD 还必须在 `notes/dependencies.txt` 写实际依赖 pack 名。具体格式以 SKILL 和打包 reference 为准。
- Workshop 最终文案使用 Steam BBCode。
- 游戏侧排障先跑 `tools/wh3diag.py`，命令索引见 `tools/README.md`；禁止另写重复 pack/mdmp 解析器。
- 内容查询先跑 `tools/wh3index.py`（SQLite 预索引：DB 主键/外键引用、pack 内部路径、loc、行值 `show --diff`、招募链路 `links`、表列 `cols`）；索引过期先 `build`。禁止为一次查询手写 TSV 扫描/diff 脚本。
- 加载顺序不可概括为“补丁统一靠前/靠后”：同内部路径是文件级遮蔽，最近实测靠前胜出；不同片段中的同主键是 DB 行级冲突，处理方式不同。任何排序修改先读 `references/crash_and_load_order_diagnostics.md` 对应章节。

## 指南维护

用户反馈可复用的 diagnostics、日志、实测或流程修正时，同一任务内更新 development 指南：高层流程写 `SKILL.md`，细则写对应 `references/*.md`，并更新 `CHANGELOG.md`。单个 MOD 状态写入该 MOD 文档或 `.codex/runtime_state.md`；按日事件写入 history。实测规则保留触发条件并标注 `[实测/需随版本复查]`。
