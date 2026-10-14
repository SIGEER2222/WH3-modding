# PSW 能力/技能全目录与塔奖励品级方案

> 数据来源：`!!Prayer_of_star_witch.pack` 二进制表解码（rituals 464 行）+ 脚本全文
> （`psw_额外函数/psw_主函数×2/psw_记忆结晶/psw_UI` 等）。提取产物在 `scratch/psw_ritual_catalog.json`、
> `scratch/psw_jyjj_pools.json`、`scratch/psw_ritual_names.json`。
> 解码器：`scratch/decode_db_table.py`（build_pack.py 编码的逆运算）。

## 1. 总览：PSW 的"超能力"分布在哪

| 层 | 载体 | 数量 | 性质 |
|---|---|---|---|
| **记忆结晶（什亭之匣）** | `psw_jyjj_{sx,xd,xg}_*` 仪式键 | 101 张（PSW 自带 lv1-5 品级池） | 派系级"卡牌"，体力+次数双消耗，效果=效果包+脚本 |
| **额外能力（ewnl/超能力）** | `psw_dlc6_*`、`psw_pql_*`、`psw_moyin_*` | ~60 个 | 仪式驱动，多为脚本实现 |
| **buff/支援系** | `psw_dlc7_buff/lilika/chunting/feibi_qmd/firefly/zaomiao_*` | ~50 个 | 各角色体系辅助仪式 |
| **非能力条目** | `mulu`目录、`main_sx`计数、`jwts`招募、`xueli`案件、`saima`、`ams`商店、`tfmw`魔王、`mw`世界boss | ~280 个 | 系统/菜单/资源条目，**不是能力** |

仪式表关键事实：**所有能力仪式的 `self_payload` 都是 `psw_pql_qyyszf` 标记**，真实效果 100% 走
Lua（`RitualCompleted` 分发 19 个特殊分支 + `psw_jyjj_main_use_effect` 卡效果分发 + 各体系独立监听）。
想复用效果 → 调 PSW 全局函数或直接发结晶；想改数值 → 自制效果包。

## 2. 品级划分轴

| 品级 | 判据 | 塔内定位 |
|---|---|---|
| **UR·镇塔** | 灭派系/灭行省级（不可逆、改变战局版图） | 仅"塔之馈赠"终局二选一或禁用 |
| **S·战略** | 行省/地区级打击或控制、跨图机动、全军级恢复 | 登顶/Boss 层稀有牌 |
| **R·战术** | 单目标增益/伤害/控制、单体传送、召唤 | 精英层/商店牌 |
| **N·支援** | 资源、临时面板、抽牌、轻恢复 | 普通牌 |
| **EX·不可授** | 绑定专属角色/天赋、tfmw 魔王战元数据、会写剧情全局态 | 不进池 |

## 3. 可直接复用的脚本能力（已核实函数体）

### UR·镇塔（灭派系/灭省）

| 能力 | 键 | 实测效果 | 守卫 |
|---|---|---|---|
| 帝弓降世 | `psw_dlc6_ex_fuxuan_dgjs` | 目标派系**所有领军将领+部队全灭** | 非人类/黑名单 `_qb`/魔王豁免/自身实力≤目标才可用 |
| I.Am.Atomic | `psw_dlc6_anying_atomic` | 目标**行省内所有敌派领军部队全灭**（`kill_character_and_commanded_unit`） | 同上守卫 |

### S·战略（区域打击/控制/机动）

| 能力 | 键 | 实测效果 |
|---|---|---|
| 诺亚的大洪水 | `psw_dlc6_pql_ewnl_nyddhs` | 目标**地区内所有交战敌派军队 -20~80% 兵力**（耗魔力×2+水土等级×4+20，上限 80%） |
| 流星雨 | `psw_dlc6_xingfa_cnl_liuxing` | 目标地区内所有交战敌派军队 **-50~80% 兵力**，自身 6 回合 CD |
| 镜之环 | `psw_jyjj_xd_feibi_jzh` | **冻结目标地区内所有敌军 2 回合**（不能移动）+记录坐标；配套 `追寻光芒之所` 把派系领袖传送至该坐标 |
| 飞雷神 | `psw_jyjj_xg_main_feileishen` | **派系领袖传送至目标角色旁**（任意可见角色） |
| 异界跃迁 | `psw_dlc6_qiyana_yjyq_own/ally` | 先标记己军角色，再将其传送至友军目标旁（两段式） |
| 时间回溯 | `psw_dlc6_xingfa_cnl_sjhs` | **本派系全军恢复 100% 兵力**+2 回合 buff，6 回合 CD |
| 不眠不休 | `psw_dlc6_ex_mika_syxy_bmbx`（未花系） | 派系全军行动力恢复（`psw_main_reheal_xd_juli`） |
| 演出开始 | `psw_jyjj_xg_xnm_ycks` | 目标角色**1 回合不能行动**+省域粉丝计数换祈愿石 |

### R·战术（单目标）

