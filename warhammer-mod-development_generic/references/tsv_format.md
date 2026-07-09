# RPFM TSV 文件格式规范

本文件只记录 DB/Loc TSV 的格式、列数、版本和导入检查。新增/派生兵种、坐骑、武器、porthole 等完整链路见 `unit_creation_workflow.md`。

## DB TSV 标准结构

默认使用 RPFM 可导入的三段结构：

```tsv
列名1	列名2	列名3
#<表名>;<版本号>;<Pack内部相对路径>
数据1	数据2	数据3
```

规则：

- 第 1 行是列名，按目标表 schema 的列顺序写，不写 `header` 占位。
- 第 2 行是元数据，格式为 `#<table_name>;<version>;db/<table_name>/<internal_table_name>`。
- 第 3 行起是数据行。
- 分隔符必须是 Tab。
- 每行列数必须与列名行一致。
- 表版本号和列顺序必须从原版表、RPFM schema、RPFM 导出样例或目标 MOD 同表文件确认。
- 本地文件可用 `.tsv`；Pack 内部路径通常不带 `.tsv`，以 RPFM 导出样例为准。

示例：

```tsv
attribute	attribute_group
#unit_attributes_to_groups_junctions_tables;2;db/unit_attributes_to_groups_junctions_tables/!!custom_unit_attribute_patch
guerrilla_deploy	custom_example_attribute_group
```

## 修改原版已有数据

修改原版单位、属性、能力或关联关系时：

- 先查原版实际读取的 key、group、junction 或 resource path。
- 从同表同类原版行复制结构，只改必要字段。
- 不要新建未被任何原版链路引用的孤立 key。
- 不要凭记忆手写列；列数不一致会导致 RPFM 导入失败或游戏读取异常。
- 默认使用唯一内部表名，例如 `!!custom_<feature>`；不要默认使用 `data__`。

如果目标是新增/派生单位，不要把流程塞进 TSV 格式判断里；改读 `unit_creation_workflow.md`。

## Loc TSV 标准结构

RPFM 导入 Loc TSV 也需要元数据行，但格式不同于 DB 表：

```tsv
key	text	tooltip
#Loc;1;text/db/custom_example_CN.loc		
land_units_onscreen_name_custom_example_unit	自定义单位	false
land_units_concealed_name_custom_example_unit		false
```

规则：

- 第 1 行固定为 `key	text	tooltip`。
- 第 2 行使用 `#Loc;1;<Pack 内部 loc 路径>`，路径通常是 `text/db/<file>.loc`，不是 `.loc.tsv`。
- 第 2 行仍保持 3 列，元数据后补两个空字段。
- 从第 3 行起才是 Loc 数据。
- Loc 文本换行使用字面量 `\n`，不要写真实物理换行。
- 若 RPFM 对导入后的 Loc 报 `Invalid line jump/tabulation detected in loc entry`，优先检查文本字段中是否混入真实换行或真实 Tab；普通说明文本不强制换行时，改为单行文本是最低风险规避方式 `[实测/需随版本复查]`。
- 同一个 Pack 内 Loc key 必须唯一；不要同时放中英两套相同 key 的 Loc TSV。

## Loc key 与描述字段

Loc key 必须按原版同表同字段确认，不套单一模板。

单位相关常见提醒：

- `land_units_onscreen_name_<land_unit>` 是单位显示名常见 key，但仍需查同类原版。
- `land_units_tables.historical_description_text` 与 `short_description_text` 还必须引用对应 description DB 表中存在的 key。
- 新增历史/短描述时，同时新增 `unit_description_historical_texts_tables` / `unit_description_short_texts_tables` 行和对应 Loc 文本。
- 只在 `text/db/*.loc.tsv` 增加描述 key，不补 description DB 行，会触发 invalid reference。

## 文件名与内部表名

推荐：

```text
db/<table_name>/!!custom_<feature>.tsv
```

Pack 内部：

```text
db/<table_name>/!!custom_<feature>
```

规则：

- `custom_` 是模板前缀，真实 MOD 改用稳定唯一短前缀。
- `!`、`!!`、`!!!` 只影响加载排序，不是覆盖开关。
- DB 追加/覆盖少量同 key 行时，用唯一内部表名即可。
- 默认不要使用 `data__`；整表替代是 `[高风险整表替代]`。

## 表版本参考

不要把旧 reference、记忆或示例中的版本号当最终值。生成前必须复核：

1. `gamedata/db/<table_name>/` 原版导出。
2. RPFM schema 或 RPFM 导出的同表样例。
3. 用户指定目标 MOD/Pack 的同表文件。

## 数据格式检查清单

- [ ] UTF-8 / RPFM 可识别编码。
- [ ] 第 1 行为列名，第 2 行为元数据，第 3 行起为数据。
- [ ] 使用 Tab 分隔。
- [ ] 每行列数一致。
- [ ] 表名、版本、Pack 内部路径正确。
- [ ] 数值和布尔格式与原版同列一致。
- [ ] 文本字段没有未转义 Tab 或真实换行。
- [ ] 文件末尾无多余空行、无多余尾部 Tab。
- [ ] 外键引用在原版或同一 MOD 中存在。
- [ ] 修改原版对象时使用的是实际被读取的 key/group/junction。
- [ ] RPFM diagnostics 无 invalid reference、missing loc、schema、banned table 错误。

## 何时复制原版整表

默认不复制整表。只有用户明确要求 data core / 整表替代，并理解兼容风险时才考虑：

1. 标注 `[高风险整表替代]`。
2. 包含完整原版表数据和所有必要修改。
3. 说明会与其他修改同表的 MOD 高概率冲突。
4. RPFM diagnostics 和游戏实测通过。

## 生成前最小流程

1. 查原版或 RPFM schema，确认列名、版本和类型。
2. 查目标 MOD/Pack 的同表惯例。
3. 查实际引用链。
4. 生成唯一内部表名。
5. 导入 RPFM 并运行 diagnostics。
6. 游戏内验证数值、UI 或日志效果。
