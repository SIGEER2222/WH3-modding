# MOD 命名规范（通用版）

## 核心原则

- `custom_` 是本 skill 使用的**通用占位前缀**，不是必须保留的固定前缀。实际开发时建议替换为你自己的短前缀，例如 `my_`、`abc_`、`yourmod_`。
- 所有自定义 key、Lua 模块名、DB 内部表名和 Loc 文件名都应有稳定前缀，避免与原版和其他 MOD 冲突。
- `!`、`!!`、`!!!` 是文件名排序/加载优先级工具，不是“覆盖开关”。
- 默认不要使用 `data__` 作为 MOD 文件名。
- 文件名使用小写 + 下划线（snake_case）。
- DB 表目录名必须与原版表目录名一致，区分大小写。

## 前缀选择

推荐流程：

1. 选择一个不会与常见 MOD 冲突的短前缀，例如 `my_` 或 `custom_`。
2. 同一个 MOD 内全程使用同一前缀。
3. 多个相关 MOD 可以使用同一系列前缀，但要避免同 key 重复。
4. 本 skill 示例统一使用 `custom_`；复制到真实项目时可以批量替换。

不要使用没有命名空间的 key：

```text
effect_income_bonus          # 不推荐：太通用，易冲突
custom_effect_income_bonus   # 推荐：有 MOD 前缀
```

## TSV 文件名

Pack 内 DB 文件路径：

```text
db/<table_name>/<internal_table_name>
```

本地 TSV 文件示例：

```text
db/effects_tables/!!custom_example_feature.tsv
```

可用优先级前缀：

| 前缀 | 示例 | 用途 |
|---|---|---|
| `!!!custom_` | `!!!custom_core_rules.tsv` | 最高优先级；谨慎使用 |
| `!!custom_` | `!!custom_effect_bundles.tsv` | 常见关联表/辅助表 |
| `custom_` | `custom_units.tsv` | 默认优先级，普通数据表 |
| `!custom_` | `!custom_compat_patch.tsv` | 特定兼容/排序需求 |

注意：是否加 `!` 取决于加载排序需求，不代表是否覆盖原版行。

不要写成：

```text
data__.tsv       # 默认禁止；只有高风险整表替代才考虑
random_name.tsv  # 缺少 MOD 前缀，易冲突
```

## `data__` 规则

`data__` 是原版 DB 表常见内部名。将 MOD 文件命名为 `data__` 可能导致整表 data core/替代，兼容风险极高。

默认规则：

- AI 不应主动生成 `data__`。
- 用户只说“新增几行”“改几个值”“做一个 buff”“改本地化”时，一律使用唯一 `custom_` 文件名。
- 只有用户明确要求“整张表替代 / data core / 使用 data__”，才进入高风险流程。

高风险流程必须写明：

```text
[高风险整表替代]
- 会覆盖/核心化整张表。
- 可能与其他 MOD 冲突。
- 必须包含完整表数据。
- 必须重新跑 RPFM diagnostics 和游戏测试。
```

## Lua 文件命名

| 类型 | 示例 | 用途 |
|---|---|---|
| 普通功能脚本 | `custom_example_feature.lua` | 事件监听、战役逻辑、初始化 |
| 数据/配置脚本 | `custom_ancillary_list.lua` | 静态表、配置列表、辅助数据 |

Lua 自定义脚本默认放：

```text
script/campaign/mod/custom_<feature>.lua
```

## Key 命名

| 类型 | 规则 | 示例 |
|---|---|---|
| 自定义 key | `custom_<feature>` | `custom_hostile_towards_example_faction` |
| Effect key | `custom_<effect_description>` | `custom_example_diplomatic_relations` |
| Bundle key | `custom_<feature>_lv<n>` | `custom_example_bundle_lv1` |
| Module key | `custom_<feature>` | `custom_example_feature` |
| Listener name | `<MODULE_KEY>_<event>` | `custom_example_feature_faction_turn_start` |
| Saved value | `<MODULE_KEY>_<state>` | `custom_example_feature_last_turn` |

派系、subculture、unit、region、effect 等官方 key 必须查原版表，不要自行猜测。

## 目录名规范

| 类型 | 目录 |
|---|---|
| DB 表 | `db/<table_name>/`，必须与原版 DB 表目录完全一致 |
| 自定义战役 Lua | `script/campaign/mod/` |
| 覆盖原版脚本 | `script/campaign/<原版脚本路径>`，少用，风险高 |
| 本地化 | `text/db/` |
| 英文本地化 | `text/db/en/`，可按模板约定调整 |

## 本地化文件名

推荐：

```text
text/db/custom_<feature>_CN.loc.tsv
text/db/en/custom_<feature>_EN.loc.tsv
```

如果用户指定的目标 MOD 使用不同布局，以目标 MOD 内部惯例为准，但要保持同一个 MOD 内一致。

## 与其他 MOD 的一致性检查

生成文件前检查：

1. 目标 MOD 或用户指定目标 Pack 中是否已有同表文件。
2. 是否已有同 key 行，避免重复主键。
3. 叹号前缀是否有明确排序需求。
4. 本地化文件是中文/英文分开还是同目录。
5. 是否与大型 overhaul / CBFM / Mixu / SFO 等同表高冲突。

## 禁止事项

- 不要把 `!` 解释成“覆盖原版”的必要条件。
- 不要把缺少 `!` 的 `custom_` 文件名判为错误。
- 不要默认使用 `data__`。
- 不要使用无 MOD 前缀的自定义 key。
- 不要保留他人的私有前缀作为默认模板。
- 不要凭记忆拼写官方 key。
- 不要在文件名中混用空格、全角标点、特殊符号；中文注释可放末尾，但核心文件名仍用 snake_case。
