# 修订说明

本版根据原始 `SKILL.md` 与 5 个 reference 的冲突点、RPFM/WH3 Lua 文档、TW Modding 教程核对后整理。

## 2026-07-10 流程补充：游戏版本更新后的 schema/dependencies 复查

1. 增加 WH3/RPFM 更新后的兼容复查流程：先检查 RPFM schema、dependencies/cache 与当前游戏数据，再判断具体 MOD 是否需要更新。
2. 记录本地 RPFM 配置缓存位置：`%APPDATA%/FrodoWazEre/rpfm/config/schemas/` 与 `dependencies/`，只用于检测时间和状态，不手工编辑缓存 `[已查本地配置 / 需随版本复查]`。
3. 明确自动化脚本适合做检测和提醒：比较工具版本、缓存时间、游戏 `data/*.pack`、`gamedata/` 导出和 MOD TSV 表清单；真正刷新 schema/dependencies 后仍需 RPFM diagnostics 与游戏内最小回归。
4. 补充兼容判断标准：新增 schema/version、type mismatch、invalid reference、missing file/loc、banned table、datacore、Lua 日志或 UI/资源回归问题时才需要做兼容补丁；表结构变化时应重导出模板并迁移数据。
5. 补充 `gamedata/` 定义：它是从游戏 pack 导出的本地原版数据快照，不会因 RPFM 刷新 dependencies/cache 自动更新；游戏更新后如继续依赖本地查证，应重导出相关范围或标记为旧版本快照。

## 2026-07-10 实测反馈：切换弹药按钮需要 enable 效果生效

1. 根据震旦巨炮可切换爆破弹实测，补充规则：只新增 `unit_missile_weapon_junctions_tables` 与 `missile_weapons_to_projectiles_tables` 可能不会在战役战斗 UI 显示切换弹药按钮。
2. 记录亚雷鸣炮、震旦巨炮霰弹同类链路：如果 donor 通过 `effect_bonus_value_missile_weapon_junctions_tables` 的 `bonus_value_id=enable` 绑定 effect，则新切换弹药也应建立自己的 enable effect。
3. 记录自用战役 MOD 的直接自带方案：可用隐藏 effect bundle 承载该 enable effect，再通过 `script/campaign/mod/*.lua` first tick 永久施加给相关 faction；自定义战斗表现仍需单独实测 `[实测/需随版本复查]`。

## 2026-07-10 实测反馈：火炮速度/射界还需同步 articulated entity

1. 根据震旦巨炮速度和射界未随 engine/entity 修改生效的反馈，补充火炮 articulated 链路：`land_units_tables.articulated_record` 可能继续指向原版 `land_unit_articulated_vehicles_tables` 与原版 articulated `battle_entities_tables` 行。
2. 记录修正方式：派生新的 `land_unit_articulated_vehicles_tables` key、复制对应 `articulation_nodes_in_land_articulated_vehicles_tables` 行，并让新 record 指向专用 articulated entity。
3. 补充 draught mount 限速检查：若火炮 `land_units_tables.mount` 仍指向原版牵引 mount，也应复制 `mounts_tables` 与对应 mount entity，并让 land unit 指向新 mount。
4. 补充直控/特殊瞄准检查项：派生新 `battlefield_engines_tables.key` 后，可同步复制 `first_person_engines_tables` 同原火炮 key 的行到新 engine key，按设计调整 `half_horizontal_fire_arc` `[实测/需随版本复查]`。

## 2026-07-09 流程补充：Workshop release 可上传清单

1. 根据阿瓦隆龙骑士威力加强补丁的发布整理，补充 Workshop release 清单：发布目录包含 `.pack`、同名 `.png`、`description.bbcode.txt`、可选 `release_notes.bbcode.txt`、`UPLOAD_FILES.txt` 与 zip。
2. 记录 thumbnail 复用规则：优先复制 MOD 源目录中已确认的 `thumbnail.png` 或用户指定图片，不擅自整理 `assets/`。
3. 记录发布说明要求：submod/patch 必须写清依赖主 MOD、加载顺序、改动内容、语言/本地化关系和兼容性；生成后核对 pack、thumbnail 哈希与 zip 条目。
4. 明确版本管理边界：`workshop_release/` 与 `mod_output/` 默认仍作为生成/发布产物忽略，除非用户明确要求归档。

## 2026-07-09 流程补充：覆盖式 DB 补丁 diagnostics

1. 根据阿瓦隆龙骑士威力加强补丁的 RPFM 打包校验，补充覆盖式 DB 补丁判断：补丁 pack 故意包含主 MOD 同 key 最小覆盖行时，`DuplicatedCombinedKeys` 可作为预期提示处理。
2. 限定适用条件：重复 key 必须是计划覆盖目标，诊断列为主键列，且没有 invalid reference、missing file、type mismatch、schema/version 或 TSV 导入错误。
3. 要求补丁文档说明依赖主 MOD，并记录按项目约定放在主 MOD 前面加载以覆盖同 key 行 `[实测/需随版本复查]`。

## 2026-07-09 项目结构重组：mod_files、输出目录与 Workshop BBCode

