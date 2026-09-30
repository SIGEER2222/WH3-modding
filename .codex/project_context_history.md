# Codex Project Context — 事件叙事归档

2026-09-25 从 `project_context.md` 拆出：本文件是**按日事件叙事**（崩溃日结、部署记录、实测结论）的只追加归档。常驻主文件只保留路由与持久边界；当前本机/playset/具体 MOD 最近状态在 `.codex/runtime_state.md`。

- 已固化的通用经验在 `warhammer-mod-development_generic/CHANGELOG.md` 与 `references/`；本文件只供溯源查阅。
- WorkBuddy 侧同名硬链接：`.workbuddy/memory/codex_project_context_history.md`。
- 归档条目按原样保留，被后续条目推翻的结论仍有时间线意义；当前状态以实时查询为准，`runtime_state.md` 仅提供最近记录和路由。

---

## 归档条目：原「当前 MOD 环境备忘」内的崩溃日结（2026-09-19 ~ 09-20）

- **2026-09-20 崩溃日结**：全天 67 dump，每次进战斗必死（战役过渡与 autotest 同签名 `0xc0000005` 读 `0x20` @ exe+`0x1a0be3b`，外层 WER `0xc0000409 @ 0x10da8f1`，无 RES 排除 OOM）。根因=`battle_preferences\.singleplayer.battle_preferences` 缓存军表引用已被改名/禁用的 `czx_dgm_agumon`——悬空 key 在 AppData 不在 modlist，二分 pack 无效，纯原版也崩。已改名 `.bak_dead_agumon` 修复（证据 `scratch/crash_20260920/`），详见 references §10.14。教训：自造单位改名/删 key 须同步清 AppData 军表/army_setups/存档引用。
- **2026-09-20 晚间复发/签名分叉**：21:39:22 再现 `+0x1a0be3b` 读 `0x20`，21:41:14 旧实例改为 `+0x4ba1ae` 读 `0x8`，21:46:33 生成无 stream 6 的最小 dump；21:48:51 在已加载 `zzz_czx_global_lua_guard` 的新实例中仍为 native dump，内层 `+0x23b01c2` 读 `0x0`，WER 外层均为 `0xc0000409 @ +0x10da8f1`。22:04–22:09 又用真正空 modlist（仅 runtime 包）连续复现，内层多次回到 `+0x1a0be3b`；脚本只到 `battle_scripted.lua loaded`，无 RES 2004。重建后的主 `battle_preferences` 又由 `army_setups\last_setup_for_wh3_main_brt_aquitaine_classic.army_setup` 灌回 `wh3_cp1_bhashiva_qb1`/Bretonnia 配置，22:15/22:18 仍同签名；现已再次备份并移出两者等待验证。最新 stack 曾出现 QQPinyin，输入法/TSF 成为额外系统级嫌疑。另发现启动层 `steam_api64.dll` 缺失/损坏，Steam 校验已恢复该 298856B DLL（SHA1 `40D0AE44E090DB49B2309FB152FBD3E11124A376`）；这是独立于 battle init 的启动故障。**最近存档本身含 `czx_digimon`/`czx_swarm_units3`/`czx_aig3_plus` 等 10 个 Mod 标记，最新 temp 含 55 个 czx/dgm 引用；空 modlist 继续该存档不是 vanilla 对照。已用 `_launch_game([], token, "")` 启动无存档纯净主菜单，35 秒无 dump；从该主菜单进入 battle init 22:38:24、清空旧存档后 22:45:15 均以 `+0x1a0be3b` 崩溃，新 preferences 指向 `wh3_cp1_bhashiva_qb1` + `wh3_main_dae_daemon_prince` custom battle preset，Bhashiva preset 是当前首要触发器，需和新 vanilla campaign 普通战斗分开验证。** guard 只能拦 Lua callback，不能捕获 C++ 原生崩溃。
- **2026-09-20 深夜 purge+重装**：`save_games`/`temp`/`resume`/`battle_preferences`/`army_setups` 共 105 个文件归档到 `scratch/crash_20260920/purged_state_20260920_224341` 后清空；22:45:15 无存档空 Mod 仍以 `+0x1a0be3b` 崩在 Bhashiva preset——旧存档/缓存链全部排除，用户决定卸载重装。playset《全合集-非震旦》=114 项（98 steam + 16 local:data）；13 个本地包已用 `tools/build_pack.py` 从 `mod_files/` 重打并部署回 `data\`，mod_id 全部匹配（部署名≠源码目录名的：`zzz_czx_ancillary_sell→…_sell4.pack`、`zzz_czx_auto_tools→…_tools3.pack`、`zzz_czx_swarm_units→…_units3.pack`、`lalolalo9_autoconstruction→Lalolalo9Autoconstruction.pack`）。3 个本地包无源码仅存在过 `data\`：`!!ia_all_factions.pack`（Zerg虫群帝国 3656495027 的全派系解锁，疑似随工坊项下发）、`!!!wyccc_cn_localization_patch.pack`/`_batch2.pack`（Wyccc 文本补全，疑随 wyccc 工坊项下发）——工坊回下后扫描 item 文件夹恢复；`mod_id=local:data:sha256(data\规范路径[:18])`，文件名不变则 id/排序/别名自动复活。
- **2026-09-19 崩溃日结**：全天多次闪退实为多根因叠加——上午定案的 commit OOM（pagefile 已走注册表修为 C: 40GB 初始/48GB 最大并重启生效，上限 ~63GB；WMI 写不动时用 `scratch/crash_20260919/fix_pagefile3.ps1`），晚间数码宝贝系 pack（`zzz_czx_digimon`/`zzz_czx_dgm_patch`/`zz_dgm_nobin`，并行会话全天在重建）加载即让 WH3 单进程提交冲到 55.4GB 打爆上限——**用户实测禁用后恢复正常**。另有 init 期 `0xc0000005 @ 0x14182fb2b`（battle autotest 连发同址死）与 `0xc000041d` ntdll TSF 回调异常（campaign HUD 建 search_panel 时）两个次要签名，详见 `references/crash_and_load_order_diagnostics.md` §10.10/10.11。

---

## 归档条目：2026-09-21 ~ 09-24 按日记录

- **2026-09-21 晨间闪退复发（与上一条不同根因）**：01:03–06:39 又产生约 80 个 dump，`script_log` 全是 148B stub，外层恒为 `Application Error 1000 / 0xc0000409 @ Warhammer3.exe+0x10da8f1`，但**无内层 `0xc0000005`**，异常参数 `[0]=0x7` = `FAST_FAIL_FATAL_APP_EXIT`（进程主动 fail-fast，非空指针）。每次崩溃同一秒都命中 **System `Event 2004` 内存资源耗尽**：`Warhammer3.exe` 提交 **40.5/40.6/40.9/43.3/43.8/46.0/46.2/46.5 GB**；本机 RAM 15.8GB、pagefile `C:\pagefile.sys` 40/48GB、提交上限约 63.8GB，同时 Devin/steamwebhelper 再吃掉数 GB。根因 = AppData `scripts\preferences.script.txt` 在重装后被写成 `minimise_memory_usage false` + `gfx_texture_quality 3` + `gfx_unit_size 3`，而通过全验证矩阵的同目录备份 `preferences.script.txt.bak_reinstall_test` 是 `true` + texture 2。已把 `minimise_memory_usage` 改回 `true`（备份 `preferences.script.txt.bak_20260921_065145`）。**判据固化**：同签名 dump 先查 `Get-WinEvent -FilterHashtable @{LogName='System'; Id=2004}`，命中即 OOM，**不要二分 pack**；无 2004 才回退到 §10.14（AppData 悬空单位 key）/ §10.18（pack 缺 `battle_skeletons_tables`）路线。当前 C: 剩 20.1GB、E: 剩 16.5GB，已无余量再扩 pagefile，只能压 WH3 自身提交（若仍崩再降 `gfx_texture_quality`/`gfx_unit_size` 到 2）。
- **2026-09-21 二次 OOM 定案（06:50）**：重装验证矩阵通过后仍崩，用户报"并未修复"。重新取证：每次 dump 同秒都有 System **Event 2004**（`Warhammer3.exe` 提交 40.6–47.1GB，上限 63.8GB，物理内存仅 16GB）→ 是 OOM，不是 §10.14 悬空 key（该签名 `0x1a0be3b` 已不再出现，说明 9-20 的修复有效）。**注意 `minimise_memory_usage` 当时已是 true 仍崩**——ultra 贴图档（自造单位 dds：swarm 170MB + digimon 69MB）单独吃光余量。已把 `gfx_texture_quality`/`gfx_unit_size`/`gfx_unit_quality`/effects/terrain/shadow/tree/grass/water/sky 全部降到 2，备份 `preferences.script.txt.bak_20260921_oom`；新增幂等工具 `tools/set_memory_safe_prefs.py [--level 2|1] [--dry]`。判据固化在 references §10.19：**先看 System 2004，命中即 OOM，不要二分 pack**。坑：游戏运行中改 preferences 会被干净退出写回覆盖，须关闭后改并复查。**2026-09-21 傍晚实锤复发**：晨间降档后，15:42 一次干净退出把 prefs 写回 `minimise_memory_usage false`+全 ultra，11:22–18:26 连续 OOM（WH3 commit 40.8–51.4GB，18:26 为 AppHang）。18:46 重跑 `set_memory_safe_prefs.py --level 2` 修复并复查通过；用户选择不设只读、先用 level 2，复发再降 level 1。当日嫌疑包：swarm 重建涨至 221.7MB、digimon 105.5MB、新增 pokemon/animset。**复发排查固定动作：先 `Select-String preferences.script.txt -Pattern 'minimise_memory_usage'` 确认是否又被写回。**
- **2026-09-21 重装完成与最终归因**：游戏重装（83GB）+ 工坊 105 项回下 + Steam 校验修复 `steam_api64.dll`。**marine 崩溃根因实锤**：`zzz_czx_swarm_units3.pack` 的 `battle_animations_table` 引用骨架 `czx_marine`，但 pack 缺整张 `battle_skeletons_tables`（同缺 `unit_sets`/`ui_unit_groupings`）→ battle init 空指针。源 TSV 版本戳不可信（写 v56/5/3，游戏实际读 v17/2/1）。修复=旧包补三表+清 stale 单位（cishe/gou/leishou）+补 loc 缺口；`tools/sync_pack_to_source.py` 已把部署包反同步回 `mod_files/zzz_czx_swarm_units`（含凯瑞甘 agent 全套，此前源码缺失）。state.db 曾被截成 2 项，已从 `state.db.bak_deploy_ia_all_factions` 恢复 114 项 playset_items + enabled_order。验证矩阵全过：swarm/digimon+swarm/全 playset 自定义战斗 + 全 playset IE 战役初始化到回合处理。仍缺 `!!!wyccc_cn_localization_patch*.pack`×2（无源，纯文本，不崩）。

### 2026-09-21 晚：全 playset bad_alloc 收官与归因修正
- 全 playset(114mod) 菜单启动在 ultra 档 commit 4→18.4GB 爬升后 `0xe06d7363`(bad_alloc) 崩；`set_memory_safe_prefs.py --level 1` 后同配置稳定 3.8GB/180s+。该机 114-mod 合集实测须 level 1。
- `+0x10da8f1` 只是通用 fail-fast 出口：内层 `0xe06d7363`=C++异常(bad_alloc)、`0xc0000005`=null-deref，归因必须读 mdmp 异常流，不能只看 WER。
- 修正：早前'旧 AppData 触发 +0x1a0be3b'系误判——Copy-Item 拷目录嵌套 `scripts\scripts\` 致 prefs 未生效+并行压测负载巧合；旧用户态全部拷回后仍通过。间歇 init 崩与并行会话压测窗口强相关。
- 游戏现以 level 1 在主菜单运行(pid 35276)；旧 profile `Warhammer3.fresh_test_193357` 的 crash_report 17.6GB 待确认清理。


### 2026-09-22：数码宝贝 v2 / 宝可梦 / 虫群整合部署

- **数码宝贝 v2（`zzz_czx_digimon_v2`，104 只正式中文名单位）**：源目录由 `zz_test_dgmB2` 改名而来；缺的 70 套骨架/动画/bin 从 `zz_test_dgmslim` 补齐（两者模型文件逐字节一致，安全）；修两处坏数据：`land_units.ground_stat_effect_group` 非法值 `medium`→`large`（7 行，注意 capture_tier 等列的 medium 是合法值，替换必须按列定向），`unit_special_abilities.activated_projectile` `wh_main_*`→`wh2_main_spell_high_magic_soul_quench*`（8 行）；loc 按 `ROSTER.tsv` 补齐 104 条短描述+103 条历史描述（构建门槛 short≥8 字/hist≥40 字）。pack 构建通过（227MB/10692 文件），部署用 `--deploy-name zzz_czx_digimon.pack` 原位升级（mod_id 不变，playset pos 107 保留）。
- **宝可梦首部署**：`zzz_czx_pokemon`（7 只）+ `zzz_czx_vmp_pokemon_unlock`（vmp 招募，含 pkm_025 皮卡丘共 7 行）已在 playset pos 111/112。
- **虫群合并**：`zzz_czx_swarm_expansion` 实质是 feilong/zhanglang 的 6 张新贴图（rmv2/wsmodel/material 与主包逐字节相同），已合入 `zzz_czx_swarm_units`；其 DB/loc 全是主包子集或过时内容（cishe/gou/leishou 已删除单位），不合并。另补 `ui_unit_groupings_onscreen_chong_zu=虫群` loc。swarm_units 重部署 pos 108。
- **playset 手术**：`zzz_czx_dgm_patch`（pos 109）从 `playset_items` 移除——其 `czx_dgm_agumon/gabumon` key 与 v2 冲突且被 v2 取代；pack 文件留 data\ 不加载。`zzz_czx_swarm_expansion` 本就不在 playset。
- **`zzz_czx_vmp_unit_unlock`（pos 106）**：68 行解锁中 49 个 `dgm_chr###` 单位随 v1 被替换成为悬空引用（无害，游戏跳过未知 unit key）；`czx_dgm_*`（2 个）+ 虫群（16 个）仍有效。
- **遗留**：`data\zzz_czx_digimon.pack` 部署时游戏正在运行被锁（PID 7280），需关游戏后重跑 `build_pack.py zzz_czx_digimon_v2 --deploy --deploy-name zzz_czx_digimon.pack`。audit 对全部相关包 0 ERROR，仅 `wh3_main_cth_the_northern_provinces` 已知误报 WARN。
- **仓库根目录误生成文件** `C:\Users\...\state.db`（WSL 相对路径事故，0B+1B 两个）已删除。

