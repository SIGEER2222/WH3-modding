# czx_swarm_expansion 实现报告

本文记录 `czx_swarm_expansion`（虫群帝国扩展补丁）的主要实现方式、模型/动画来源、DB 逻辑、参考资料、信源和本地验证文件。

## 1. 项目目标

补丁针对 Workshop MOD `3656495027`，本体文件为 `Imperial Arbiter.pack`，本体内部的虫群单位集 key 为 `skv_chongzu`。

本补丁目标：

- 将原有 `cishe`（刺蛇）的部队数量从 8 提高到 12。
- 为帝国增加飞龙 `czx_feilong`。
- 为帝国增加蟑螂 `czx_zhanglang`。
- 为帝国增加战役英雄凯瑞甘 `czx_kerrigan`。
- 将新单位接入虫群帝国的 unit set、帝国建筑招募、帝国军事分组和自定义战斗权限。
- 为凯瑞甘接入 wizard agent、黑暗系法术技能树、帝国派系招募权限和中文本地化。

## 2. 主要实现方式

### 2.1 纯 DB + Loc 增量补丁

这是一个不含 Lua、不含自定义模型资源的增量补丁：

- 源码目录：`mod_files/czx_swarm_expansion/`
- DB 源文件：24 张 `!!czx_swarm_expansion.tsv`
- Loc 源文件：`text/db/czx_swarm_expansion_CN.loc.tsv`
- 生成脚本：`tools/gen_czx_patch.py`
- 本地卡片/技能图标生成脚本：`tools/gen_czx_cards.py`
- pack 输出：`mod_output/czx_swarm_expansion.pack`

所有 DB 表都使用独立的 `!!czx_swarm_expansion` 分片。游戏加载时会将该分片和原版/本体分片合并：

- 新 key（例如 `czx_feilong`）会新增记录。
- 与原 MOD 相同主键的 `cishe` 行用于覆盖原有 `cishe` 数据。
- 不复制整张原版表，不使用 `data__` 作为补丁分片。

生成脚本中的统一写表函数位于 `tools/gen_czx_patch.py` 第 14-19 行，表头、版本、内部路径和数据行均由脚本写入。

### 2.2 打包方式

使用本地 Python pack builder 生成 PFH5 MOD pack：

```powershell
$env:RPFM_SCHEMA_WH3="E:\Code\WH3-modding\tools\schema\schema_wh3.ron"
python E:\Code\WH3-modding\tools\build_pack.py czx_swarm_expansion
```

当前输出特点：

- PFH5。
- MOD 类型。
- 当前最终输出 49 个内部文件：29 个 DB、1 个 Loc、16 个 PNG 资源、3 个 RPFM reserved 文件。
- 未压缩（`compression_format = None`）。
- `dependencies_manager_v2.rpfm_reserved` 为空数组；实际依赖通过 MOD 管理器和加载顺序保证。

## 3. 单位和英雄的实现逻辑

### 3.1 刺蛇 `cishe`

文件：`db/main_units_tables/!!czx_swarm_expansion.tsv`

覆盖原本 `cishe` 行：

- `num_men`: `8 -> 12`
- `max_men_per_ship`: `8 -> 12`

没有改 `cishe` 的模型、武器、动画或 unit set，只覆盖部队规模字段。

### 3.2 飞龙 `czx_feilong`

实现方式是“新建 DB key + 复用原版古墓王腐尸秃鹫视觉/战斗链”：

| 链路 | 使用的 key |
|---|---|
| `main_units.unit` | `czx_feilong` |
| `main_units.land_unit` | `czx_feilong` |
| 部队规模 | 24 entities |
| `land_units.key` | `czx_feilong` |
| `land_units.man_entity` | `wh2_dlc09_tmb_flying_carrion` |
| `land_units.man_animation` | `bi1b_carrion` |
| `land_units.primary_melee_weapon` | `wh2_cld09_tmb_carrion` |
| `land_units.attribute_group` | `wh2_dlc09_tmb_mon_carrion_0` |
| `land_units.ai_usage_group` | `flying_melee_flanker_undead` |
| `unit_variants.variant` | `wh2_dlc09_tmb_carrion` |
| `unit_variants.unit_card` | `czx_feilong` |
| UI 分组 | `chong_zu` |

