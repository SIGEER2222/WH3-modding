# PSW 合并补丁测试清单

## 斯卡文抽奖 / 地下城槽位隔离

在斯卡文玩家存档中确认：

1. 找到至少一个已有 Under-Empire 的地区，并记录其 `slot_set_key` 和建筑。
2. 点击 PSW 抽奖按钮；抽中的天赋应出现在独立的 `psw_cult_slot_set_key` 管理器中。
3. 回到原地下城，确认原 `wh2_dlc12_slot_set_underempire` / `wh2_dlc29_slot_set_underempire` 建筑与槽位数量未变化。
4. 再抽一次并触发一次天赋失败回退/清理，确认只改 PSW 槽。
5. 在尚无安全自有地区的存档中点抽奖，确认脚本记录 `no safe owned region` / `lottery cancelled`，且地下城仍不变；占领地区后重试应建立专用槽并恢复抽奖。
6. 读档后重复第 2–4 步，确认不会重复创建 slot set 或覆盖地下城。

日志标记：`[psw_skaven_slots]`、`[psw] lottery cancelled`。

当前静态源检查不能替代游戏内验证；部署后必须用 WMM 启动目标存档完成以上场景。

## 世界 Boss 传送

在有存活世界 Boss 的玩家存档中：

1. 选中一支非领主军队，再触发世界 Boss 传送并选择传送；确认日志中的 `commander_source=current_ui`（或 `cached_selection`）和 CQI 对应所选军队，而不是派系领袖。
2. 让当前 UI 选择与缓存不一致，重复传送；应以确认时当前选中军队为准，即日志来源为 `current_ui`。
3. 在诊断副本中让当前选择与缓存都不可用；确认回退优先选首支非领主在图军队，仅无其他军队时才选领主，并从 `[psw_boss_tp]` 日志确认来源。
4. Boss 军队移动后再次传送；确认日志 `destination_source=live_boss`，并在 Boss 当前军队附近落地。
5. 在诊断副本中让实时 Boss 目标不可用、但保留阶段刷新坐标；确认回退日志 `destination=saved_spawn_fallback`。
6. 目标坐标缺失/无效时确认日志为 `teleport skipped`，且没有触发 Boss 挑战状态或移动任意我方军队。
7. 选择回程，确认与去程相同 CQI 回到记录的出发位置；若该军队已失效，确认日志为 `original commander unavailable`，且其他军队不移动。

日志标记：`[psw_boss_tp]`。


## 魔女高塔（星塔试炼 P0）

入口：外交建筑「星巫战法」-> 联动祈愿 ->「星塔试炼」。

1. 新开试炼：确认生成祈愿军（通用将领 + 6 队基础兵）、第 1 层登阶困境弹出、
   日志 [psw_tower] tower army spawned。
2. 迎战 -> 确认困境 -> 敌军在塔军附近生成并强袭 -> 战后日志胜/败、
   胜者部队满血补员、缺失单位补回、将领 +1 阶。
3. 奖励困境：三个「选项 I/II/III」的 payload 应显示真实单位卡，
   择一入伍；「放弃招募」+25 星尘。
4. 秘境：随机事件各选项按文案结算（星尘增减 / 部队 / 国库 / 伏击战 / 越层）。
5. 商铺层（3/8/13/18/23/28）：三档标价正确扣星尘并发兵；星尘不足时
   点击无效（日志 shop buy failed），可离开重选；每层限购一件。
6. 休整：+8 星尘直接进下一层；离开高塔：试炼清空、祈愿军解散、星尘保留。
7. 层主层（10/20/30）：敌军预算与 Exalted 将领正确；通关 30 层后
   胜利困境 -> +12000 国库、+200 星尘、军队解散。
8. 败北：败军 -> 终结困境 -> 清理（敌军消失、试炼状态清空、星尘保留）。
9. 存档/读档恢复：分别在 battle_pending、reward、event、shop 状态
   存档重进，从联动入口继续应恢复对应困境；in_battle 中存档读档后
   应清敌 -> 重发迎战困境。
10. 联动页二级菜单：更多联动 -> 狱政管理按钮仍工作。
11. 兼容性：无 Lin/无双/监狱 mod 时联动页仍含星塔且可用；
    PSW 派系 subculture 不在 25 池内时回退帝国池生成单位。