### 2026-09-22 晚：基础兵种一级解锁 + vmp_unit_unlock 回归 playset
- **用户要求**：虫群/数码宝贝/宝可梦的基础单位不要都挂二三级建筑，跳虫级基础兵要一级解锁。
- **`zzz_czx_digimon_v2`（pos 100）**：16 只成长期（ROSTER `stage=rookie`：亚古兽/加布兽/比丘兽/巴达兽/哥玛兽/巴鲁兽/甲虫兽/基尔兽/妖狐兽/多路兽/小狗兽/v仔兽/拉拉兽/向日葵兽/叮克兽/兹巴兽）改挂脚手架 294 建筑的**全链补全**（512 个建筑含全部 1 级军事建筑），成熟期→3级、完全体/究极体/BOSS→4级不变。`building_units_allowed` 10944→14432 行。
- **`zzz_czx_vmp_unit_unlock`**：虫群基础兵 `czx_feilong`(飞龙,t1)/`czx_inf_marine`(感染枪兵,t2)/`czx_baochong`(爆虫,t2) 从 `wh_main_vmp_necromancers_1` 改挂**僵尸同款主城链**（`wh_main_vmp_settlement_major_1-5`+`minor_1-3`+`special_settlement_{altdorf,castle_drakenhof,couronne}_1-5_vmp`，共 23 行/单位），开局即招；其余 13 个虫群单位仍挂禁忌图书馆。68→134 行。注意源码里跳虫 `czx_gou`/刺蛇 `cishe`/雷兽 `leishou` 早已删除（loc 残留无害）。
- **`zzz_czx_vmp_pokemon_unlock`（pos 112）**：4 只基础形态（妙蛙种子/小火龙/杰尼龟/皮卡丘，700 费）同样改挂主城链；3 只进化型（妙蛙花/喷火龙/水箭龟，1600 费）留禁忌图书馆。7→95 行。
- **playset 修复**：`zzz_czx_vmp_unit_unlock.pack` 文件一直在 data\ 但 mod_id `local:data:3e31733718553dbf4f` 不在 playset（9-21 重装改名重打后漏回），已手工补入《全合集-非震旦》pos 113 + enabled_order + user_mod_data，state.db 备份 `.bak_deploy_vmp_unit_unlock`。重装后本地包"文件在但不在 playset"的坑要复查——**核实方法**：`local:data:<sha256(小写正斜杠路径)[:18]>`（已验证 `sell4`→`af5c4027ee754b2138`）。
- **部署**：游戏运行中 pack 被锁无法覆盖；三包已构建在 `mod_output/`，挂了个 powershell 监视器 `scratch/deploy_pending/copy_when_game_exits.ps1` 等 Warhammer3 退出后自动拷进 data\（日志 `scratch/deploy_pending/log.txt`）。下次启动游戏生效。
- 一次性脚本 `scratch/tier1_recruit_20260922.py`（WSL python3 可跑，ROOT 用 `__file__` 定位）；通用规则已记入 `references/unit_creation_workflow.md`"招募建筑等级门槛"节。