模型和动作仍来自腐尸秃鹫 donor，但兵牌已经改为本地生成的 `ui/units/icons/czx_feilong.png`，不再直接使用腐尸秃鹫兵牌。

因此“飞龙”当前仍不是 SC2 原始 3D 模型；它是原版模型 + 本地定制兵牌的过渡实现。

### 3.3 蟑螂 `czx_zhanglang`

实现方式是“新建 DB key + 复用原版古墓巨蝎视觉/战斗链”：

| 链路 | 使用的 key |
|---|---|
| `main_units.unit` | `czx_zhanglang` |
| `main_units.land_unit` | `czx_zhanglang` |
| 部队规模 | 1 entity |
| `land_units.key` | `czx_zhanglang` |
| `land_units.man_entity` | `wh2_dlc09_tmb_mon_tomb_scorpion` |
| `land_units.man_animation` | `sc1_scorpion01` |
| `land_units.primary_melee_weapon` | `wh2_dlc09_tmb_scorpion_claws` |
| `land_units.attribute_group` | `wh2_dlc09_tmb_mon_tomb_scorpion_0` |
| `land_units.ai_usage_group` | `melee_gatecrusher_undead` |
| `unit_variants.variant` | `wh2_dlc09_tmb_scorpion` |
| `unit_variants.unit_card` | `czx_zhanglang` |
| UI 分组 | `chong_zu` |

模型和动作仍来自古墓巨蝎 donor，但兵牌已经改为本地生成的 `ui/units/icons/czx_zhanglang.png`。当前“蟑螂”仍不是 Zerg 蟑螂模型，而是古墓巨蝎模型 + 本地定制兵牌的过渡版本。它保留单实体巨兽属性，并挂载 `wh3_main_unit_passive_single_entity`。

### 3.4 凯瑞甘 `czx_kerrigan`

凯瑞甘采用“新建 agent subtype + 新建 campaign unit + 复用暗精女术士完整技能树”的方式。

#### 战斗单位链

| 链路 | 使用的 key |
|---|---|
| `main_units.unit` | `czx_kerrigan`（英雄） / `czx_kerrigan_lord`（领主版） |
| `land_units.key` | `czx_kerrigan` / `czx_kerrigan_lord` |
| `land_units.man_entity` | `wh2_main_def_infantry_hero_blood_low_kb_resist` |
| `land_units.man_animation` | `hu1b_elf_staff_and_sword` |
| `land_units.primary_melee_weapon` | `wh2_main_def_sorceress_staff` |
| `land_units.attribute_group` | `wh2_main_def_cha_sorceress_dark_0` |
| `land_units.ai_usage_group` | `mage_highvalue` |
| `unit_variants.variant` | `wh2_main_def_sorceress` |
| `unit_variants.unit_card` | `czx_kerrigan` / `czx_kerrigan_lord` |
| UI 分组 | `wh2_main_wizard_dark` |
| 语音 actor | `wh2_main_vo_actor_Dark_Elves_Sorceress` |

战斗实体、动作、法杖和属性组仍来自暗精女术士 donor；兵牌已改为本地生成的 `czx_kerrigan.png` 与 `czx_kerrigan_lord.png`。

这两个版本目前都使用原版暗精女术士的战斗模型，并没有导入 SC2 的凯瑞甘 3D 模型。

#### Agent 链

`agent_subtypes_tables` 新建两套身份：

- 英雄：`czx_kerrigan`，agent=`wizard`，`is_caster=true`，`associated_unit_override=czx_kerrigan`，费用 800。
- 领主版：`czx_kerrigan_lord`，agent=`general`，`recruitment_category=legendary_lords`，`is_caster=true`，`associated_unit_override=czx_kerrigan_lord`，费用 1100。
- 两者都复用暗精女术士的黑暗魔法图标、语音和名字组 `czx_kerrigan`。
- 当前领主版只接入单位查看/自定义战斗和 agent/技能链，**没有改现有 Empire startpos，也没有新建独立 Zerg faction**。

