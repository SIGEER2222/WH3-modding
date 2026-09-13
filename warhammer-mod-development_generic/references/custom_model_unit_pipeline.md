# 外部模型 → 自造兵种完整管线

本文件记录"用户提供一个 `.glb` 模型文件，到游戏里能招募、能动、数值合理的新兵种"的端到端流程。与 `unit_creation_workflow.md`（纯 DB 派生单位）互补：本文档覆盖**自定义网格资产**一侧。

适用前提：工作区 `tools/` 下已有以下脚本（本项目在 `E:\Code\WH3-modding\tools\`）：

| 脚本 | 用途 |
|---|---|
| `blender_rig.py` | Blender 无头：建骨架 → 导入 GLB → 自动蒙皮 → 导出 skinned GLB |
| `convert_new_units.py` | skinned GLB → RMV2 v8 + DDS + wsmodel + material + variantmeshdefinition |
| `add_inf_units_db.py` / 生成脚本 | land_units/main_units/variants/loc/招募建筑等 DB 行 |
| `gen_new_unit_cards.py` | 单位卡 PNG（60×130）+ infopic |
| `build_pack.py` | `mod_files/<mod>` → `.pack` |
| `parse_anim_skeleton.py` / `parse_anim_clip.py` | 解析 `.anim` 骨架/动画片段（v7/v8 含 bitrate 压缩） |
| `blender_pose_render.py` / `blender_render_rmv2.py` | 无头渲染：绑定姿态 / 摆动画姿势截图 |
| `export_gamedata.py` | 读游戏 pack 条目（支持压缩条目解压） |

## 端到端流程

```
用户 GLB
  → 1. 检查 GLB（顶点数/贴图/是否已带骨）
  → 2. 选骨架（形态对照表）→ blender_rig.py → skinned GLB
  → 3. convert_new_units.py → RMV2 v8 + 贴图 + wsmodel/material + VMD
  → 4. DB 生成脚本 → land/main_units/variants/unit_variants/描述/招募/loc
  → 5. 数值对标原版供体（见 tsv_format.md「新单位数值对标法」）
  → 6. 技能/属性：复用现有链或按列名克隆原版链
  → 7. gen_new_unit_cards.py → 图标
  → 8. build_pack.py → 部署 data 目录
  → 9. AssetEditor 日志验证骨架加载（或二进制读 RMV2 头 offset 8）
  → 10. blender_pose_render 多帧动作截图验收
  → 11. Mod Manager 游戏内实测
