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