`agent_culture_details_tables` 将它挂到帝国 wizard 招募链；`faction_agent_permitted_subtypes_tables` 允许以下派系招募：

- `wh_main_emp_empire`
- `wh2_dlc13_emp_golden_order`
- `wh2_dlc13_emp_the_huntmarshals_expedition`
- `wh3_main_emp_cult_of_sigmar`
- `wh3_dlc27_emp_empire_dm`

#### 技能树链

最初的风险是直接复用原版 key `wh2_main_skill_node_set_def_sorceress_dark`。该 key 是 `character_skill_node_sets_tables` 的主键，直接复用会覆盖原版暗精女术士技能树。

现在的实现是：

1. 英雄新建 `czx_skill_node_set_kerrigan`。
2. 领主版新建 `czx_skill_node_set_kerrigan_lord`。
3. 两套 set 使用独立的三个 SC2 语义节点：灵能鞭挞、灵能风暴、吸收；不再把整套暗精女术士 42 节点直接挂到凯瑞甘。
4. 每个自定义 skill 复制对应暗精 donor 的原版技能效果 junction，再换成独立 skill/node key。
5. 用 `character_skill_node_sets_tables` 分别绑定 `czx_kerrigan` 和 `czx_kerrigan_lord`。
6. 新建四个独立 ability key，并复制原版 effect/phase 链：
   - `czx_ability_mutalisk_regeneration`
   - `czx_ability_roach_regenerative_tissue`
   - `czx_ability_zergling_adrenal_glands`
   - `czx_ability_ultralisk_frenzied`
6. 具体映射：飞龙=组织再生、蟑螂=再生组织、跳虫=肾上腺素、雷兽=狂暴甲壳；分别复制原版 regeneration/frenzy 的可用 effect 链，避免直接改全局原版 ability。

实现代码在 `tools/gen_czx_patch.py` 的技能树、能力复制和 `land_units_to_unit_abilites_junctions_tables` 生成段；对应图标在 `ui/battle ui/ability_icons/`。

这仍是“原版 WH3 effect 链 + SC2 语义命名”的实现，不是从 SC2 数据文件直接移植的技能效果；三个主动/法术效果的实际底层仍分别借用了暗精 Chillwind、Bladewind 和 Soul Stealer 的 WH3 effect 链。

## 4. 招募、编组和自定义战斗逻辑

### 4.1 战役建筑招募

`building_units_allowed_tables` 将 `czx_feilong` 和 `czx_zhanglang` 加入：

- `wh_main_emp_forges_1`
- `wh_main_emp_forges_2`
- `wh_main_emp_forges_3`
- `wh_main_emp_forges_4`

每个建筑各有两条记录，共 8 条。`faction` 留空、`enabled=false` 的写法沿用了本体虫群单位的既有模式；实际是否在所有目标帝国派系的招募界面出现仍需战役测试。

### 4.2 军事编组

`units_to_groupings_military_permissions_tables` 将两个新单位加入：

- `wh_main_group_empire`
- `wh_main_group_empire_reikland`

这是招募/军队 UI 分组权限，不等同于建筑招募权限，因此两类表都需要存在。

### 4.3 自定义战斗

`units_custom_battle_permissions_tables` 当前只给 `wh_main_emp_empire` 增加：

- `czx_feilong`
- `czx_zhanglang`

凯瑞甘目前没有新增自定义战斗权限行，因此她是否能在自定义战斗中显示需要单独测试，不能把 campaign agent 权限当成 custom battle 权限。

### 4.4 虫群 unit set

三个新 key 都挂入本体 `skv_chongzu`：

- `czx_feilong`
- `czx_zhanglang`
- `czx_kerrigan`

unit set 连接用于承接本体 unit set 相关的加成/分组链，但它本身不替代建筑招募权限。

### 4.5 单实体能力

`land_units_to_unit_abilites_junctions_tables` 为以下单位添加 `wh3_main_unit_passive_single_entity`：

- `czx_zhanglang`
- `czx_kerrigan`

飞龙是 24 模多实体单位，没有挂载该 single entity 被动。

## 5. 本地化实现

Loc 文件：`text/db/czx_swarm_expansion_CN.loc.tsv`