1. 根据当前工作区结构调整，将具体 MOD 源文件目录从旧示例 `mod/<MOD名>/` 统一为 `mod_files/<MOD名>/`，图片素材归入 `assets/image/`，打包输出归入 `mod_output/`，Workshop 发布材料归入 `workshop_release/`。
2. 在 `SKILL.md`、`references/project_structure.md` 与项目文档中补充打包前选择规则：先询问用户手动用 RPFM 打包，还是由 Codex 自动打包；默认先准备源文件，不直接自动打包。
3. 在 RPFM/发布流程中补充 Steam Workshop 文本约定：最终发布描述使用 Steam BBCode，Markdown 只作为中间草稿。
4. 精简 `SKILL.md` 入口：保留入口规则、reference 路由、默认流程和高风险禁区，详细流程继续放在对应 references。

## 2026-07-09 发布流程补充：英文主包与 Loc-only 中文补丁

1. 根据将阿瓦隆龙骑士发布到 Steam 创意工坊的整理需求，补充多语言发布结构：默认语言做完整主 MOD，中文等其他语言做只含 `text/db` Loc 的轻量补丁，避免同一 pack 内中英同 key 文本互相覆盖。
2. 记录加载顺序：Total War 启动器/Mod 管理器中，汉化补丁应排在主 MOD 前面，以覆盖后面主 MOD 的同 key Loc 文本；CA 社区资料显示新版 Mod Manager 支持手动排序，但具体覆盖行为仍需按游戏内实测复查。
3. 记录开局事件体验修正：首回合 dilemma 若在 First Tick 里直接 `cm:callback`，延迟可能在加载/开场镜头阶段被消耗；实测反馈为 10 秒仍像加载后立刻弹出。修正为 First Tick 注册 `PanelOpenedCampaign`，等战役 UI 面板打开后再倒计时触发 `[实测/需随版本复查]`。

## 2026-07-09 流程补充：Mod 管理器 thumbnail

1. 根据为阿瓦隆龙骑士 MOD 添加管理器缩略图的需求，补充 thumbnail 与单位卡/porthole 的区别：启动器缩略图通常使用与 `.pack` 同名、放在 pack 同目录的 `.png`，而不是 DB 中的 `unit_card` 或 `main_units` porthole 链路。
2. 记录资源维护方式：可在 MOD 源目录保留 `thumbnail.png` 作为可维护副本，同时在 `mod/` 目录输出 `pack同名.png` 供管理器读取；该图片应保持小于 1MB `[已查外部资料 / 需随版本复查]`。

## 2026-07-09 修复反馈：Pack 写回后旧功能回归核对

1. 根据“只保留了阿瓦隆龙骑士，精英部队与战役减费用文本丢失”的反馈，补充 RPFM 写回规则：当工作目录是 TSV/资源源副本、`.pack` 是导出结果时，修复或重打包后必须核对旧功能 marker，而不是只检查本轮新增内容。
2. 在 `rpfm_and_verification_workflow.md` 增加 Pack 写回与回归核对流程：必要时从工作目录全量重导入 `db/`、`text/db/`、`script/`、`ui/`、`composite_scene/` 等游戏读取路径，避免 pack 内旧 DB/Loc/资源文件缺失或未同步。
3. 记录中文 Loc 验证细节：`decode_packed_file` 的 JSON 转义输出不适合单独判断中文文本是否存在；需要确认中文 Loc 时应反导出 TSV 后检查，并在检查后删除临时导出文件 `[实测/需随版本复查]`。

## 2026-07-09 流程补充：首回合 Dilemma 替代 startpos 开局奖励

1. 根据放弃修改主菜单初始军队兵牌、改为艾拉瑞丽首回合事件二选一的需求，补充低冲突模式：若前端初始兵牌可保持原版，进战役后的奖励/单位授予优先用 Lua 触发自定义 dilemma，而不是继续追 startpos。
2. 在 `lua_api.md` 记录最小链路：`dilemmas_tables`、`cdir_events_dilemma_choice_details_tables`、`cdir_events_dilemma_option_junctions_tables` + `cm:create_dilemma_builder` / `cm:create_payload` / `cm:launch_custom_dilemma_from_builder`。
3. 记录防重复规则：读档仍需注册 `DilemmaChoiceMadeEvent` 监听器，首回合触发与奖励结算分别用 saved value 记录，奖励若要精确作用到角色军队则在选择回调里执行 `[已查原版脚本 / 实测需随版本复查]`。

## 2026-07-09 RPFM 反馈：Loc line jump/tabulation warning

1. 根据 `text/db/*.loc` 报 `Invalid line jump/tabulation detected in loc entry` 的反馈，补充 Loc 排查规则：先检查文本字段是否含真实换行或真实 Tab。
2. 对不强制需要换行的普通说明文本，优先改为单行，避免 RPFM 在导入/保存 Loc 后继续给出 line jump/tabulation warning `[实测/需随版本复查]`。

## 2026-07-09 实测反馈修正：初始军队卡

1. 撤回“战役内传奇领主/trait 详情需要覆盖 `effect_bundles_localised_description_<bundle_key>`”的泛化记录：用户复查后确认派系效果不需要显示在传奇领主详情界面，不能把该界面误判写成通用规则。
2. 根据主菜单路径“战役 -> 新建 -> 超凡帝国 -> 高等精灵 -> 艾拉瑞丽 -> 领主详情 -> 初始军队”的实测反馈，保留 `frontend_faction_top_units_tables` 说明：该表不控制这个具体初始军队卡位。
3. 记录 UI 查证线索：`campaign_select_new.twui.xml` 的 `start_units`/`card_holder` 使用 `CcoFrontendFactionLeader.UnitList`、`CcoCampaignStartInfo` 与 `CcoUnitDetails` 动态填充；Lua first tick 调整开局军队不会提前改变主菜单显示，真正改卡位可能涉及 startpos/前端 CCO 高冲突资源 `[实测/需随版本复查]`。
4. 补充 startpos 排查规则：主菜单初始军队兵牌若必须同步显示，通常要改并重建 `campaigns/<campaign>/startpos.esf`；本地 RPFM Server 5.0 探测显示 build startpos 需要 pack 位于游戏 `data/` 且能识别 campaign id，但若 post 阶段在最小探测包也失败，应转向检查 RPFM/BOB/Assembly Kit 配置，而不是采信临时生成物 `[实测/需随版本复查]`。