### 2026-09-22 深夜：vmp_unit_unlock 清雷 + 精英分层
- **删 `czx_kerrigan`/`czx_kerrigan_lord` 三表全部行**（building/groupings/exclusive）：这两个是 agent key，按既往记录进 `units_to_groupings_military_permissions` 会启动崩溃；且该包此前从未真正进 playset，这次启用前必须清。战役凯瑞甘已由 swarm 包改走 `Lin_Summon_Servant.pack` 的 `lin_all_kerrigan_zerg` 召唤（swarm notes 已声明依赖 Imperial Arbiter + Lin_Summon_Servant）。
- **删 52 个 v1 `dgm_chr###`/`dgm_g133`/`dgm_u133` 死 key**（v1 `zzz_czx_digimon` 不在 playset）；保留 `czx_dgm_agumon/gabumon`（v2 有效 key，冗余无害）。building 表 134→82 行，groupings/exclusive 68→16 行。
- **精英分层**：虫群精英（baolongshou/dehaka/hd_dblack/inf_tank/mangshou）与宝可梦进化型（venusaur/charizard/blastoise）从 `necromancers_1` 移 `wh_main_vmp_necromancers_2`（原版 terrorgheist 同级的图书馆 2 级）；中阶（zhanglang/jibian/hd_white/black/green/inf_diamondback）留 necromancers_1。
- **部署**：监视器 `scratch/deploy_pending2/` 已在游戏间隙把两个 unlock 新包拷入 data\（md5 与 mod_output 一致），用户 21:25 启动的游戏已加载修正版。swarm_units 本体：游戏 21:28 短暂退出窗口内 `deploy_pending3` ps1 与 `scratch/_deploy_swarm_on_exit.py` 两个看守同时触发，build_pack --deploy 于 21:28:50 把"召唤 lin_all_kerrigan_zerg"版写入 data\（mod_id `local:data:14ace1a3e1a423bd2a` pos 110 不变，state.db 备份 `.bak_deploy_zzz_czx_swarm_units`），用户 21:31 重启的游戏已加载该版；同时 `zzz_czx_aig3_plus` 也重部署（新增 `lin_all_kerrigan_base_0/ultimate_0` 的 AIG3 mage_highvalue 分类——AIG3/auto-ability 表键是**战斗单位 key** 而非 agent subtype：Lin 凯瑞甘 agent subtype `lin_all_kerrigan_zerg` 的 associated_unit_override=`lin_all_kerrigan_base_0`，开技能后换 `lin_all_kerrigan_ultimate_0`；`zzz_czx_battle_ui` 的 auto_ability 表已同步补两行，该包不在 playset 仅重打到 mod_output）。**21:38:01 最终版已部署**：游戏 21:37 退出间隙看守 v3 完成 `build_pack.py --deploy`，data\ 包=156806604B 含 `czx_kerrigan_cleanup_legacy` 清理逻辑，用户随后重启的游戏（PID 19220）加载的是最终版。游戏内表现待实测。
- **核实「跳虫」**：swarm 主包无跳虫单位——`gou`（跳虫）/`cishe`（刺蛇）只存在于 `zzz_czx_swarm_expansion` 源码且该包不在 playset（已确认是已删除单位）。现役虫群基础兵=飞龙/感染枪兵/爆虫三只，均已一级主城可招。

### 2026-09-22 深夜续：跳虫/刺蛇恢复（用户要求）
- **删除原因**：gou/cishe/leishou 从来不是完整单位——只有 main_units 行+ability 定义+loc 描述+裸 rigid_model_v2，缺 land_units/variants/wsmodel/材质/图标全套；9-21 修包时按悬空引用清掉。
- **恢复方式 = donor 变体路线**（不用那俩裸网格）：gou 借用原版 dire wolf（man_animation `wf1_dire_wolf`、entity `wh_main_monster_wolf_hound_blood`、武器 `wh_main_vmp_wolf_fangs`、variant `wh_vmp_dire_wolves`、兵牌 `wh_main_vmp_dire_wolves`）；cishe 借用墓穴巨蟒（`sn1_sepulchral_stalker_halberd`/`wh2_dlc09_tmb_mon_sepulchral_stalker`/`wh2_dlc09_tmb_halberd_stalker`+远程 `wh2_dlc09_tmb_stalker_gaze` 吐刺/variant `wh2_dlc09_tmb_sepulchral_stalkers_halberd`）。全部引用原版 key，零新资产风险。
- **数据**：gou=war_beast 60人 t1 750费 attr=czx_zerg_baneling，技能=肾上腺素+代谢加速+虫群狂暴（pack 里早已定义）；cishe=monstrous_infantry 12人 t3 1950费 attr=czx_zerg_beast，技能=棘刺齐射。两单位已补齐 land/main/unit_variants/unit_set/ability junction/description/currency/25派系 custom_battle 全链，loc 名称已加。
- **招募**：gou→主城链 23 建筑（一级即招，虫群"小狗"定位）；cishe→necromancers_1。groupings/exclusive 已加。leishou（雷兽）未恢复——连 main_units 行都没有，如要恢复需用 warsphinx donor 从零建（包里有 leishou_2.rigid_model_v2 裸网格）。
- **wh3diag db 输出截断坑**：单表只打印前 ~25 行然后 `... +N rows`，验证行数对不对别看 grep 命中数。
- **坑**：exec 环境会预展开命令里的 `$var`/`$(...)`/反引号（含 heredoc 内），写 ps1/含$脚本须用 chr(36) 占位符法或 write 工具。

### 2026-09-23：兵牌立绘化 + 宝可梦卡面 ? 修复
- **? 根因**：宝可梦 unit_variants.unit_card 用了 pmv###（variant key 误当卡面 key），实际图标文件叫 pm###——ui/units/icons/pmv###.png 不存在 → 游戏显示 ?。已改为 pm001/003/004/006/007/009/025。注意 venusaur 的 variant 列保持 pmv003 不动（用户手修的自洽链：pm003 动画↔pmv003 变体↔pm003 vmd），只改最后一列 unit_card。
- **立绘替换**：zzz_czx_digimon_v2 104 只 + zzz_czx_pokemon 7 只全部从「模型截图」换成官方立绘。源：wikimon.net（MediaWiki，Special:FilePath/<页名>.jpg 直链 + api.php prop=images 兜底；站内命名多用空格分词如 Metal Greymon/War Greymon，X 抗体页名 Xxx (X-Antibody)）与先前已下载的宝可梦 475px 官图。脚本 scratch/unit_art/fetch_dgm.py + dgm_map.py（unit key→wikimon 候选页名表）。
- **卡面规格**：icon/portrait=60×130、infopic=120×260 RGBA。方形立绘按 cover 居中裁切（垂直偏上 bias 0.40 保头部），转换逻辑在 scratch/unit_art/make_cards.py。三张同名不同尺寸写 ui/units/icons/、ui/portraits/units/no_culture/、ui/units/infopics/。
- **虫群不换图**：现役 16 个图标本身是带材质暗底渲染（非裸截图）；SC2 官方虫族立绘未能拉到（fandom/liquipedia/百度均被拦，bing 图搜结果退化）。
- **已重打部署**：zzz_czx_digimon_v2.pack（303MB/10900 files，pos 100）、zzz_czx_pokemon.pack（15.4MB/192 files，pos 103），pack 内抽验 pm025/czx_dgm_gatomon/czx_dgm_wargreymon 为新图。
- **本机工具**：Windows Python313 带 PIL 12.3.0（/mnt/c/Users/22448/AppData/Local/Programs/Python/Python313/python.exe）；WSL python3 无 PIL，无 ImageMagick——之前记的 "ImageMagick 12.3.0" 实为 PIL。

