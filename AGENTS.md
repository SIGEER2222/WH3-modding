# Codex 工作规则

适用范围：本文件所在目录及其所有子目录。

## 项目身份

本工作区用于《全面战争：战锤3》MOD 制作。它目前包含本地 RPFM 工具和一份战锤3 MOD development 指南 skill，不是普通应用程序源码仓库。

当前项目结构约定：

- `assets/image/`：用户维护的图片和美术素材；默认只引用，不整理、不清理。
- `mod_files/`：MOD 打包前的可维护源文件目录。
- `mod_output/`：打包后的 `.pack` 等输出产物；不纳入版本管理。
- `workshop_release/`：Steam Workshop 发布用文件；文本描述默认使用 Steam BBCode。
- `bilingual/`、`gamedata/` 与 `rpfm-v5.0.5-x86_64-pc-windows-msvc/`：只读参考资料或本地工具，默认不修改。

## 必读上下文

处理本项目任务前，先读取：

1. `.codex/project_context.md`
2. `warhammer-mod-development_generic/SKILL.md`
3. 任务相关的 `warhammer-mod-development_generic/references/*.md`
4. 必要时读取 `docs/PROJECT_STRUCTURE.md` 和 `docs/RPFM_USAGE.md`

如果当前会话已经加载了 `warhammer-mod-development` skill，仍以本项目内 `warhammer-mod-development_generic/` 作为可维护源副本。

## 默认不要改动

- 不要修改、格式化或清理 `rpfm-v5.0.5-x86_64-pc-windows-msvc/`，除非用户明确要求更新 RPFM 工具。
- 不要把 RPFM 的 `.dll`、`.exe`、Qt 插件或资源文件当作项目代码分析对象。
- 不要把一次性测试 Pack、游戏日志、大型原版导出文件默认写入指南规则。

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
- 需要打包 MOD 时，先询问用户选择“用户手动用 RPFM 打包”还是“Codex 自动打包”；默认不直接自动打包。
- 需要准备 Workshop 文案时，使用 Steam 支持的 BBCode 格式，不使用 Markdown 作为最终发布格式。

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