## 2026-07-09 实测反馈：Lua 派系效果不进前端说明

1. 根据“脚本应用维护费 buff 已生效，但主菜单与战役派系效果文本不显示”的反馈，补充：需要前端/派系效果文本时，应把可见 effect 放进传奇领主/派系实际使用的 DB bundle，例如 `faction_starting_general_effects_tables` 指向的 `lord_trait_*`，不能只依赖 `cm:apply_effect_bundle`。
2. 记录防叠加规则：同一实际数值效果不要同时由 Lua 独立 bundle 与起始 trait bundle 应用，否则可能叠加成两倍效果。
3. 在 `project_structure.md` 补充前端派系选择显示查证路径：`frontend_faction_leaders_tables`、`frontend_factions_tables`、`frontend_faction_top_units_tables` 与 `faction_starting_general_effects_tables`；其中 `frontend_faction_top_units_tables` 需主菜单实测确认具体面板读取行为 `[实测/需随版本复查]`。

## 2026-07-09 流程补充：单位集合维护费与开局军队脚本微调

1. 在 `common_effect_keys.md` 补充限定具体单位维护费的 effect 链路：不要直接复用绑定 `all_units` 的 `wh_main_effect_force_all_campaign_upkeep`；应新建专用 effect，并通过 `effect_bonus_value_ids_unit_sets_tables` 的 `upkeep_mod` 绑定自建 unit set。
2. 在 `lua_api.md` 修正永久应用 effect bundle 的参数说明：本地官方脚本文档说明 `cm:apply_effect_bundle(..., turns)` 可用 `-1` 表示永久应用。
3. 补充开局军队小改流程：用 `cm:is_new_game()` + saved value + `cm:remove_unit_from_character` / `cm:grant_unit_to_character` 在 first tick 调整，避免覆盖 startpos `[已查本地官方脚本文档 / 需游戏内复查]`。

## 2026-07-09 战役反馈：DB RoR 三件套存在但精英招募仍不显示

1. 根据高等精灵自建 RoR 在部队浏览器可见但战役精英招募界面不显示的反馈，补充 Lua 注入方案：保留 `mercenary_unit_groups_tables`、`mercenary_pool_to_groups_junctions_tables` 与等级限制表，同时在 `script/campaign/mod/` 用 `cm:add_unit_to_faction_mercenary_pool` 把自建 RoR 加入人类派系的 `renown` pool。
2. 记录本地官方脚本文档差异：`add_unit_to_faction_mercenary_pool` 可把 unit 加入 faction mercenary pool；`add_units_to_faction_mercenary_pool` 要求该 unit 类型已在 pool 中存在，不适合作为自建 RoR 初始化入口 `[已查本地官方脚本文档 / 需游戏内复查]`。

## 2026-07-09 战役反馈：RoR 部队浏览器可见但精英招募不出现

1. 在 `unit_creation_workflow.md` 补充 RoR 可见性排查：部队浏览器可见但战役精英招募界面找不到时，优先检查 `campaign_mercenary_unit_character_level_restrictions_tables.character_level` 是否高于当前领主等级；测试或开局可见设计可设为 `0`。
2. 补充 exclusive faction 白名单提醒：若原 RoR 池已有新增可玩派系，例如高精 `wh3_dlc27_hef_aislinn`，自建 RoR 也应同步补齐 `units_to_exclusive_faction_permissions_tables`，否则该派系可能看不到单位 `[实测/需随版本复查]`。

## 2026-07-09 RPFM 反馈：battle personality junction 空字段

1. 根据 `land_units_to_battle_personalities_junctions_tables` 无法被 RPFM 正常读取的反馈，补充 autonomous rider junction 规则：不能只填 `battle_personality` 与 `land_unit`，还要从 donor 行复制 `attach`、`riders_attachment_point`、`engine_articulation_index` 与 `jettison_rider`。
2. 记录当前修正方式：多实体骑龙骑手行使用 `autonomous_rider`、`ap_riderpos_0`、`-1`、`true`，与原版精灵公主骑耀星龙和普通阿瓦隆龙骑兵挂点链路一致 `[实测/需随版本复查]`。

## 2026-07-09 流程补充：精英部队 / RoR 招募池

1. 在 `unit_creation_workflow.md` 补充“精英部队 / RoR 招募池”小节：派生限 1 队精英单位时，除 `main_units_tables.campaign_cap=1` 外，还应补 `is_renown`、`restrict_xp_gain_in_campaign`、RoR mercenary pool、角色等级限制、unit set 与权限链路。
2. 记录高等精灵 RoR 示例的常见入口：`mercenary_unit_groups_tables` + `mercenary_pool_to_groups_junctions_tables`，池为 `wh2_main_hef_units_of_renown_pool`，子文化为 `wh2_main_sc_hef_high_elves` `[已查原版 DB / 需随版本复查]`。
3. 明确精英版默认不应新增 `building_units_allowed_tables` 行，否则会从建筑和精英招募界面同时出现；外观、rider 武器、弹药或技能变动仍应使用独立 key。

