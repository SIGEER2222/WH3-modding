## 2026-09-25 深夜：自定义兵种扩展应用到 9.0 新阵营「亡灵军团」

1. `wh3_dlc29_nag_host_of_nagash`（纳迦什军团=亡灵军团，DLC29/9.0 新增）：military_group `wh3_dlc29_nag_group_undead_legions`、subculture `wh3_dlc29_sc_nag_undead_legions`，主城链 `wh3_dlc29_nag_settlement_necropolis_1..5`，小城三选一 `mausoleum/cove/chambers_1`，特殊城 `pyramid_of_nagash_nag_2..5(_floating)`。
2. 新建 `zzz_czx_nag_undead_unlock`（部署 pos 112，依赖 swarm+pokemon+digimon_v2）：129 单位组授权 + 25 单位派系独占授权（仅虫群18+宝可梦7）+ 2064 条建筑解锁（全单位挂 necropolis1-5/小城/pyramid）+ 凯瑞甘 wizard/general 两条 agent 许可。
3. **语义坑**：`units_to_exclusive_faction_permissions` 是白名单表——单位一旦有行就只认行内 allowed=true 的派系。虫群/宝可梦原被 VC 解锁包限死在 `wh_main_vmp_vampire_counts`，加 nag 行是正确扩展；数码兽原本无行=全派系可用，绝不能给它加 exclusive 行（会把 104 只数码兽锁成亡灵专属，AI 其他派系全丢）。
4. 招募可用性三件套：组权限（military_group）+ 派系独占（可选白名单）+ `building_units_allowed`（建筑→单位入口，faction='' 即对能建该建筑的派系生效；enabled 列原版绝大多数 false）。
5. playset《全合集-非震旦》：移除两个仅对 `wh_main_vmp_vampire_counts` 生效的旧解锁包（vmp_unit_unlock / vmp_pokemon_unlock——nag 战役用不到），现 113 项。英灵召唤 Lin_Summon_Servant 本就在集（pos 95，派系无关）。
6. 待实测：亡灵军团战役中三类生物兵在招募面板的实际出现情况（静态链路已验证：compat+dep 全绿）。

## 2026-09-25 晚续：崩溃排查工作流收口——签名速查表 + 首查顺序 + 三个遗漏案例补档

1. **§一新增"首查顺序"**（0-5 步）：Event 2004→OOM 不二分 → bad_mods_report → mdmp 内层签名分流 → 启动层（steam_api64/Steam 握手）→ vanilla 也崩查 AppData/环境；全程先确认无并发会话拉起游戏。
2. **§三新增"签名速查表"**：11 类内层签名（`0xe06d7363` bad_alloc / `+0x1a0be3b` 悬空 key / `+0x2ccd917` matched-combat / `+0x157acc6` junction 悬空 / `+0x52a21a`+`+0x538a0a` 9.0 挂载 / `+0x1a957e7`+`+0x4e5b30` 环境级 / `+0x4926f0` stub / UAF exec / `0xc000041d`）→ 判定 + 首查节号，替代翻遍 §10.x 案例找签名。
3. **§10.1/§10.20 补 9.0 废弃警告**：`game_startup_mode battle` 在 9.0 vanilla 也定死，仅适用 ≤8.1.1；判据精神由前端二分承载。
4. **补档三个此前只在记忆/CHANGELOG 散落的案例**：§10.34 matched-combat `+0x2ccd917`（含 9-25"内部名==stem==DB key、勿改 vanilla 名"修正）；§10.35 junction 悬空键 `pkm_solar_beam`（含 pack_subset 字节二分假阳性陷阱、audit_dangling_refs 近似键教训）；§10.36 AI 回合 UAF（未最终定案，嫌疑清单留档）。
5. AGENTS.md 排查入口表"启动二分排错"行补 9.0 前端二分指针。

## 2026-09-25 晚：9.0 兼容审计流程固化为 `wh3diag.py compat` + 6 个扩展包兼容补丁

1. **工具固化**：`wh3diag.py` 新增 `compat <pack> [--dep PACK]... [--emit FIX]` 子命令，把当天散在 scratch 的一次性审计脚本（`_ver_report_all`/`_audit_refs`/`_audit_nondb`/`_gen_90fixes`/`_dedupe`）收敛为一条命令。审计三段输出：旧版 DB 表（头版本 vs vanilla 基线 + 新增列清单）、悬空外键（RON `is_reference` 元数据 + vanilla∪本包∪依赖键域）、过期 twui 判定（抹 GUID 行集合 diff → stale-copy/tweak/rewrite）。`--emit` 直接产出 `mod_files/<fix>/` 补丁源（TSV 按列名映射重编码、已知改名键改写、主键去重、stale-copy twui 用 vanilla 同路径落盘、notes/+预览图）。
2. **维护点**：9.0 新列默认值表 `COMPAT_NEWCOL_DEFAULTS` 与已验证键改名表 `COMPAT_KEY_RENAMES` 维护在 wh3diag.py 顶部常量，后续补丁季追加。
3. **schema 优先级修正**：`schema_ron()` 原优先 RPFM appdata 副本（陈旧、缺 v12/v39）导致 compat 误报 DECODE-FAIL；已改为项目 `tools/schema/schema_wh3.ron`（已同步上游）优先、RPFM 副本兜底。
4. **回归验证**：compat 对 Imperial Arbiter（v11→v12 单表）、Arthas（5 表+3 改名+twui stale-copy）、Prayer（14 表+2 改名组+2 twui）、Luke（2 表）的审计结果与当天手工审计逐项吻合；Arthas `--emit` 自动去重 7 个改名撞键行，与手工 `_dedupe.py` 结果一致。
5. **流程文档**：references 新增 §10.33「大版本兼容排查的固化流程」八步 runbook（基线新鲜度→compat 审计→人工复核改名→--emit→build_pack --deploy→补丁排目标前→回读验证→归因边界）；tools/README.md 与 AGENTS.md 排查入口表同步登记。
6. **当日补丁交付回顾**：`czx_{ia,luke,psw,chanliuzi,arthas,boudicca,xiang}_90fix` 共 7 包已部署并插入《全合集-非震旦》pos 96-104、目标包 105-111（补丁全部排前），playset 114 项一致；详细修法见 §10.32。静态验证通过，游戏内回归待下次实测。
7. **遗留**：compat 暂未并入 anim/rmv2/bnk 头版本检查（手工比对路径仍在）；`stale-copy` 判定是启发式，mod 在旧 vanilla 拷贝上小改也会命中（本次 `settlement_hostile_slots.twui.xml` 即属此类，遮蔽前需眼看）。

## 2026-09-25 虫群枪兵不能攻击：animpack bin 内部名≠套件 key + variantmesh 缺武器槽

1. 症状：`czx_inf_marine`（自定义骨架 czx_marine 的远程枪兵）战局中不开火。DB 行与原版火枪手逐字段比对无差异、23 条自定义剪辑全在盘、骨架/prop 节点齐全、属性组无禁攻项——静态链路全部干净。
2. 根因A（套件注册）：animpack 内 `czx_empire_sword_rifle.bin` 的内部套件名残留 donor 名 `hu1_dlc25_empire_sword_hochland_long_rifle`，DB key `czx_empire_sword_rifle` 解析不到套件。对照已验证包（宝可梦 pm001/pkm_*、数码 v2 `patch_dgm_animpack_names.py`）：**内部名==animpack 条目文件名stem==DB key**。已将 4 个 bin 全部改为 stem（`czx_cst_promethean`/`czx_dlc17_ghorgon01`/`czx_empire_sword_rifle`/`czx_steamtank01`），原位重写 offset 8 处 u16 长度前缀字符串（`scratch/patch_swarm_internal_names.py`）。注意先前一版误把内部名改成 vanilla `hu1_empire_sword_rifle`——会遮蔽原版火枪手套件，方向错误。
3. 根因B（武器挂载）：`czx_inf_marine.variantmeshdefinition` 无 weapon_1/weapon_2 槽，步枪网格从不挂载。已镜像原版火枪手：weapon_1=`emp_young_nobles_rifle_2h_set1`@be_prop_0、weapon_2=`emp_state_troops_swords_set1`@be_prop_1、shield@be_prop_2、weapon_3-5 空槽。
4. 已重建部署（189MB/386 文件，data\ 与 mod_output md5 一致），wh3diag 静态验收通过；游戏内实测被 Steam 更新（24237342→25509431，exe 暂缺）+ Lin_Summon_Servant 坏 DB 记录（缺 Lin_Generic_Framework 依赖时弹 bad_mods 终止框）双重阻塞，待更新完成后用 `battle_marine_fire.xml` + 完整依赖链重测。[实测/需随版本复查]