日志标记：[psw_tower]。

### 2026-10-10 实测记录（merged30/31，伊姆瑞克旧存档）

- 星尘来源修正：`cm:faction_add_pooled_resource` 的 factor 参数须传
  `pooled_resource_factors` 键（`other`/`events`），不是 junction 的
  `unique_id`；传 `psw_tower_stardust_other` 会静默失败、余额恒 0。
  同时 campaign_group 授予的资源只在**新档初始化**时创建，旧存档中
  `resource()` 为空接口。因此星尘权威余额改为 saved_value
  `psw_twr_sdust`，pooled resource 仅 pcall 镜像（新档点亮资源栏）。
- 已验证：开塔(军4411/6兵/天赋+3) -> 节点 -> 迎战 -> 伏击战生成 ->
  自结算胜利 -> 奖励(放弃+25) -> 休整(+8) -> 第18层商铺 ->
  水晶兑换x2(+150,扣gmsj) -> 购普通增援(-350,兵卡6->7) -> 离开高塔
  (run ended: quit 清理完整)。塔代码全程无 SCRIPT ERROR。
- 已知交互坑：UI 点击日志中的 `tab_details` 是悬停噪声，并非点击失败；
  看似未生效的点击实际已生效，重复点会**双重推进层数**（不是代码 bug）。
- 分辨率 2560x1440 时 uicomponent `position on screen` 即物理像素坐标，
  docker dump 的 pos 可直接用于 SendInput 点击（1:1）。
- 待测：事件各选项效果、精英(5/15/25)/boss(10/20/30)层、30层通关、
  各状态存档恢复、镜像资源在新档的显示。

### 2026-10-11 联动层实施（merged32_link，未游戏实测）

- v2 + 联动：祝福/休整子困境/竞逐者/冷却（v2 既有）之上，新增
  生态联动——里程碑馈赠（10/15/20/25 层 + 登顶无双>从者>圣物）、
  4 个联动事件（star_gate/captive/relic/omen）、5 件塔圣物自制
  ancillary（ancillaries+ancillary_info+to_effects 三表必备：
  缺 info 行会被扫描判 missing_reference）。
- 软依赖探测：`summon_servant`/`wyccc_wushuang_hero_lottery_config`
  全局表存在性；Lin 资源按 pooled_resource 读数 -1 + 发后回读验证；
  全部 tpcall，缺席回退星尘/水晶。
- 无双发放链：create_agent → find_faction_subtype →
  wyccc_wushuang_character_setup:prepare → 写回 lottery.state.claimed+save。
- 监狱系统不联动：queue_prison_incident 是 local 未导出，战俘事件走资源。
- 待测：联动通道每个 grant_* 实际落位（从者/无双角色是否如期入世、
  art/命名是否正常、claimed 是否防重复）、里程碑播报、圣物入库、
  omen 扰乱对 rival 层数的回写。


### 2026-10-12 试炼流派（merged33_schools）待测
- [ ] 开始试炼后弹出择道困境，五道描述完整
- [ ] 凡武道：初始军仅近战系，战利品/商铺/事件招募只出近战系
- [ ] 远击道：远程池；百兽道：巨兽池（造价窗1200内能否成军）
- [ ] 各道 cul 祝福实际出现在三选一（凡武-血潮汹涌 等）
- [ ] 首通证道播报 +5 水晶；二通无额外
- [ ] 存档在择道状态恢复重发困境

### 2026-10-12 MCT 配置（merged34_mct，未游戏实测）
- [ ] MCT 面板出现「魔女高塔」条目，5 节 15 项全部渲染
- [ ] sd_mult=2 时塔内星尘收入翻倍；victory_mult=0 时登顶无国库星尘
- [ ] w_elite=0 时掷路签不再出精英；全 0 时兜底发事件签
- [ ] rival_enable=off 后竞逐者冻结；rival_pace=3 明显提速
- [ ] rival_reinf=0 时抢先登顶不再带援军
- [ ] run_cd=0 时 run 结束立即可再入塔
- [ ] 改完设置同一回合内生效（不重启）；无 MCT 环境回退默认值不报错
- [ ] 英杰御灵（异道页 SECOND）：单将+15级+御灵孤胆包，战利/商铺/事件=灵契召唤巨兽
- [ ] 择道首页 FIFTH 万灵诸道翻页，异道页 THIRD 重择返回
- [ ] army_cap=30 时起步编成约9队、敌军满编29、援军约12；改20后相应收缩

