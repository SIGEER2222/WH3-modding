# Codex Project Context

这是一个《全面战争：战锤3》MOD 制作工作区。当前主要资产是本地 RPFM 工具和一份可维护的 `warhammer-mod-development` 指南源文件。

## 当前目录

```text
E:\Code\WH3-modding\
├── AGENTS.md
├── README.md
├── .codex/
│   └── project_context.md
├── .agents/
│   └── README.md
├── assets/
│   └── image/
├── docs/
│   ├── PROJECT_STRUCTURE.md
│   ├── RPFM_USAGE.md
│   └── DEVELOPMENT_GUIDE_UPDATE_RULES.md
├── mod_files/
├── mod_output/
├── workshop_release/
├── scratch/        # 临时/实验性文件，.gitignore 忽略；一切一次性脚本/预览/中间产物都只能放这里
├── manual_edit/     # 用户手工 Blender 修权工作目录（.blend 大文件，.gitignore 忽略）
├── gamedata/        # 由 tools/export_gamedata.py 从游戏 pack 导出（2026-09-06 重建）
├── bilingual/       # 同上；localisation__.loc_CN.tsv 为合并中文速查表
├── references/      # 本地 MOD/英雄/美术参考样例，仅引用
├── tools/           # export_gamedata.py 等工作区脚本（tools/_*/ 为已忽略的中间产物目录）
├── rpfm-v5.0.6-x86_64-pc-windows-msvc/
└── warhammer-mod-development_generic/
```

## 关键判断

- `rpfm-v5.0.6-x86_64-pc-windows-msvc/` 是工具目录，不是待开发源码。
- `warhammer-mod-development_generic/` 是本项目维护的 development 指南源副本。
- 以后具体 MOD 打包前源文件放在 `mod_files/<MOD名>/`。
- 图片、美术源素材放在 `assets/image/`，由用户维护；Codex 默认只引用，不整理、不清理。
- 打包后的 `.pack` 输出放在 `mod_output/`，不作为源码维护。
- Steam Workshop 发布包、预览图、说明文本等放在 `workshop_release/`，其中说明文本默认使用 Steam BBCode。
- 原版导出、脚本、DB 和 UI 参考资料放在 `gamedata/`。
- 游戏内中英对照和本地化参考文件放在 `bilingual/`。
- `gamedata/`、`bilingual/` 与 RPFM 工具目录仅供读取或调用，不要修改、格式化、清理或移动其中的文件。
- 一次性脚本、调试输出、截图、中间导出等无关改动放在 `scratch/`，该目录被 `.gitignore` 忽略。
- **根目录卫生（2026-09-13 用户要求立约）**：禁止在仓库根目录新建任何临时文件/目录；`_tmp_*`、`_preview/`、`_work_*/` 只允许出现在 `scratch/` 内（`.gitignore` 已兜底）。新增顶级目录必须先在 `AGENTS.md` 与 `docs/PROJECT_STRUCTURE.md` 登记职责。历史上堆积的根目录 `_tmp_*.py` 已归置到 `scratch/tmp_scripts/`，`_preview/`→`scratch/_preview/`、`_work_kerrigan/`→`scratch/_work_kerrigan/`。
- 制作 MOD 需要打包时，默认由 Codex 自动完成全流程（ → 复制到游戏  → 备份  后插入当前 playset 并同步 ），不再询问；仅当用户明确说要自己用 RPFM 打包时才停在源文件。本地 loc 补丁与被汉化包同路径时须排在对方**之前**（同路径遮蔽靠前胜出）。

## 本机 WH3 路径

以下是本机 Steam 安装位置，属于本地环境配置，不代表其他机器：

- 游戏 `data/`：`E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data`
- Steam Workshop 内容：`E:\Program Files (x86)\Steam2\steamapps\workshop\content\1142710`
- MOD 管理器源码：`E:\Code\wyccc-warhammer-mod-manager`

查找原版 pack、游戏数据或 Workshop MOD 时优先使用以上路径；Workshop AppID `1142710` 对应《全面战争：战锤3》。外部目录默认只读，除非用户明确要求修改、复制或发布。