## 2026-07-09 诊断反馈：projectiles_tables 数值列格式

1. 根据 `projectiles_tables` RPFM 读取异常反馈，补充 projectile 射程字段格式检查：调射程时不仅要同步 `effective_range`、`calibration_distance`、`expiry_range`，还要保持各列原版数值格式。
2. 记录当前原版核对：`effective_range` 与 `expiry_range` 使用整数格式，`calibration_distance` 使用小数格式；若把整数列写成 `333.3333` 这类小数，RPFM 可能无法正常识别/导入该行 `[已查原版 DB / 需随版本复查]`。

## 2026-07-09 实测反馈：Loc 文本被写成问号

1. 在 `unit_creation_workflow.md` 的 Loc 规则中补充：写入中文或其他非 ASCII 文本后必须回读文件，确认文本没有被替换为字面量 `?`、`????` 或乱码。
2. 记录排查顺序：如果游戏内技能名/简介显示问号，但 Loc key 已存在且 RPFM 不报 missing loc，应优先检查 MOD Loc TSV 对应 key 的文本内容是否已经损坏，而不是只继续补同类 key `[实测/需随版本复查]`。

## 2026-07-09 流程补充：克隆单位主动技能并修改使用次数

1. 在 `unit_creation_workflow.md` 补充单位能力克隆流程：修改主动技能次数时，应新建 `unit_abilities_tables` 与 `unit_special_abilities_tables` key，并同步复制实际存在的 UI 效果、禁用条件和 Loc。
2. 记录 `icon_name` 可继续指向 donor 原图标 key，避免未制作新图标时出现缺失资源。
3. 补充 `effect_bonus_value_unit_ability_junctions_tables` 的风险：不要机械复制 `uses_mod` 等加成链路；若目标是固定使用次数，复制后可能被科技/效果重新改变次数 `[已查原版 DB / 需游戏内复查]`。

## 2026-07-08 指南重组：新增兵种流程沉淀与 skill 瘦身

1. 将完整新增/派生兵种经验整理到 `references/unit_creation_workflow.md`，覆盖单位基础链、多源拼装、骑乘/多实体、坐骑缩放、battle personality、360 度骑射、武器/projectile、unit card、porthole、Loc 与 RPFM diagnostics。
2. 精简 `SKILL.md`：只保留触发后必须立即知道的总原则、reference 路由、高风险规则和新增兵种快速提醒。
3. 精简 `references/tsv_format.md`：聚焦 DB/Loc TSV 格式、列数、版本、Loc metadata 和导入检查；新增兵种长流程改由专门 reference 承载。
4. 更新 `MANIFEST.md`、项目上下文和维护规则，将 `unit_creation_workflow.md` 纳入后续指南维护目标。

## 2026-07-08 流程补充：单位兵牌图片与 unit_card

1. 补充单位兵牌导入流程：`unit_variants_tables.unit_card` 指向 `ui/units/icons/<unit_card>.png`，字段值不带 `.png` 扩展名。
2. 记录当前原版核对：阿瓦隆姐妹和耀星龙兵牌均为 `60x130` PNG；新单位独立兵牌应按该尺寸生成并放入 MOD 的 `ui/units/icons/`。
3. 明确从 donor 派生新单位时，若已制作成品兵牌，应同步改 `unit_card`，避免继续显示 donor 兵牌 `[已查原版文件/需随版本复查]`。

## 2026-07-08 实测反馈：动态 porthole 镜头锁头

1. 记录高画质动态 porthole 的新问题形态：专用 `.csc` 已排除坐骑后，若头像表现为头部相对镜头几乎不动、身体在晃，优先怀疑模板内置 camera/target 轨道绑定了头部或焦点。
2. 补充模板选择建议：带 `camera_focal_*`、`position`、`orientation` 等完整镜头轨道的 `.csc` 可能覆盖 `main_units_tables.porthole_camera` 的自然固定取景；可改用带固定 `[Camera]` 的原版 porthole 模板。
3. 补充安全处理方式并记录用户确认：若固定镜头模板带有额外可见发丝/道具节点，可把该节点模型路径替换为原版 `dummy_mesh` 等空资源，而不是强删二进制节点；本项目已确认该方案解决 porthole camera 锁头表现 `[实测/需随版本复查]`。

## 2026-07-08 实测反馈：动态 porthole 专用 composite scene

1. 补充动态 porthole 修正流程：当多实体骑乘单位的高画质头像仍捕捉到坐骑时，应通过 `main_units_tables.porthole_composite_scene` 指向专用 `.csc`，让场景只加载目标骑手/步兵模型与动画。
2. 记录 `.csc` 模板选择原则：优先使用原版单实体 humanoid 场景，避免带坐骑、多人或额外发丝/道具节点的模板，否则可能残留不想显示的模型。
3. 记录二进制替换注意事项：替换 `.csc` 内嵌资源路径时必须同步字符串长度字段；未修改的原版动画、模型和材质可直接引用，不应重复打包为同名覆盖资源 `[实测/需随版本复查]`。

## 2026-07-08 实测反馈：动态 porthole 排除坐骑失败

