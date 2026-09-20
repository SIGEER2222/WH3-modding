# czx_swarm_expansion — 虫群帝国扩展补丁

针对 Workshop MOD `3656495027`（Zerg / 虫群帝国，pack 名 `Imperial Arbiter.pack`，
内部前缀 `skv_chongzu`）的增量补丁。只含 DB/文本，不改模型资源。

生成方式：`python tools/gen_czx_patch.py` 重新生成全部 TSV。

详细实现、donor 模型来源、本地参考与验证信源见：`IMPLEMENTATION_REPORT.md`。

## 改动内容

1. **刺蛇（`cishe`）部队数量 +50%**：`main_units_tables` 覆盖行，
   `num_men` 8 → 12，`max_men_per_ship` 8 → 12。
2. **飞龙（`czx_feilong`）**：donor = 古墓王腐尸秃鹫
   `wh2_dlc09_tmb_mon_carrion_0`（多实体飞行单位，24 模）。
   复用 donor 的 entity / variant / 兵牌 / 武器 / spacing / 属性组。
3. **蟑螂（`czx_zhanglang`）**：donor = 古墓巨蝎
   `wh2_dlc09_tmb_mon_tomb_scorpion_0`（单实体巨兽）。
4. ~~凯瑞甘英雄/领主版~~ **已于 2026-09-19 移除**：`czx_kerrigan` /
   `czx_kerrigan_lord` 全部 DB 行、脚本、Loc 与模型资源已删除。
   刀锋女王改由「英灵召唤 (Summon Servant)」（Workshop 3552538974）提供。
5. **本地定制兵牌**：飞龙、蟑螂改用 `czx_*.png` 本地生成卡片，不再直接使用 donor unit card。
6. **SC2 语义被动**：飞龙/蟑螂挂载再生，跳虫/雷兽挂载狂热，作为 Mutalisk/Roach/Zergling/Ultralisk 的第一版 SC2 语义映射。

## 招募方式

- 飞龙、蟑螂沿用本体的 `wh_main_emp_forges_1~4`（帝国锻造厂）招募，
  并加入 `wh_main_group_empire` / `wh_main_group_empire_reikland`
  军事编组与帝国自定义战斗权限，同时挂入本体 `skv_chongzu` unit set。


## 已知取舍 / 待验证

- `[需验证]` 当前 `ui/units/icons/` 的 `czx_*.png` 是本地生成的矢量风格过渡卡，不是 SC2 官方兵牌；后续如找到更好的 SC2 素材，可直接替换同名 PNG。
- `[需验证]` 新单位描述文本 `czx_*` 已同时加入
  `unit_description_short_texts_tables` 与
  `unit_description_historical_texts_tables` 及对应 Loc。
- `[需验证]` 飞龙沿用了腐尸秃鹫的亡灵属性组
  （`wh2_dlc09_tmb_mon_carrion_0`，含 crumbling 等亡灵特性），
  若不希望虫群单位带亡灵特性，需新建属性组。
- `[需验证]` 蟑螂沿用了古墓巨蝎的亡灵属性组，同上。
- `[需资源]` 当前本地没有 SC2 `.m3`/`SC2Mod` 或可转换的 Zerg 模型源；飞龙、蟑螂仍使用 WH3 donor 模型/动作。需要提供合法 SC2 模型源后，才能继续做 M3→WH3 variantmesh/wsmodel/rigid_model_v2 转换。
- 本体另有 `!!ia_all_factions.pack` 全派系补丁；该补丁只覆盖
  gou/leishou/cishe，不会覆盖新单位——如需全派系，可再做一个
  `czx` 全派系补丁（3318 行建筑表模式）。

## 加载与依赖

- **前置 MOD**：必须启用 `Imperial Arbiter.pack`（Workshop 3656495027）。
- **加载顺序**：`czx_swarm_expansion.pack` 必须在 `Imperial Arbiter.pack` **之后**加载。
  因为 patch 引用本体的 `skv_chongzu` unit set、`chong_zu` UI 编组、
  `cishe` land_unit 与原始模型资源。
- **PFH5 MOD pack**：无额外 `dependencies_manager_v2` 记录，依赖靠 MOD 管理器排序保证。

## 诊断结果

- **结构/round-trip**：Python 解码最终 pack 全部 49 个文件，与源 TSV/资源清单一致；主键唯一性检查通过。
- **引用交叉检查**：对照 vanilla `gamedata/` 与 `Imperial Arbiter.pack`，
  `main_units`、`land_units`、`unit_variants`、`building_units_allowed`、
  `character_skill_node_sets`/`items`、`faction_agent_permitted_subtypes`、
  `unit_set_to_unit_junctions` 等关键引用无缺失。
- **RPFM server diagnostics**：
  - 通过 WebSocket 在本机 `rpfm_server` 上运行 `DiagnosticsCheck`；
  - 将 `Imperial Arbiter.pack` 作为依赖 pack 加载后检查；
  - 本次 pack 的 RPFM diagnostics 仍主要是 WH3 dependencies 缓存假阳性、预期的 `cishe` 覆盖和缺少 porthole；自定义 ability 图标的缺失提示已消除。
  - 其中 `DuplicatedCombinedKeys: cishe` 是本 patch 有意覆盖原 `main_units` 造成的，预期之内；
  - `FieldWithPathNotFound: ui/units/minspec_portholes/*` 与 `ui/units/icons/wh2_main_def_sorceress*` 属于兵牌/porthole 资源缺失提示，本体也有同类 porthole 提示，游戏仍可加载；
  - 大量 `NoReferenceTableNorColumnFoundNoPak`（`man_entity`、`building` 等列）是因为 RPFM 5.0.6 在当前 WH3 依赖缓存下只读取 `data/manifest.txt` 中的 233 个松散文件，没有从 `.pack` 解压出 DB 表做参考；`LoadAllCAPackFiles` 能加载所有 CA pack，但 diagnostics 仍不把它们作为依赖参考表。这在当前环境下是 **RPFM 依赖缓存 bug/限制导致的假阳性**，用 Python 对照 `gamedata/` 能验证这些引用在 vanilla 中存在。
- **实际加载状态**：已检查并启用 wh3mm 当前 preset 中第 128 项的 `czx_swarm_expansion.pack`；`Imperial Arbiter.pack` 在第 82 项，加载顺序正确。最终 108795-byte pack 已覆盖到游戏 `data/`，并已用 SHA-256 核对与 `mod_output` 一致。
- **已修复关键问题**：`character_skill_node_sets` 不再覆盖原版暗精女术士技能树。

## 待办（下一步可选）

- SC2 风格的真实 3D 模型/variantmesh；当前仍使用 donor 模型和动作。
- 专用 porthole / minspec porthole 图片。
- 将飞龙弹射攻击、蟑螂酸性喷吐进一步拆成独立 projectile/effect/character skill 链。
- 若需要战役领主开局，再补 Empire startpos 或独立虫群 faction；当前领主版只接入 Unit Viewer/自定义战斗。
