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

## Schema 版本降级编码 `[实测/需随版本复查]`

`tools/build_pack.py` 的 `encode_db` 按 TSV 元数据声明的版本查 schema；**schema 缺失时警告并回退到低一版编码**（例：`[warn] schema for battle_entities_tables v39 not found, using v38`）。如果相邻版本列数不同，回退编码会产生**字段错位/截断的坏行**，游戏直接判定整表非法（`bad_mods_report.txt` → `first_invalid_database_table`）。

- 实测案例（2026-09-20）：`battle_entities_tables` v39 比 v38 多一列 `stop_before_turn`，用 v38 schema 编码 v39 声明的表 → WH3 启动即 `BadMods` 拒载整个 pack；把 TSV 版本号改回 v38（多余列按顺序被忽略或丢弃）后正常编码。
- 规则：**TSV 声明的版本必须 == 打包 schema 版本**。构建日志出现 `schema for <表> v<N> not found, using v<M>` 警告时视为构建失败处理，不要带病出包。
- 判断相邻版本列差异的方法：对比 schema_wh3.ron 中两版字段列表；若新版只是尾部加列，降级声明通常安全；若中间插列/改类型，必须拿到正确 schema 或手工对齐列。

## 克隆原版数据行 `[实测/需随版本复查]`

克隆原版行（技能链、属性组等）进 MOD TSV 时，**必须按列名对齐取值**，不能按列位置从其他来源（导出版本不同的 TSV、手工粘贴串）拷贝：

- 不同来源的同一表可能 schema 版本不同、列数不同。实测案例：`unit_special_abilities_tables` 某来源 74 列 vs 本 MOD 71 列，按位置粘贴导致 `voiceover_state`/`miscast_chance` 等字段整体错位。
- 正确做法：读原版 `data__.tsv` 的列名行建 `列名→值` 映射，再按目标 TSV 自己的列名行逐列取值，缺的填空。
- 批量向 junction 表插行时，去重键要用**整行**，不能只用第 1 列——junction 表第 1 列常是外键（技能名/属性名），多行共享同值。

## 新单位数值对标法

给自造单位定数值时，按"形态/骨架/定位"选 1~2 个原版供体单位逐项对标，不要凭空写：

- 供体选择：`land_units.man_animation`/`man_entity` 同骨架动画集 + 同 caste（monstrous_infantry/monster/war_beast）+ 相近模型数。
- 必对字段：`bonus_hit_points`（注意是**每模型**血量，单体巨兽的几千上万不能抄到多模型单位）、armour、ma/md/cb/morale、weapon 的 dmg/ap/bvl/bvi、`num_men`、`multiplayer_cost`/`recruitment_cost`/`upkeep_cost`。
- 总血量粗算：HP/模型 × 模型数 ≈ 供体总血量 ±20%。
- 自爆类单位参照 `wh2_dlc15_unit_abilities_exploding_unit`（隐藏引擎标记，死亡即爆）+ `expendable` 属性；原版自爆单位均为单模型（膨胀尸 1×1600HP/425 金，自爆蛆 1×660HP/425 金），多模型自爆单位要按"每模型都是一发炸弹"定价。