```

## 1. GLB 入库前检查

- 先拷到 `scratch/` 用 **ASCII 文件名**——bash/Python 管道传中文路径给 Blender 会乱码。
- `blender_render_rmv2.py`（或同套 GLB 渲染脚本）先出绑定姿态图，确认模型形态、朝向、比例，再决定骨架。
- 用户模型不精致没关系——先保管线通，美术问题后期再调。

## 2. 骨架选择

按**形态**选动画集，不按名字猜。本项目实测映射 `[实测/需随版本复查]`：

| 模型形态 | 骨架 | 参考单位 |
|---|---|---|
| 普通双足人形 | `humanoid01b` | 多数步兵/英雄 |
| 2.4m 宽体人形 | `humanoid06` | 牛头人级怪步 |
| 9m 级巨兽（佝偻指行） | `humanoid11b` | Ghorgon |
| 多足爬虫/球腹虫 | `spider01` | 巨蛛 |
| 多足蟹形兽 | `crab01` | 腐烂普罗米修斯 |
| 四足猛兽 | `bigcat01` | 战神獒（73 个 clip） |
| 四足重装巨兽（鞍座） | `heavyquadruped01` | 野生三角龙 Stegadon |
| 车辆/战争机器 | `steamtank01` | 蒸汽坦克（25 骨，含 barrel_*/wheel_*/exhaust_*） |
| 恐狼形 | `wolf01` | （338 个 clip） |
| 蝎形 | `scorpion01` | 古墓巨蝎（138 clip） |
| 飞鸟 | `bird01b` | 鹰/凤凰系 |

补充实测 `[实测/需随版本复查]`：

- `heavyquadruped01` 骨架包围盒被 howdah/鞍座骨拉高（y 0..7.2 但腿区只到 ~2.6），fit 轴要用 `x`（体宽）而非 `auto`，否则模型被过度放大、腿骨区绑不到权重。
- `steamtank01` 的车辆"炮管/排气管"骨可以借给模型的长颈/尾状突起——绑定后会随开火后座/行进动画摆动。
- donor RMV2 里没有的骨架可去 `warmachines.pack`（蒸汽坦克在 `warmachines/engines/emp_steam_tank/`）。

骨架候选可先扫 anim pack 提取 `.anim` + `.bone_inv_trans_mats` 边车，用 `parse_anim_skeleton.py` 看骨骼规模。**注意：pack 里部分条目是 ZSTD/LZ4 压缩的**（magic `28 b5 2f fd`），`export_gamedata.py` 已处理解压，手工 extract 时注意 `[实测/需随版本复查]`。

## 3. 蒙皮绑定（blender_rig.py）

- 自动最近骨权重。**必须启用装饰骨黑名单**：`skirt_*/cape_*/belt_*/platform_section_*/feather_*` 等布料/挂载/羽毛骨会抢薄片状网格（甲壳、刃臂）的权重，动画一播就撕裂 `[实测]`。
- 躯干核心骨优先原则：球形/桶状躯干顶点容易被周围腿骨分抢，必要时给躯干设核心骨白名单。
- 绑定产物：`<unit>_skinned.glb`（`tools/_out/`）。

## 4. RMV2 转换（convert_new_units.py）

- 输出 RMV2 **v8** 格式，头部 offset 8 写骨架名——游戏靠这个字段挂动画。
- **单 LOD** 可把 6MB 压到 ~1.5MB/模型；贴图 base 2048、normal/mr 1024 再省体积。
- 每个单位产物：`.rigid_model_v2`、`.wsmodel`、`.xml.material`、DDS×5、`.variantmeshdefinition`。
- VMD 必须指向真实存在的 wsmodel——死链会让单位无声失败（本项目 leishou 曾有此坑）。

## 5. DB 生成

沿用 `unit_creation_workflow.md` 的最小链：main_units / land_units / variants / unit_variants / 属性组 / unit_set / 招募 / 自定义战权限 / loc。本项目约定：

- 招募建筑与该 MOD 既有兵种**同一套主招募建筑表**，不单独发明。
- `man_animation`/`man_entity` 直接用供体单位的（如牛头人 entity + `humanoid06` 动画集），不新建 entity，除非要改速度/质量/碰撞。
- `primary_melee_weapon` 也优先复用原版武器 key，要改数值才克隆新 key。

### 5a. 载具/战争机器单位的特殊链路 `[实测/需随版本复查]`

蒸汽坦克这类"引擎单位"的视觉网格不走 `unit_variants → variants → VMD` 主链，而是：

```
land_units.engine ──→ battlefield_engines_tables.key
                        ├─ model = <VMD 名>（引擎可见网格的 variantmeshdefinition）
                        ├─ gun_animation_table = wm_steam_tank01（引擎动画集）
                        ├─ battle_entity（碰撞/移动实体）
                        └─ destroyed_model / destruction_animation（可复用原版被毁模型）
land_units.articulated_record ──→ land_unit_articulated_vehicles_tables（车轮关节，原样复用）
land_units.mount = emp_hidden_mount_steam_tank（隐藏骑乘座）
unit_variants.variant ──→ 乘员 VMD（原版是 wh_emp_state_troops：乘员模型站在车体挂点上，
                          由引擎骨架驱动时保持绑定姿态；可换成同 hu1 骨架的自造变体）