### 2026-09-23 续：gou/cishe/leishou 改挂 Imperial Arbiter 真模型（用户指出原版 mod 自带）
- **最终架构**：`Imperial Arbiter.pack`（ws 3656495027，playset pos 111）本身含 gou/cishe/leishou 的**完整实现**——wsmodel/rmv2/materials/tex 全套（`wolf01/gou/`、`sn01/cishe/`、`bc1/tmb/tmb_warsphinx/leishou_2`）、variants/unit_variants/兵牌/icons+infopics、`skv_chongzu` unit_set 与动画映射（`wf1_dire_wolf_gou→wolf01`、`sn1_sepulchral_stalker_halberd_cishe→snake01`）。我方 swarm_units（pos 110，靠前胜出）只保留自定义的 main/land（数值+技能）与 unit_variants（variant/card 改指 `gou`/`cishe` 同名 key，恰好与 IA 行同靶），variants/动画/兵牌全靠 IA。
- **冲突清理**：我方源里两个**不完整**裸 rmv2（`wolf01/gou/g.rigid_model_v2`、`bc1/.../leishou_2.rigid_model_v2`，缺 wsmodel/材质/贴图）与 IA 同路径且我方靠前会遮蔽完整版——已移出包到 `scratch/donor_dupes/`。
- **leishou 雷兽借此恢复**：无需自建——IA 提供全部定义，我方只加 unlock 包招募行（`wh_main_vmp_necromancers_2`，精英位）+ exclusive/groupings/custom_battle（25派系）+ loc 名称描述。
- **兵牌**：gou/cishe/leishou 的 unit_card=同名 key → IA 提供 `ui/units/icons|infopics/*.png`（真立绘非截图）；IA 无 `portraits/no_culture`——已从 IA icon 缩放生成三张 60×130 放进我方包补齐。
- **依赖声明**：swarm_units 与 vmp_unit_unlock 的 notes/dependencies.txt 均加 `Imperial Arbiter.pack`（build_pack 会写进 PFH5 头+Mod Manager 依赖提示）。land_units 动画列用原版 key（`wf1_dire_wolf`/`sn1_sepulchral_stalker_halberd` 均存在于 vanilla battle_animations_table，gamedata 已验证），不依赖 IA 自定义动画 key。

### 2026-09-23 续2：三包数值平衡（用户拍板：跳虫/刺蛇走虫群特色，雷兽保留 IA boss 值）
- **跳虫 gou**：60→80 人虫海（恐狼同编制），750 费不变——性价比偏高是刻意特色；md14/hp72/0甲保持脆皮。
- **刺蛇 cishe**：玻璃炮化——12→8 人（对齐 IA 原设编制）、md34→26、士气55→50、1950→1800；ma30+棘刺齐射+吐刺远程保留。
- **雷兽 leishou**：不加覆盖行，吃 IA 原值（ma85/md70/hp18000，2750 费挂 necromancers_2）。
- **顺手修的真离群值**：`czx_zhanglang` 蟑螂 12人×6012hp（克隆单体墓穴蝎子忘改血量→7.2万总血）降到 700/只=8400 对标巨蟒 6912；`czx_inf_tank` 当时把 `main_units.num_men=3` 误读成 3 辆独立蒸汽坦克并降到 3200 HP（旧判定已撤销，见下文恢复 donor HP=9052） ≈ 一辆原版。
- **宝可梦**：3 只进化型 tier 1→3（数值本来就是三档单体怪）；4 只基础型护甲 wh2_main_body_95→wh2_main_body_40。tier 字段主要影响 AI 招募权重/品质分类，不改招募建筑档位。
- **数码宝贝 104 只不动**：成长期(90-100人/~400)→成熟期(8-12人/~1000)→完全体(3-6人/~1500-1700)→究极体(3人/~2600)→t5 单体 boss(2400-5600/hp1-2万) 曲线自洽，无离群。
- **平衡审计产物**：`scratch/balance_audit.txt` 是前一轮快照；本轮复审校正了坦克误判，不能再把 `main_units.num_men=3` 当作 3 辆独立 Steam Tank。原版 `wh_main_emp_veh_steam_tank` 同样 num_men=3，战斗实体/steam-tank mount 是单辆；`czx_inf_tank` HP 已从错误的 3200 恢复到 donor 9052。蟑螂 700/只、gou 80只、cishe 8只等既定平衡保持。

### 2026-09-23 续3：三包技能与动画复审
- 宝可梦 7 只此前没有技能链；新增主动技能（毒粉/毒花爆发/小火焰/喷射火焰/冰冻光束/十万伏特）及 4 类被动（毒性藤蔓、火焰亲和、龟壳远程抗性、皮卡丘魔法近战），全部使用已有游戏效果 key，并补齐技能 Loc。技能使用次数有限，具体强度待战斗实测。审计同时发现基础型护甲误写为不存在的 `wh_main_body_40`，已改成表中有效 key `wh2_main_body_40`。
- `cishe` 的刺棘齐射去掉无 enable junction 的效果门槛，并挂回槽状脊刺被动；爆虫改正确的额外火药被动图标/source type，修复 duplicate unique_id。
- Digimon 被动属性组复核：原 archetype groups 将 `causes_terror` 广泛施加到非飞行系低阶单位；现为14组/40条 attribute junction 按阶段拆分。16只成长期去掉 fear/terror/wallbreaker，保留对应的飞行/潜行/心理免疫；T2/T3保留 fear，34只 T4+ 单体精锐/Boss 才有 terror。104只中103只具主动技能；RosemonBM按设计使用再生+Tifaret自我增益两项被动，不另强加主动。
- 动画文化路由：Digimon 104 个动画 key 原先仅注册 Cathay；现在按合法 `culture_pack_ids_tables` 集合扩展。Pokemon 的 24→29 culture packs，swarm 为四个自定义 animation key 与 `gou/cishe/leishou` donor 键补齐缺项。
- 静态动画/蒙皮核验：DGM 104/104、自造 Pokemon 7/7 的 RMV2 skeleton 与 `.anim` skeleton 对齐，所有加权顶点骨骼索引在范围内；三包自定义动画 key 均有 battle DB/bin、attack clip 与有效 culture pair；DGM 104/104、PKM 7/7、swarm 4/4 动画数据可解析，DGM/PKM 蒙皮索引全通过，culture pair 覆盖率 100%。PKM 7 只的 `move.anim` 原与 `idle.anim` 字节完全相同；已通过新工具 `tools/retarget_bonemap.py`（显式语义骨映射 + 世界空间旋转差值）生成真实 walk cycle：pm001←wf1_walk_01(wolf01)、pm003←hq01_walk_1(heavyquadruped01/Stegadon，宽展腿匹配)、pm004/006/007←rp1_walk_01(raptor01/史兰魔驹)、pm009/025←hu1_sws_walk_01(humanoid01)。关键坑：PM 骨架 L/R 与 vanilla 镜像相反（PM `L*` 在 +X，vanilla `*_left` 在 -X），映射须 our-L→donor-right；animroot 含前进 Z 位移按骨盆高度比缩放（0.15~0.72）；妙蛙花足部仍残留 ≤0.09m 穿地（宽展腿+damp0.4 后）。骨映射存 `scratch/pm_walk_maps/`，渲染预览 `scratch/pm_walk_out/*.png`；游戏内目视验收待做。swarm 仅 `czx_hd_white` 有 65/33174 个零权重顶点（其余可移动部件全有权重），需游戏/AssetEditor目视确认那一小块是否是附件。
- 本轮没有修改 RMV2、VMD、材质或贴图。三个 pack 已重建到 `mod_output`；swarm/Pokemon/Digimon v2 data 已于 08:14/08:28 部署且 SHA-256 与 mod_output 一致。当前 `Warhammer3.exe` 08:27 后再次启动，未关闭/接管；本轮尚未游戏内回归。第一轮 watcher 按旧名更新了未在 used_mods 中加载的 `zzz_czx_digimon.pack`；现役 `zzz_czx_digimon_v2.pack` (`local:data:6d429f74a958fd64f5`, pos100) 已在最终 DGM 被动属性修正后重部署；错误命名文件留在 data 但不在 playset/used_mods。`fd0eb1a79c73854428` 已核实不在任何 playset；pos113 `b8b674...` 是 Fast End Turn，保留不动。`scratch/deploy_correct_dgm_after_game_20260923.ps1` DGM 被动属性最终修正后再次部署 Pokemon 与 active `zzz_czx_digimon_v2.pack`；三包 data 与 mod_output SHA-256 一致，`used_mods` 仍是既有 playset（含 v2、Pokemon、swarm），没有 state.db 删除。错误 DGM id fd0 缺席；pos113 Fast End Turn 保持原样；非活动 `zzz_czx_digimon.pack` 留在 data。Warhammer3 当前 PID 20688 运行中，不关闭/接管；最后的 used_mods 快照含 `zzz_czx_fast_end_turn.pack`。此前 Fast Off 60 秒回归是另一轮配置，不代表当前状态；本轮未做游戏内单位回归。