| 能力 | 键 | 实测效果 |
|---|---|---|
| 该剪票了哦/时符 | `psw_jyjj_xg_main_jianpiao`、`xd_xiaoye_shifu` | `replenish_action_points`：目标角色**行动力全恢复** |
| 未花的援护 | `psw_dlc6_ex_mika_mulu_whdwh` | 目标军队**兵力全恢复 100%**+buff |
| 瞳术天照 | `psw_jyjj_xg_zuozhu_tstz` | 目标军队施加赤炎 debuff（`tstz_bundle`） |
| 加具土命 | `psw_jyjj_xd_zuozhu_jjtm` | 敌全军 3 回合 debuff |
| 起源弹 | `psw_jyjj_xg_qiesi_qyd` | 目标军队施伤害包（对 boss 军无效守卫） |
| 感知汲取 | `psw_jyjj_xg_ktll_gzjq` | 目标军队 debuff + 其派系 tfmw 防 -5 |
| 慈爱的飞吻 | `psw_jyjj_xg_mali_chu` | 目标派系：兵力差<8 时 +800 屏障 3 回合 + tfmw 血+8 |
| 安的巨大英灵 | `psw_jyjj_xd_anne_jdyl` | `grant_unit_to_character`：目标军队**直接加一个巨兽单位** |
| 爱丽丝决斗 | `psw_dlc6_alice_game_juedou` | 1v1 决斗邀请（需蔷薇少女天赋+对局状态）→ EX |
| 恶魔契约 | `psw_dlc6_gxj_emqy` | 梗小姐专属 → EX |
| 预卜吉凶 | `psw_dlc6_cstf_fuxuan_ybjx` | 符玄专属占卜 → EX |
| 生/死形态、启示之翼 | `psw_dlc6_cstf_niao_*/ygn_qszy` | 形态切换，角色专属 → EX |

### N·支援（资源/面板/抽牌）

| 能力 | 键 | 效果 |
|---|---|---|
| 魔力炼金 1-4 | `xg_main_moli_1~4` | 国库 `(100~500)×回合数 + 魔力×5×系数` |
| 财宝箱 | `xg_main_caibao` | 共鸣水晶 +1 |
| 疾如岛风 | `xd_main_jrdf` | 结晶使用次数 +1 |
| 预知梦 | `xd_main_yuzhi` | 随机得一张已解锁 lv5 结晶（可选类别） |
| 治愈 1-4 | `xg_main_zhiyu_1~4` | 派系全军 +10/20/30/50% 兵力 |
| 魔力爆发 | `xg_main_mlbf` | 按"魔力诱导"层数加 tfmw 攻 |
| 光玉 | `xd_zhu_guangyu` | tfmw 血+2 + 随机属性 + 光玉计数 |
| 守护星芒 | `xg_xinghui_shxm` | **全体人类玩家** +5 护甲计数（多人向，单机慎用） |
| 愿主垂怜/垂怜经/审判/祝福/似神者/荣耀颂/伊甸园/大天使长 | `ex_mika_syxy_*` ×16 | 未花"神名"安装体系——全部绑未花天赋线 → 多数 EX |
| 七曜元素 火水金木土日月 | `psw_pql_*` ×7 | 耗 qyyszf 升对应属性等级 1 点（日/月需 2）——PSW 自有成长资源，**塔版可做成"七曜点"资源奖励** |
| 美德 节制/正义/勇敢/宽容/慷慨/希望/诚信 | `dlc7_feibi_qmd_*` | 菲比美德体系，绑角色 → EX（机制可仿：自选一种全局美德 buff） |
| 春庭花卉 百可花/美耳草/天使花/合欢/香草 | `dlc7_chunting_*` | 敌军队花卉 debuff → R 级可复刻为塔诅咒牌 |
| 莉莉卡 扰乱/浮游/古代语/月女神/巨人兵援助/青月祝福 | `dlc7_lilika_*` | 角色专属增益 → EX（机制可仿） |
| 魔引 祸鸦日神之乌/神木三珠树/异化提亚马特 | `moyin_ex_*` | 召唤型"魔引"觉醒物 → S~UR（需核实召唤物强度） |

## 4. 记忆结晶（什亭之匣）101 张 —— PSW 自带品级

PSW 在 `psw_记忆结晶.lua` 已把卡池分 lv1-5（权重各 5）：