启动游戏可通过 `E:\Code\wyccc-warhammer-mod-manager` 后端 `API._launch_game(mod_ids, order_token)`；清单写游戏根目录 `used_mods.txt`，运行时另生成 `wyccc_launch_mods.txt` 与 `!!!!wyccc_runtime_options.pack`。加载清单被两个后端实例并发修改会触发 token 校验报错，自动化启动前先确认只有一个后端/UI 实例。data 目录 pack 需以 `local:data:*` id 进入 playset 才会写入 `mod` 行加载；直接放 `data\` 而无 mod 行只会记 `unknown file`。

## 本机硬件与 AI 推理环境（2026-09-13）

- **GPU 优先（用户明确要求）**：本机有 NVIDIA GeForce RTX 2070（8GB），后续所有 AI/TTS/模型推理任务一律优先走 GPU，不要默认 CPU。装库时直接选 CUDA 版，例如 `pip install "torch==2.11.0+cu128" --index-url https://download.pytorch.org/whl/cu128`（PyPI 的 Windows wheel 是 CPU 版）。
- **TTS/语音实验环境**：venv `C:\Users\22448\venvs\wh3tts`（torch 2.11.0+cu128）；HF 缓存约定放 E: `scratch\tts_lab\hf_cache`（C: 盘长期紧张，大模型下载前先查 E: 空间并设 `HF_HOME`）。注意：**2026-09-13 磁盘清理已删除整个 `scratch\tts_lab`（23.5G，含 hf_cache 与 indextts2_ckpt）**，模型需重下；venv 仍在。实测与坑见 `references/audio_and_vo.md` "本机已实测可用的管线"。
- **磁盘卫生**：模型/数据集/音频中间产物一律放 `scratch/`；下载大文件后对比 `x-linked-size` 校验完整性；失败的 partial 缓存及时删。

## Workshop 订阅/下载能力（本机已具备，勿再回答"做不到"）

- **订阅**：`E:\Code\wyccc-warhammer-mod-manager\backend\steamworks_bridge.py` 提供完整 Steamworks 桥接，复用正在运行的 Steam 客户端会话，**全程可脚本化、无需用户点击**：
  - `subscribe_workshop_items(ids, root=Path(仓库根))` → `{'subscribed': [...], 'accepted': True}`
  - `perform_workshop_operation('subscribe'|'unsubscribe'|'force_update', id, root=...)`
  - `query_workshop_subscription_status(ids, lang, root=...)`、`query_workshop_dependencies`、`publish_workshop_item`（发布 MOD）
  - 调用方式：`sys.path.insert(0, r'<repo>\backend')` 后 `import steamworks_bridge`；Node 22+ 已自动发现（`E:\Program Files\nodejs\node.exe`），底层为 `steam_runtime\workshop_bridge.js` + stdin JSON。
  - 实测（2026-09-12）：`subscribe_workshop_items(['2801517996'])` → `accepted: True`，SFO 汉化订阅成功。