```

要点：

- `battlefield_engines.model` 填的是 **VMD 文件名**（如 `emp_steam_tank` → `variantmeshes/variantmeshdefinitions/emp_steam_tank.variantmeshdefinition`），不是 wsmodel 路径。
- `main_units` 的主键列是 `unit`；蒸汽坦克供体行按 `land_unit` 列匹配（其 `unit` 是另一个 imperial_supply 记录）。
- `num_engines`/`num_mounts`/`primary_missile_weapon`（炮弹）沿供体整行克隆即可。

## 6. 数值对标

详 `tsv_format.md`「新单位数值对标法」。要点回顾：

- 供体 = 同骨架动画集 + 同 caste + 相近模型数。
- `bonus_hit_points` 是**每模型**血量；总血池 ≈ 供体 ±20%。
- `recruitment_cost`（战役）与 `multiplayer_cost` 分开同步。
- 一对多的相似单位（如两种混合体）用武器/属性区分定位，不要数值完全雷同。

## 7. 技能与属性

- 优先**复用本 MOD 已有技能链**直接加 junction 行。
- 需要新技能时，按列名对齐克隆原版整链：`unit_abilities` → `unit_special_abilities`（新 `unique_id`）→ `special_ability_phases` → `special_ability_to_special_ability_phase_junctions` → junction → loc。
- 自爆类：`wh2_dlc15_unit_abilities_exploding_unit` 是引擎级"死亡即爆"标记（隐藏 active，`wh_type_augment`，phase 本身无效果）；原版自爆单位全是**单模型**（膨胀尸 1×1600HP/425 金、自爆蛆 1×660HP/425 金），配 `expendable` 属性。多模型自爆单位按"每模型一发炸弹"定价 `[已查原版 DB / 需游戏内复查]`。
- 属性组按定位给：fear/terror/wallbreaker/expendable/guerrilla/hide_forest 不要无脑全套。

## 8. 验收层级（由轻到重）

1. **二进制**：RMV2 头 offset 8 骨架名非空；文件含权重数据。
2. **AssetEditor 日志**：打开 RMV2 后日志出现 `<skel>.anim` + 自动匹配 idle clip 即绑定成功。**WPF/D3D 视口截图可能全黑/白屏，日志才是可靠证据** `[实测]`。
3. **无头 pose render**：`blender_pose_render.py` 对每单位渲 idle+attack 多帧；重点看炸面/脱肢/漂浮碎块/贴地。姿态应用公式：`pose = C·(A·B⁻¹)·C⁻¹·bone_rest`（glTF 往返后 rest 帧 roll 不一致，必须相对绑定姿态增量驱动）`[实测]`。
4. **游戏内**：Mod Manager 启动 → 自定义战看模型/动画/技能/自爆表现；战役看招募建筑图标/兵牌/porthole。

## 9. 已知坑速查

| 症状 | 根因 | 修法 |
|---|---|---|
| 摆姿势碎成放射状 | 装饰骨抢权重 | blender_rig 黑名单重绑 |
| 连绑定姿态都碎 | rest 帧 roll 不一致，双重坐标转换 | pose 用相对增量公式 |
| AssetEditor 截图全黑 | WPF/D3D 视口截屏问题 | 看日志+二进制，勿当绑定失败 |
| 动画 0 帧 / No Skeleton | RMV2 头无骨架名/无权重 | 补蒙皮重转 |
| VMD 指向不存在 wsmodel | 死链 | 改 VMD 或补 wsmodel |
| 单位血量离谱 | HP 是每模型值，抄了单体巨兽 | 按模型数折算 |
| 中文路径喂 Blender 乱码 | 编码 | 拷 scratch 改 ASCII 名 |

## 10. 相关文档

- `unit_creation_workflow.md`：纯 DB 派生单位、招募链、RoR、兵牌/porthole。
- `asseteditor_animation_workflow.md`：AssetEditor 操作细节、Skin Wrap、动画 clip 解码格式。
- `tsv_format.md`：列名对齐克隆、数值对标法、junction 插行去重。