### 2026-09-23 续4：Fast End Turn 触发战役战斗崩溃（已源码修复）
- 同一战役存档、经 WMM 且手动点击预战界面的“手动战斗”后，114 项全合集与 `zzz_czx_fast_end_turn.pack` 均加载时复现 `0xc0000005 @ Warhammer3.exe+0x1a0be3b`（读 `0x20`、148B battle stub），无 Event 2004。
- 受控分组确认 `zzz_czx_fast_end_turn.pack` 单独回加即可触发；Global Lua Guard 单独回加通过。Pokemon+解锁组、swarm+Digimon+VMP unit unlock 组也通过。
- 源码级 A/B 定因：首帧 `SetPref` 组中 `gfx_texture_quality`/`gfx_unlimited_video_memory`/`minimise_memory_usage` 三条图形/内存偏好写入是触发组（组内未再单条隔离）；`_apply_all` UI 下拉回调与 `fast_forward_end_turns` 开关均单独验证通过。
- 修复版（保留 fast_forward + UI 回调、删三条 gfx/内存写入）已部署，pack 4694B；同存档手动战斗回归通过（battle-start hook 26.5s、64 脚本枚举、存活 >10min、无 dump/2004）。活动播放集 `f43f...` 已改名 `WH3 Campaign Stable`（114 项含修复版）。原《全合集-非震旦》114 项与《测试2》106 项保留。图形/内存档位今后用 `tools/set_memory_safe_prefs.py` 离线管理，不在 Lua 首帧改写。


### 2026-09-23（5）PM guard/getup 重定向补齐 + 部署监视器
- 在既有 move clip 之外补齐 bin 实际引用的其余动作槽：`guard.anim` 7 只全部换成真剪辑（pm001/003←wf1_defend_01 wolf01、pm004/006/007←rp1_defend_front_01 raptor01、pm009/025←hu1_sws_defend_front_01 humanoid01），`getup.anim` 仅 pm004/007/009/025 需要（其 hu1 系 bin 引用 knockdown_facedown_getup；pm001/003/006 bin 不含 getup 引用，保留原 idle 副本无害）；pm004/007 的 getup 用新建的 hu 骨映射（`pm004_hu.json`/`pm007_hu.json`，映射与 move 的 raptor 映射各自独立）。
- 映射规则：guard/getup 按各自 clip 的 donor 骨架选映射文件，不沿用 move 的映射；pm003 guard 须用 wolf 映射（`pm003_wolf.json`）而非 hq 映射。
- 落包验证：7 只 move/guard/getup 均非 idle 副本（sha 互异）、skeleton_name/骨骼数与各 PM 骨架一致、时长 0.9~2.7s。pack 重建为 15,202,032B/199 文件。
- 部署：`zzz_czx_pokemon.pack` 旧版仍在 data\（游戏 PID 20688 运行中），新监视器 `scratch/deploy_pending5/copy_when_free.py`（pid 15976，8h 窗口）等待游戏退出后自动复制 + sha 校验 + 写 done.txt。游戏内目视验收（走/防/起身/攻击/技能特效）仍是未做项。

### 2026-09-23 续6：三包补 animpack 容器（无移动/攻击动画根因确认+部署完成）
- **根因**：三包自定义动画集全部以 loose `.bin` 放在 `animations/database/battle/bin/`——战斗系统不索引 loose bin，必须装 `.animpack` 容器（vanilla/IA/数码v1 无一例外）。9-19 文档已记此规则但生成脚本（digimon_batch/build_pokemon_stage2/虫群克隆）从未产出 animpack。症状=模型正常进场、全程绑定姿势、无任何动画。
- **修复**：新工具 `tools/pack_animsets.py` 离线打包 animpack（格式 u32 count + 每条 {str16 内部路径 + u32 len + bin bytes}，无需 AssetEditor）。三包各生成 `<mod>_animsets.animpack`：PKM 7 条、DGMv2 104 条、swarm 4 条 animset；离线解析全部通过、无缺失引用。
- **附带修复**：4 个 bin 引用 `reference_poses/czx_*.anim` 但实际文件名是 `pm###.anim`（改名遗漏）——已用 anim_rw 改 skeleton_name 落盘为 czx_* 名 + 补 invmats。21 个"缺 .anm.meta"骨架经查为 sn1/bi1/wf1/sp1 族，vanilla 本就无 meta，无需补。
- **部署**：`zzz_czx_pokemon.pack`→同名、`zzz_czx_digimon_v2.pack`→同名、`zzz_czx_swarm_units.pack`→`zzz_czx_swarm_units3.pack`（部署名不同），三包已复制到 data\，SHA-256 与 mod_output 逐一校验一致（watcher `scratch/deploy_pending6/done.txt`），部署时游戏未运行。
- **文档修正**：RMV2 v8 头骨架名在 offset 12（旧记 offset 8 错，offset 8 是 u32 字段），已改 references 两处；animpack 规则已补充 pack_animsets 离线生成法+验证法。
- **待办**：用户游戏内实测移动/攻击/防御/死亡动画是否恢复——这是唯一未验证环节。若仍无动画，下一步查 used_mods 实际加载包名（旧 `zzz_czx_digimon.pack` 非 v2 不在 playset）、animpack 命名/位置约定、动画槽语义。