| lv | 数量 | 代表卡 | 效果类型 |
|---|---|---|---|
| 1 | 7 | 防御/攻击(小)、治愈(小)、赤之黑键、今汐一式、柚子编年史 | tfmw 面板/轻治疗/国库 |
| 2 | 12 | 防御/攻击(中)、治愈2、魔力炼金2、螺旋丸、手枪速射、光玉、克苏鲁宝可梦、菲比主导 | 同上加强 |
| 3 | 29 | 防御/攻击(大)、治愈3、魔力爆发、慈乐之音、绿之破音、镜之环、死兆、疾如岛风、使魔操控、起源弹、剪票、天照、演出开始、追寻光芒之所、飞萤之火、今汐终式、暴力美学、Astrum应援 | 混合，**战略牌开始出现** |
| 4 | 31 | 防/攻4、治愈4、魔力炼金4、天之车轮、巨大英灵、该隐之印、天衣无缝、仙法螺旋丸、星星花绽放、时符、星落、开海(ql)、预知梦?、冰枪突刺、神霓飞芒、制令克己复礼、感知汲取、压制攻击、守护星芒、净化烈焰、妖精萤火 | 强战术 |
| 5 | 22 | 炽天覆七重圆环(防5)、攻击5、预知梦、开海、岩王帝君、生命演算、飞雷神、银冰吐息、克己复礼系、青月女神祝福、神秘果、我们的冒险、直至一切燃烧殆尽 | 顶层 |

效果分类标记（源码内建）：`dmg_jyjj_pool` 14 张伤害卡、`heal_jyjj_pool` 16 张治疗卡、
`jyjj_can_target_ritual` 10 张需选目标的"真·超能力卡"（飞雷神/天照/飞吻/起源弹/演出/剪票/
时符/巨大英灵/镜之环/感知汲取）——这 10 张就是用户要的"超能力"主体。

**关键约束**：
- sx/xg 卡多数是 **tfmw 魔王战元数据**（`psw_tfmw_add_temp_atk/def/hp`）——只影响 PSW 自家
  boss 战计数，对普通战局**零作用**。→ 普通派系拿 sx 攻防卡 = 废牌。
- 鸣潮系卡（今汐/珂莱塔/菲比/维里奈/守岸人/坎特蕾拉 6 角色线）使用前检查 `mc_data.gmz_data.is_on`
  ——未获"共鸣者"即弹窗拒绝。→ **EX：不可授予无共鸣者的派系**，除非奖励里先送共鸣者。
- 卡使用还消耗"体力"+"次数"（`player_tili_crt`/`card_use_num_crt`）——送卡同时要评估这两项存量。

## 5. 塔集成方案（建议）

**主方案：发"真结晶"，不发仿品**
塔奖励直接调 PSW 原生 API 把结晶塞进玩家什亭之匣：
```lua
-- 解锁并立刻获得 1 张（原生 UI/消耗/音效全保留）
if psw_main_data and psw_main_data.player_data[fac] 
   and psw_main_data.player_data[fac].crt_card 
   and psw_main_data.player_data[fac].crt_card[key] then
    psw_jyjj_main_unlock(fac, key, true)   -- is_unlock=true + card_num+1
end
-- 随机抽：psw_jyjj_main_pickup(fac, "default"|"xg"|"xd"|"sx")
-- 补充消耗品：psw_jyjj_tili_num_change(fac, n, "heal") / psw_jyjj_use_num_change(fac, n, "heal")
```
好处：玩家在原界面用牌，数值/音乐/动画原汁原味，零维护。风险：依赖 `player_data` 已初始化
（PSW 对人类派系自建）+ 鸣潮卡条件限制 + tfmw 卡对普通派系无用——**发牌前按上述约束过滤池**。

**辅方案：塔牌复刻战役侧效果**
对 tfmw 系/条件不符的卡，塔自制等价物（现有 8 张星辉牌即此路线）：
- sx 攻防卡 → 复用现有 `psw_twr_gift_might/ward` 效果包思路，给真实军队面板
- 飞雷神/剪票 → 已可做（`teleport_to`/`replenish_action_points` 是 vanilla API，原版函数可直接 pcall 调用）

**品级映射（建议）**
| 塔品级 | 来源 | 发放场景 |
|---|---|---|
| UR | 帝弓垂询（已实装）、Atomic 复刻版 | 仅登顶馈赠二选一，一局一次 |
| S | lv5 池 10 张目标卡（飞雷神/镜之环/剪票/天照/起源弹/演出/感知汲取/巨大英灵/时符/加具土命）+ 流星雨/大洪水复刻 | Boss 层/30 层 |
| R | lv3-4 池战役侧有效卡 + 七曜点+2 | 精英层/星门事件高档 |
| N | lv1-2 池 + 体力/次数补充 + 共鸣水晶 | 普通层/事件 |
| 排除 | 鸣潮系未获共鸣者的卡、纯 tfmw 计数卡（除非玩家玩 PSW 魔王线）、形态切换/决斗/契约、menu/计数条目 | — |

**待实测确认**：
- `psw_jyjj_main_unlock` 对非 PSW 深玩派系是否安全（`crt_card[key]` 可能不存在 → 先判空）
- 送"次数/体力"是否即时生效（`use_num_change(...,"heal")` 直改 `player_data`）
- 魔引（moyin）三件的召唤强度未读，S/UR 定级需先看 `moyin` 函数体
- `main_use_effect` 若绕过 PSW 卡 UI 直接当塔牌用，会同时消耗体力/次数——塔版应走"送结晶"而非"代放"