1. 根据用户游戏内实测，修正高画质动态 porthole 规则：对多实体骑乘单位的自建 mount entity 设置 `battle_entities_tables.porthole_composite_scene=false`，并保留 donor 的 `main_units_tables.porthole_camera`，仍不能排除坐骑模型。
2. 明确低画质静态 porthole 可通过复制 `ui/units/minspec_portholes/<donor>.png` 与 mask 并改成新单位 key 解决；高画质实时 porthole 则会按实际单位/实体捕捉。
3. 若高画质动态头像必须只显示 donor 步兵/骑手而不是实际坐骑组合，应制作或编辑专用 `main_units_tables.porthole_composite_scene` 指向的 `.csc`，在场景中只摆放目标模型/动画 `[实测/需随版本复查]`。

## 2026-07-08 实测反馈：低画质 porthole 与实体排除

1. 修正新增单位 porthole 规则：低画质静态头像不是只靠 `main_units_tables.porthole_camera`，还需要 `ui/units/minspec_portholes/<main_units.unit>.png` 及 mask 同名资源；缺失时可能显示上一个选择单位的残留头像。
2. 补充借用 donor 静态头像流程：复制 donor 的 minspec porthole 图片和 mask 到 MOD 中，并改为新单位 key 文件名。
3. 补充高画质实时头像试验路径：如果只想显示骑手而排除坐骑，可测试把自建 mount/附属 entity 的 `battle_entities_tables.porthole_composite_scene` 设为字面值 `false`，并保留 donor 的 `main_units_tables.porthole_camera`；若仍无效，则需要制作或编辑专用 `.csc` `[实测/需随版本复查]`。

## 2026-07-08 实测反馈：新单位 porthole 头像镜头

1. 补充新增/拼装单位的 porthole 排查：战斗界面左下角头像不仅依赖单位卡和 variant，还要检查 `main_units_tables.porthole_camera` 与 `porthole_composite_scene`。
2. 记录多实体骑乘单位问题形态：继承步兵 porthole camera 可能导致高画质实时头像中骑手和坐骑重叠，低画质静态头像也可能回退异常。
3. 推荐为新单位新增 `unit_porthole_camera_settings_tables` 专用 key，并让 `main_units_tables.porthole_camera` 指向它；`porthole_composite_scene` 可参考原版，但 `.csc` 通常是二进制且嵌入具体模型/动画，不应随意套用到不同兵种 `[实测/需随版本复查]`。

## 2026-07-08 流程补充：projectile 连发与弹速字段

1. 补充 projectile 连发/点射字段：`burst_size` 与 `burst_shot_delay` 控制连发节奏，和 `projectile_number`、`shots_per_volley`、单位总弹药量属于不同层级。
2. 调整三连发、短点射或弹速时，应在专用 projectile 上核对 `burst_size`、`burst_shot_delay`、`muzzle_velocity` 与 `base_reload_time`。
3. 标注动画表现仍需游戏内复查，尤其是普通弓箭/骑射动画是否真的按 burst 连续发射 `[需验证]`。

## 2026-07-08 实测反馈：弓箭多弹体与 shots per volley

1. 记录用户实测方向：普通弓箭/骑射动画可能不像龙弩等多发武器那样明显表现 `projectiles_tables.shots_per_volley` 的多弹体散布。
2. 补充试验路径：若目标是让一次弓箭射击生成多支可散布弹体，可测试 `shots_per_volley=1` 并提高 `projectile_number`，同时进战斗复查动画、弹体数量和命中表现。
3. 标注为 `[实测/需随版本复查]`，不写成所有武器通用的绝对规则。

## 2026-07-08 实测反馈：projectile 装填显示下限排查

1. 补充 `projectiles_tables.base_reload_time` 的排查提示：普通单位主远程武器链低于 4 秒时，游戏内显示/实际节奏可能受 UI、战斗引擎或射击动画周期限制。
2. 记录一次原版 DB 核对经验：按 `land_units.primary_missile_weapon -> missile_weapons.default_projectile -> projectiles.base_reload_time` 检查，未发现普通 land unit 主武器链使用低于 `4.0000` 的 projectile 样本；该结论标注为 `[实测/需随版本复查]`。
3. 明确 `land_units_tables.reload` 更接近装填技能/修正值，不等同于基础装填秒数。

## 2026-07-08 流程补充：projectile 散布与碰撞半径

1. 补充 projectile 群体覆盖调整：在专用 projectile 上小幅调整 `spread` 与 `collision_radius`，可提高对密集目标的覆盖，但需要游戏内复查命中表现。
2. 明确该类调整应作用于新建 projectile key，不直接修改 donor 原版弹体；避免影响所有使用同一弹体的原版单位。

## 2026-07-08 实测反馈：专用 unit spacing 微调

1. 补充列阵微调流程：当原版 spacing 大方向正确但模型间距略小/略大时，应复制 `unit_spacings_tables` 行为新 key，只改必要间距字段，再让目标单位 `land_units_tables.spacing` 指向新 key。
2. 明确不要直接修改原版共用 spacing key；否则会影响所有使用该 spacing 的单位。

## 2026-07-08 实测反馈：多模型飞行骑乘单位列阵 spacing