### 2026-10-12 签名编队+勋级（merged38_comps2，未游戏实测）
- [ ] 精英层(5/15/25)：主题命中签名编队——nor 猛犸群/emp 蒸坦/skv 武器队整队出现（tlog "signature comp"）
- [ ] Boss 层：chs=Chosen 王座军、dae=四神大魔混编、kho/nur 魔军签名
- [ ] 伏击战 wef 主题=Waywatcher 阵
- [ ] 敌军兵牌勋级：F≤10=2 级、≤20=5、>20=8、精英+1、Boss=9（战斗内看兵牌金杠）
- [ ] MCT sig_comp=off 后回退信条构建
- [ ] DLC29 单位（blightkings/泰坦/摩竭/德肯霍夫）实装入场

### 2026-10-12 魔女馈赠（merged39_gifts2，未游戏实测）
- [ ] 登顶播报「魔女亲授：EX 天赋已直入祈愿槽」；派系祈愿槽新增一格 psw_tf_ex_*
- [ ] 登顶播报「星辉临赐」；派系效果列表出现 星辉临战/星幕加护 之一，3 回合后消失
- [ ] 天赋槽全满时馈赠静默跳过（无播报无报错）
- [ ] 天赋共鸣：本体天赋≥20 时祈愿军将领入塔 +1 级（40 个 +2，封顶 +5）
- [ ] 里程碑 15 层可出 星穹法球/星轨长弓；星轨长弓详情页远程威力+15、远抗+8
- [ ] 重复登顶天赋不重复（set_<key> 去重）
- [ ] 非 PSW 派系（无 slot manager）登顶不报错，仅跳过天赋馈赠

### 2026-10-12 效果包+词缀+Asc（merged40_sig，未游戏实测）
- [ ] 精英/Boss 战敌军详情面板出现军势 bundle（巨兽军势/火力军势等）
- [ ] 入塔事件播报「塔之谴」词缀，全部敌军面板可见词缀效果
- [ ] MCT mutator=off 后新 run 无词缀播报、敌军无词缀效果
- [ ] 通关后再入塔播报 Ascension I 且敌军带 asc1 bundle；二通升 II
- [ ] skv/nor/vmp/brt 精英战偶发变体签名（瘟疫僧海/冰原狼群/幽冥骑影/天马团，tlog "signature variant"）
- [ ] sig_comp=off 时签名 bundle 也不挂（与编队同条件）

### 2026-10-12 帝弓垂询（merged41_digong，未游戏实测）
- [ ] 登顶确认后弹「帝弓垂询」困境（有交战 AI 派系时），两选项描述完整
- [ ] 选「帝弓降世」：目标派系所有领军将领+军队消失（feed 派系毁灭/军队损失滚动），播报「帝弓已降」
- [ ] 选「收起星弓」：+2 共鸣水晶，播报「星弓归鞘」
- [ ] 无交战派系/敌全 _qb/敌无领军 → 登顶后不弹此困境（日志 digong: no eligible target）
- [ ] 魔王派系 tfmw_is_start 时不会成为目标
- [ ] 存档于帝弓困境待决→读档→下回合重发困境；目标已灭则清标志不骚扰
- [ ] 不触发本体守卫漏网：人类派系（多人档）绝不被选

### 2026-10-12 帝弓垂询+奖励概率（merged41_digong，未游戏实测）
- [ ] 登顶清算后弹「帝弓垂询」二选一（有合法目标才弹；无交战敌/全_qb/魔王时静默跳过）
- [ ] FIRST 帝弓降世：目标派系全部领军将领+所率军队抹除，播报「帝弓已降」；SECOND 收弓 +2 共鸣水晶
- [ ] 目标失效（和谈/灭国）时点 FIRST 播报「星矢落空」不伤兵
- [ ] 存档/过回合后垂询重发（SK.digong 待决标志，属主+目标双校验）
- [ ] MCT reward_chance<100 时战后兵牌奖励节点按比例替换为保底星尘
- [ ] MCT link_chance<100 时里程碑/登顶联动奖励按比例走保底档

