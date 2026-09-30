# RPFM 使用约定

本项目自带 RPFM：

```text
rpfm-v5.0.6-x86_64-pc-windows-msvc/
├── rpfm_ui.exe
└── rpfm_server.exe
```

通常使用 `rpfm_ui.exe` 打开图形界面。`rpfm_server.exe` 仅在明确需要自动化或服务模式时使用。

## 在本项目中的角色

RPFM 用于：

- 打开和保存 `.pack`。
- 查看、导入、导出 DB 表。
- 编辑 Loc 本地化。
- 设置 dependencies。
- 运行 diagnostics。
- 检查无效引用、缺失本地化、schema 错误、冲突文件和 datacore 风险。

RPFM 不用于：

- 存放项目说明。
- 存放通用开发经验。
- 作为 Codex 的源码分析目标。

## 打包方式

制作或修改 MOD 到需要打包时，默认由 Codex 使用 Windows Python313 执行：

```text
C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe tools/build_pack.py <mod名> --deploy
```

该流程负责生成 `mod_output/` 产物、部署到游戏 `data\`、备份并更新 Mod Manager 状态、写入本地包元数据和预览图。仅当用户明确要求自己使用 RPFM 时，才停在 `mod_files/<MOD名>/` 源文件并提供手工导入、diagnostics 与验证清单。Steam Workshop 发布文件放入 `workshop_release/`，最终说明文本使用 Steam BBCode。

## 用户明确要求时的手工 RPFM 工作流

1. 用 RPFM 打开目标 Pack 或新建 Pack。
2. 确认游戏为 Total War: WARHAMMER III。
3. 设置必要 dependencies。
4. 从原版或目标 Pack 导出同表样例。
5. 在 `mod_files/<MOD名>/` 按样例维护 TSV、Loc、Lua 或资源文件。
6. 导回 Pack。
7. 保存到 `mod_output/`。
8. 运行 diagnostics。
9. 修复 diagnostics 中的错误或风险。
10. 进游戏测试。
11. 查看最新 `script_log_*.txt`。

## Codex 处理 RPFM 反馈时

当用户提供 RPFM diagnostics 或截图文字时：

- 先按错误类型分类：DB 引用、Loc、schema、冲突、空文件、datacore、依赖。
- 查 `warhammer-mod-development_generic/references/rpfm_and_verification_workflow.md`。
- 如果错误暴露出指南缺失或错误，并且可复用，按 `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md` 更新指南。

## 注意

- RPFM 工具目录中的二进制文件不要手工修改。
- 不确定 Pack 内部路径时，以 RPFM 显示和导出的样例为准。
- 不确定表版本时，以 RPFM schema、原版表或目标 Pack 为准。