包含：

- 飞龙名称、短描述、历史描述。
- 蟑螂名称、短描述、历史描述。
- 凯瑞甘名称、短描述、历史描述。
- 凯瑞甘 agent 名称和描述覆盖。
- `names_name_789900001=凯瑞甘`。

描述 DB 表由以下两张表提供 key：

- `unit_description_short_texts_tables`
- `unit_description_historical_texts_tables`

## 6. 模型、资源和代码的真实来源

### 6.1 模型不是本补丁制作的

本补丁目前没有添加 `variantmeshes/`、`animations/`、`audio/` 或 SC2 原始 3D 资源；但已经添加本地生成的定制兵牌/信息图：

- `ui/units/icons/czx_feilong.png`
- `ui/units/icons/czx_zhanglang.png`
- `ui/units/icons/czx_kerrigan.png`
- `ui/units/icons/czx_kerrigan_lord.png`
- 对应的 `ui/portraits/units/no_culture/` 和 `ui/units/infopics/` 文件。

生成脚本：`tools/gen_czx_cards.py`。这些 PNG 是本地绘制的矢量风格过渡卡，不是从 SC2 客户端提取的官方图片。

所有模型/动画/武器/变体资源仍通过 DB key 指向游戏原版 CA pack 中已经存在的资源：

- 飞龙：古墓王 Carrion donor。
- 蟑螂：古墓王 Tomb Scorpion donor。
- 凯瑞甘：暗精 Sorceress Dark donor。

因此当前版本是“数据库派生/换名补丁”，不是包含 Zerg 美术资源的完整美术 MOD。

#### 本地 SC2 模型搜索结果

已检查：