### 2026-10-12 星辉卡牌（merged42_cards，未游戏实测）
- [ ] 入塔困境出现第三项「星辉手牌」；冷却困境出现第二项同名
- [ ] 牌单困境逐张列出（≤4 张），FIFTH 收起
- [ ] Boss 层(10/20/30)胜利各 +1 牌、登顶 +1、deck 事件免费+1/-60尘+2
- [ ] 星步：全军行动力回满（塔军不受影响）；归星：领主回首都
- [ ] 星愈：全军血量回满；星风/星律：1/2 回合效果包挂上
- [ ] 星眸：全图迷雾散开；星锻：入手塔圣物；星晶：水晶+2
- [ ] 手牌满第 5 张自动折 +30 星尘（播报 overflow）
- [ ] 用牌后还有手牌自动重开牌单（连打链）
- [ ] 无领军将领时打星步/星愈 → 卡牌保留+fail 播报
- [ ] 牌单困境中存档读档：卡牌保留（困境消失可重进）

## merged42_polish 待测
- [ ] 存档/读档后节点三签、奖励、祝福、商店货架、事件与存档前完全一致（SL 不重掷）
- [ ] 困境打开时连点塔入口不叠第二张困境（dlg 锁）
- [ ] 5/15/25 层首签必为精英且签面已播报敌方派系；里程碑 m2 文案与实际相符
- [ ] 每层推进收到「高塔回响·第N层」feed（同层不重复）
- [ ] Boss 层：具名播报 + 常驻援军入场 + 额外词缀播报 + 敌将星弓
- [ ] 休整层 FOURTH 遣散删队尾兵牌 +60 尘；单将时退化保底
- [ ] 主动撤退清算上限 4 水晶；败北腰斩后上限 2
- [ ] 新事件：献祭换 S 祝福 / 蚀星契约 +200 尘 / 星赌下战翻倍返还
- [ ] 开局 FOURTH 自谴：敌军双词缀 + 全局星尘 +50%
- [ ] 证道流派再入塔收到「道印护佑」开局祝福
- [ ] 节点 FIFTH 星辉手牌：打出/空手均正确回节点；CD 期 SECOND 开手牌
- [ ] 商店满编/无将领时不扣星尘；购买后货架清空

### 2026-10-12 记忆结晶馈赠（merged43_jyjj，未游戏实测）
- [ ] Boss 层 10/20/30 胜 → 结晶 N/R/S 档播报 + 什亭之匣内可见可用
- [ ] 无共鸣者派系 → 鸣潮系卡不落入抽选（日志无 jyjj_grant error）
- [ ] 非 PSW 深玩派系（crt_card 未初始化）→ 静默跳过，不报错
- [ ] 附赠体力+2/次数+1 实际到账（什亭之匣界面数值）

### 2026-10-12 禁咒卡牌（merged44_rare，未游戏实测）
- [ ] 登顶后手牌入手星陨或星缚（禁咒，不入普通池）
- [ ] 打出星陨 → 最强交战派系全军兵力 -40~60%（战报可查）
- [ ] 打出星缚 → 最强交战派系全军下回合不能移动
- [ ] 无交战派系时打出 → fail 播报且卡牌保留
- [ ] 帝弓黑名单（_qb 剧情派系/魔王）目标自动跳过

### 2026-10-12 实测记录（merged45_dbgtest，伊姆瑞克存档，调试困境注入）

调试入口：点 docker 外交钮 → 关外交面板 → 「高塔调试台」困境弹出（5 项）。
注意：SendInput 点击需要游戏窗口处于前台，IDE 抢前台时点击全部落空；
PostMessage(pclick) 能触发引擎 uicomponent dump 但对困境按钮无效。

- [x] 调试困境菜单正常弹出、五选项路由正确
- [x] FIRST：四牌入手 + 手牌困境自动展开
- [x] 手牌 UI 逐张打出：打出星步(march) → "card used: march, left=3" + feed 播报 + 手牌自动重开
- [x] 打出星愈(heal) → "card used: heal, left=2" + feed 播报
- [x] 空槽位点击无害：只重开手牌，不消耗不报错
- [x] 手牌溢出：3 手牌时再发 4 张 → 2 次 card_overflow 播报（+60 星尘）
- [x] SECOND：结晶 N/R/S 各发放一张，jyjj N/R/S = true/true/true
       （N=psw_jyjj_xg_main_moli_3 / R=psw_jyjj_xd_yly_smck / S=psw_jyjj_xg_main_zhongli）