- **下载时序**：游戏运行时 Steam 默认**暂停**工坊下载——订阅 accepted 后文件不落盘属正常现象，关游戏后自动续下；`force_update` 要求已有安装路径，未下载的项会报 `no install path`。
- **备用文件拉取**：`E:\Tools\steamcmd\steamcmd.exe +login anonymous +workshop_download_item 1142710 <item_id> +quit`（匿名下载，不订阅，产物在 `steamcmd\steamapps\workshop\content\1142710\<id>\`）。

## 当前 MOD 环境备忘（2026-09-12）

- `data\!czx_yinyin_expedition_fix.pack`：本工作区生成的 Yin-Yin 悬空引用修复补丁，用唯一片段名 `zzz_yinyin_exp_fix` 复制 EXP 的 nodes/links/set_items 与基础包 node_sets 片段；需保持在 playset 中（local:data id `local:data:16cc06034a984a76f6`）。若日后删除该文件需同步从 playset 移除。
- `RLH_English_Patch_Arthas.pack`（Workshop 3440283762）：用户明确不要——会把原 MOD 变英文。保持未订阅；对 `Random_Legendary_Heroes_Arthas.pack` 的 missing_dependency 告警保持忽略，不要自动补订。
- `cth_deer24_units_TLA_warband_upgrades.pack`（Workshop 3034203267）：已过期，引用上游删除的 `wh3_deer24_hailongjiajun`，已从 playset 移除；替代品为 Pinkbee 重制兼容包（3432190138）。
- `zzz_czx_swarm_expansion.pack` / `zzz_czx_swarm_units.pack`：当日重建后疑似启动原生崩溃元凶，为 `.DIS` 禁用。后续 `zzz_czx_swarm_units3.pack`（`local:data:f3059665227313a571`）已回到《全合集-非震旦》pos 51 正常加载；`zzz_czx_swarm_expansion` 仍未启用、不在 playset。
- 2026-09-19：两个虫群包源码中的刀锋女王凯瑞甘（`czx_kerrigan` 英雄 / `czx_kerrigan_lord` 领主，含模型/兵牌/loc/直刷脚本/技能树）已全部移除——改用「英灵召唤 (Summon Servant)」（Workshop `3552538974`，前置 `3376886102` 通用框架）提供的凯瑞甘。`gen_czx_patch.py` 已同步删除凯瑞甘生成段。注意该 mod 当前**未订阅**（Steam 客户端离线/UGC 掉线，bridge subscribe 报 "no network connection"；9-2 曾订阅、9-5 取消）。
- `zzz_psw_merged.pack`：2026-09-12 重建并部署——修复 `psw_06_chaichu.lua` 拆除天赋后 `show_advice("psw_chaichu_done")` 无 advice_threads/advice_levels 记录导致的 "Placeholder Body" 卡死弹窗；新增 `advice_threads`/`advice_levels` 片段 + `advice_levels_onscreen_text_1214413929` loc。诊断方法见 `references/ui_popup_and_event_diagnostics.md`。
- `zzz_psw_merged.pack` 天赋链修复（2026-09-20）：用户报"没满却提示满了"——实际是 `ui_psw_main_tfxz` 监听器末尾 `elseif 1==1` 兜底的 `advice_alice_tf_yyytf`（"获取天赋失败"），点击未命中任何 `psw_tf_*` 分支（已拥有/EX 超上限/未知键）时触发并拆空 4 个 offer 槽。修复：① `psw_额外函数.lua`（同路径遮蔽生效文件）nor/ex 池填槽前过滤 `set_*`/`set_main_*`/`global_data.set_main_*` 已拥有项、空池置 nil 不填槽；`final_tf_count>=13`→`>=99`。② `psw_02_tianfu.lua` 的 `psw_main_tfxz` 改名 `psw_main_tfxz_merged`（同名全局会被后加载的原版覆盖）；`ui_psw_main_tfxz` 回调/条件暴露为 `ui_psw_main_tfxz_merged_cb`/`_condition` 全局。③ 新增 `zzz_psw_talent_fix.lua`：first-tick 里 remove+add 重新注册两个监听器（原版 psw_天赋.lua 文件作用域的 remove+add 会清掉我们早前注册的同名监听器；监听器同名追加共存、按注册序触发）。④ 兜底分支加 `out()` 诊断（key/owned/jishu_ex_count）+ 0.5s 延时自动补抽（必须延时——同步重抽会提前解掉 main_yi_pick 锁导致原版同名监听器重复处理）。注意：`suifu/xieyue/xueshou.lua:67` 报错来自 `quanpaixijingyingbingjiakuai.pack`（3562559526）里的旧副本（`},--` 多了逗号），我们包内同名文件已是修复版。
- `czx_auto_skill_manage.pack`：2026-09-12 新建本地包并部署（mod_id `local:data:19063cd1d67e2e16bb`，playset pos 144）——自动勾选人物技能页"自动分配技能点数"复选框；脚本通过 `SimulateLClick` 点击 `checkbox_auto_management`（Cco 绑定，状态按角色持久化）。源码在 `mod_files/czx_auto_skill_manage/`。
- `zzz_czx_ancillary_sell4.pack`（mod_id `local:data:af5c4027ee754b2138`，《全合集-非震旦》pos 102，源码 `mod_files/zzz_czx_ancillary_sell/`）：`!ancillary_panel.pack`（xyz_ancillary_panel，工坊 3253398688）装备面板的补丁——详情框右下角三个出售钮：出售选中（icon_income）/出售勾选（icon_income_plus）/一键出售当前筛选未装备件（icon_treasury，在面板购买钮 `xx_button_add_ancillary` 左侧）+ 双击列表行直接出售 + 每行右上角勾选框（150ms tick 补挂/同步，`Parent()` 取行 key）+ `button_list` 内"只看已拥有"开关（借 `xx_sets` 白名单过滤）+ 部队一键撤编。全部经 UITrigger 服务端校验（已装备/传奇锻造豁免）。**2026-09-20 修复**：旧版出售钮 `SetDockingPoint(9)+正 X 偏移` 被推出详情框右缘外不可见——右缘 dock 正 X=向外，须负 X 收进面板（见 lua_api.md dock 节）。注意：`script/campaign/mod/*.lua` 按文件名字母序加载而非 playset 顺序，补丁脚本须 `zzz_` 前缀排在 `xyz_` 之后，attach 带 retry。旧 `zzz_czx_ancillary_sell3.pack`（`local:data:95eacca79d455f053b`）/`sell2`（`local:data:b81a801010eb0ceebf`，仅《全合集》pos 147 引用）文件仍在 data\ 但不在当前 playset；sell3 游戏退出后可删。
- `Lalolalo9Autoconstruction.pack`（local pack，pos 44）：2026-09-12 已把自动建设默认改为开启——`Lalolalo9AutoConstructionEnabled` 初值与无存档值 else 分支均 `0→1`（源码 `mod_files/lalolalo9_autoconstruction/`，原包备份 `scratch\Lalolalo9Autoconstruction.pack.bak`）。开关按存档持久化，手动关过的存档仍保持关。
- `sm0_recruit_defeated cn.pack`（2855270850）：已在 playset 但必须排在 `sm0_recruit_defeated.pack`（2854819509）**之前**才生效（同路径 loc 整文件遮蔽，靠前胜出）；2026-09-12 已从 pos 80 移到 pos 51，EN 包退到 52。若"战争难民"事件变回英文，先查这两项的相对顺序。
- `zzz_nanu_dynamic_rors_cn.pack`：2026-09-13 新建本地汉化补丁并部署（mod_id `local:data:2bc18e784693bed592`，playset pos 26，位于 `!!_nanu_dynamic_rors.pack` pos 27 **之前**——同路径 loc 遮蔽靠前胜出）。覆盖 Nanu's Dynamic Regiments of Renown（工坊 3278112051）全部 9 个 loc 文件共 3260 行中文；源码 `mod_files/zzz_nanu_dynamic_rors_cn/text/db/`，生成器与手工词典在 `scratch/_translate_nanu.py` + `scratch/nanu_loc/_manual_dict.py`（如 mod 更新出新文本，重跑生成器并把 miss 补进词典）。已知限制：脚本拼接的随机兵种名不在 loc 中，无法汉化。
- playset 重复项：`steam:3018964477:!!prayer_of_star_witch.pack` 在 pos 9 与 pos 106 各出现一次，`!!prayer_of_star_witch_movie.pack` 在 pos 10 与 pos 58 重复——`state.db` 的 `playset_items` 有重复行 `[需验证：是否为管理器 UI 双预设合并残留]`。
- **活动 playset 已切换（2026-09-18）**：`current_playset_id:warhammer3` = `a0f587afe1664c39be6c70b1e56abc79`《全合集-非震旦》(108 项)，不再是《全合集》。自动化部署/删改前先查该 key 的当前值。
- `zzz_czx_battle_tactical_commander.pack`：v2 战术指挥器，2026-09-18 首测踩 `bm:armies()` 杀计时泵 + `_lib` upvalue nil 两致命伤；**2026-09-19 起路线废弃**——用户判定自制不如 AI General III，改为 AIG3 submod 路线。源项目 `mod_files/czx_battle_tactical_commander/`（git 仓库，SIGEER2222）与打包源 `mod_files/zzz_czx_battle_tactical_commander/` 保留归档，pack 在 data\ 但不在任何 playset。
- **2026-09-20 崩溃日结**：全天 67 dump，每次进战斗必死（战役过渡与 autotest 同签名 `0xc0000005` 读 `0x20` @ exe+`0x1a0be3b`，外层 WER `0xc0000409 @ 0x10da8f1`，无 RES 排除 OOM）。根因=`battle_preferences\.singleplayer.battle_preferences` 缓存军表引用已被改名/禁用的 `czx_dgm_agumon`——悬空 key 在 AppData 不在 modlist，二分 pack 无效，纯原版也崩。已改名 `.bak_dead_agumon` 修复（证据 `scratch/crash_20260920/`），详见 references §10.14。教训：自造单位改名/删 key 须同步清 AppData 军表/army_setups/存档引用。
- **2026-09-20 晚间复发/签名分叉**：21:39:22 再现 `+0x1a0be3b` 读 `0x20`，21:41:14 旧实例改为 `+0x4ba1ae` 读 `0x8`，21:46:33 生成无 stream 6 的最小 dump；21:48:51 在已加载 `zzz_czx_global_lua_guard` 的新实例中仍为 native dump，内层 `+0x23b01c2` 读 `0x0`，WER 外层均为 `0xc0000409 @ +0x10da8f1`。22:04–22:09 又用真正空 modlist（仅 runtime 包）连续复现，内层多次回到 `+0x1a0be3b`；脚本只到 `battle_scripted.lua loaded`，无 RES 2004。重建后的主 `battle_preferences` 又由 `army_setups\last_setup_for_wh3_main_brt_aquitaine_classic.army_setup` 灌回 `wh3_cp1_bhashiva_qb1`/Bretonnia 配置，22:15/22:18 仍同签名；现已再次备份并移出两者等待验证。最新 stack 曾出现 QQPinyin，输入法/TSF 成为额外系统级嫌疑。另发现启动层 `steam_api64.dll` 缺失/损坏，Steam 校验已恢复该 298856B DLL（SHA1 `40D0AE44E090DB49B2309FB152FBD3E11124A376`）；这是独立于 battle init 的启动故障。**最近存档本身含 `czx_digimon`/`czx_swarm_units3`/`czx_aig3_plus` 等 10 个 Mod 标记，最新 temp 含 55 个 czx/dgm 引用；空 modlist 继续该存档不是 vanilla 对照。已用 `_launch_game([], token, "")` 启动无存档纯净主菜单，35 秒无 dump；从该主菜单进入 battle init 22:38:24、清空旧存档后 22:45:15 均以 `+0x1a0be3b` 崩溃，新 preferences 指向 `wh3_cp1_bhashiva_qb1` + `wh3_main_dae_daemon_prince` custom battle preset，Bhashiva preset 是当前首要触发器，需和新 vanilla campaign 普通战斗分开验证。** guard 只能拦 Lua callback，不能捕获 C++ 原生崩溃。
- **2026-09-20 深夜 purge+重装**：`save_games`/`temp`/`resume`/`battle_preferences`/`army_setups` 共 105 个文件归档到 `scratch/crash_20260920/purged_state_20260920_224341` 后清空；22:45:15 无存档空 Mod 仍以 `+0x1a0be3b` 崩在 Bhashiva preset——旧存档/缓存链全部排除，用户决定卸载重装。playset《全合集-非震旦》=114 项（98 steam + 16 local:data）；13 个本地包已用 `tools/build_pack.py` 从 `mod_files/` 重打并部署回 `data\`，mod_id 全部匹配（部署名≠源码目录名的：`zzz_czx_ancillary_sell→…_sell4.pack`、`zzz_czx_auto_tools→…_tools3.pack`、`zzz_czx_swarm_units→…_units3.pack`、`lalolalo9_autoconstruction→Lalolalo9Autoconstruction.pack`）。3 个本地包无源码仅存在过 `data\`：`!!ia_all_factions.pack`（Zerg虫群帝国 3656495027 的全派系解锁，疑似随工坊项下发）、`!!!wyccc_cn_localization_patch.pack`/`_batch2.pack`（Wyccc 文本补全，疑随 wyccc 工坊项下发）——工坊回下后扫描 item 文件夹恢复；`mod_id=local:data:sha256(data\规范路径[:18])`，文件名不变则 id/排序/别名自动复活。
- **2026-09-19 崩溃日结**：全天多次闪退实为多根因叠加——上午定案的 commit OOM（pagefile 已走注册表修为 C: 40GB 初始/48GB 最大并重启生效，上限 ~63GB；WMI 写不动时用 `scratch/crash_20260919/fix_pagefile3.ps1`），晚间数码宝贝系 pack（`zzz_czx_digimon`/`zzz_czx_dgm_patch`/`zz_dgm_nobin`，并行会话全天在重建）加载即让 WH3 单进程提交冲到 55.4GB 打爆上限——**用户实测禁用后恢复正常**。另有 init 期 `0xc0000005 @ 0x14182fb2b`（battle autotest 连发同址死）与 `0xc000041d` ntdll TSF 回调异常（campaign HUD 建 search_panel 时）两个次要签名，详见 `references/crash_and_load_order_diagnostics.md` §10.10/10.11。
- **战斗 AI 现状（2026-09-19，《全合集-非震旦》110 项）**：`steam:2799316652:aigeneral_iii_pancake.pack` pos 55 + `aigeneral_3_chinese`（汉化 loc）pos 56 + `@xiang_necessary_integration`（jg77_babysitter，记玩家攻击令+溃逃自动再找目标，按 uc_manager claim 避让 pancake 单位）pos 15 + **`zzz_czx_aig3_plus.pack`（`local:data:d1ecea5ed5c6353e4f`，pos 109，本次新建）**——AIG3 submod 三层：① planner 级 doctrine 常驻指令（rush→attack_unit / hold→defend_position+僵持爬行）；② 托管单位自动技能（v1 烘焙表移植）；③ detachments 拉扯层（uc_manager claim 制：charger 骑兵循环冲锋 / skirmisher 引擎 skirmish 风筝+猎物优选 / wounded 残血高价值拉出停车，上限 6 单位，VictoryCountdown 全员归还 chasing）。v1 `zzz_czx_battle_ui5.pack` 已移出 playset（文件留 data\）。submod API 面+claim 交接语义见 `references/lua_api.md` "AI General III 扩展接口"节；AIG3 全部源码已解包在 `scratch/_aig3/extracted/`。
- 同名 `db` 片段跨 pack 遮蔽规则：加载顺序靠前 pack 胜出（实测）。Yin-Yin 系 `!cth_yinyin_expedition.pack` 必须排在 `cth_yinyin_pol.pack`/`!cth_yinyin_pol.pack` 之前，或依赖上述 fix pack。

## 本地 MOD 元数据机制（wh3mm，2026-09-13 补全）

- **介绍（备注）/别名**：`%APPDATA%\WycccModManager\state.db` → `user_mod_data(mod_id, alias, notes)`，按 `local:data:<路径sha256[:18]>` / `steam:<wsid>:<pack>` 索引；改库前先备份（目录内 `.bak_*` 惯例）。
- **封面**：pack 同目录同名图片（`<pack>.png/.jpg/.jpeg/.webp`，`_find_preview`）→ 本地包封面直接放 `data\<stem>.png`；工坊封面即同目录 `<item>/<pack>.png`（发布时同名 PNG 随 pack 上传）。
- **简介来源**：`mod.description` 只来自工坊缓存 `workshop_cache.json`；本地包若与某工坊 item 文件夹内同名 pack 冲突（`_merge_data_workshop_duplicates`），会继承该工坊标题/简介/封面——zzz_psw_merged 曾因此显示魔女の祈祷的介绍（流浪文件已移走，`workshop_pack_index.json` 对应条目已清）。
- 本地包封面已按 10:7（700x490）统一生成在 `data\`，生成器 `scratch/mod_audit/gen_covers3.py`（PIL，Windows Python313）；`!!!!wyccc_runtime_options.pack` 属 INTERNAL_FEATURE_PACK_NAMES 隐藏项，不需要元数据。

## 工作方式

需要生成或修改 WH3 MOD 内容时，先阅读 `warhammer-mod-development_generic/SKILL.md`，再按任务类型读取对应 reference：

- 新增/派生兵种、坐骑、武器、兵牌、porthole：`references/unit_creation_workflow.md`
- TSV/DB：`references/tsv_format.md`、`references/naming_conventions.md`
- Lua：`references/lua_api.md`
- effect/effect bundle：`references/common_effect_keys.md`
- 目录与原版查证：`references/project_structure.md`
- RPFM、日志、网页核验：`references/rpfm_and_verification_workflow.md`

当用户反馈“这样不对”“RPFM 报错”“游戏日志报错”“以后按这个规则来”时，判断是否需要更新 development 指南。更新流程见 `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md`。
- **2026-09-21 重装完成与最终归因**：游戏重装（83GB）+ 工坊 105 项回下 + Steam 校验修复 `steam_api64.dll`。**marine 崩溃根因实锤**：`zzz_czx_swarm_units3.pack` 的 `battle_animations_table` 引用骨架 `czx_marine`，但 pack 缺整张 `battle_skeletons_tables`（同缺 `unit_sets`/`ui_unit_groupings`）→ battle init 空指针。源 TSV 版本戳不可信（写 v56/5/3，游戏实际读 v17/2/1）。修复=旧包补三表+清 stale 单位（cishe/gou/leishou）+补 loc 缺口；`tools/sync_pack_to_source.py` 已把部署包反同步回 `mod_files/zzz_czx_swarm_units`（含凯瑞甘 agent 全套，此前源码缺失）。state.db 曾被截成 2 项，已从 `state.db.bak_deploy_ia_all_factions` 恢复 114 项 playset_items + enabled_order。验证矩阵全过：swarm/digimon+swarm/全 playset 自定义战斗 + 全 playset IE 战役初始化到回合处理。仍缺 `!!!wyccc_cn_localization_patch*.pack`×2（无源，纯文本，不崩）。