## 2026-09-24 战役初始化闪退根因：ability junction 悬空键（pkm_solar_beam）

1. 症状：所有存档加载 + 新战役初始化 ~15-20s 必崩 `0xc0000005`（`+0x157acc6` 读 null+0x18）；自定义战斗正常；全 playset 去掉 `zzz_czx_pokemon.pack` 即存活。[实测/需随版本复查]
2. 二分方法学教训：字节级 pack 子集（`pack_subset.py` 抽出部分 db 表重打包）会**制造新的悬空引用**——`main_units+land_units` 双子集崩溃其实是缺 variants/weapons 支撑表导致的假阳性，一度误导方向。正确做法是从 **TSV 源重建行子集**（`scratch/mk_pkm_row_subset.py`），保证引用闭包完整。
3. 关键反转：部署包与 TSV 重建包逐字节比对，13 张共享表**仅 GUID 不同**——行内容完全一致，崩源只在重建子集**未包含**的表里。分组追加测试（G1 战役杂表 / G2 权限表 / G3 技能链）→ G3 崩。
4. 根因：`land_units_to_unit_abilites_junctions` 有一行 `pkm_solar_beam → pkm_003_venusaur`，但真实技能键是 `pkm_003_solar_beam`（缺 `003_` 段）。战役初始化解析单位→技能映射时取空指针 → 崩。该悬空是 9/23 技能重命名时的残留。
5. 教训：`audit_dangling_refs.py` 当天曾报过 `pkm_solar_beam` 悬空但被当作误报忽略（误判它指向已存在的 `pkm_003_solar_beam`）——**junction 表的 ability 列必须同时对照包内 unit_abilities 键 + vanilla 键，两表键名不一致时前缀相似不等于存在**。[实测]
6. 修复后验证链：单包 G3 存活 90s → 生产包重建部署（playset pos 107）→ 全 playset 115 包新战役 120s 存活 → 用户真实存档加载 150s 存活。

## 2026-09-23 宝可梦/数码v2/虫群补 animpack 容器（无移动/攻击动画根因）

1. 用户实测三包单位"模型在但无移动/攻击动画"。排查确认 clip 数据、battle DB、battle_skeletons、culture 映射、RMV2 骨架名全链路完好——根因是动画集以 loose `.bin` 提供，未被战斗系统注册（同 9-19 数码兽白模已记录的规则，但生成脚本产物从未落地该要求）。
2. 新增 `tools/pack_animsets.py`：离线把 mod 的 `animations/database/battle/bin/*.bin` 打成 `.animpack` 容器（格式 u32 条目数 + 每条 {str16 内部路径 + u32 长度 + bin 原字节}），不依赖 AssetEditor。
3. 三包生成 `<mod>_animsets.animpack`（PKM 7 / DGMv2 104 / swarm 4 条 animset），离线解析全部到 payload 末尾、引用 bin 无缺失；顺带修复 4 个 bin 引用 `reference_poses/czx_*.anim` 但文件为旧名 `pm###.anim` 的不匹配。
4. 第二轮修正：把工作范本数码 v1（50 个 animpack、**0 个 loose bin**）与三包（animpack+loose bin 并存）对比后，删除三包全部 loose `.bin`——消除 loose bin 若被扫描可能与 animpack 条目重复注册/遮蔽的风险，使包结构与已验证范本逐字节同构。animpack 允许裸表（count+str16+len+bytes，v1 格式）或 LZ4 包裹表（vanilla/IA 格式），两种游戏都认。
5. 重建并部署：`zzz_czx_pokemon.pack`、`zzz_czx_digimon_v2.pack`、`zzz_czx_swarm_units3.pack`（swarm 部署名不同），data\ 与 mod_output SHA-256 一致。游戏内验证受环境级早期初始化崩溃（+0x2cfe551/+0x4926f0，vanilla 同签名）阻塞，重试中；移动/攻击动画确认待实测。
5. 附带修正文档错误：RMV2 v8 头骨架名实际在 **offset 12**（offset 4=版本 u32、offset 8=u32 字段），旧记 offset 8 有误，已改 pipeline/asseteditor 两处。

## 2026-09-22 实际战役闪退：移出残留 battle_preferences

1. 全合集经 Mod Manager 载入最新存档进入战斗时复现 `0xc0000005` 读 `0x20 @ Warhammer3.exe+0x1a0be3b`，script log 为 148B battle stub，且无 Event 2004；vanilla/full-playset vanilla/gou 最小战斗对照均通过。
2. AppData 二进制 `.singleplayer.battle_preferences` 中发现旧 `czx_kerrigan` key；当前 swarm 已改用 `lin_all_kerrigan_zerg`，该缓存属于旧战斗军表状态。已备份并移出，未删除存档或 army_setups。
3. 首次移出缓存后 WMM 曾进入战役/战斗结果面板；但用户后续在最新与较早存档再次进入战斗，22:38、22:46、22:50 仍复现 `+0x1a0be3b`。因此 battle_preferences 处理不是最终修复，问题继续收敛到 campaign→battle 公共路径或外部/存档上下文。

## 2026-09-22 Pokemon A/B 变体 battle init 闪退定界

1. 自动化 `pkm_ab.py` 的多个 Venusaur A/B 变体只加载 runtime + `zzz_czx_pokemon.pack`，在 148B battle stub 阶段以 `0xc0000005` 读 `0xfffffff8 @ Warhammer3.exe+0x5c0ce5` 崩溃；同一时段无 System Event 2004，因此不是本轮 OOM。
2. 真正触发条件是 Venusaur variant 链不一致：`unit_variants` 的 `pmv001`、`pm003.variantmeshdefinition` 指向 Bulbasaur、donor `man_animation` 等错误组合均失败；恢复 `pm003` 全链后通过。`causes_fear/causes_terror` 互换不改变结论。
3. 用 Windows Python313 执行 `tools/build_pack.py zzz_czx_pokemon --deploy`，静态 `wh3diag` 验收通过；固定 `pkm_venu_fixed` 战斗运行 161 秒、峰值 7.74GB、无新 dump。

## 2026-09-21 重装后第三方 Steam API 再次覆盖官方 DLL

1. 用户反馈重装后曾短暂恢复，随后普通战斗再次黑屏；核对发现 `steam_api64.dll` 已被 3,511,296B 的第三方 DLL 覆盖，SHA1=`980ea8cce849c7dbd529786058851800028c2930`，与 `steam_api64_goldberg.bak` 相同。
2. `steam_api64_o.dll` 是官方 298,856B DLL，SHA1=`40d0ae44e090db49b2309fb152fbd3e11124a376`；当前已备份第三方文件、禁用 `cream_api.ini` 并恢复官方 DLL。
3. 该变量与 MOD DB/解锁补丁无关，需在官方 DLL 状态下重新测试普通战斗。

## 2026-09-21 纯净播放集仍复现普通战斗 init 崩溃