### 2026-09-23 续7：animpack 格式精修 + 自测战斗（环境崩溃阻塞中）
- **格式复核**：对比三个工作范本——数码 v1 chr###.animpack = 裸表（u32 count + str16 path + u32 len + bin bytes，无压缩）；vanilla/IA = u32 解压尺寸 + LZ4 frame 包裹同一张表。两种游戏都认；我们的裸表与 v1 逐字节同构。
- **loose bin 删除**：v1 工作范本 = 50 animpack + **0 loose bin**；三包原先是 animpack+loose bin 并存。为消除重复注册/遮蔽风险已删全部 loose `.bin`（swarm 的 `.bin.bak` 补丁备份挪 `scratch/swm_bin_bak/`），重建后三包均为 animpack-only 布局。
- **部署**：三包已重新部署（pokemon/digimon_v2 同名，swarm→`zzz_czx_swarm_units3.pack`），SHA 与 mod_output 一致。
- **自测战斗**：`scratch/battle_animverify.xml`——敌方 vmp 放 10 个自定义单位冲锋（走/跑/攻/死全演），我方 emp 原版兵接战；culture 行已核两派系全覆盖。`tools/battle_autotest.py` + `scratch/retry_battle.py` 拉起，截图用 `scratch/anim_verify/shoot_loop.py`（PIL ImageGrab，输出拷到 `C:\Users\22448\AppData\Local\Temp\animverify\` 供 read 看图——scratch 被 gitignore read 工具拒读）。
- **阻塞**：环境级早期初始化崩溃 ~14 连挂（+0x2cfe551/+0x4926f0/+0x2ccd91x，全是已知 vanilla 同签名环境崩溃，非包问题）；retry_battle 30 次循环跑着等窗口。若窗口一直不来，用户自己开游戏测即可——包已就位。
- **完整交接文档**：`.codex/handoff_animpack_fix_20260923.md`（根因/格式细则/验证清单/测试资产用法/下一步/坑位，供接手 AI 直接续作）。


## 2026-09-23 晚：matched-combat 闪退根因修复（已部署验证）

- 根因：自定义动画套件 bin 的**内部套件名**未注册进 vanilla animations/matched_combat/attila_generated.bin 注册表；遇可触发 matched-kill 的敌人（绿皮等 hu21 系）时查询返回 -1 → +0x2ccd917 崩溃。基斯里夫/帝国/震旦不触发故之前误判为随机崩。
- 修法：把每个带 matched 引用的 bin 内部名改为其 donor 的 vanilla 套件名（结构性重写头部：u16 长度+名字+u32+u16+骨架名，**不能只替换字符串不更新长度**，否则头部解析错位产生隐性损坏）。
- 映射：emp_sws1→hu1_empire_sword_and_shield；sn1_serp→sn1_serpent；bi1_eagl→bi1_eagle；empire_sword_rifle→hu1_dlc25_empire_sword_hochland_long_rifle；dlc17_ghorgon→hu11b_dlc17_ghorgon；cst_promethean→cr1_cst_promethean。
- 已部署：pokemon 4 bin、digimon_v2 91/104 bin、swarm 4 bin（playset pos 100/102/109）。swarm 以 playset 实际加载名 zzz_czx_swarm_units.pack 部署（units3 副本已删）。
- 验证：digimon_v2+亚古兽 vs 绿皮兽人 75s 零崩溃（此前同场景必崩）。
- 待验证：内部名是否与套件解析身份共用（若共用，多 bin 同名可能致剪辑错绑/降级动画）；动画目视验收未完成。
- 清理：playset 移除 zz_test_battlectrl；data\ 删 15 个测试 pack + ~50 个测试 XML；used_mods.txt 已按 114 项 playset 重写。

- 兵模/费用平衡（同日）：跳虫 80→120模@550；刺蛇 8→12@1500；飞龙 @600；爆虫 12→16@700；寄生坦克 **3→1台**@2200；宝可梦四小只 2400→2000HP@650、最终型 8500→8000HP@1800；数码兽顶级封顶（启示录兽 20000→16000HP@5000、终千 18000→16000、光堕 17000→15000、须佐/光正 @4400、帝皇龙PM/奥米加X/红莲CM/杰斯X @3800-4000）。已部署三包。
- Mod Manager 残留清理：17+1 条 stale user_mod_data/playset 记录已删（zz_pkm_*、zz_empty、旧 digimon.pack、虫群 units3/扩展补丁等）；scratch/purge_stale_moddata.py 可复用（按路径 hash 校验 data\ 现存文件）。

## 2026-09-23 监狱按钮修复 + 宝可梦技能/兵模
- [实测] `wyccc_prison_system.lua` 顶层 `local` 205 个超 Lua 单函数 200 上限 → 整个 mod 编译失败、监狱按钮消失（script_log 报 "main function has more than 200 local variables"）。修法：尾部 9 个工具函数改 `wp_` 前缀全局函数 → 196。WH3 lua 大文件须注意此硬上限。
- 宝可梦包新增完整技能链（10 技能：投射主动用 unit_special_abilities.activated_projectile + unit_abilities 链；被动用 special_ability_phases+stat_effects）。投射物 key 必须经 projectiles 表验证：二进制扫描会命中非 key 字段，有效 key 示例 `wh2_dlc10_abilities_frost_breath_explosion`、`wh2_dlc11_cst_necrofex_colossus_flamethrower_fire`、`wh_main_spell_fire_fireball`、`wh_main_spell_heavens_urannons_thunderbolt`。
- 小火龙/杰尼龟/妙蛙种子 1→6 模、皮卡丘 1→8 模（main_units.num_men+max_men_per_ship、land_units.bonus_hit_points 按模数等比缩、rank_depth=3）。
- 部署监视器模式：`scratch/deploy_on_game_exit.ps1`（后台轮询 Warhammer3 进程退出→自动 build_pack --deploy），游戏运行时 pack 锁定无法部署时用。

### 2026-09-23 晚：宝可梦基础型改 16 模编制（用户拍板）
- **前情**：某轮把 4 只基础型从单体改成 6（御三家）/8（皮卡丘）模、单模 HP 340/250 保持总血 2000 不变——用户指出"数值和兵模给得太少"。问题：① 6/8 模不上不下（原版怪步 16、战兽 80）；② 多模单位每死一模掉 1/N 输出，"总血不变"等比缩是实质削弱。
- **现值**（已部署 pos 107）：御三家（妙蛙种子/小火龙/杰尼龟）16 模 × 350HP = 5600 总血，费 650→800，维持 200；皮卡丘 16 模 × 260 = 4160，费 750，维持 187。supplies 费用 600/550。ma32/md28/士45/甲40、武器 60+28 不动（已优于恐狼 26/14）。ROSTER.tsv 已同步。
- **关键坑**：4 只基础型原本挂着 wh3_main_unit_passive_single_entity（单体受伤 debuff：速度×0.9、近战伤害×0.8，随掉血生效）——多模单位挂这个等于掉模掉血双重惩罚，已删；3 只进化型仍单体保留。改兵模数时必查这类 single-entity 能力。
- 部署时 data\ pack 曾报 locked（游戏刚退出的残留句柄，tasklist 已查无进程），手动 cp 可绕过；稍后重跑 --deploy 即成功。

## 2026-09-24 三包重设计收尾
- 宝可梦: 7只全部 1主动+1被动; 修正4个假key: flamethrower投射物→wh2_cst_necrofex_colossus_flame, water_gun→wh2_dlc10_unit_abilities_frost_breath, hydro_pump→wh3_dlc24_unit_abilities_ice_breath, pikachu接触→wh2_dlc17_unit_contact_dazed(wh_main_unit_contact_dazed不存在); solar_beam空投射物=正确设计(venom_wave同构,靠phase)
- 虫群: 孤儿技能遁地突袭已挂莽兽; 18只技能全覆盖
- 数码: 104只全部≥1技能(均值2.6),无需改
- audit_dangling_refs 对 vanilla key 有假阴性,需对照 gamedata/db/ 验证
- 部署: 游戏在跑(PID21420用户手动),已挂 deploy_on_game_exit.ps1 监视器,退出自动部署 pokemon+swarm

## 2026-09-25 晚：9.0 旧存档与播放集清单收口

- 诊断冻结于 `scratch/crash_20260925_212244/`：无同刻 Event 2004，故本轮不是 OOM。早期 `+0x1bb9418` 已由 `czx_chop_90fix` 遮蔽旧 HUD 解决；`+0x22c0f80` 由 `zzz_czx_fast_end_turn` 的 fleets 下拉自动点击触发，现源码已移除 fleets 点击。
- 活动播放集曾包含两个失效引用：`local:data:2bc18e784693bed592` 与 `steam:3278112051:!!_nanu_dynamic_rors.pack`。已备份 `state.db` 后移除，114 项清单经 WMM 可成功启动主菜单；`zzz_czx_nag_undead_unlock.pack` 也保持移出，源文件和 data 产物未删除。
- `zzz_czx_prison_default.pack` 已重建部署为 `local:data:da0e9dd1bfc96eb954`，放在 `wyccc_prison_system.pack` 前；源码仅持久化永久收押状态，读档清空战斗快照、待处理收监队列和 battle svr 标记。静态审计 0 findings，包内 Lua 已回读确认。
- 同一 `伊泰恩_自动保存.*` 仍以 `+0x257ce84` 崩溃，但 triage 的存档指纹为 `8.1.0/8.1.1`，运行 exe 为 `9.0.0.0`；无监狱包对照与有监狱包同类崩溃，结论为 8.1.x→9.0 跨版本存档 world-restore 引擎兼容问题，不是 MOD 内容问题。不要继续用该旧存档验证 MOD。
- WMM 114 项清单启动请求成功，`Warhammer3.exe` 在 90 秒检查时仍存活；但 `modified.log` 仍为 113/114 挂载差，故主菜单和全量挂载尚未完成证明。监狱补丁已确认在工坊监狱包前胜出。后续验证应使用 9.0 新开战役，并先解决两个未挂载 Workshop 条目。

## 2026-09-26：用户报障"有些程序看不到窗口"→ UI 自动化禁令入规范

- 定因：`scratch/wh3_click.py`、`real_click.py`、`minimize_others.py`（09-22 战斗自动化测试期产物）为让程序化点击落在游戏上，对其他顶层窗口 `ShowWindow(h,0)`（SW_HIDE，任务栏/Alt-Tab 均不可见）/SW_MINIMIZE，并 `taskkill` steamwebhelper/gameoverlay。
- 复查当前桌面：首轮 `MainWindowHandle` 判据漏检（主窗口被 SW_HIDE 后该属性归 0）；改用 `EnumWindows`+`!IsWindowVisible` 后实锤 Devin（pid 14956，1920x1059 与 1022x766 两窗）与 msedge（1920x1059）主窗口仍被藏，已 `ShowWindow` 恢复（`scratch/_hidden_check.ps1` 为复查/恢复工具）。QQ/Steam/PixPin 等托盘程序自隐藏属正常未动。游戏本体（PID 35908）窗口可见正常。
- 处置：AGENTS.md 项目硬约束、SKILL.md 高风险原则、references §10.41、CHANGELOG 同步立规——自动化只允许操作 `Warhammer3.exe` 自身窗口（PrintWindow/PostMessageW/SetForegroundWindow），禁止藏/移/最小化其他程序窗口、禁止杀无关进程；三脚本头部加禁跑警告。


## 2026-09-26 深夜：digimon be_prop 挂点轨道补写（iter13 遗留收口）

- **做了什么**：scratch/fix_beprop_tracks.py（全动态剪辑）+ fix_beprop_tracks_dyn.py（static-map/压缩剪辑重建全动态）对 mod_files/zzz_czx_digimon_v2/animations/battle/ 全部 grafted 剪辑补写 be_prop_* 轨道：L_prop=inv(W_animroot)⊗W_driver，映射 0/1→hand_right、2→hand_left、3→spine_2、4→root、5→hand_left（对齐 vanilla hu1 VMD attach_point 惯例）。
- **全量结果**：9496 剪辑 → ok=8765 / no-prop=731（无 prop 骨骨架正常跳过）/ other=0；799 个压缩剪辑（meg/met/ple/sea/dorugo/omega0/shine0/veemo0/wargr0 九族）经 resolve_locals 重建为全动态后写 prop。抽样 140 剪辑：归一化 FK 下 prop 世界位置与 driver 逐帧零偏差、四元数半球连续、非 prop 通道保真（0 pos / <=0.003 deg rot）。
- **关键技术坑**：压缩编码（rb=4 s8 range）解出**非单位四元数**（animroot |q|=1.0011）——q·v·conj(q) 按 |q|^2 缩放，1.84m 力臂放大成 ~8mm 偏差。FK/求逆必须逐 quat 归一化（引擎按单位 quat 处理）。原始压缩剪辑可从 mod_output 旧包/部署包回取（本轮已就地覆盖）。
- **部署**：mod_output/zzz_czx_digimon_v2.pack 重建为 533MB（+42MB）。WH3（pid 22636，12:34 手动拉起）运行中 pack 锁定——scratch/deploy_digimon_when_free.sh watcher 挂后台，游戏退出后自动 build_pack --deploy + sha256 校验。**教训**：WSL 里 tasklist //FI（git-bash 双斜杠习惯）在 tasklist 是非法参数静默失败、grep 不到名字会误判"进程已退"——进程检测用 powershell.exe Get-Process；deploy() 的 PermissionError 三重试兜底正确拦下了本次误触，旧包未被损坏。
- **遗留**：轨道 != 挂载——VMD <SLOT attach_point="be_prop_N"> + prop rmv2 + variant 配装才是武器实显；当前 digimon 武器仍是 skinned 进 body。L4 战斗复测等游戏空档与并发会话让位。

## 2026-09-27 崩溃簇分诊（13 dump 三族）+ playset 切换/部署收口

- **崩溃分布**：`+0x1a957e7`×6（16:10-17:30，战局 init，`params=[0x0,0x20]`；17:30 vanilla 空表对照同崩=环境级定案已录 §10.31）、`+0x4e5b30`×5（17:14-17:43 挂载期 `params=[0x0,0x3e8]`，未到主菜单；同集 17:46/17:49 成功挂载=间歇性）、`+0x22c0f80`×2（14:10/15:37）+`+0x22c8774`×1（17:53）=§10.40 intro 窗族。
- **环境证据**：mp_log 09:46 UTC 段 `Native_Platform_Ready failed → PLATFORM_OFFLINE`——Steam 离线态，与 §10.31「等环境恢复」判断一致；无 Event 2004。
- **17:53 关键样本**：新 nag 战役 `script_log_270926_1749`（307 载），dismiss 级联 194.5s 完→fet2 门控放行后 224.1s 下拉点击→14s 静默→238.3s flyover 起步→239.7s CinematicTrigger→崩。崩溃窗内零 mod 行；mp_log 叠 `REPORT_START_OF_TURN_END`+78s starvation。结论=§10.40 引擎侧残留（vanilla 内联 mo:start() 不可控），guard v2 在位仍中。
- **playset 切换**：当前活动集 = `d8c514a3`「存档纳迦什军团_自动保存.516926157.save」113 项（存档快照，15:47 建）；其 pos24 冻结在旧 `auto_tools3`（带未拆 debug 探针 first_tick/FactionTurnStart 原生扫描）——已手术换 `zzz_czx_auto_tools.pack`（d567...），备份 `state.db.bak_20260927_swap`，enabled_order 同步。
- **部署收口**：confid_90fix(00:01 新版)/psw_merged/psw_90fix/90_wyccc_fix/autoconstruction 五个滞留包已同名拷入 data\；digimon_matfix 等 v2/v5 裁决后联动。
- **遗留**：《全合集》c2cfd9b4（139 项）仍带失效 nanu 引用 + wsid 3278112051 文件缺失=挂载缺口（该集若启用须先清）；`!!prayer_of_star_witch_movie.pack` 在 used_mods 无 Mod: 挂载行（文件在盘）长期项；prefs 仍挂 OOM 危险档（minimise_memory_usage=true/gfx_texture_quality=3）。

## 2026-09-27 晚：Mod Manager 冲突报告功能落地（mod↔mod / mod↔vanilla 静态检测）

- **起因**：用户要求把本次崩溃排查沉淀的冲突知识做进 Mod Manager（参考 MO2/Vortex）。实现为按需报告，不进常规扫描热路径。
- **落地**（`wyccc-warhammer-mod-manager`）：`backend/conflict_scan.py`（文件级遮蔽按 playset 靠前胜 + vanilla manifest 遮蔽比对 + DB 片段解码行级冲突靠后覆盖 + 声明依赖缺失/禁用区分 + 表版本与解析失败诊断）、`wh3_db_schema_full.json`（RON 全表烤出 1742 表含 is_key）、`parse_db_table` 加 `schema_map` 参数与 `OptionalI32` 解码；RPC `get_conflict_report(deep)`；前端 `ConflictReportModal`（类型/严重度过滤、winner 标注、点参与包跳列表、深扫按钮）+ 六语文案。测试：后端 12 新用例、前端 3 组件用例。
- **真集验证**（113 项存档集 d8c514a3）：快扫 ~3s / 深扫 ~15s；168 同路径遮蔽（如 `zzz_psw_merged` 赢 `psw_全局变量总表.lua`）、1662 vanilla 遮蔽（`!all_ancillaries.pack` 空片段清 1407 原版行属已知刻意覆盖）、1567 行级冲突、1 缺失依赖（`czx_mod_fixes`→失效 `!!_nanu_dynamic_rors`）。诊断细则入 references §4.2。
- **教训**：`parse_db_table` 的 schema_map 必须是 `{表名:{版本:字段}}` 嵌套，直传版本层会全表 unparsed；mod manager 仓库整仓在 CRLF 归一化中（git diff 全文件假象），该测试失败 `force_update_*` 系本机 WH3 正在运行属环境性。
- **晚复核纠偏**[修正初报"60 过期片段"结论]：首版报的 60 个 db_fragment_invalid 实为两个解码器缺口而非 mod 过期——①无版本标记片段被误配最高版本定义（RPFM 惯例无标记=v0，PSW 主包/wyccc_base_lib/自家 swarm_units 全是这种）；②CA/RPFM 的 **LZMA1** 压缩载荷（`u32 dsize + 0x5d + u32 dict(8MB) + 裸 LZMA1 流`）完全不支持，`@z_double_skill_points` 全包 12 个压缩条目静默 None。两处已修（`parse_db_table` 加 force_version + v0 优先 + `_decode_fragment` 全版本兜底；`_decompress_payload` 加 LZMA 路径并对 zlib 输出加声明大小校验防 1 字节假阳性）。修复后 invalid=0、unparsed=0、行级冲突 1567。playset 压缩普查：15/111 包压缩（13 zstd/1 lz4.frame/1 lzma）。

## 2026-09-28 下午：intro/flyover 崩族最终根除——fet 直写 observation_options（v6）

- **定案**：`+0x22c0f80`（读 null+0x58）= DropdownMenuOption 回调读死 context；fet 模拟点击 armies/heroes 下拉在 UI 持锁/面板挂起期概率性崩（0728/2008 日志末行均为 clicked option2，存活三次点击皆无锁）。v4 的 `_ui_idle` 门控三连存活但治标。
- **API 定案**（zz_obs_probe 九轮探针）：`observation_options_for_faction(f,x)` 第二参忽略返回派系自身记录 OPT[f]；`set_character_observation_options_for_faction(f,obs)` 可写任意派系、799 全写 ~4ms；`observation_options_for_allies/enemies/neutrals` getter 是不绑模型的默认对象=单向写路径只能发不能验；locomotion_speed 枚举 {NORMAL,FAST,VERYFAST}、camera_follow {OFF..VERYHIGH} 非法值静默保持。
- **v6 实现**：`_apply_all` 枚举全派系逐写 OPT[f]+三组 setter 兜底+本地回读；`_ui_idle` 移除（模型写与 UI 锁无交，实测持锁期写入存活）；`end_cinematic`+稳定窗保留防原版 intro 覆盖。SimulateLClick 点击机全删。
- **验证**（nagv6，script_log_280926_1647）：flyover 完整（end_cinematic 280.9s）→ apply 314.9s（writes ok=799 fail=0、三组 setter true、me.*=VERYFAST）→ SURVIVED+90s 无 dump。
- **部署名陷阱二踩**：`--deploy` 默认名 zzz_czx_fast_end_turn.pack 但 playset 引用 end_turn2.pack——静默白改过一次，务必 `--deploy-name zzz_czx_fast_end_turn2.pack`。
- **清理**：zz_obs_probe 已从 playset/state.db/data\ 移除（源保留 mod_files/zz_obs_probe）；state.db 备份 .bak_remove_probe。

## 2026-09-28 深夜续：22:24 +0x22c8774 战后返回崩——静默窗轮询器收口

- **复核修正**：2221 会话日志断在 168.8s 但 mp_log（RETURNING_FROM_BATTLE 14:24:14UTC）换算崩点 ~182s 引擎时——**~14s 全静默窗**；mp_log 全程 starvation 风暴（21/21/30s stall）。形态=09-27 17:53 首例同签名（§10.40"零 mod 行+starvation=引擎侧残留"）。
- **静默窗盘点**（wh3diag grep register_repeating --scope used）：常驻原生调用剩三处——sell4 双 tick 持捕获引用（150/250ms，9 处 ancillary_panel:Visible()）、!ai_treasury interval=0 每帧 find+SetStateText 写、psw_UI singleshot（面板开窗一次性，已排除常驻）。
- **处置**：①sell4 改 fresh_panel+Address() 代际校验，全部 9 处换 panel_visible() 门控，面板重建则延迟重绑；②新建 zzz_czx_treasury_guard 同路径遮蔽 !ai_treasury.pack（pos12 压 13，mod_id local:data:1c928b235a5e11d7f6），interval 0→500ms+ui_locked+Visible 三重门——**两个新静默写源已清**。备份 scratch/state.db.bak_20260928_tg。
- **部署边界**：游戏运行中 data\ 锁——treasury_guard 已手动拷入 data\+playset/state.db 手术完毕（下启动生效）；sell4 新包建好在 mod_output，后台 watcher 等游戏退出自动 deploy。运行中 2247 会话带 canary 版，三组 canary（reposition/move_up/deferred create）全部成对、无新 dump。
- **新范式入 §10.40**：静默窗崩溃先盘点 register_repeating 常驻计时器（无日志但每 tick 原生调用）+ 捕获 UIC 引用跨 teardown 复用一律按 UAF 族处理。

## 2026-09-30 晚：多签名崩溃簇复核 + 播放集剪除事故恢复 + 测试垃圾大清删

- **崩溃簇复核（36 dump）**：当日多签名并存——`+0x1813d25`×11（11:49 起，exe 09:08 升 9.0.1.0 后的新主导偏移，stub 期早期 init）、若干 null+8/+0x5a0/+0x10 挂载期变体、用户真实闪退 `+0x22bf668`（18:04，null+0x58 UI teardown 族，script_log_300926_1802：141s 点 tab_army→units_panel 构建窗内 BRF 12 钮注入+czx_disband deferred create 随即崩）。`used_mods.txt` 曾污染至 214 行/127 唯一，zz_* 测试包混入真实清单。
- **CreamAPI 回流再修**：steam_api64.dll 又变回 Cream shim（834,560B，f641ad26），SmokeAPI（4.2MB）躺在旁边未生效——早会话的 swap 被还原（疑 exe 更新/验证触发，未查实）。已重命名复原：active=SmokeAPI(460a2ade)，Cream 存 `steam_api64.cream_active.dll`+`.cream.dll`。
- **播放集剪除事故（18:06–18:22）**：15 项被移出（digimon_v2/pokemon/tmb+vmp unlocks/global_lua_guard/hero_grants/prison_default/czx_90_wyccc_fix/czx_mod_fixes/cth_grand_cannon/jar_army_size/zz_iso×2）→ 用户报"虫群和数码宝贝没了"（古墓王档招募链断+单位定义未挂载）。按 18:13 基线手术补回 13 真包原位（备份 `state.db.bak_20260930_postrestore`），剪除者未查明（另一会话或 WMM 前台操作）。
- **大清删（用户指令）**：data\ 测试残留 28 项删（zz_* png、s1_*.xml、孤立封面）；9 个被锁 .pack 挂 `scratch/_cleanup_testpacks_on_exit.ps1` 退出后删+部署重建 czx_mod_fixes；mod_output 清 19 个 zz_* 产物；mod_files 清 45 个 zz_* 测试源目录。`test.pack`（steam:3241827850）移出播放集→119 项（订阅保留）。czx_mod_fixes 删失效 nanu 依赖声明（nanu 系不在集）。
- **深扫基线（119 项，scratch/smoke_conflict.py 已支持动态 playset+user_dir）**：四类高危检查全零（prefs_dangling/dangerous_pref/unlisted_movie/pack_unreadable）；db_missing_reference ×11 medium 惰性（跨战役键+不可招死引用）；missing_dependency ×1=nanu（待 watcher 部署后消失）；steam_api_suspicious=SmokeAPI 已知良性误报。
- **遗留**：`+0x1813d25` 早期 init 崩未定级（exe 更新后偏移漂移）；`+0x22bf668` UI teardown 残点=BRF 重建+disband deferred create；播放集剪除操作者未查明；`!!!!wyccc_faction_grants.pack`（dgm_megas+swarm→tmb 军组/建筑授权 18+42 行）已生成挂载，但授权≠单位定义，须配合播放集内单位包才生效。
