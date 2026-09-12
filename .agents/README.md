# Agent Notes

本目录用于放置其他代理或自动化工具需要的项目说明。

当前权威规则在根目录 `AGENTS.md`。任何代理处理本工作区任务时，都应先读取根目录规则，再读取 `.codex/project_context.md` 和 `warhammer-mod-development_generic/SKILL.md`。

不要把 `rpfm-v5.0.6-x86_64-pc-windows-msvc/` 当作待改源码；它是本地 RPFM 工具。

具体 MOD 源文件默认放在 `mod_files/`；图片素材在 `assets/image/`；打包产物在 `mod_output/`；Workshop 发布材料在 `workshop_release/`，发布文本使用 Steam BBCode。需要打包时先确认用户手动用 RPFM 打包还是由 Codex 自动打包。

## 本机 MOD 管理器与启动

- MOD 管理器源码位置：`E:\Code\wyccc-warhammer-mod-manager`
- 启动游戏可调用 `E:\Code\wyccc-warhammer-mod-manager\backend\launcher.py::launch_game()`，参数使用游戏路径 `E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III`、`used_mods.txt`、`app_id=1142710`、`executable_name=Warhammer3.exe`。