- [x] FOURTH：EX 天赋授予成功 talent granted: psw_tf_ex_fia_3
- [x] FIFTH：进塔困境 psw_dilemma_tower_opening 正常触发
- [x] 禁咒失败保留：打出星陨 → digong_scan error → card_fail 播报 + 卡牌保留 + 手牌重开
- [x] THIRD 帝弓垂询：无合法目标时静默跳过（"no eligible target"），不崩不弹

### 发现的 BUG（已修复，merged46_rankfix 已实测通过）

- 根因：`math.huge` 在本游戏 Lua 环境为 nil → best_rank 初始 nil →
  r(数字) < nil 报错。与 faction_strength_rank 无关（首轮修法方向偏了）。
  修复：best_rank=nil 起步 + `not best_rank or r < best_rank` + type(r)=="number" 守卫。
  注意：排障时行号会随文件版本位移——第一次报错 741=旧行的 r<best_rank，
  第二轮 744=新行的 elseif 同表达式；静态比对必须按文件体真实行号定位。

### 重启验证（merged46_rankfix，2153 会话全过）

- [x] 帝弓垂询困境弹出 + 目标=最强交战派系 wh2_dlc11_cst_vampire_coast
- [x] 帝弓降世实际灭军：digong fired ... armies wiped=19，feed 出现「派系覆灭」
- [x] 星陨命中结算：card used: starfall（digong_target 命中后真实扣血，n>0）
- [x] 星缚冻结生效：card used: starbind（apply_effect_bundle_to_force 成功）
- [x] 结晶 N/R/S 三轮全 true（moli_3/smck/zhongli、yuzhi、fangyu_2/xlhxcd/firefly_rsdj）
- [x] FIFTH 进塔链 + 塔内星辉手牌入口
- [x] 调试台五项全绿（dbg_1~dbg_5 各一轮）

## 2026-10-11 星仪常驻面板 + 按钮创建时机修复（rankfix 原位更新，0629/0637 会话）

### 修复：顶栏钮创建时机 UICreated→first_tick

- 根因：UICreated（~45s）时 menu_bar>buttongroup 尚未生成，
  hub_ensure_button 静默 return → 按钮永不出现；FactionTurnStart
  兜底要等下回合，首发会话等于没有入口。
- 对照：PSW psw_main_ewnl_button、arthas_quest_teleport 均 first_tick 建钮。
- 修法：cm:add_first_tick_callback(hub_ensure_button + 1s 延迟重试)，
  UICreated/FactionTurnStart 监听保留作冗余。

### 实测结果

- [x] dump_buttongroup：bg[14] psw_twr_hub_button pos=322,2 38x38 vis=true
      （排在 psw_main_ewnl_button 与 arthas_quest_teleport 之前）
- [x] 点击星仪钮 → uicomponent psw_twr_hub_button → 面板「魔女高塔·星仪」打开
- [x] 状态行：「高塔静默·可随时开启试炼·星尘0·共鸣水晶27」渲染正确
- [x] 「开启试炼」行 → psw_dilemma_tower_opening builder 签发
- [x] opening 四选项渲染：开始试炼/离开/星辉手牌/自谴试炼（新增 payload 正常）
- [x] 择道「星塔正途」→ tower army spawned（9 单位，含 ROR 变体）
- [x] 登阶节点「迎战守卫/探索秘境/星屑商铺/离开高塔/星辉手牌」渲染
- [x] 「离开高塔」→ run ended: quit 干净退出
- [x] 外交钮钩 → psw_dilemma_tower_dbg builder 签发（绕每回合一困境配额）
- [x] 调试台 FIRST → 4 牌入手 + psw_dilemma_tower_cards 手牌困境
- [x] 星仪面板卡牌行：星步/星陨/星缚/星愈 4 行带图标渲染
- [x] 悬停星缚行 → 详情板显示 卡名+lore+效果（【禁咒·星缚】缚之环封彻时空…）
- [x] 点击星愈行 → card used: heal, left=3 + feed 播报 + 面板刷新剩 3 张

### 结论

静态入口 UX 全链通过：无需弹窗即可浏览/使用已获星辉卡牌与查看状态；
困境只保留在真正需要即时抉择处（opening/择道/节点/手牌主动展开）。
