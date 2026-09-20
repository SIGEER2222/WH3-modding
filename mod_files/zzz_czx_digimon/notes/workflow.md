# WH3 数码兽 MOD 全流程记录（可复用为"游戏提取模型→WH3 单位包"流水线）

## 0. 总览

```
提取素材 → 资产规范化 → DB 接线（~25 表）→ loc 补全 → 招募/战斗权限
→ 平衡矩阵 → build_pack.py 打包 → Mod Manager 部署 → 运行时验证
```

## 1. 素材提取与盘点

- 源：原作者提取包（chr### 命名），每只 = rmv2 模型 + DDS 贴图 + animpack 动画集 + J_* 原生骨架 + VMD + 兵牌图标。
- 先盘点可用单位数：原作者只做到 50 只（不是 104），以"资产链完整"为准入门槛，缺文件的单位不进包。
- 资产审计清单（每单位必须齐）：`rigid_model_v2`、`textures/*.dds`、animpack、`battle_skeletons` 注册值与 skeleton 文件名一致、兵牌 png。

## 2. 源目录结构

```
mod_files/zzz_czx_digimon/
  variantmeshes/wh_variantmodels/hu1/<chr###>/
  db/<table_name>/!!dgm_digimon.tsv      # 列名行→元数据行→数据行
  text/db/!!!dgm_digimon.loc.tsv         # 必须有 meta 行
  ui/units/icons/
  notes/  pack_notes.txt alias.txt dependencies.txt mod_type.txt balance.md
  preview.png
```

## 3. DB 接线（25 张表，每单位最少行）

| 表 | 作用 | 要点 |
|---|---|---|
| land_units | 战斗数值（HP/攻防/士气/武器引用） | man_animation=chr### |
| main_units | 经济（招募/维持/MP价/回合） | land_unit 引用 |
| melee_weapons / missile_weapons / projectiles | 近战打击+远程弹丸 | strike/shot 双武器 |
| unit_abilities + land_units_to_unit_abilites_junctions | 技能挂载 | junction 别漏 |
| battle_skeletons | 骨架注册 | **必须与 skeleton 文件名一致**，错即 `BATTLE_SKELETONS_TABLE bad entry` |
| battle_animations_table | animpack 注册 | |
| battle_entities | 实体定义 | **表版本陷阱**：源数据是 v39 但 schema 只有 v38，按 v38 声明（v39 仅多 stop_before_turn 尾列），错位会被 bad_mods_report 拒载 |
| culture_to_battle_animation_tables | 全文化动画映射（24 文化×50=1200 行） | |
| unit_variants / variants | 模型-贴图绑定 | |
| unit_special_abilities / unit_attributes* / unit_sets* | 属性与集合 | |
| building_units_allowed | 招募门禁 | 按建筑等级过滤成树，不要全员平铺 |
| units_custom_battle_permissions | 自定义战斗 | 50×25 派系=1250 行 |
| units_to_groupings_military_permissions | 战役军备池 | 50×105=5250 行 |
| cdir_military_generator_unit_qualities | AI 招兵质量档 | 按强度分 tier |
| battle_currency_units_cost_values | supplies 造价 | |
| unit_description_* / loc | 名称与描述 | onscreen_name + 短描述必须齐，构建有门禁 |

## 4. 平衡矩阵（进化树造价）

按 `bonus_hit_points` 分档，对齐原版单体巨兽锚点，维持费=招募÷4：

| 阶段 | HP | 招募 | 维持 | MP | 回合 | supplies | 建筑层 | cdir |
|---|---|---|---|---|---|---|---|---|
| 成长期 | 2400 | 700 | 175 | 700 | 1 | 500 | Lv1-2 | t2s3 |
| 成熟期 | 5200 | 1100 | 275 | 1000 | 1 | 900 | Lv2-3 | t2s5 |
| 完全体 | 8500 | 1600 | 400 | 1500 | 2 | 1500 | Lv3-4 | t3s5 |
| 究极体 | 14000 | 2400 | 600 | 2100 | 3 | 2200 | Lv4-5 | t4s4 |
| 传说究极体 | 14000 | 2800 | 700 | 2400 | 3 | 2600 | Lv4-5 | t5 |

建筑等级从 key 尾数解析（含 `_2A`/`_3_tormentors` 变体）；传说档=皇家骑士+古代+超究极形态单独溢价。

## 5. 打包与部署

- `tools/build_pack.py zzz_czx_digimon --deploy`，**必须 Windows Python313**（脚本硬编码 E:\ 路径）。
- 产物：mod_output pack → data\ → state.db playset upsert（mod_id=local:data:<sha256[:18]>）→ user_mod_data alias+mod_type。
- 补丁型 MOD 必须写 `notes/dependencies.txt`（进 PFH5 头依赖块 + rpfm_reserved）。
- **游戏运行时对 data\ pack 持文件锁**——部署必须等游戏退出，否则挂载半写文件必崩。

## 6. 验证清单

1. TSV 列宽/主键重复/外键引用（main→land→weapon→ability→building）
2. 建筑 key 与原版表不撞
3. 构建零 schema 警告
4. modified.log 确认 `Mod:` 挂载行；script_log/gfx.log 无骨架/模型/贴图错误
5. 战斗实例化（sunits_generated）+ 兵牌 + 中文名 + 拉近截图确认非占位模型
6. 排查顺序铁律：游戏自带日志 → 用户 A/B 实测 → 受控实验（harness 先跑空包基线）