1. 根据 20 模型飞行骑乘单位列阵反馈，补充：`rank_depth` 不是唯一控制列阵排数的字段，`land_units_tables.spacing` 的模型间距过大也会限制可拖拽展开宽度。
2. 记录对照方法：不要把 4 模型超大型飞行单位的 spacing 直接套给 20+ 模型单位；应优先参考同模型数级别的飞马、龙马、鹰骑士等飞行骑兵/怪兽单位。
3. 示例判断：`wh2_dlc15_super_monstrous_cavalry_flying` 水平间距较大，适合少模型狮鹫骑士；20 模型单位若需要能展开为 2-3 排，可参考 `wh_main_cavalry_pegasus_knights` 等同规模飞行骑兵 spacing，并需游戏内复查 `[实测/需随版本复查]`。

## 2026-07-07 流程补充：projectile 每轮箭数与建筑/友军伤害

1. 补充远程弹药与弹体行为区分：弹药量通常改 `land_units_tables.primary_ammo` / `secondary_ammo`，每轮射击箭数优先查 `projectiles_tables.shots_per_volley`，不要误改 `projectile_number`。
2. 补充建筑与友军伤害字段：`projectiles_tables.can_damage_buildings`、`building_damage_multiplier`、`can_damage_allies` 等行为字段应在新建专用 projectile 上修改，避免影响原版 donor 单位。

## 2026-07-07 实测/流程补充：新单位专用武器链与弹药

1. 补充新单位平衡流程：调整近战武器威力时应复制 `melee_weapons_tables` 为新 key，并让新单位指向它；不要直接改原版共用近战武器。
2. 补充远程武器链排查：有 autonomous rider、`battle_entity_stats_tables` 或 `unit_missile_weapon_junctions_tables` 的单位，不能只改 `land_units_tables.primary_missile_weapon`，这些引用也应同步指向新 missile weapon。
3. 明确“弹药量”通常对应 `land_units_tables.primary_ammo` / `secondary_ammo`；不要把弹药量调整误写成 projectile 的 `projectile_number`，除非目标是改变每次发射弹体数 `[需验证]`。

## 2026-07-07 实测反馈：骑乘射手 mount entity 射界

1. 根据用户游戏内实测，补充骑乘射手 360 度射界排查：只把 rider entity 改成 `fire_arc_close=360.0000` 可能不足，若 mount entity 仍保留原怪兽/坐骑的 `120.0000`，游戏内单位射界显示仍可能是 120。
2. 对有 `land_units_tables.mount` 的新建多实体骑乘射手，应沿 `land_units.mount -> mounts_tables.entity -> battle_entities.fire_arc_close` 检查自建专用 mount entity；需要 360 度射界时，将该专用 mount entity 同步为 `360.0000`。
3. 该规则标注为用户实测经验：只用于新建专用 mount entity，不直接改原版共用坐骑 entity `[实测/需随版本复查]`。

## 2026-07-07 实测反馈：骑乘射手 360 度射击排查

1. 根据永恒女王侍女骑乘形态与精灵公主骑飞行坐骑的原版 DB 对比，补充：`fire_arc_close=360.0000` 是必要线索但不应单独视为充分条件。
2. 若新建多实体 autonomous rider 单位游戏内仍不能 360 度射击，应继续比对 rider/infantry entity 的 `turn_speed`、tracking ratio、`locomotion_constants`、`projectile_penetration_resistance`、`can_dismember` 等字段，以及 `battle_personalities_tables.autonomous_rider_hero` 是否和原版同类链路一致。
3. 记录武器/弹道对比判断：永恒女王侍女、阿瓦隆姐妹、精灵公主弓箭链没有独立射界字段；若 projectile/weapon 结构同类，优先修 entity/personality 链路，不要无理由扩大为武器整链复制 `[实测/需随版本复查]`。

## 2026-07-07 实测反馈：多实体骑乘单位的 360 entity、激励与减员

1. 修正多实体骑乘单位的 360 射击规则：新建 360 rider entity 后，不只要在 `battle_personalities_tables.battle_entity` 引用，也要复查 `land_units_tables.man_entity` 是否仍指向旧实体，必要时同步改为新 entity。
2. 补充从领主骑乘单位复制属性组时应剔除 `encourages` 等领主/英雄专用激励光环属性，除非设计明确需要。
3. 根据用户实测反馈，记录 20 模型骑乘单位需要复查 rider/mount `battle_entities_tables.can_dismember`；需要正常减员时可为自建多实体 rider/mount entity 启用 `can_dismember=true`，并标注仍需游戏内复查。

## 2026-07-07 实测反馈：骑龙多实体单位的类型、动画与 entity 链

1. 修正多源拼装骑乘单位规则：骑乘怪兽/骑龙领主的多实体版本不要默认按 cavalry 处理，应优先复制目标骑乘领主/怪兽的 `land_units_tables.category`、`class`、`man_entity`、`man_animation`、`ai_usage_group` 等同链字段。
2. 补充 battle entity 规则：360 度骑射通常由 rider/infantry `battle_entities_tables.fire_arc_close=360.0000` 实现，需要新建 360 rider entity 并在 `battle_personalities_tables.battle_entity` 中引用。
3. 补充缩放坐骑规则：只改 `variants_tables.mount_scale` 会改变视觉大小，但不会改变碰撞/受击体积；需要独立小型坐骑时还应复制 mount entity，并调整半径、质量、高度、硬直和 locomotion 等字段，仍需游戏内复查。

## 2026-07-07 RPFM 导入反馈：Loc TSV 元数据行

