STATUS: IN_PROGRESS

# 虫群包模型检验台账（zzz_czx_swarm_units）

- 部署名：`zzz_czx_swarm_units.pack`（mod_id `local:data:14ace1a3e1a423bd2a`，playset《WH3 Campaign Stable》pos 87；9-23 晚起不再用 units3 名）
- 依赖（PFH5 头已声明）：Imperial Arbiter.pack（pos 106）、Lin_Summon_Servant.pack（pos 103）
- 渲染产物：`scratch/model_check/swarm/`；看图副本 `C:\Users\22448\AppData\Local\Temp\modelcheck\swarm\`

## 骨架/动画集速查

| unit | 骨架 | animset(man_animation) | 备注 |
|---|---|---|---|
| czx_feilong 飞龙 | bird01b | bi1b_carrion(vanilla) | |
| czx_zhanglang 蟑螂 | scorpion01 | sc1_scorpion01(vanilla) | |
| czx_jibian 畸变体 | humanoid06 | hu6_gor_dual_axe | |
| czx_hd_green | humanoid06 | hu6_gor_dual_axe | |
| czx_hd_white | humanoid01b | hu1b_def_whip_and_shield | |
| czx_hd_black | humanoid01b | hu1b_def_whip_and_shield | |
| czx_hd_dblack | humanoid11b | hu11b_dlc17_ghorgon | |
| czx_baochong 爆虫 | spider01 | sp1_giant_spider | |
| czx_mangshou 莽兽 | czx_ms | czx_cst_promethean(自定义bin) | |
| czx_baolongshou 暴龙兽 | heavyquadruped01 | hq1_feral_stegadon | |
| czx_inf_tank 感染坦克 | czx_stank01 | czx_steamtank01(自定义bin) | engine=czx_inf_tank_engine；unit variant=czx_inf_marine=驾驶员(同 vanilla steam tank 设计) |
| czx_dehaka 德哈卡 | czx_dehaka1 | czx_dlc17_ghorgon01(自定义bin) | |
| czx_inf_diamondback | spider01 | sp1_giant_spider | |
| czx_inf_marine 感染枪兵 | czx_marine | czx_empire_sword_rifle(自定义bin) | 9-25 刚修武器槽+内部名 |
| gou 跳虫 | wolf01 | wf1_dire_wolf(vanilla) | IA donor：vmd 我方提供→IA g.wsmodel |
| cishe 刺蛇 | snake01 | sn1_sepulchral_stalker_halberd(vanilla) | IA donor：无我方 vmd，variant→IA cishe2.vmd |
| leishou 雷兽 | (bc1_warsphinx) | IA 全提供 | IA donor：我方零资产零DB行 |
| czx_kerrigan | humanoid01b | hu1b_elf_staff_and_sword | 已删单位残留（引用链完整，仅留 vmd/DB 行，无招募入口） |
| czx_kerrigan_lord | humanoid01b | hu1b_elf_staff_and_sword | 同上 |
| kerrigan_base_0 | humanoid01e | —(Lin 召唤体 lin_all_kerrigan_base_0) | 特殊：只查引用链 |
| kerrigan_ultimate_0 | humanoid01e | —(Lin 召唤体 lin_all_kerrigan_ultimate_0) | 特殊：只查引用链 |

## 单位台账

| unit | L0 | L1 | L2 | L3 | L4 | 问题/修复 | 状态 |
|---|---|---|---|---|---|---|---|
| czx_feilong | ✅ | ✅ | ✅ | ✅ | ⏭无游戏窗口 | rmv2 内嵌 tmb_carrion donor 贴图串=vanilla 同款惯例非缺失 | ✅通过(L0-L3) |
| czx_zhanglang | ✅ | | | | ⏭无游戏窗口 | | |
| czx_jibian | ✅ | | | | ⏭无游戏窗口 | | |
| czx_hd_green | ✅ | | | | ⏭无游戏窗口 | | |
| czx_hd_white | ✅ | | | | ⏭无游戏窗口 | | |
| czx_hd_black | ✅ | | | | ⏭无游戏窗口 | | |
| czx_hd_dblack | ✅ | | | | ⏭无游戏窗口 | | |
| czx_baochong | ✅ | ✅ | ✅ | ✅ | ⏭无游戏窗口 | | ✅通过(L0-L3) |
| czx_mangshou | ✅ | ✅ | ✅ | ✅ | ⏭无游戏窗口 | | ✅通过(L0-L3) |
| czx_baolongshou | ✅ | ✅ | ✅ | ✅ | ⏭无游戏窗口 | | ✅通过(L0-L3) |
| czx_inf_tank | ✅ | ✅ | ✅ | | ⏭无游戏窗口 | variant=inf_marine=驾驶员设计确认非bug；engine 走 czx_steamtank01 | 待 L3 补档 |
| czx_dehaka | ✅ | | | | ⏭无游戏窗口 | | |
| czx_inf_diamondback | ✅ | | | | ⏭无游戏窗口 | | |
| czx_inf_marine | ✅ | ✅ | ✅ | ✅ | ⏭无游戏窗口 | 9-25 武器槽/内部名修复本轮复核链路齐；hu1 剪辑骨名全匹配 | ✅通过(L0-L3) |
| gou | ✅ | ⏭IA donor | ⏭ | ⏭ | ⏭无游戏窗口 | 🔧vmd 直连 rmv2(裸贴图名)→改指 IA g.wsmodel，已部署 | 🔧已修待游戏实测 |
| cishe | ✅ | ⏭IA donor | ⏭ | ⏭ | ⏭无游戏窗口 | 🔧variants 行残留指向 vanilla 巨蟒遮蔽 IA cishe2→已改 cishe2，已部署；land_unit 动画=sn1 stalker(vanilla donor 惯例) | 🔧已修待游戏实测 |
| leishou | ✅ | ⏭IA donor | ⏭ | ⏭ | ⏭无游戏窗口 | 我方零行，IA 全供 | |
| czx_kerrigan | ✅ | ⏭残留 | ⏭ | ⏭ | ⏭ | 单位已删仅引用链检查：vmd→wsmodel→rmv2(hu1b)→tex 齐 | |
| czx_kerrigan_lord | ✅ | ⏭残留 | ⏭ | ⏭ | ⏭ | 同上 | |
| kerrigan_base_0 | ✅ | ⏭Lin召唤体 | ⏭ | ⏭ | ⏭ | vmd→rmv2(hu1e)+材质链齐 | |
| kerrigan_ultimate_0 | ✅ | ⏭Lin召唤体 | ⏭ | ⏭ | ⏭ | 同上 | |

## 迭代记录

### iter 1 — 台账建立 + L0 全量 + 首批 L1-L3

- **环境确认**：Warhammer3.exe 实测未运行（prompt 中"运行中"已过时）→ 本包可以直接 --deploy。
- **L0 结论**：
  - 部署包 `zzz_czx_swarm_units.pack` PFH5/386 文件/189MB，依赖块 [Imperial Arbiter, Lin_Summon_Servant]，pos 87 在 playset。
  - 源码↔包内容一致（仅根目录 implementation_notes.md 不打包=设计如此）；无 loose bin。
  - animpack `zzz_czx_swarm_units_animsets.animpack`：4 条目，内部名==stem==DB key（czx_cst_promethean/czx_dlc17_ghorgon01/czx_empire_sword_rifle/czx_steamtank01），bin 头骨架名==battle_skeletons 行（czx_ms/czx_dehaka1/czx_marine/czx_stank01），.anim 引用 37+45+269+7 条全部可解析（包内+vanilla）。
  - 17 个 rmv2 offset12 骨架名与各自 animset 骨架一致；materials/材质/贴图链全通。
  - culture_to_battle_animation 198 行：4 个 czx animset 各 29 culture + wf1_dire_wolf 26 + sn1 28 + bc1_warsphinx 28，全派系覆盖。
  - audit_dangling_refs：0 ERROR / 18 WARN（全部是 wh3_main_cth_the_northern_provinces 已知误报）。
  - unit_card 图标全可解析。
- **发现问题并修复（已重建部署 pos87）**：
  1. `cishe` variants 行 variant_filename=`tmb_sepulchral_stalkers_halberd`（9-22 vanilla-donor 残留）遮蔽 IA 的 `cishe`→`cishe2` 真刺蛇模型（我方靠前胜出）→ 改为 `cishe2`。
  2. `gou.variantmeshdefinition` 直连 `g.rigid_model_v2`（内嵌贴图为裸文件名无路径，缺 wsmodel 材质绑定层）→ 改指 IA 的 `g.wsmodel`（几何同文件+4材质）。自我托管的 g.rmv2+6tex 保留无害。
  - 部署验证：新包 variants 解码 cishe→cishe2、gou.vmd→g.wsmodel；mod_id 不变。
- **L1 静态渲染**（`scratch/model_check/swarm/l1/` → Temp `modelcheck/swarm/*.png`）：
  - inf_marine/feilong/mangshou/baochong/baolongshou/inf_tank 六只全部贴图正确、形态完整、无紫黑缺贴图、无碎裂。inf_marine 与既有 card_marine_*.png 形态一致（虫化巨爪人形为设计形态）。
- **L2 骨架叠加**（`l2/*.png`，tools/blender_skel_overlay_json.py + 各自声明骨架 json；czx_* 骨架经 parse_anim_skeleton 生成 world_pos_frame0 于 `swarm/skel/`）：
  - marine(czx_marine)/mangshou(czx_ms)/baochong(spider01)/baolongshou(heavyquadruped01)/inf_tank(czx_stank01) 骨骼全部落在网格内、脚着地。
  - feilong 叠加图上骨架看似外溢 → 数值核查 `check_feilong_skel.py`：GLB 86 关节静置位置与 bird01b.json **逐骨 0 误差**，网格 bbox ±6.02 正好覆盖翼梢 feather 骨——骨架本来就是同一份，判定通过。
- **L3 动画 GIF**（`l3/*.gif` + `l3_strips/` 首中尾帧拼图）：
  - inf_marine：hu1_rifle_stand_idle/aim_fire/sws_attack 三段——举枪瞄准、挥爪攻击均真实运动，脚不陷地。
  - feilong：从 anim2.pack 提取 bi1b_attack_04/fly_attack/fly_walk/fly_stand/stand_idle_02/death_front_01 共 6 个 .anim → pose json；idle/attack_04/fly_walk/death 四段正常（展翅、扑击、坠地）。
  - mangshou：cr1_attack_01/stand_01 正常；baochong：sp1_jump_attack（腾空扑跳）/stand_idle_04（毒囊鼓动）正常；baolongshou：hq01_attack_01/stand_idle_05 正常。
  - 全程无顶点爆炸、无绑定姿势滑行。
- **L4**：未做——Warhammer3.exe 未运行（无游戏窗口）；本环境有 gfx/D3D 早期崩溃史，不自动归因本包。
- **遗留**：
  - gou/cishe/leishou 游戏内外观需等游戏窗口实测（现已是 IA 标准链，风险低）。
  - inf_tank 驾驶员 marine 在引擎骨架下的呈现（vanilla driver 同款模式）待 L4 观察；inf_tank L3 待补 engine/steam tank 剪辑。
  - implementation_notes.md 是源码根文档不打包，非问题。
  - audit_dangling_refs 18 WARN = wh3_main_cth_the_northern_provinces 不在 custom_battle_factions（上游表键缺失，非本包模型问题，全包统一写法）。
- **下批建议**：czx_dehaka(czx_dehaka1+custom bin)、czx_jibian(hu6)、czx_hd_green(hu6)、czx_zhanglang(scorpion01)、czx_inf_diamondback(spider01)——跨 4 骨架，覆盖剩余自定义 dehaka1 链。