- `E:\SC2\SC2new\StarCraft II\`
- `E:\Download\`
- `E:\Code\WH3-modding\`
- WH3 `data/` 中的模型相关资源路径

没有找到可直接使用的 `.m3`、`.m3a`、`SC2Mod`、`variantmeshdefinition`、`wsmodel` 或 `rigid_model_v2` 的 SC2/Zerg 模型源。因此当前没有“已经导出的 SC2 模型”可接入。

要完成真正的 SC2 模型，需要：

1. 从用户自己的 SC2 安装/CASC 或合法社区资源取得 Zerg `.m3`、贴图和动画源。
2. 将 M3/骨骼/贴图转换或重建为 WH3 的 `variantmeshdefinition -> wsmodel -> rigid_model_v2 -> materials/textures` 链。
3. 将模型骨骼映射到 WH3 战斗动画；飞龙还要单独处理飞行骨骼和动画，蟑螂/雷兽要处理碰撞、实体大小和死亡动画。
4. 在本 MOD 中新增 `variantmeshes/`、实体/动作和必要的 `variants_tables` 引用，再替换当前 donor key。

RPFM 本身不能把 SC2 `.m3` 直接转换成 WH3 可用模型；当前 pack 仍只包含 WH3 donor 模型引用和本地 PNG。

### 6.2 本体跳虫/雷兽/刺蛇的真实来源

需要区分本体已有单位和本补丁新增单位：

- `gou`（跳虫）、`leishou`（雷兽）、`cishe`（刺蛇）不是本补丁新建的，而是目标本体 `Imperial Arbiter.pack` 的 `skv_chongzu` 分片中已有的自定义单位。
- 本体不仅有 DB 行，还包含自有 variantmesh、模型、材质和贴图资源：
  - 跳虫：`variantmeshes/variantmeshdefinitions/gou2.variantmeshdefinition`、`variantmeshes/wh_variantmodels/wolf01/gou/g.rigid_model_v2`、`g.wsmodel`、`tex/*.dds`。
  - 雷兽：`variantmeshes/variantmeshdefinitions/leishou.variantmeshdefinition` / `leishou_2.variantmeshdefinition`、`variantmeshes/wh_variantmodels/bc1/tmb/tmb_warsphinx/leishou_2.rigid_model_v2`、`leishou_2.wsmodel`。
  - 刺蛇：`variantmeshes/variantmeshdefinitions/cishe2.variantmeshdefinition`、`variantmeshes/wh_variantmodels/sn01/cishe/es*.rigid_model_v2`、`*.wsmodel`、`tex/*.dds`。
- 但它们仍复用了部分 donor 的 WH3 动画/战斗键：跳虫使用 `wf1_dire_wolf_gou`，雷兽使用 `bc1_warsphinx`，刺蛇使用 `sn1_sepulchral_stalker_halberd`。静态数据能确认资源和引用关系，不能证明原 MOD 作者当初是否从 donor 网格重制过模型。
- 本补丁当前只给 `gou` 和 `leishou` 增加独立的 SC2 语义 ability，不覆盖它们已有模型资源。

本体文件：

```text
E:\Program Files (x86)\Steam2\steamapps\workshop\content\1142710\3656495027\Imperial Arbiter.pack
```

### 6.3 具体 donor 表来源

每个 donor 的战斗实体、动画、武器、属性组和变体 key 来自本地原版导出：

- `gamedata/db/main_units_tables/data__.tsv`
- `gamedata/db/land_units_tables/data__.tsv`
- `gamedata/db/unit_variants_tables/data__.tsv`
- `gamedata/db/variants_tables/data__.tsv`
- `gamedata/db/battle_entities_tables/data__.tsv`
- `gamedata/db/battle_animations_table_tables/data__.tsv`
- `gamedata/db/melee_weapons_tables/data__.tsv`
- `gamedata/db/unit_attributes_groups_tables/data__.tsv`
- `gamedata/db/unit_attributes_to_groups_junctions_tables/data__.tsv`

本体虫群 key 和本体已有 unit set 来自：

```text
E:\Program Files (x86)\Steam2\steamapps\workshop\content\1142710\3656495027\Imperial Arbiter.pack
```

本地工作区中也通过 `gamedata/` 和 pack 解析脚本核对了 `skv_chongzu`、`cishe`、`gou`、`leishou` 及其招募链。

## 7. 本地参考和验证信源

### 7.1 直接数据源（最高优先级）

1. 本地游戏原版 DB 导出：`E:\Code\WH3-modding\gamedata\db\`。
2. 本地 RPFM WH3 schema：`E:\Code\WH3-modding\tools\schema\schema_wh3.ron`。
3. 目标 Workshop 本体：`Imperial Arbiter.pack`，Workshop ID `3656495027`。
4. 本补丁源文件：`E:\Code\WH3-modding\mod_files\czx_swarm_expansion\`。
5. 生成脚本：`E:\Code\WH3-modding\tools\gen_czx_patch.py`。

### 7.2 本地工作区开发参考

- `warhammer-mod-development_generic/SKILL.md`
- `warhammer-mod-development_generic/references/unit_creation_workflow.md`
- `warhammer-mod-development_generic/references/tsv_format.md`
- `warhammer-mod-development_generic/references/naming_conventions.md`
- `warhammer-mod-development_generic/references/project_structure.md`
- `warhammer-mod-development_generic/references/rpfm_and_verification_workflow.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/RPFM_USAGE.md`
- `AGENTS.md`
- `.codex/project_context.md`

### 7.3 本次验证产物

以下文件记录了自动化验证过程；它们位于 `tools/`，属于本地诊断辅助文件，不是游戏 MOD 源码：

- `tools/_tmp_diagnose_pack.py`：DB/Loc 引用交叉检查。
- `tools/_tmp_pk_check2.py`：根据 schema `is_key` 检查 pack 内主键唯一性。
- `tools/_tmp_roundtrip.py`：源 TSV 与 pack 解码结果逐行 round-trip 比较。
- `tools/_tmp_rpfm_diagnostics.py`：RPFM server WebSocket diagnostics 客户端。
- `tools/_rpfm_diagnostics_output2.json`：RPFM diagnostics 输出。
- `tools/_tmp_parse_rpfm_diag2.py`：筛选本补丁 diagnostics 的脚本。
- `tools/_rpfm_diagnostics_orig.json`：本体 `Imperial Arbiter.pack` 的对照 diagnostics。

验证结果：

- pack 内部 49 个文件均能解码。
- 29 张 DB/Loc 源表与 pack 解码内容 round-trip 一致；PNG 资源也已打入 pack。
- DB 主键唯一性检查通过。
- Python 关键引用交叉检查无缺失。
- RPFM diagnostics 的 `DuplicatedCombinedKeys: cishe` 是预期覆盖提示。
- RPFM 产生的大量 `NoReferenceTableNorColumnFoundNoPak` 与当前 RPFM 5.0.6 WH3 dependencies 缓存不读取 `.pack` DB 表有关，已用 `gamedata/` 交叉验证，不应直接当作真实 invalid reference。
- **当前实际不可见的直接原因已定位**：`C:\Users\22448\AppData\Roaming\wh3mm\config.json` 的当前 WH3 preset 中，`czx_swarm_expansion.pack` 位于第 128 项，但原先 `isEnabled=false`；`Imperial Arbiter.pack` 位于第 82 项。也就是说 pack 文件虽然已经复制到游戏 `data/`，但之前的启动配置没有启用它，游戏自然不会读取新增单位。
- 经用户授权后，已将用户配置和 wh3mm 安装目录旁的 `config.json` 中该项启用；当前条目已不再带 `isEnabled=false`（wh3mm 对启用项默认省略该字段）。最终 pack 已覆盖到游戏 `data/`，与 `mod_output` SHA-256 一致。

## 8. 已知限制

1. 飞龙和蟑螂沿用古墓王亡灵属性组，可能带来亡灵 `crumbling` 或相关战斗行为。
2. 模型和动作仍是 donor 资源；本地生成的 PNG 只解决兵牌/信息图，不等于导入了 SC2 3D 模型。
3. 当前的 Mutalisk/Roach/Zergling/Ultralisk 技能映射使用独立 ability key，但底层复制 WH3 原版 `regeneration`/`frenzy` effect 链。
4. 凯瑞甘英雄和领主版已经使用独立的三个 SC2 语义技能节点，但底层主动效果仍分别复制暗精 Chillwind、Bladewind 和 Soul Stealer；尚未制作全新的 SC2 projectile/effect。
5. 凯瑞甘技能树包含暗精坐骑节点，但 `land_units.mount` 为空；坐骑节点是否应该删除或补齐坐骑链，尚未游戏验证。
6. 领主版目前只接入 Unit Viewer、自定义战斗和 agent/技能链，没有接入 Empire startpos 或独立 Zerg faction。
7. RPFM diagnostics 报告部分 minspec porthole 路径缺失；当前只补了兵牌和 infopic，没有专用 porthole。
8. 尚未启动 WH3 进行 custom battle/campaign 实机测试，因此不能把结构验证等同于游戏功能验证。

## 9. 外部通用参考

这些资料用于 RPFM/WH3 MOD 的通用工作流和 API 规则；具体 key 和资源仍以本地当前版本 DB 为准：

- RPFM 文档：<https://frodo45127.github.io/rpfm/>
- RPFM server 命令文档：<https://frodo45127.github.io/rpfm/chapter_server_2.html>
- WH3 campaign scripting 资源索引：<https://chadvandy.github.io/tw_modding_resources/WH3/campaign/campaign_index.html>
- TW Modding Troubleshooting：<https://tw-modding.com/wiki/Troubleshooting>
- 本体 Workshop 页面（按 ID）：<https://steamcommunity.com/sharedfiles/filedetails/?id=3656495027>

外部资料没有提供本补丁的模型或代码；本补丁的实际实现依据是本地原版 DB、目标 Workshop pack、本地 schema 和本地生成/验证脚本。


---

## 10. 真实 3D 模型接入（蟑螂 / 飞龙 / 凯瑞甘）

### 模型来源

用户通过图生 3D 工具生成并提供了三个静态 GLB（无骨架、无动画、单网格、4K PBR 贴图）：

- 蟑螂（Roach）：36,245 顶点 / 50,000 三角面
- 飞龙（Mutalisk）：32,591 顶点 / 50,000 三角面
- 凯瑞甘（Kerrigan）：40,930 顶点 / 49,922 三角面

### 骨架方案

静态 GLB 无法直接进 WH3。处理流程：

1. 从游戏 `anim2.pack` 解出 donor 骨架资源并解析 `.anim` 二进制（自写解析器，参考 hexagon62/warhammer3_model_serializer）：
   - 凯瑞甘 → `humanoid01b`（89 骨，复用 sorceress 动画集）
   - 蟑螂 → `scorpion01`（93 骨，复用 tomb scorpion 动画集）
   - 飞龙 → `bird01b`（86 骨，复用 carrion 动画集）
2. `tools/parse_anim_skeleton.py`：解析 .anim v8 → 骨骼名/父子/帧0世界变换 JSON。
   实测四元数按 /32767 直接解码、无符号翻转时得到正确姿态（C++ 参考实现的符号处理有差异）。
3. `tools/blender_rig.py`（Blender 4.5 headless）：从骨架 JSON 建 armature → 导入 GLB → 按骨架包围盒缩放对齐 → 顶点绑骨。
   Blender 骨热权重（bone heat）对这些网格失败，改为**最近骨段距离权重**：每顶点取最近 4 根骨骼段，按 1/d² 归一。
4. 导出带 JOINTS_0/WEIGHTS_0 的 skinned GLB。

### RMV2 写入

本地没有可用的 GLB→RMV2 CLI（AssetEditor 仅 GUI 且转换器只进不出到命令行）。
根据 AssetEditor 源码（`RigidModel/*`）自写 `tools/rmv2_convert.py`：

- 解析 donor RMV2（v8, weighted4/cinematic 顶点格式, 36B/顶点），**保留 donor 的完整材质块**
  （attachment points、transform、shader params、material id=weighted/65），只替换网格数据与贴图路径。
- 顶点编码：half4 位置（V8 extra-precision w 缩放）、byte4 骨骼索引、byte4 权重（量化到和=255）、
  byte4 法线/副法线/切线、half2 UV、byte4 顶点色。
- 坐标：glTF→RMV2 按 AssetEditor 约定翻转 X。
- 写满 4 个 LOD（同一网格复用，沿用 donor 的 lod 距离/质量字节）。

### 贴图

- 从源 GLB 解出 baseColor / normal / metallicRoughness PNG，缩到 2048×2048。
- mask=纯黑（无阵营染色）、specular=中性灰。
- 经 `tools/texconv.exe`（微软 DirectXTex 官方二进制）转 BC7_UNORM DDS，带完整 mip 链。

### 资源路径

```text
variantmeshes/variantmeshdefinitions/czx_feilong.variantmeshdefinition   (纯文本 XML)
variantmeshes/variantmeshdefinitions/czx_zhanglang.variantmeshdefinition
variantmeshes/variantmeshdefinitions/czx_kerrigan.variantmeshdefinition
variantmeshes/wh_variantmodels/bi1b/czx/czx_feilong/czx_feilong_01.{rigid_model_v2,wsmodel}
variantmeshes/wh_variantmodels/sc1/czx/czx_zhanglang/czx_zhanglang_01.{rigid_model_v2,wsmodel}
variantmeshes/wh_variantmodels/hu1b/czx/czx_kerrigan/czx_kerrigan_01.{rigid_model_v2,wsmodel}
（各自 materials/*.xml.material + tex/*.dds，BC7）
```

纯文本 wsmodel/VMD 的有效性已用其它 Workshop mod（saber 等）同格式文件佐证。

### DB 改动

- 新增 `db/variants_tables/!!czx_swarm_expansion`（v6）：`czx_feilong / czx_zhanglang / czx_kerrigan / czx_kerrigan_lord`
  → `variant_filename` 指向新 VMD；scale 沿用 donor 值（carrion 0.5 / scorpion 1.0 / sorceress 1.15）。
- `unit_variants` 四行 variant 列改为新 variant key。

### 已知限制（需游戏内验证）

- 自动权重未经人工修整，动画变形质量未知（尤其手指/翅膀边缘）。
- 飞龙模型按翼展对齐 bird01b，体长方向可能比 carrion 偏大。
- material_map 由 glTF metallicRoughness 直接转存，通道语义与 WH3 spec/gloss 布局可能不完全一致。
- 蟑螂网格相对 scorpion 骨架高度略矮（4.0 vs 6.5），受模型比例限制。
