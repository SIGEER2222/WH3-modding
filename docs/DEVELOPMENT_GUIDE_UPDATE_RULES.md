# Development 指南更新规则

本规则用于决定何时、如何根据新需求或错误反馈更新 `warhammer-mod-development_generic/`。

## 触发条件

遇到以下情况时，应考虑更新 development 指南：

- 用户明确说“记到指南里”“以后按这个规则”“更新 development 指南”。
- 用户指出 Codex 生成的 WH3 MOD 方案、TSV、Loc、Lua 或 RPFM 流程有错误。
- 用户提供 RPFM diagnostics、游戏日志、崩溃信息或实测结果，证明现有指南缺少规则或规则不准确。
- 用户提出一个会反复使用的项目规范，例如命名前缀、目录组织、测试流程。
- 新的原版文件、RPFM schema 或可靠文档推翻了当前指南内容。

## 不应提升为通用指南的情况

以下内容默认不写入通用 `SKILL.md`：

- 某个具体 MOD 的一次性设计选择。
- 未验证的猜测。
- 只适用于用户临时测试 Pack 的路径。
- 与当前 WH3 版本或 RPFM 版本强绑定、但没有复查标记的结论。
- 只影响本项目工作区的 Codex 行为，而不是 WH3 MOD 开发规则。

这些内容按性质写入 `.codex/runtime_state.md`、`.codex/project_context_history.md`、`mod_files/<MOD名>/notes/` 或当前任务说明；不要塞回每次会话必读的 `.codex/project_context.md`。

## 更新目标

| 信息类型 | 更新位置 |
|---|---|
| 高层原则、必读规则、常用工作流 | `warhammer-mod-development_generic/SKILL.md` |
| 新增/派生兵种、坐骑、武器、兵牌、porthole | `warhammer-mod-development_generic/references/unit_creation_workflow.md` |
| TSV/DB 格式 | `warhammer-mod-development_generic/references/tsv_format.md` |
| Lua、监听器、First Tick、API | `warhammer-mod-development_generic/references/lua_api.md` |
| 命名、前缀、`data__` | `warhammer-mod-development_generic/references/naming_conventions.md` |
| 加载顺序、文件遮蔽、DB 行冲突、崩溃/OOM | `warhammer-mod-development_generic/references/crash_and_load_order_diagnostics.md` |
| Effect、Effect Bundle、scope | `warhammer-mod-development_generic/references/common_effect_keys.md` |
| 工作区、原版文件、本地化资料路径 | `warhammer-mod-development_generic/references/project_structure.md` |
| RPFM、打包部署、日志、网页核验、排错流程 | `warhammer-mod-development_generic/references/rpfm_and_verification_workflow.md` |
| 文件清单变化 | `warhammer-mod-development_generic/MANIFEST.md` |
| 每次指南规则变化 | `warhammer-mod-development_generic/CHANGELOG.md` |

## 更新流程

1. 判断反馈是否可复用。
2. 尽量用原版文件、目标 Pack、RPFM diagnostics、游戏日志或可靠文档核验。
3. 选择最小合适的指南文件更新。
4. 保留验证状态标签：
   - `[已查官方文档]`
   - `[已查原版脚本]`
   - `[实测]`
   - `[实测/需随版本复查]`
   - `[需验证]`
5. 如果是错误修正，写清“错误形态”和“正确处理方式”。
6. 如果新增文件或改名，更新 `MANIFEST.md`。
7. 每次指南规则变化都更新 `CHANGELOG.md`。
8. 检查 `SKILL.md` 与 reference 是否互相矛盾。
9. 检查历史事件、单个 MOD 状态和本机环境没有被误放回常驻上下文或通用 SKILL。

## 写法要求

- 使用简短、可执行的规则句。
- 示例使用 `custom_` 作为占位前缀，真实 MOD 另行替换。
- 不把“常见情况”写成“唯一情况”。
- 不把单次实测写成 CA 官方规则。
- 对版本敏感经验加 `[实测/需随版本复查]`。
- 对未查证 API、scope、Loc key、表版本加 `[需验证]`。

## 快速判断

可以提升到指南：

- “RPFM diagnostics 报 missing loc，因为 Loc key 前缀套错了；以后必须查原版同表同字段。”
- “读档后监听器没注册，因为用了 `add_first_tick_callback_new`；读档也要存在的监听器用 `add_first_tick_callback`。”
- “某表版本号不能凭记忆写，必须从 RPFM 导出样例确认。”

不要提升到通用指南：

- “这个具体 MOD 的前缀叫 `abc_`。”
- “这次测试 Pack 临时放在桌面。”
- “某个未复现的猜测可能导致崩溃。”