1. 修正 Loc TSV 生成规则：不能只写 `key/text/tooltip` 三列表数据；RPFM 导入 Loc TSV 时应包含 `#Loc;1;text/db/<file>.loc` 元数据行。
2. 明确 Loc TSV 的元数据格式不同于普通 DB TSV，路径通常以 `text/db/` 开头且内部文件名使用 `.loc`，不是本地导入文件的 `.loc.tsv`。
3. 建议新增单位 Loc 同时提供 `land_units_onscreen_name_<unit>` 与空的 `land_units_concealed_name_<unit>`，保持与原版/已验证 MOD 示例一致。

## 2026-07-07 多源拼装骑乘/多实体新单位流程

1. 补充从多个原版单位组合新单位时的 DB/TSV 检查流程，例如兵牌/模型、坐骑/动画、武器、招募建筑和科技分类分别来自不同来源单位。
2. 明确多实体骑乘单位需要同步确认 `main_units_tables.num_men`、船只人数、`land_units_tables.num_mounts`、编组 spacing/rank 与飞行 AI 分类。
3. 补充 autonomous rider 链路：如目标骑乘动画依赖 `land_units_to_battle_personalities_junctions_tables` 与 `battle_personalities_tables`，应新建 battle personality，而不是只改 `land_units_tables.man_animation`。
4. 记录远程 360 度射击可能依赖 360 fire arc 的 rider/infantry battle entity 与 `mounted_fire_move` 等属性组合，生成后必须进战斗复查 `[需验证]`。
5. 明确多来源科技继承优先通过把新单位加入来源单位实际使用的 unit set；复制前需避开单实体、领主或剧情专用 unit set。

## 2026-07-07 实测反馈：坐骑缩放与骑手体积

1. 根据用户实测，记录在骑乘坐骑 variant 中同步降低 `variants_tables.scale` 会导致领主/英雄骑手模型也被缩小。
2. 修正坐骑局部缩放规则：若目标是只改变坐骑体积，优先仅调整新坐骑 variant 的 `mount_scale`，并保留原版 `scale`；修改后仍需游戏内复查骑手位置、动画、选择圈和碰撞表现。

## 2026-07-10 projectile 弹道与弹速反馈

1. 根据巨炮 projectile 实测反馈，补充 `trajectory_sight` 调整规则：`fixed` 弹道可强制高抛但 `muzzle_velocity`/`max_elevation` 可能不按设定参与，`dual_low_fixed` 在无遮挡目标上可能仍走低平分支。
2. 明确需要“曲射且弹速生效”时，应优先测试非 fixed donor，例如 `low` 配合较高 `max_elevation`、合适 `muzzle_velocity`/`gravity`，并以游戏内炮弹轨迹为准 `[实测/需随版本复查]`。
3. 根据近距离目标实测，记录 `high` 会强制或倾向最大角/高角分支，可能让高速重炮近距离几乎垂直向上发射；这类需求优先测试 `low` 分支。
4. 补充按指定最小距离和角度反推 gravity 与最大射程的公式：`gravity = velocity^2 * sin(2 * angle) / range`，最大射程约为 `floor(velocity^2 / gravity)`；高速炮若要求近距离仍有较大低角，射程会自然大幅缩短。
5. 补充 `low` / `high` 可理解为抛物线两解中的低角解/高角解；若目标是尽量保留远射程，可测试 `high` 分支并按 `velocity^2 / target_range` 反推近似重力，但近距离会自然变得很陡 `[实测/需随版本复查]`。
6. 补充按指定高角反推重力后，用最高仰角估算最近可解距离、用 45 度估算理论最远射程的流程；记录 900 弹速、100m 高角约 80 度的示例：`gravity≈2770.36`、88 度最近约 20.39m、45 度最远约 292.38m `[实测/需随版本复查]`。
7. 根据亚雷鸣炮爆破弹链路补充可切换弹药流程：`unit_missile_weapon_junctions_tables` 追加可切换 missile weapon，`missile_weapons_to_projectiles_tables` 指向替换 projectile；若绑定 `effect_bonus_value_missile_weapon_junctions_tables.enable` 则由科技/效果解锁，未绑定时需游戏内复查是否默认可切换。

## 2026-07-07 RPFM 诊断反馈：custom battle set piece character

1. 根据 RPFM diagnostics，记录 `units_custom_battle_permissions_tables.set_piece_character` 引用的是 `battle_set_piece_armies_characters_tables.character_name`，不是普通 `main_units_tables.unit`。
2. 修正新增领主/单位复制自定义战斗权限的规则：不要机械替换 `set_piece_character` 为新单位 key；除非同步新增 set piece character 行，否则沿用原版有效引用。

## 2026-07-07 领主 subtype 与坐骑局部修改流程

1. 补充“新增原版领主/英雄 subtype，并只修改新角色某个坐骑模型/大小”的 DB 链路流程。
2. 明确不要直接修改被多个角色或兵种共用的原版 `mounts_tables`、`variants_tables`、`battle_entities_tables` key；应复制新 bodyguard、mount、variant、mount skill 与 ancillary 链路。
3. 补充 `variants_tables.scale` / `mount_scale` 与 `campaign_mounts_tables` 在坐骑视觉缩放中的使用注意，并标注需游戏内复查骑手位置、动画、选择圈和碰撞表现。

## 2026-07-07 新单位远程武器派生规则