1. 通过 Mod Manager 新建空播放集，仅加载 `!!!!wyccc_runtime_options.pack`，从主菜单新开 Vampire Counts 战役；进入第一场普通战役仍复现 `0xc0000005 @ Warhammer3.exe+0x1a0be3b` 与 148B battle stub。
2. 该轮无 gameplay MOD、无旧存档/军表缓存、无新 Event 2004；确认当前普通战斗黑屏不是 DGM、swarm 或独立 Vampire 解锁补丁的 DB 问题。
3. 原《全合集-非震旦》110 项播放集已通过 Mod Manager 恢复；纯净诊断播放集保留供后续 Steam/NVIDIA 覆盖层、第三方注入和安装/驱动环境 A/B。

## 2026-09-21 基础兵种包与 Vampire Counts 解锁补丁拆分

1. 将 DGM、swarm、DGM mini patch 的 Vampire Counts campaign 接入行迁移到独立 `zzz_czx_vmp_unit_unlock.pack`；基础包只保留单位资源与自定义战斗链。
2. 主解锁补丁包含 68 行建筑、军事组和 exclusive faction 数据，依赖 `zzz_czx_digimon.pack`、`zzz_czx_swarm_units.pack`、`zzz_czx_dgm_patch.pack`；Pokemon 另拆为可选 `zzz_czx_vmp_pokemon_unlock.pack`，依赖 `zzz_czx_pokemon.pack`，避免主补丁自动把 Pokemon 拉回 playset。
3. 新增 `tools/split_vampire_unlock_patch.py` 与 `tools/split_optional_pokemon_unlock.py`；当前稳定 playset 已移出 Pokemon，主解锁补丁已重部署。

## 2026-09-21 A/B：DGM+swarm 可过 campaign，Pokemon 触发 commit OOM；Bhashiva preset 独立修正

1. 通过 Mod Manager 重启验证：DGM + DGM mini patch + swarm（110 项）完整进入 savegame 阶段，无新 dump；加入 Pokemon 后 campaign load 触发 Event 2004，WH3 commit 43.65GB。
2. battle_preferences 清空后仍自动回填 `wh3_cp1_bhashiva_qb1` 并触发 `+0x1a0be3b`；已做可回滚等长替换为普通原版 `wh3_cth_desert_01_01`，后续启动不再出现该 null-deref，OOM 单独处理。
3. 当前稳定基线保留 DGM+swarm+patch，Pokemon 暂时移出当前 playset；Pokemon 需要后续低资源版本或更小 playset 才能重新启用。

## 2026-09-21 Vampire Counts 低扇出战役接入

1. 用户选择把自定义单位挂到当前吸血鬼派系的原版一级建筑，而不是恢复全派系招募。
2. 新增 `tools/add_vampire_custom_unit_access.py`：DGM 50、swarm 16、Pokemon 7、DGM mini patch 2 个单位各增加一条 `wh_main_vmp_necromancers_1` 建筑入口、一条 `wh_main_group_vampire_counts` 军事组和一条 `wh_main_vmp_vampire_counts` exclusive faction 限定。
3. `cdir_military_generator_unit_qualities` 保持 0 行；不会把这些单位恢复到 AI 随机军生成器。安全包已重建，尚未部署到正在运行的游戏。

## 2026-09-21 自定义单位包战役安全版：移除全派系随机军池扇出

1. 用户实测：禁用 `zzz_czx_dgm_patch`、`zzz_czx_digimon`、`zzz_czx_pokemon`、`zzz_czx_swarm_units`、`!!ia_all_factions`、`@z_all_agent_actions` 后，新战役初始化不再在 Event 2004/42.96GB commit 处崩溃；当前 107 项清单成功运行至脚本完整加载。
2. 根因不是磁盘包大小，而是 DGM/swarm/Pokemon 源表把单位扩展到全军事组、全建筑和 AI 随机军生成器，campaign load 时形成高扇出运行时组合。
3. 新增 `tools/trim_custom_unit_campaign_pools.py`：备份并清空三个单位包及 DGM mini patch 的 `building_units_allowed`、`units_to_groupings_military_permissions`、`cdir_military_generator_unit_qualities` 数据行；保留单位 DB、模型/动画和 custom battle 权限。安全版默认“自定义战斗可用、战役招募/AI 随机军关闭”。
4. 已生成未部署测试包到 `mod_output/*_safe.pack`；由于游戏仍在运行，未覆盖 `data\\`，待退出后经 Mod Manager 重启回归。

## 2026-09-21 固化 tools/wh3diag.py：游戏侧排查只读 CLI（替代 scratch 一次性解析脚本）

