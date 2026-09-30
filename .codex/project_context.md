# Codex Project Context

本工作区用于《全面战争：战锤3》MOD 制作。本文件只做路由，不复制 `AGENTS.md`、SKILL、reference 或运行状态正文。

## 按需路由

- WH3 制作、打包、RPFM、游戏排障：`warhammer-mod-development_generic/SKILL.md`，再读任务匹配的 `references/*.md`。
- **查 DB key/内部路径/loc/行值对比（改了哪些数）/招募外键链（unit→group→pool→faction）/表列：先跑 `tools/wh3index.py`**（已预索引全部源码+pack，毫秒级；命令见 `tools/README.md`，索引过期先 `build`）。看**合并后生效的单位面板**（玩家视角最终值）跑 `tools/wh3catalogue.py`（无头版 Mod Manager 单位图鉴）。
- 当前 playset、本机路径、Workshop、具体 MOD、AI/TTS、分页文件：`.codex/runtime_state.md`；操作前仍须查询真实状态。
- 崩溃、部署、实测时间线：`.codex/project_context_history.md`。
- 目录职责：`docs/PROJECT_STRUCTURE.md`；RPFM 手工操作：`docs/RPFM_USAGE.md`；工具命令：`tools/README.md`。

## 持久事实

- 项目内 `warhammer-mod-development_generic/` 是指南的可维护源副本。
- `.workbuddy/memory/codex_project_context.md` 与本文件是硬链接，不要重复读取。
- 真实 MOD 启用与排序必须实时读取 Mod Manager `state.db`；历史 playset 名称、数量和 position 均不是常量。
- 本机/具体 MOD 最近状态写 runtime state，事件叙事写 history，可复用通用经验写 SKILL/reference 与 `CHANGELOG.md`。