1. 补充新增单位借用并强化其他单位远程武器/弹药时的处理流程：复制 `missile_weapons_tables` 与对应 `projectiles_tables`，用新 key 形成独立武器链。
2. 明确不要直接修改 donor 单位的原武器或 projectile；新单位应通过 `land_units_tables.primary_missile_weapon` 指向自己的新 missile weapon。
3. 补充射程修改时需检查 `effective_range`、`calibration_distance`、`expiry_range` 等 projectile 字段，并只复制 donor 实际使用到的 projectile 关联表。

## 2026-07-07 RPFM 诊断反馈：banned table

1. 根据 RPFM diagnostics，记录新增单位变体时 `allied_recruitment_core_units_tables` 与 `main_unit_ownership_content_pack_junctions_tables` 会被标记为 banned table。
2. 更新新增单位变体流程：默认不要复制这些 banned table；如 diagnostics 报 banned table，优先删除对应 MOD 表文件，而不是改列或改 key。

## 2026-07-07 RPFM 诊断反馈：单位描述与 Loc 重复

1. 根据 RPFM diagnostics，补充 `land_units_tables.historical_description_text` 与 `short_description_text` 必须引用对应 description DB 表中已存在 key 的规则。
2. 明确新增单位如果沿用原描述，应保留原 description key；如果创建新描述，必须同时新增 description DB 表行和 Loc 文本，不能只新增 Loc。
3. 明确同一个 Pack 中 Loc key 必须唯一，不要同时放中英两套同 key Loc；需要双语言时分语言 Pack 或打包前只保留目标语言 Loc。

## 2026-07-07 新增单位变体流程

1. 增加从原版单位派生新单位的 DB/TSV 流程说明。
2. 明确新增单位变体需要复制 `main_units_tables`、`land_units_tables`、属性组、模型/单位卡、招募/权限、单位集合、UI 和 Loc 等必要链路。
3. 明确带数字主键的表复制时必须生成新的唯一 key。
4. 明确默认不复制 `battle_set_piece_*`、`armed_citizenry_*`、`mercenary_unit_groups` 等会改变原版任务战斗、驻军或特殊军队编成的表。

## 2026-07-07 单位属性 TSV 规则修正

1. 根据实际 MOD 制作反馈，补充“修改原版已有单位/属性/关联关系时必须先查原版实际引用链”的规则。
2. 明确 TSV 不只要列数匹配，还必须与目标原版表的列名、列顺序、版本号和同类行结构一致。
3. 明确不能新建未被原版读取的孤立 key 来承载修改；例如单个单位添加静态属性时，应使用 `land_units_tables.attribute_group` 和 `unit_attributes_to_groups_junctions_tables` 的真实关联链。

## 2026-07-07 参考目录命名更新

1. 将原 `源码/` 路径统一改为 `gamedata/`，用于存放提取的游戏原版数据。
2. 将原 `多语言/` 路径统一改为 `bilingual/`，用于存放游戏内中英对照和本地化参考文件。
3. 明确 `gamedata/` 与 `bilingual/` 仅供读取参考，不应生成、修改、格式化、清理或移动其中的文件。
4. 同步更新 `SKILL.md`、`references/project_structure.md`、`references/lua_api.md`、`references/rpfm_and_verification_workflow.md` 与 `references/tsv_format.md` 中的查证路径。

## 2026-07-06 项目工作区规则追加

1. 增加反馈驱动的指南维护规则：用户需求、RPFM diagnostics、游戏日志或实测错误反馈若可复用，应同步更新 `SKILL.md` 或对应 reference。
2. 明确错误反馈不得直接提升为绝对规则；实测经验需标注 `[实测/需随版本复查]`，未核验内容需标注 `[需验证]`。
3. 增加与项目级 `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md` 的关联。

## 关键修正

1. 修正 `core:add_listener` 示例：必须为 5 参数，第四参数是 callback，第五参数才是 persistent。
2. 修正 TSV 头部：标准结构为“列名行 → `#表名;版本;路径` 元数据行 → 数据行”，删除错误的 `header` 占位行。
3. 修正 `!` 前缀说明：叹号只用于排序/加载优先级，不是覆盖开关。
4. 修正 `data__` 说明：默认禁止作为 MOD 文件名，仅作为高风险整表替代高级模式。
5. 修正 `add_first_tick_callback_new` 说明：它不是“太晚”，而是只适合新战役；读档也需要的监听器应使用 `add_first_tick_callback`。
6. 修正 effect scope 表述：reference 中的 scope 只作为常见起点，每个 effect 必须查原版 junction 表确认。
7. 修正本地化规则：Loc key 前缀由具体表和字段决定，不能套单一模板。
8. 保留日志、术语库、UI dump_tree、Campaign Group Member 等实测经验，但标注为模板约定或实测。

## 新增内容

- 增加 `references/rpfm_and_verification_workflow.md`，集中放 RPFM、网页文档、原版核验和排查流程。
- 增加 API 验证状态标签：`[已查官方文档]`、`[已查原版脚本]`、`[实测]`、`[需验证]`。
- 增加 RPFM diagnostics 工作流。

## 2026-07-06 generic 版追加修正

1. 将原私有前缀替换为通用占位前缀 `custom_`。
2. 删除项目结构中的固定 MOD 清单，不再内置任何外部项目名称。
3. 将“已有项目”相关表述改为“用户指定的目标 MOD / 目标 Pack”，避免误导为必须沿用第三方项目。
4. 将 Lua、DB、Loc、TSV 示例统一改为 `custom_` 命名。
5. 保留 `custom_` 只是示例前缀的说明，真实项目可替换为 `my_` 或其他唯一前缀。