1. 新增 `tools/wh3diag.py`——固化崩溃排查会话中反复手写的取证路径：`crashes`（mdmp 异常码/params/故障地址→模块偏移/上下文寄存器/stack.txt 符号链）、`scriptlog`（各 script_log 加载枚举数/最后枚举文件/marker 命中，自动标注 148B stub=崩在枚举前、枚举截断=崩在加载中段）、`which`（跨包反查内部路径，data\+工坊 1142710+mod_output 全扫）、`ls`/`meta`/`cat`（PFH5 索引/头/依赖块/rpfm_reserved/单文件提取）、`db`（按 schema_wh3.ron 解码表行）、`usedmods`（清单序号/grep/两清单 diff）、`paths`。pack 参数支持裸文件名自动解析；Windows Python313 与 WSL python3 双跑（`X:\` ↔ `/mnt/x` 自动映射，`WH3_GAME_ROOT`/`WH3_APPDATA`/`RPFM_SCHEMA_WH3` 可覆盖）。
2. `tools/export_gamedata.py` 新增索引级原语 `read_pack_header`/`iter_pack_index`/`read_pack_payload`/`PackIndexEntry`（不读 payload 的全包扫描）；`iter_pack_entries` 改为复用，行为不变。
3. 路由登记：`AGENTS.md` 新增「排查入口（问题形态→工具）」表；新建 `tools/README.md` 用法索引；`.codex/project_context.md` 与 `docs/PROJECT_STRUCTURE.md` 登记；`references/crash_and_load_order_diagnostics.md` §三/§六/§10.13 挂工具指针。
4. 修正 references §六 PFH5 头字段标号：offset 8 = dep_count（原误标"保留"）、offset 12 = dep_size 依赖区字节数（原误标 dep_count）。

## 2026-09-21 跨表悬空引用审计器 + 静态修复一批 + playset/AppData 卫生

1. 新增 `tools/audit_dangling_refs.py`：对 `mod_files/` 全量做跨表悬空引用审计——自动从 vanilla gamedata 推断外键（源列值集 ⊆ 目标唯一列），另有 variantmesh 文件存在性、loc key 精确匹配（表名前缀按原版约定）、`show_advice`→advice_threads、battle_skeletons 声明、TSV 列数一致性等检查；报告落 `scratch/audit_dangling_refs_report.tsv`。最终 0 ERROR / 126 WARN（WARN 多为上游工坊包提供的 key 或归档测试包）。
2. 据此修复：`zzz_czx_swarm_units` 补 `battle_skeletons_tables`（czx_marine/ms/dehaka1/stank01，按 donor 骨架 humanoid01/crab01/humanoid11b/steamtank01 复制改名，节点字段为前缀语义）+ `skv_chongzu` unit_set/`chong_zu` grouping/loc；swarm_expansion projectiles 行去掉多余尾列；cth 龙弩 elite/vanguard 补 `units_onscreen_name_*` loc；pokemon `fear/terror`→`causes_fear/causes_terror`（vanilla 属性名，原先静默失效）；digimon 权限表 `wh3_main_cth_the_northern_provinces`→`the_western_provinces`。
3. `tools/build_pack.py zzz_czx_swarm_units --deploy` 重打部署为 `zzz_czx_swarm_units.pack`（含骨架声明）；playset 手术：删除新条目复位的 pos116 行与 pos54 旧 `units3` 行指向互换、删 2 个 pack 已消失的死引用（wyccc 汉化补全×2，内容以 `data\text\` 散 loc 存活），重排 position，同步 `enabled_order`——117→114 项、0 重复、0 missing。旧 `zzz_czx_swarm_units3.pack/.png` 移入 `scratch/prefs_backup_20260921/`。
4. §10.14 同类复发实例：`.singleplayer.battle_preferences` 缓存军表又含已删除的 `czx_kerrigan` 与不在 playset 的 `pkm_025_pikachu`——已备份至 `scratch/prefs_backup_20260921/` 并删除（连同 `army_setups` 残留），游戏 06:29 重建的 prefs 只剩 vanilla key。**自造单位改名/删除时必须同步清 AppData 军表缓存**这条再次验证。
5. DLC 补丁核对：`E:\Download\战锤III 8.0 dlc未加密补丁` 三件套与游戏目录完全一致（`steam_api64.dll`=980ea8cc cream 版、`steam_api64_o.dll`=40d0ae44 原版备份、`cream_api.ini` 相同），8.0 重装后补丁实际已就位，无需覆盖。
6. 新工具 `scratch/mdmp_exc.py`：解析 .mdmp ExceptionStream 拿内层异常码/地址并按 ModuleList 基址换算 exe 偏移——比 stack.txt（只有模块名）信息量大，崩溃归因第一步。
7. 遗留定界（同日 A/B）：`+0x1a0be3b` 在重装后 vanilla 基线**间歇复现**——`battle_basegame --mods none` 07:0x/08:16 通过、09:51/09:55 崩；且在 cream_api 全卸载（ini 移除 + steam_api64.dll 换回原版备份）状态下仍连崩（+0x1a0be3b、+0x2cfe551）——**cream_api 补丁排除、OOM 排除（06:49 后无 Event 2004）、mod 内容排除（vanilla spawn 也崩 +0x2cfe551）**，收敛到引擎竞态/系统注入层（QQPinyin TSF 在每个 dump 模块表但仅 1/33 出现在崩点栈顶，证据弱）。zz_pkm 四分片同签名全崩大概率是基线污染而非包内容问题。协调笔记 `scratch/crash_20260921/NOTE_cross_session.md`。



1. 09-21 01:03–06:39 约 80 个 dump，外层签名恒为 `Application Error 1000 / 0xc0000409 @ Warhammer3.exe+0x10da8f1`，异常流无内层 `0xc0000005`，`ExceptionParameters[0]=0x7`(`FAST_FAIL_FATAL_APP_EXIT`)——进程主动 fail-fast，与 §10.14/10.18 的空指针路径不同。
2. 定案：每次崩溃同一秒命中 System `Event 2004`（内存资源耗尽），`Warhammer3.exe` 提交 40.5–46.5GB；本机物理内存 15.8GB、pagefile 40/48GB、提交上限约 63.8GB，另有 Devin/steamwebhelper 等占用数 GB。
3. 触发开关：`preferences.script.txt` 被写成 `minimise_memory_usage false` + `gfx_texture_quality 3` + `gfx_unit_size 3`；通过全验证矩阵的 `preferences.script.txt.bak_reinstall_test` 是 `true` + `2`。已把 `minimise_memory_usage` 改回 `true`（备份 `preferences.script.txt.bak_20260921_065145`）。
4. 归因文档新增 §10.19，判据固化：**先看 System 2004**，命中即 OOM，不要去二分 pack；无 2004 才回退到悬空单位 key / 缺 battle_skeletons 路线。

## 2026-09-21 二次修正：只开 `minimise_memory_usage` 不足以救 OOM，必须同时降贴图/单位档位

1. 反例：06:29–06:49 批次崩溃时 `minimise_memory_usage` 已是 true，但 `gfx_texture_quality`/`gfx_unit_size`/`gfx_unit_quality` 仍为 3(ultra)，`Warhammer3.exe` 照样提交 43.3/43.8/47.1GB 并被 Event 2004 判死——自造单位 pack 的 dds（swarm 170MB + digimon 69MB）单独就能吃光降内存后的余量。
2. 键名修正：减负要动 `gfx_unit_size`（单位规模）与 `gfx_unit_quality`（单位细节）两个独立键，只改其中一个不够。
3. 内层签名不唯一：本批同时出现 `0xe06d7363`(bad_alloc) 与 `0xc0000005 @ 0x14182fb2b`，都是同一 OOM 的不同落点；归因以 Event 2004 是否同秒为准，纠正 §10.11 表里把两行分开列的印象。
4. 新增可复用工具 `tools/set_memory_safe_prefs.py [--level 2|1] [--dry]`：幂等把上述键设为安全值并备份 `.bak_*`，装机/画质被重置后跑一次即可。
5. 写入时机坑：游戏实例运行中改 `preferences.script.txt`，其干净退出会把内存旧值写回文件、静默覆盖改动（实测 01:32 的 false 在 06:48 实例退出后变 true）；应在游戏关闭后改并复查，崩溃退出则不写盘。
6. 归因文档 §10.19 追加修正小节；本次已把全部档位降到 level 2 并备份 `preferences.script.txt.bak_20260921_oom`。

## 2026-09-20 全局 Lua 回调护栏与原生崩溃边界

1. 新增 `zzz_czx_global_lua_guard`：在 campaign/battle 脚本环境中尽早包住 `core:add_listener`，并尝试包住 `cm/bm` 的 callback 注册；异常按 tag 限流记录后返回，避免单个 Lua 回调中断事件泵。
2. 明确边界：`pcall/xpcall` 不能捕获 `Warhammer3.exe` 的 C++ 访问违例、坏接口解引用或 battle init 原生崩溃；21:41:14 最新 dump 仍是 WER `0xc0000409 @ 0x10da8f1`，内层 `0xc0000005` 读 `0x8 @ 0x4ba1ae`。
3. 已打包部署 `zzz_czx_global_lua_guard.pack`（当前 playset pos 112）；21:47:45 新实例已确认加载，21:48:51 仍产生 native dump（内层 `0xc0000005` 读 `0x0 @ 0x23b01c2`），脚本日志显示崩溃前正在构建 `Random Army Manager/chaos_besiegers_tze_2`，证明 guard 不能替代原生崩溃归因 `[实测/需随版本复查]`。
4. 22:04–22:09 空 modlist（仅 runtime 包）仍连续 battle init 崩溃；空跑的 `battle_preferences` 主缓存含 `wh3_cp1_bhashiva_qb1` 及混合原版军表，已备份并改名等待重建。最新 stack 顶层出现 QQPinyin，增加输入法/TSF A/B 方向 `[实测/需随版本复查]`。
5. 重建后主缓存又由 `army_setups\last_setup_for_wh3_main_brt_aquitaine_classic.army_setup` 灌回同一配置，22:15/22:18 仍为 `+0x1a0be3b`；已再次备份并移出该 preferences 与 army setup，等待验证 `[实测/需随版本复查]`。
6. 修复启动层 `steam_api64.dll`：Steam 校验发现游戏目录唯一不匹配项为 298856B DLL，曾报 corrupt/missing 并因 App Running 状态暂停；重启 Steam 后重新验证已 commit 恢复，SHA1=`40D0AE44E090DB49B2309FB152FBD3E11124A376`。
7. 修正“空 modlist=vanilla”判据：最近存档二进制含 `czx_digimon`/`czx_swarm_units3`/`czx_aig3_plus` 等 Mod 标记，最新临时战役状态含 55 个 `czx/dgm` 引用；无 Mod 清单继续该存档仍不是纯净对照。
8. 通过 Mod Manager `_launch_game([], token, "")` 做真正纯净主菜单对照：无存档、无 gameplay Mod、数据补丁 zero modification，运行 35 秒无 dump；此前崩溃归因收敛到 Mod 存档/战斗状态进入 battle init 的路径 `[实测/需随版本复查]`。
9. 从该纯净主菜单进入实际 battle init 后，22:38:24 仍以 `0xc0000005` 读 `0x20 @ 0x1a0be3b` 崩溃；新 preferences 指向 `wh3_cp1_bhashiva_qb1` + Daemon Prince custom battle preset。新增 vanilla Bhashiva/custom-battle engine/cache 方向，需与新 vanilla campaign 普通战斗分开验证 `[实测/需随版本复查]`。
10. 22:41 起清空全部 AppData 旧状态（105 文件归档 `scratch/crash_20260920/purged_state_20260920_224341`），22:45:15 无存档空 Mod 仍同签名崩在 Bhashiva preset——归因收敛到 vanilla preset/损坏的安装文件；用户卸载重装，13 个本地包已从 `mod_files/` 重打并以原 mod_id 部署回 `data\`，3 个无源码本地包（`!!ia_all_factions`、`!!!wyccc_cn_localization_patch`/`_batch2`）待工坊回下后扫描恢复 `[实测/需随版本复查]`。

## 2026-09-20 过回合闪退第二轮：非 OOM，v9 熔断 psw 监听器错误风暴

1. 推翻前夜 OOM 归因：minimise_memory_usage+贴图降档生效后 WH3 私有提交稳定 15.3GB/63.3GB 仍崩，0xc0000409 @ 0x10da8f1 证实为引擎通用 fail-fast 落点而非 OOM 专属；mdmp 内层 0xc0000005 param0=8（DEP 执行违例）——级联中对象先死后被原生调用。
2. !psw_crash_guard.lua 升 v9：文件顶层包 core.add_listener，debug.getinfo 匹配原版 psw 文件名（英雄/天赋效果/独特能力/第六批/第七批 等 16 个）+ FactionTurnStart/FactionTurnEnd 事件时套“非玩家派系早退”前置检查——psw 监听器只对玩家派系有意义，却为 ~100 个 AI 派系每回合全量执行（先解引用 player_data/pooled_resource 再判 is_human 的错误顺序），sm0_log 实测每秒几十条错误。
3. czx_debug_recruit.lua 停用（CZX_DEBUG_RECRUIT_ENABLED=false 保留开关）：UnitCreated 全局探针本身每事件再灌 ~10 次 pcall 原生调用，8500 条/会话放大级联负载。
4. 部署走 deferred_deploy.ps1（游戏运行中 pack 被锁，退出后自动补 deploy）；归因文档新增 §10.13（fail-fast 签名修正、mdmp 解析要点、v9 模式、待办 A/B 测试）。

## 2026-09-19 社区调研转化：AIG3+ 第二批增强

1. 调研对象：AIG3 工坊评论/discussion（"500 射程满弹药走进近战"、"rush 远处敌人不贴脸"、"挤成一团推搡"、"大量魔法浪费"、围城跑图边布阵）、SFO Battle-AI-Tweaks（技能标签不可靠/误伤友军/风筝阈值）、Better Battle AI（反追放风筝/援军停滞）、AI Coordinated Assault（高速单位先送）、Auto Abilities mod（按条件触发技能）、paperpancake 自家 Attack Move and Countercharge（锚点+leash 后卫模式实证可行）、Advanced AI submod（按冲锋加成筛选循环冲锋单位）、No Infinite Charge（引擎冲锋加速 9s+13s 冷却——印证 charger dwell/rearm 节奏）。
2. 落地改动：rush doctrine 改用 `planner:rush_unit`（少整队多推进，治"挤团推搡"）；charger 认领加接战门（`last_contact_ms>0` 防骑兵先送）；新增 `guard` 认领类（锚点+leash 守后排反空军/召唤偷炮）；新增 pass 2.5 步射手 `skirmish` 旗标托管（70m 开/110m 关滞回带，uc 旗标开关同 cast 机制免 claim，`no_skirmish` profile 避让）；cast 纪律：target_ground 友军溅射检查（35m 内有我方单位跳过——SFO 头条修复）、self/friend buff 只在近战或 <45m 放（治"魔法浪费"）。
3. 未做方向（备查）：第二 planner 侧翼分队（`alliance:create_ai_unit_planner` + move_to_position 弧线绕后 → rush_unit 掏后排，planner 级真包抄）；`set_should_reorder(false)` 减 30s 重整抖动 [需验证]；`defend_position_of_sunit(领主)` 锚定守线；技能语义表（治愈类按 HP<75% 触发需逐技能标注）。

## 2026-09-20 装备补丁出售按钮不可见修复 + 出售交互增强

1. 根因：`zzz_czx_ancillary_sell` 旧版把出售钮 `SetDockingPoint(9)+SetDockOffset(+56/+106,0)` 挂在 `ancillary_detail` 右下角——右缘 dock 点正 X 是**向外**推，两钮全部落到详情框右缘外、右侧 HUD 栏底下不可见（script_log 里 "sell patch active" 正常，纯布局问题）。修正为负 X 收进框内：`sell_one -48 / sell_checked -98 / sell_all -148`，排在面板购买钮 `xx_button_add_ancillary`（+6）左侧。
2. 新增交互：双击列表行直接出售（150ms `czx_sell_ui_tick` tick 计数做 ~600ms 双击窗口，无 wall-clock API）；每行右上角 20x20 勾选框（tick 扫描 list_box 补挂 `czx_checkbox`，`context.component:Parent()` 取行 key，`checked` set 驱动 `btn_sell_checked` 计数/合计 tooltip）。出售校验统一收敛 `can_sell`（owned+未装备+非传奇锻造），服务端 UITrigger 逻辑不变。
3. `references/lua_api.md` 补丁技巧节新增两条：`SetDockingPoint/SetDockOffset` 方向语义（右缘+X向外须负X入内、上缘+Y向内、下缘+Y向外）与行内勾选框挂法（绑定行动态重建须 tick 补挂）。
4. 游戏运行中旧包被锁：改用 `--deploy-name zzz_czx_ancillary_sell4.pack --replace local:data:95eacca79d455f053b` 换名部署（新 mod_id `local:data:af5c4027ee754b2138`，pos 102 原位替换，enabled_order 已同步）；旧 `zzz_czx_ancillary_sell3.pack` 留 data\ 待游戏退出后清理。

## 2026-10-04 PSW 前往讨伐传送静默失效修复

1. 根因：`dilemma_tf_duoren_legend_tp` FIRST 无脑 `cm:teleport_to(faction_leader)`——派系领袖弗拉德（cqi 1225）受伤未带兵在图，`teleport_to` 对无军队角色静默失效（日志仍写 `Teleporting [character_cqi]` 行）。实测档中在图军队为伊莎贝拉（1224）。
2. 修法（`psw_02_tianfu.lua`）：新增 `psw_char_deployable`（非 null/非 wounded/非 at_sea/`char_is_general_with_army`）、`psw_tp_commander`（领袖优先→遍历 `military_force_list` 跳过 armed_citizenry、优先 `force_type:key()=="ARMY"` 再任意有将领军队）、`psw_csys_target_character`（`creat_sszm_mf_cqi` 失效时按传奇领主 subtype 池扫魔王派系）。`dilemma_tf_duoren_tp`/`dilemma_tf_duoren_legend_tp` 的 FIRST/SECOND 全部改走解析器，并记录 `boss_tp_commander_cqi`/`legend_tp_commander_cqi` 供"传送回原位置"召回同一角色。
3. `lua_api.md` 新增"传送角色（cm:teleport_to）"节：静默失效行为、deployable 判定、领袖→军队回退模式、回程按 cqi 找回同一角色。
4. 已重新打包部署 `zzz_psw_merged.pack`（886606B，playset pos 67）。游戏内回归：阻止重生仪式→前往讨伐应传送当前在图军队（伊莎贝拉）→传送回原位置 [需实测]。

## 2026-10-05 监狱补丁支持收监 roster 单位（魔王 BOSS 修复）

1. 根因：魔女 mod 魔王军队的 BOSS（psw_tfmw_*_boss_*）是 grant_unit_to_character 授予的 lord/hero 种姓 main_units roster 单位——不是战役角色、无 family_member。笼牢可锁定+击杀，但战-役桥接 saved_battle_character_entry 按 unit_index 查不到 fm -> "exact battle target resolution failed" 拒收。军队的普通生成将领（多丹等）仍走原角色路径可正常抓捕。
2. 修法（zzz_czx_prison_default/script/campaign/mod/wyccc_prison_system.lua）：snapshot_pending_battle 给无关联角色的非驻军单位写 fm=0 桥接条目（战斗侧 unit_is_not_commander_class 已保证匹配者必为指挥官级）；saved_battle_character_entry 对 fm=0 匹配返回 {is_unit, unit_key, unit_cqi, source_faction, army_mf_cqi} 单位目标；queue/finalize 经 evidence.identity.is_unit 分流；新增 capture_unit_prisoner 存 {is_unit, record_id, unit_key, source_faction/culture, portrait=ui/units/icons/<key>.png}；记录键值化 prisoner_record_key/remove_prisoner_record（角色按 fm、单位按 record_id）。
3. 动作语义：招降走 perform_unit_recruit（同设施/每回合一动/概率门槛，成功 cm:grant_unit_to_character 授予 army_general_with_space 选出的有空位玩家将领——领袖>ARMY>其他军队，unit_list<20）；释放/赎金经 return_captured_unit 授回来源派系有空位将领（无军队则记录移除并日志）；审讯复用文化 bundle+经验池+招降加成；leader disposition 天然跳过（is_faction_leader=false）；显示名用 land_units_onscreen_name_<key>。自动劝降（FactionTurnEnd）与手动按钮共用 perform_recruit 自动走单位分支。
4. lua_api.md 新增"roster 单位不是角色"节（grant_unit_to_character 单位无 fm/associated_character null、按单位重建的收监模式）。已部署 zzz_czx_prison_default.pack（pos 100，原包 101 之前）。游戏内回归 [需实测]：笼住 psw 魔王 BOSS 45s 内击杀→监狱出现该单位记录→招降进玩家军队/释放授回/赎金收款/审讯给经验，存档读档记录不丢，普通角色捕获不回归。

## 2026-09-20 战斗 init 定死归因：battle_preferences 悬空单位 key

1. 现象：全天 67 个崩溃 dump，每一次进战斗（战役过渡与 autotest XML 皆然）都死在 battle_scripted.lua loaded 之后；内层签名主为 0xc0000005 读 0x20 @ exe+0x1a0be3b，外层 WER 恒 0xc0000409 @ 0x10da8f1；当日无 RES 2004，排除 OOM。
2. 根因：%APPDATA%attle_preferences\.singleplayer.battle_preferences 缓存的上次军表含 3x czx_dgm_agumon；该 key 随数码宝贝包重建改名（dgm_chr050_agumon）且 digimon 曾禁用——所有已加载 pack 都不提供此 key，战斗 init 恢复军表解析出 NULL 定死。
3. 教训：悬空引用在 AppData 缓存而非 modlist，二分 pack 永远收敛不了；纯原版+空 modlist 也崩是强信号。修法=删/改名该 prefs 文件（已改名 .bak_dead_agumon，证据在 scratch/crash_20260920/）。自造单位改名/删 key 时需同步清理 battle_preferences/army_setups/saved_characters/存档中的旧 key 引用。
4. references/crash_and_load_order_diagnostics.md 新增 §10.14 记录触发条件、判据速查与清理范围。

## 2026-09-22 数码宝贝 v2 补齐与三包整合

1. **骨架/动画/bin 命名口径**：`animations/skeletons/<骨骼名>.anim`、`animations/battle/<骨骼名>/` 按 `battle_animations_table.skeleton` 列命名；`animations/database/battle/bin/<动画表key>.bin` 按 `battle_animations_table.key`（即 land_units.man_animation）命名——审计脚本必须走 `man_animation→BAT key→skeleton` 两级映射，直接拿 skeleton 名对 bin 名会全报缺失。
2. **`battle_skeletons_tables` 主键列是 `name`** 不是 `key`/`skeleton`，静态检查取列时要兼容。
3. **`ground_stat_effect_group` 无 `medium` 值**（原版只有 small/large/large_bst/ethereal/aquatic_*/elves_wef*/small_strider 等）；同表 `capture_tier`/`key_building_capture_tier`/`score_capture_tier` 的 `medium` 是合法值——**TSV 批量替换必须按列定向**，全文替换会误伤合法列。
4. 法术弹丸 `soul_quench` 正确 key 是 `wh2_main_spell_high_magic_soul_quench`（wh2_ 前缀），写 wh_main_ 会成悬空引用。
5. `ui_unit_groupings` 自定义分组的 loc key = `ui_unit_groupings_onscreen_<group_key>`；漏了游戏里兵种分类标签显示原始 key。
6. **同骨架多代产出可移植**：同一管线两代输出（dgmslim/dgmB2）若 rmv2 逐字节一致，则 skeleton .anim + animations/battle/<skel>/ + bin 三件可整套平移补齐缺漏单位；反之骨架重生成后旧骨架不可混用。
7. `build_pack.py` 构建门槛：每单位需 `units_onscreen_name_*`/`land_units_onscreen_name_*` 齐全、`unit_description_short_texts_text_*` 非占位（≥8字）、`unit_description_historical_texts_text_*` ≥40 字，否则拒绝打包。

## 2026-09-22（续）：animpack bin 骨架一致性

- [实测/需随版本复查] 自定义骨架单位的三方一致性检查：`db/battle_animations_table` 行骨架、rigid_model_v2 内嵌骨架名、animpack `.bin` 内嵌 `animations/skeletons/*.anim` 路径必须指向同一骨架。czx 虫群包曾出现前两者已是自定义骨架但 bin 仍引原版 `humanoid01/humanoid11b`——骨架名等长时可原位二进制补丁（如 `humanoid01`→`czx_marine` 均 10 字符）。补丁仅替换 `animations/skeletons/` 前缀路径，勿动 `animations/battle/` 剪辑借用。
- [实测] bin 中引用不存在的 `.anm.meta`/`.snd.meta` 是原版常态（软引用，游戏容忍），不算悬空错误；`.anim` 引用缺失才是真问题。
- [实测] 剪辑内嵌骨骼列表顺序与骨架 `.anim` 不一致属正常（WH3 按骨名匹配）；WM 引擎 bin 通常不含 skeleton 路径。
- 工具：`scratch/bin_missing_check.py`（bin 引用对账）、`scratch/clip_bone_audit.py`（剪辑骨骼 vs 骨架）、`scratch/vmd_skel_map.py`（vmd→wsmodel→rmv2 骨架声明）。

## 2026-09-22（续）：基础兵种一级建筑解锁

- `building_units_allowed` 无链内继承：单位要在建筑链各级都可招，须每级各写一行（原版僵尸在 settlement 链 1-5 级重复出现即此模式）。只写 1 级会在建筑升级后消失 `[实测/需随版本复查]`。
- 链补全法：`building_levels_tables.level_name -> chain` 反查后取链内全部等级，可把"成熟期起挂 2/3 级建筑"的脚手架一键下放到 1 级；一次性脚本 `scratch/tier1_recruit_20260922.py`。
- VMP "开局即招"模板 = 僵尸同款 23 建筑集合：`wh_main_vmp_settlement_major_1-5` + `minor_1-3` + `wh_main_special_settlement_{altdorf,castle_drakenhof,couronne}_1-5_vmp`。
- 坑：本地包换文件名重打后 mod_id（`local:data:<sha256(小写/正斜杠路径)[:18]>`）变化会让旧 playset 引用失效——`zzz_czx_vmp_unit_unlock` 就因此静默掉出 playset，表现是"文件在 data\ 但游戏里完全没有"。排查：算 hash 对 playset_items。
- 游戏运行中 `data\` pack 被进程锁定，build_pack --deploy 拷不进去；可把 state.db 侧先做（备份后插 playset_items+enabled_order），文件复制挂监视器等游戏退出。
- `zzz_czx_vmp_unit_unlock` 历史遗留两张地雷已清：`czx_kerrigan`/`czx_kerrigan_lord` 在 groupings/building/exclusive 三表的行全删（战役内凯瑞甘改走 Lin_Summon_Servant 的 `lin_all_kerrigan_zerg` 召唤，见 swarm pack notes）；52 个 v1 `dgm_chr###` 死 key 全删（v1 包不在 playset）。虫群精英（baolongshou/dehaka/hd_dblack/inf_tank/mangshou）与宝可梦进化型（venusaur/charizard/blastoise）移 `wh_main_vmp_necromancers_2`（原版 terrorgheist 同级），中阶留 necromancers_1。
- **残缺单位恢复法（donor 变体路线）**：gou（跳虫）/cishe（刺蛇）原本只有 main_units+ability+loc+裸 rigid_model_v2，缺 land_units/variants/wsmodel/材质——按悬空清掉后用户要求恢复。做法：land_units/main_units 直接克隆原版 donor 行改 key 与文本（dire wolf→跳虫、sepulchral stalker→刺蛇），unit_variants.variant 与 unit_card 直接引用原版 variant_name/兵牌 key（`wh_vmp_dire_wolves`/`wh2_dlc09_tmb_sepulchral_stalkers_halberd`），variants 表零新增。比"补网格三件套+材质"快且零资产风险；裸 rigid_model_v2 留 pack 里等以后想做真模型再接。
- wh3diag `db` 输出单表只打前 ~25 行（`... +N rows` 截断），核对行数以 `rows=N` 计数为准，或直接 grep pack 二进制。

## 2026-09-23：兵牌图规范与 ? 排错

- unit_variants.unit_card 的值是 ui/units/icons/<key>.png 的文件 stem，与 variant key 无关——把 variant key（如 pmv003）误填为 unit_card 会得到 ? 兵牌。审计法：对每个 unit_card 检查本 pack ui/units/icons/ 存在同名文件，或用 wh3diag.py which "units/icons/<key>" 确认由 vanilla/其他 pack 提供。
- 兵牌三件套尺寸：icon 60×130、portrait(ui/portraits/units/<culture>/) 60×130、infopic(ui/units/infopics/) 120×260，均 RGBA。方形立绘 cover 居中裁切即可（垂直 bias ~0.4 保头）。
- 立绘来源[实测]：wikimon.net 可直连（数码宝贝官方立绘，Special:FilePath/<页名>.jpg 直接 302 到图；页名有空格分词习惯，X 抗体为 Xxx (X-Antibody)）；starcraft fandom/liquipedia/github 主站/百度百科在本机网络均被拦，bing 图搜结果会退化——SC2 虫族立绘暂无可靠源，donor 单位直接引用原版兵牌 key 是最稳解。
- wikimon 的 MediaWiki 版本无 prop=pageimages，用 prop=images（记得 redirects=1）+ stem 归一化匹配挑 <页名>.jpg。

- **donor pack 复用模式**：当工坊包已含同名单位的完整实现时，优先引用其 variants/兵牌 key 而非自建不完整资产；自建包 position 靠前胜出可保留自定义 main/land 数值。必须删除与 donor 同路径的不完整文件防遮蔽；依赖写进 notes/dependencies.txt 让 PFH5 头与 Mod Manager 都认。
- wh3diag cat 出的 PNG 前可能带 pack 包装头（非 PNG magic 起始），找 PNG 魔数偏移截取；若为 zstd 帧（magic 28 b5 2f fd）先解压。
- **数值平衡审计法**：对 main/land_units 两表按 unit key join 出 人数/费用/ma/md/士气/hp/甲 一行一单位快照，重点查"单体怪血量×多人数"型克隆残留（蟑螂 12×6012 即此类——donor 是单体怪时 bonus_hit_points 必须确认实体语义，不能只按 main_units.num_men 机械相乘）。

## 2026-09-23 三包复审：技能补齐、动画文化路由与坦克血量回正

- Pokemon 7 只单位此前没有 `unit_abilities` 链；现补每只一个主动技能和按草/火/水/电定位的被动技能，复用已存在的 vanilla projectile/contact/phase 效果，并补齐 22 条技能 Loc。施法动画表现仍需游戏内复查。审计还发现基础型护甲 key `wh_main_body_40` 不存在，已修正为 vanilla `wh2_main_body_40`。
- 动画静态审计确认 7 个 Pokemon 的 RMV2 权重有效、攻击 clip 有动态轨道，但每只 `move.anim` 与 `idle.anim` 字节完全相同，**没有独立步行动画**。已通过新工具 `tools/retarget_bonemap.py` 用显式语义骨映射生成 walk cycle：妙蛙种子←wf1_walk_01(wolf01)、妙蛙花←hq01_walk_1(heavyquadruped01，Stegadon 宽展腿与妙蛙花匹配)、小火龙/喷火龙/杰尼龟←rp1_walk_01(raptor01 双足带尾)、水箭龟/皮卡丘←hu1_sws_walk_01(humanoid01)。注意 PM 骨架 L/R 与 vanilla 镜像相反，映射必须 our-L→donor-right；animroot 前进位移按骨盆高度比缩放（0.15~0.72）。骨映射存 `scratch/pm_walk_maps/`。
- Digimon 属性组原先把 `causes_terror` 无差别施加给多类低阶单位；拆为14个阶段/编制属性组与40条 junction：16只 Rookie 去掉 fear/terror/wallbreaker，34只 T4+ 单体精锐/Boss 保留 terror，其余中高阶按 archetype 保留 fear。104只中103只已有主动技能；RosemonBM 的“慈悲/提法雷特”按恢复与自我增益设计保留两项被动，不强加主动。
- Digimon v2 的 104 个自定义动画 key 原先只在 Cathay culture 注册；扩展到合法 `culture_pack_ids` 清单。Pokemon 原有 24 个文化映射补齐其余有效文化包；swarm 补齐 4 个自定义 animation set 与 VMP donor `sn1`/`bc1` 等缺失 pair。custom-battle 权限本身不会代替动画文化映射。
- 修复 swarm：`cishe` 的 `requires_effect_enabling=true` 没有 enable junction，改为直接可用；补回 `czx_ability_hydralisk_grooved_spines` 被刺蛇引用；爆虫被动改用实际 `wh2_dlc11_unit_passive_extra_powder` 图标/source type，修正重复 `unique_id`。

- 坦克血量复核：`wh_main_emp_veh_steam_tank` 原版 donor 同样 `main_units.num_men=3`，但土地战斗实体/steam-tank mount 是单辆坦克；此前把 3 误读为 3 辆并将 `bonus_hit_points` 降至 3200 属过度削弱，已恢复 donor 的 9052。蟑螂 700/只修正保留。
- 三个 pack 已构建至 `mod_output`，静态悬空引用审计 0 ERROR（148 WARN 为既有北方行省权限与 IA donor `leishou` 跨包引用提示）。首轮 watcher 更新了未加载的 `zzz_czx_digimon.pack`；used_mods 与 playset 确认实际加载名是 `zzz_czx_digimon_v2.pack`，误生成文件未在 playset，Fast End Turn pos113 保持不动。swarm/Pokemon/Digimon v2 data 已于 08:14/08:28 部署且 SHA-256 与 mod_output 一致，playset 未重排，Fast End Turn pos113 保持不动。错误名 DGM 文件仍留在 data 但未加载。Warhammer3 PID 20688 当前仍运行，本轮未中断/接管；最后的 used_mods 快照含 `zzz_czx_fast_end_turn.pack`，而 Fast Off 的 60 秒回归是另一轮配置，不在当前状态。本轮未对 Digimon 被动/宝可梦技能做游戏内画面回归，战役验证需避开已知 Fast End Turn campaign-battle crash。

## 2026-09-23：Fast End Turn 触发 campaign battle-init 闪退（已源码修复）

- 用同一战役存档、通过 Mod Manager，并手动点击预战界面的手动战斗按钮进行逐组 A/B。`zzz_czx_fast_end_turn.pack` 单独回加即可复现 `0xc0000005` 读 `0x20 @ Warhammer3.exe+0x1a0be3b`、148B stub；无 Event 2004。Global Lua Guard 单独回加、Pokemon+解锁组、虫群+数码宝贝+VMP 解锁组均通过。
- 原 114 项播放集仅排除 Fast End Turn 的 113 项回归通过（battle-start hook 27.4 秒、存活 >60 秒），证明它是充分触发项。
- **源码级定位**：首帧 `cm:add_first_tick_callback` 中的三条图形/内存偏好写入（`gfx_texture_quality`、`gfx_unlimited_video_memory`、`minimise_memory_usage`）是触发组——只删 `_apply_all` UI 回调仍崩，全删 `SetPref` 保留 UI 回调则通过；仅保留 `fast_forward_end_turns` 单项也通过最终回归。
- **修复与回归**：`czx_fast_end_turn.lua` 现只保留 `SetPrefAsBool('fast_forward_end_turns', true)` + `_apply_all` 速度下拉自动化，图形/内存偏好改由 `tools/set_memory_safe_prefs.py` 离线管理。已重打部署（pack 4694B），同一存档经 WMM 手动进入战斗：64 个 battle 脚本枚举完成、battle-start hook 26.5 秒执行、进程存活 >10 分钟、无新 dump、无 Event 2004。活动播放集改名 `WH3 Campaign Stable`（114 项含修复版 Fast End Turn）；原 114 项《全合集-非震旦》与《测试2》保留。详见诊断指南 §10.30。


## 2026-09-23：PM 动画补齐第二阶段——guard/getup 重定向

- 在第一轮 move clip 之后，按各 unit 的 `bin` 实际引用补齐剩余动作槽：`guard.anim`（7 只全员，bin 有 defend 引用）与 `getup.anim`（仅 pm004/007/009/025——其 hu1 系 bin 引用 `knockdown_facedown_getup`；pm001/003/006 bin 无 getup 引用，保留 idle 副本）。
- 经验：同一单位不同动作槽可混用不同 donor，**映射文件必须跟 clip 的 donor 骨架对应**——pm003 的 move 用 hq 映射、guard 用 wolf 映射（`pm003_wolf.json`），混用会在 bonemap 阶段报 donor 骨缺失。
- 全员 guard：pm001/003←`wf1_defend_01`(wolf01)、pm004/006/007←`rp1_defend_front_01`(raptor01)、pm009/025←`hu1_sws_defend_front_01`(humanoid01)；getup 统一 `hu1_sws_knockdown_facedown_getup_01`，pm004/007 另建 hu 骨映射。
- 落包静态验证：21 个新 clip 均非 idle 副本、skeleton_name/骨数与各自 PM 骨架一致；pack 15,202,032B/199 文件；游戏运行中由 `deploy_pending5` watcher 待退后复制。游戏内目视验收待做。

## 2026-09-25：Update 9.0 闪退定案——8 个版本不兼容包被禁用

- 9.0（build 25509431）晨间自动更新打穿 116 项《WH3 Campaign Stable》播放集；两个签名：`0xc0000005` 读 `0x20` @ `+0x52a21a`（挂载期崩）与读 `0x8` @ `+0x538a0a`（挂载完成后崩），均早于脚本枚举，非 OOM、非 CreamAPI、非当日更新包。
- 前端二分（`Warhammer3.exe <modlist>;` + `modified.log`/`mp_log.txt` 判据）定位 8 个真凶：`Unique_Faction_UI_III`、SFO 五包（main/warband/fesir/tla/brt）、`longer.pack`（依赖 SFO 主包）、`zz_diag_junction.pack`（本地诊断包，junction 指向 WH3 不存在的 WH2 Tomb Kings 组，单包复现 `+0x538a0a`）。其余 108 项前端验证通过；已从 `state.db` 当前播放集与 `enabled_order` 移除（备份 `scratch/crash_20260925/state.db.bak_*`），diag 包本体移至 scratch。
- 重要方法修正：`game_startup_mode battle` autotest 在 9.0 上 vanilla 也定死（`+0x1a957e7`），不能再当二分基线；改用前端启动二分，且"进程存活"须配合 `modified.log` 挂载数判据（挂载完会停在 press-any-key 待输入，不是卡死）。详见 §10.31。
- 遗留：8.1.1 老战役档 `campaign_load` 无 mod 也崩（`+0x243ae98`），为独立存档兼容问题；`twwh3-memreader.dll` 硬偏移注入物建议停用。

## 2026-09-25 晚：扩展玩法包 9.0 兼容补丁组（6 包全量修复部署）

- 对崩溃排查期被移出的 9 个扩展包做逐表审计（版本头对比 vanilla db.pack + RON `is_reference` 悬空键 + twui/bin/rmv2/bnk 格式头 + lua 外部调用），产出 6 个独立兼容补丁包 `czx_{luke,psw,chanliuzi,arthas,boudicca,xiang}_90fix`，均已部署进《全合集-非震旦》（补丁 pos 99-104、目标 pos 105-111，靠前遮蔽）：
  - 按当前版本重编码旧版表分片 44 张（psw 14 + chanliuzi 7 + arthas 5 + xiang 15 + luke 2 + boudicca 1），新增列填 vanilla 典型默认；v0 无标记表保持 v0。
  - 修 9.0 已删/改名键：`wh3_dlc20_group_chs_festus`→`wh3_dlc20_group_chs_festus_glottkin`（20 行）、`wh3_main_sla_cav*`→`wh3_dlc27_sla_cav_*_tormentors`、unit_sets 死键 `skv_infantry`→`skv_all`/`vmp_corpses`→`vmp_corpse_units`/`wh2_dlc11_emp_spearmen_swordsmen_flagellants_halberdiers`→`emp_infantry`（改名后按主键去重 7 行）。
  - twui：psw 过期 v141 `dlc24_formless_horror.twui.xml` 与 arthas 过期 `dilemma.twui.xml`（旧 `CanMakeChoice` 签名）均为无 mod 内容的旧版拷贝，已用当前 v142 vanilla 文件遮蔽还原；xiang 的 `character_details_panel` 系为真改写，保留。
  - `!!Prayer_of_star_witch_movie`、`zzz_czx_hero_grants`、`zzz_czx_vmp_pokemon_unlock` 审计零问题，直接回归播放集。
- 工具：`build_pack.py` 的 `encode_value` 补齐 `ColourRGB`/`ColourU32`/`I16`/`I24` 编码（修 ritual_targets 表必需）。
- 验证：全部补丁包逐表 `decode_db_table` 通过、头部版本=vanilla 当前版、非改名行逐值回读一致；播放集 `playset_items` 与 `enabled_order` 均为 114 项一致，补丁→目标顺序全部满足。游戏内回归待做。详见 references §10.32。
