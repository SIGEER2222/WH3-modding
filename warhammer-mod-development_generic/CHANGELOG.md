# 修订说明

## 2026-09-13 规则新增：工作区卫生——根目录禁止丢临时文件

1. 应用户要求清理根目录堆积垃圾并立约：35 个 `_tmp_*.py` 一次性脚本移入 `scratch/tmp_scripts/`，`_preview/`→`scratch/_preview/`、`_work_kerrigan/`→`scratch/_work_kerrigan/`，0 字节 `battlefield_engines.model` 移入 `scratch/`。
2. `AGENTS.md` 新增"工作区卫生"节：根目录只允许治理文件与已登记顶级目录；`_tmp_*`、`_preview/`、`_work_*/` 只允许出现在 `scratch/` 内；`tools/` 脚本自身产物放 `tools/_<name>/`（`tools/_*/` 整体忽略）；新增顶级目录须先登记职责。
3. `.gitignore` 同步：`/manual_edit/`（用户 .blend 修权目录，415M 二进制不入库）、`tools/_*/` 合并原逐条列出项、新增 `/_tmp_*`/`/_preview/`/`/_work_*/` 根目录兜底。
4. `references/custom_model_unit_pipeline.md` 预览约定从根目录 `_preview/` 改为 `scratch/_preview/`；`manual_edit/README.md` 引用路径同步修正。

## 2026-09-13 规则变更：打包默认自动执行 + 本地汉化补丁全流程

1. 应用户要求取消"打包前询问手动/自动"规则：`AGENTS.md`、`.codex/project_context.md`、`SKILL.md`、`references/rpfm_and_verification_workflow.md` 四处统一改为默认由 Codex 用 `tools/build_pack.py` 自动打包、部署 data、写 playset，不再询问。
2. 落地 `zzz_nanu_dynamic_rors_cn.pack`（Nanu Dynamic RoRs 全量汉化）：3260 行 loc 全翻，翻译管线为"官方 CN 精确反查 → 句式模板 → 手工词典（含 mod 笔误变体）"，0 漏翻；同路径遮蔽靠前胜出，插在本体之前。
3. 新知记入 `references/rpfm_and_verification_workflow.md`：`local:data:<id>` = `local:data:` + `sha256(规范路径)[:18]`（规范路径=绝对路径 `\`→`/` 后 casefold），改 playset 须同步 `enabled_order:<game_id>`。

## 2026-09-13 实测：中文 TTS 引擎横向对比（第二轮）

1. 新跑通 **Spark-TTS-0.5B**（克隆 `clone_spark_advisor.wav` + 参数造声 `orig_spark_male.wav`）与 **IndexTTS-2**（克隆 `clone_idx_advisor.wav` + 情感文本控制 `clone_idx_advisor_angry.wav`，emo_text="怒吼，充满杀气" 被 QwenEmotion 正确解析为 angry=0.95）。
2. **VoxCPM2 判弃用**：voxcpm 2.0.3 三种输入模式均输出幻觉语音，模型已从缓存删除。**F5-TTS 中文克隆被用户判定质量差**，产出与包已删。
3. 当前用户试听最佳：**Qwen3-TTS-0.6B-Base 克隆**（`clone_qwen_advisor.wav`）；1.7B 克隆也已产出待对比。
4. 新坑已记入 `references/audio_and_vo.md`：hf-mirror 大文件逐文件 curl + `x-linked-size` 校验（urllib 循环曾静默截断 3.5GB→800MB）；HF cache 移 E: + symlink 权限规避；IndexTTS-2 需补丁适配 transformers 4.57；descript-audiotools 降级 protobuf 会弄崩 onnxruntime。

## 2026-09-13 清理规则：workshop 目录就地改 pack 的备份必须外移或删除

1. 实测 `steamapps/workshop/content/1142710` 32G 中约 12G 是历次就地修改留下的 `.bak`/`.codex-backup`/`.pre*`/`.orig_*`/`.disabled-*`/`.broken_*` 死备份（单 3018964477 目录 ~11.2G），已全部删除。
2. 游戏只加载 `.pack` 后缀；带额外后缀的备份文件不参与加载，删除安全。
3. `references/rpfm_and_verification_workflow.md` 新增"就地修改 workshop 目录 pack 的备份清理"节：备份放 `scratch/` 或验证后删除，附 find 巡检命令。

## 2026-09-13 实测：AI 配音管线本机跑通

1. 环境 `C:\Users\22448\venvs\wh3tts`（torch 2.11.0+cpu）：F5-TTS、Qwen3-TTS（voice_clone + voice_design）、faster-whisper、edge-tts 全部实测出声；样例在 `scratch/tts_lab/out/`。
2. 原版 wem 提取链：`tools/export_gamedata.py` 的 `iter_pack_entries` 解 pack → `scratch/tts_lab/vgmstream/vgmstream-cli.exe` wem→wav → faster-whisper 转写参考文本 → F5/Qwen 克隆。
3. 两个坑记入 `references/audio_and_vo.md`：torchcodec↔torch ABI 强绑定（卸载 torchcodec + patch `torchaudio.load` 绕过）；HF_ENDPOINT=hf-mirror 偶发连不上需改指官方站。
4. 英文包 `audio_en.pack` 内含 `campaign_vo_cs_proximity` 领主对白 wem，可直接作克隆参考音；中文包仅 ~1600 条顾问/叙事音。

## 2026-09-13 补充：AI 配音（TTS/语音克隆）管线

`references/audio_and_vo.md` 新增"AI 配音管线"节：

1. 当前主流本地方案：GPT-SoVITS（微调音色最像）、IndexTTS-2/2.5（情感解耦适合战斗吼叫）、CosyVoice 3.0（最易部署）；云端 ElevenLabs 质量上限最高。
2. 推荐链路：原版 .wem→wav（AssetExplorer/vgmstream）→ 建数据集 → 克隆生成 → wav→AssetEditor→.bnk/.wem→pack。

## 2026-09-12 新增：音频与语音（VO）接入调研

新增 `references/audio_and_vo.md`，要点：

1. WH3 语音走 Wwise Dialogue_Event（State 路径决策树），普通音效走 Event；语音媒体在 `audio_<lang>.pack` 的 `audio/wwise/<lang>/<id>.wem`，soundbank 在 `audio_*_bnk.pack` 的 `audio/wwise/*.bnk`。
2. 单位战斗语音主链路：`main_units.audio_voiceover_actor_group`→`audio_vo_actor_groups`（`vo_actor_1..15`）+ `audio_voiceover_culture`；`land_units.selection_vo`=`vo_sel_*`；`land_units.man_entity`→`battle_entities`→`audio_entity_types`→`audio_entity_actors`。`.variantmeshdefinition` 的 `META_DATA` 可按模型覆写 `audio_entity_type`/`audio_actor_id`/`audio_armour_type`/`audio_melee_weapon_type`。
3. 领主/英雄战役语音走 `agent_subtypes.audio_voiceover_actor_group`（`campaign_vo_*` 事件族）；派系兜底在 `factions.default_audio_actor_vo_group`；坐骑有 `mounts.voiceover`。Lua 可 `cm:trigger_campaign_vo`/`cm:add_character_actor_group_override`。
4. 自定义语音：AssetEditor Audio Project Compiler 产 `.bnk` 优先；手工 Wwise 路线必须合并 vanilla Dialogue_Event 决策树否则遮蔽原版 VO。
5. 复用原版语音只需填 DB 字段、零音频文件；实测样例 `references/luke_hero/`。

## 2026-09-12 新增：AssetEditor 模型/动画预览与 Skin Wrap 重绑定工作流

新增 `references/asseteditor_animation_workflow.md`，要点：

1. AssetEditor（`tools/AssetEditor/`，v0.78）可不开游戏直接预览 RMV2 模型动画；流程为开 `.rigid_model_v2`（非 `.variantmeshdefinition`）进 Kitbash Editor → 底部动画面板选 `animations\skeletons\<skel>.anim` + clip → ▶ 播放看帧计数与变形。
2. RMV2 v8 头 offset 8 存骨架名 ASCII；v7 未蒙皮文件该字段为空且无权重串，编辑器显示 No Skeleton / 0 帧——本次确认 Arbiter 包 `leishou_2`、`g` 两网格属此类，其余四虫绑定正常。
3. 修复路径：Pin 工具 SkinWrap 模式（目标=同名选择全选坏网格，源=导入的蒙皮参考网格，应用后日志见 `SkinWrapRiggingCommand` + 顶点缓冲重建）；参考网格会落在 Editable Model 里，**保存前必须删**；同文件其他未蒙皮部件（bst_warhounds_head_02）要单独再包一次。
4. UI 自动化细节（截图×1.58 坐标换算、scratch/ 下 `_click/_shot/_uia_*` 辅助脚本、Delete 热键=裸 Delete、对象树选中不高亮要看状态栏）已写入 reference 的"UI 自动化要点"节，后续 AI 可直接复用脚本。

## 2026-09-12 实测反馈：Cco 绑定 UI 控件的默认值无法用 twui 改，需脚本模拟点击

1. 人物技能页"自动分配技能点数"复选框（`checkbox_auto_management`）是**原版**控件，绑定 `CcoCampaignCharacterAutoManagement`；勾选状态按角色持久化在存档（`IsAutoManaging`），改 twui 无效。
2. 解法：`find_uicomponent` → `CurrentState()` → `SimulateLClick()`；或 `GetContextObject("CcoXxx"):Call("...")` 直接读写 context（函数表见 `gamedata/ui/metadata.json`）。
3. 新增小节到 `references/lua_api.md`："UI 组件操作：Cco 绑定控件的脚本化"，含 `PanelOpenedCampaign` 布局名差异（`character_panel` vs `character_details_panel`）与幂等防自激要点。
4. 落地实例：本地包 `czx_auto_skill_manage`（mod_files 同名目录 + build_pack 构建），`PanelOpenedCampaign` + `ComponentLClickUp` 双钩子自动勾选复选框。

## 2026-09-12 实测反馈：战役内 "Placeholder Body" 卡死弹窗 = `show_advice` 缺 DB 记录

新增 `references/ui_popup_and_event_diagnostics.md`：

1. `zzz_psw_merged.pack` 的 `psw_06_chaichu.lua` 拆除天赋后调用 `cm:show_advice("psw_chaichu_done")`，但包内无 `advice_threads`/`advice_levels` 记录、loc 又误用 `advice_info_text_` 前缀 → 点击确认按钮后弹出不可关闭的 "Placeholder Body" 模态框。
2. `show_advice` 完整链路：`advice_threads` 行 + `advice_levels` 行（数字 key）+ loc `advice_levels_onscreen_text_<数字key>`；`advice_info_text_*` 前缀属 infotext 面板，不是 advice 正文。
3. 修复：克隆同包已工作的 `advice_psw_tf_ex_yhzl_1` 行结构，key=`1214413929`，loc 追加 `advice_levels_onscreen_text_1214413929`；`tools/build_pack.py` 重建后部署。
4. 通用诊断：grep 启用包内 `show_advice(`/`trigger_dilemma(` 调用点 → 反查对应 DB 记录是否存在，记录缺失即命中。

## 2026-09-12 实测反馈二次修正：loc 覆盖 = 同路径文件遮蔽 + 文件名排序，守护包 v2

1. 修正先前"靠前 pack 逐键胜出"的记录：loc 实为两层——同虚拟路径时靠前 pack **整文件遮蔽**（洛阳侯 SFO 汉化包即以同名 `##SFO_*.loc` 替换 SFO 英文 loc）；不同文件名同 key 时按**文件名排序**，`!`/`#` 前缀多者优先。
2. 实证：守护包 v1 `!czx_deer24_cn_restore.pack`（单文件 `!!!czx_*.loc`）排在 `CathayENGLISH`（144 行）之前的 136 行仍被其 `!!!!!!wwd_character.loc`（6 个 `!`）击败，`wwd_miao_yin_method_*` 两行继续英文。
3. 修复：`!!czx_deer24_cn_restore_v2.pack` 改为与 EN 包完全同名的 14 个 loc 文件（4934 行，4926 恢复中文、8 个无中文源键保留 EN），靠文件遮蔽覆盖全部 EN key——与逐键排序无关，最稳。已加入全部 preset idx0。
4. 工具能力补记：`wyccc-warhammer-mod-manager` 的 `backend/steamworks_bridge.py` 可脚本化订阅工坊项（`subscribe_workshop_items` → `accepted:True`，实测订阅 SFO 汉化 2801517996 成功）；游戏运行时 Steam 暂停工坊下载属正常。已写入 `.codex/project_context.md`。
5. `zzz_czx_swarm_units.pack` 此前在 data 目录为 `.DIS` 导致无 mod 行不加载，已恢复 `.pack` 并补入全部 preset。

## 2026-09-12 实测反馈：loc 键"靠前 pack 胜出"方向确认与"界面显示英文"诊断

1. loc 覆盖方向与 DB 同名片段遮蔽一致：`used_mods.txt` / 管理器列表中**靠前**的 pack 覆盖同 key loc 文本。实测 `CathayENGLISH.pack`（行 140）排在 `DEER24Cathay.pack`（行 160）之前，其英文 loc 全部覆盖本体中文 → DEER24 领主"叶晟·缙绅逆臣"面板中英混杂。确认 2026-07-09 记录的"汉化补丁排在主 MOD 前面"方向正确，并纠正本次会话中一度按"补丁在后"直觉给出的错误答复 `[实测/需随版本复查]`。
2. MOD 的 `.loc` 不按客户端语言分流：原版 `local_xx.pack` 只加载对应语言，MOD loc 对所有客户端生效；EN 翻译补丁在中文客户端同样覆盖 → 中文客户端应禁用 `CathayENGLISH`（item 2860213243）。
3. loc 二进制诊断细节：显示文本为 UTF-16LE 存储，按 UTF-8 搜会漏检；key 也可能为 UTF-16LE，建议双编码搜索。全工坊 ~19GB/395 pack 的字节级扫描可直接在脚本中完成。
4. 详细诊断流程与案例已写入 `references/crash_and_load_order_diagnostics.md` 第九节。
5. 防复发范式：loc-restore 守护包 `!czx_deer24_cn_restore.pack`——解析 EN 补丁全部 4933 个 loc key，从 DEER24 系本体 pack 反查中文文本重建 `.loc`（8 个键无中文源保留 EN），放入 wh3mm 全部 preset 的 **idx 0**（最高优先级）；即使 EN 包被误重新启用，守护包仍靠前覆盖回中文。wh3mm preset 中条目 `isEnabled:false` 即禁用；**修正**：`used_mods.txt` 行序的真实来源是 `%APPDATA%\WycccModManager\state.db` 的 `playset_items`（mod_id + position），不是 `config.json` 的 presets 数组——后者只管管理器 UI 预设。脚本调序须按 `steam:<wsid>:<pack>`/`local:data:<hash>` mod_id 改 position（本次已把阴阳 CN 补丁移到 `cth_yinyin_pol` 之前）。
6. 另记录：游戏 `data` 目录中 `zzz_czx_swarm_units.pack` 等被 Mod Manager 改名 `.DIS`（禁用态）导致"补丁不生效"；`mod_output` 中构建产物仍在，重打包（含新凯瑞甘 60×130 兵牌/120×260 infopic）后已重新部署 `.pack`。

## 2026-09-12 实测反馈：同名片段遮蔽致悬空引用、Bad Mods 报告解读与全量启动排查

新增 `references/crash_and_load_order_diagnostics.md`，汇总本次启动崩溃排查的可复用结论 `[实测/需随版本复查]`：

1. `bad_mods_report.txt` 语义：`first_invalid_database_record/table/packfile` 指向第一条无效行所在 pack；`record` 把联合主键直接拼接打印。报告指明的是悬空外键行，不等于该 pack 损坏；修复方式是补齐被引用的 key 或移除过期包。
2. 同名 `db/<表>/<内部名>` 片段跨 pack 做文件级去重（非逐行合并），实测加载顺序靠前的 pack 胜出。`!cth_yinyin_expedition.pack` 排在基础包 `cth_yinyin_pol.pack` 之后时其 `cth_yinyin` nodes 片段被遮蔽，新节点 `wh3_main_skill_node_cth_yinyin_magic_1_5` 丢失 → 自身 set_items 行悬空报 Bad Mods。
3. 修复范式：唯一片段名补丁包 `!czx_yinyin_expedition_fix.pack`（data 目录 + 加入 playset），复制必须生效的 nodes/links/set_items/node_sets 片段到 `zzz_yinyin_exp_fix`，与加载顺序解耦；已验证 133+ 全量通过校验。
4. data 目录 `*.pack` 无 `mod` 行不加载，modified.log 记 `unknown file`；改名 `.DIS`/`.bak` 即禁用。
5. 过期兼容包案例：`cth_deer24_units_TLA_warband_upgrades.pack` 引用上游已删除的 `wh3_deer24_hailongjiajun` 单位组 → 悬空；换 Pinkbee 重制兼容包后通过。
6. PFH5/DB 片段二进制结构、Mod Manager `local:data:` 语义、二分排错纪律（badmods≠native-crash、清场要求、leave-one-out 优于孤立启用）均写入新 reference。
7. 原生崩溃（0xc0000005 @0x1404926f0）待查：当日重建的 `zzz_czx_swarm_*` 自研包为首要嫌疑，已禁用待回归 `[需验证]`。

## 2026-09-12 实测反馈：v0 表 flag 字节错误与 agent 单位误入军事编组导致启动崩溃

1. `tools/build_pack.py` 对 version=0 的 DB 表曾写 `struct.pack("<B", version)`（即 `0x00`）作为 flag 字节；经与原版 `db.pack`、Workshop `Imperial Arbiter.pack`、`!!ia_all_factions.pack` 逐字节对照，该字节恒为 `0x01`（version>0 的表在 `FCFDFEFF` 版本标记后同样写 `0x01`）。flag=0 的 v0 表使游戏启动数秒内崩溃，症状是包内多张互不相干的小表单独测试都会崩。已修正为恒写 `0x01` `[实测/需随版本复查]`。
2. `units_to_groupings_military_permissions_tables` 中 `czx_kerrigan` / `czx_kerrigan_lord`（agent 英雄/领主单位）行已移除——agent 单位不属于军事编组语义；是否真为崩因受当时测试预言机（进程存活≠通过，见第 3 条）污染，按可疑值移除处理 `[需随版本复查]`。
3. TSV 行与表头列数不一致会产生"invalid database record"启动报错：`projectiles_tables` 的 `czx_mutalisk_glaive` 行多一个 Tab（`placeholder` 掉出 `projectile_shot_type_display` 必填列），`unit_special_abilities_tables` 的 `czx_ability_kerrigan_psionic_presence` 行少一列。游戏此时在 `crash_report/bad_mods_report.txt` 写出 `first_invalid_database_record/table/packfile`——**判断 DB 校验是否通过应看该文件是否出现，而不是看进程是否存活**（报错对话框不退出进程）。生成/手改 TSV 后应全量扫描"每行列数==表头列数" `[实测/需随版本复查]`。
4. 二分定位法记录：`zzz_test_bisect.pack` 按子集重打 PFH5，Mod Manager 最小 playset（Imperial Arbiter + 测试包）启动，观察 `crash_report` 新 .mdmp，存活约 60 秒视为通过；单表隔离会因悬空外键出现假阳性，"全包减一组" 更可靠。详细说明见 `references/rpfm_and_verification_workflow.md`。
5. 新 MOD `zzz_czx_swarm_units`（源目录 `mod_files/zzz_czx_swarm_units`）替代 `zzz_czx_swarm_expansion`：5 个虫族兵种挂到全派系主要招兵建筑（解锁≥4单位的通用军事建筑链，剔除 special/rogue/outpost 等），7 个 key 进自定义战斗权限表；凯瑞甘保留原版帝国派系第 2 回合 dilemma（cdir 自动触发，Lua 只做选择处理，已修正 `context:faction()` 取实际选择派系）。

## 2026-09-10 实测反馈：旧存档缺少 player_data 字段导致 nil 数值比较崩溃，以及主 MOD 同名脚本覆盖问题

1. `psw_main_data.player_data[faction_name]` 在旧存档里可能缺少 `fia_main_js`、`swyh_install_jishu` 等后来新增字段，监听器/回调里任何 `local x = psw_main_data.player_data[f].x` 或 `psw_main_data.player_data[f].x + 1` 都会报 `attempt to compare/perform arithmetic on nil` `[实测/需随版本复查]`。
2. 修复方式：在脚本顶部维护 `psw_main_default_player_data` 完整默认值表，并加 `psw_ensure_player_data(faction_name)`，在 UITrigger 按钮回调、DilemmaChoiceMadeEvent 监听器、`psw_main_pickup` 等所有读取 `player_data` 的入口统一调用；字段值缺失时回填默认值，不再逐个加 `or 0`。
3. 补丁 pack 实测结论：`zzz_`/`!!!!`/`!!!` 前缀或 `used_mods.txt` 排序均无法保证覆盖主 MOD 同名脚本（`!!Prayer_of_star_witch.pack` 的 `psw_天赋.lua` 一直胜出）。对这类必须修复主 MOD 内脚本的场景，可靠方案是把修正后的脚本直接打进主 MOD pack，同时保留 `.pack.orig_pswfix` 备份 `[实测/需随版本复查]`。
4. 新增 `!psw_crash_guard.lua`（v7）在加载时抹除会导致原生崩溃的坏派系；`!` 前缀脚本确实会加载，但不能解决同路径脚本覆盖优先级问题。

## 2026-09-09 实测反馈：Dilemma 选择分支未处理导致抽奖分支被默认物品抽奖覆盖

1. PSW 合并补丁中 25 回合后 `dilemma_tf_25hh_tf_zb_xz` 仅处理 `SECOND`（祈愿装备/物品），`FIRST`（祈愿天赋）未处理；`DilemmaChoiceMadeEvent` 中未处理分支不报错，直接透传到后续默认分支。
2. 后续抽奖 `if/elseif` 链中“唯一物品抽奖”条件写为 `(nor_count > 4 and turn_number >= 20) or (set_25hh_qy_zb 存在)`，无条件分支在 20 回合后、玩家正常天赋数 > 4 时恒成立，导致选择天赋仍进入物品抽奖。
3. 修复：将物品抽奖条件改为仅依赖 `set_25hh_qy_zb` 标记；`FIRST` 分支显式移除 `set_25hh_qy_zb` 并交予后续 `psw_main_pickup` 处理天赋抽取。详细规则补充到 `references/lua_api.md` 的“Dilemma 选项分支兜底”`[实测/需随版本复查]`。

## 2026-09-07 实测反馈：Lua guard 无法捕获原生访问冲突

1. 根据 PSW 合并补丁在 AI 战后稳定触发 `0xC0000005`、读取空对象偏移 `0x18` 的四份 minidump，补充 Lua 与原生崩溃的边界：`pcall`/`xpcall` 不能捕获游戏 C/C++ 层访问冲突。
2. 记录 `events.CharacterPostBattleCaptureOption` 等直接写入全局 `events` 数组的回调不经过 `core:add_listener`，全局覆盖 `core.add_listener` 无法保护该路径。
3. 补充全局 hook 风险：必须保留合法的 `condition=true` 语义；代理 `cm.callback` 时不得丢失可选名称；排除条件应先于原 condition 执行。
4. 记录窄范围规避原则：只有在日志和 dump 已锁定原生 API 边界时，才在 Lua 包装层按明确对象与条件阻止非必要调用，并保留玩家及其他调用路径 `[实测/需随版本复查]`。
5. 修正 `tools/build_pack.py` 对已有二进制 `text/**/*.loc` 的保留；自动重打包不能只处理 `*.loc.tsv`，否则会静默丢失旧本地化文件。
6. 修正自动编码 DB 时的版本标记：MOD 表即使版本为 0 也显式写入 VERSION marker，保持与 RPFM 生成的旧 Pack 一致，避免无 marker 时被多版本同结构 schema 误判为其他版本。
7. PSW v4 实测在目标 cqi 成功跳过最后一条 trait 后仍以相同原生地址崩溃，确认“最后一条 Lua→原生日志”只能定位边界，不能直接当作故障调用；针对坏对象的临时规避应前移到阻止整条战斗结算路径 `[实测/需随版本复查]`。
8. PSW 原生崩溃最终用 v6 解决：肇事派系回合内存在坏军队对象，阻止其宣战/战斗仍不够（v5 失败），需直接抹除派系。灭派系注意：`cm:kill_faction` 不存在，正确组合是 `force_make_peace` → `kill_all_armies_for_faction` → 全部 `set_region_abandoned` → `kill_character` 清理残余人物 → `force_diplomacy("all")` 锁死；`cm:kill_character` 原版只传 2 参 `[实测/需随版本复查]`。
9. 判别“轮到某阵营时崩”：看日志最后一个 `faction_turn_start`/`FactionTurnStart` 属于谁且之后无下一派系标记；不能以“崩溃前最后一条日志是战斗/其他事件”推断肇事者 `[实测]`。

## 2026-09-06 调研补充：新建独立可玩派系与独立文化的边界

1. 根据当前 `gamedata` 的 `factions_tables`、`cultures_subcultures_tables`、`start_pos_factions_tables`、frontend 派系表和原版叙事脚本，补充“新 faction key 复用已有 culture/subculture”和“真正新增 culture/subculture”两条不同工作流。
2. 明确新增可玩派系不能只改 DB faction 行：还要核对 frontend、Loc、目标战役的 `start_pos_factions`，并重建唯一的 `startpos.esf`；startpos 与 Mixer/其他 startpos MOD 的兼容性属于高风险事项 `[已查原版 DB / 已查外部 startpos 资料 / 需随版本复查]`。
3. 记录新 playable culture 必须检查 `wh3_narrative_shared_faction_data.lua` 的 culture-to-narrative 映射；缺失映射时原版会警告且不会加载对应种族叙事 `[已查原版脚本]`。
4. 相关流程已写入 `references/project_structure.md` 与 `references/rpfm_and_verification_workflow.md`，并加入 `SKILL.md` 的 reference 路由。

本版根据原始 `SKILL.md` 与 5 个 reference 的冲突点、RPFM/WH3 文档、TW Modding 教程核对后整理。

## 2026-09-06 实现补充：自定义 unit ability phase 表需要 F64 编码支持

1. 为虫群单位复制原版 regeneration/frenzy ability phase 时，`special_ability_phase_stat_effects_tables` 使用了 schema 的 `F64` 字段。
2. `tools/build_pack.py` 原先只支持 `F32`，已补充 little-endian `F64` 编码；否则自动打包会在 effect phase 表阶段失败。

## 2026-09-06 实测反馈：pack 文件存在但 wh3mm preset 未启用

1. `czx_swarm_expansion.pack` 已经复制到游戏 `data/`，但实机没有出现新增单位；核对 `C:\Users\22448\AppData\Roaming\wh3mm\config.json` 后确认当前 WH3 preset 中目标 pack 的 `isEnabled=false`，所以游戏根本没有读取它。
2. 补充验证规则：文件存在、RPFM 能打开、DB 引用正确，都不等于实机加载；实机不可见时必须检查当前 MOD 管理器 preset 的启用状态、加载顺序，并在启用后重启游戏 `[实测/需随版本复查]`。

## 2026-09-06 实测/规则补充：新建英雄复用技能树不得覆盖原版 set key

1. 在 `czx_swarm_expansion` 补丁诊断中发现：`character_skill_node_sets_tables` 的主键是 `key`，若新建英雄直接复用 `wh2_main_skill_node_set_def_sorceress_dark` 等原版 set key，会在 DB 合并时覆盖原版暗精女术士的技能树。
2. 修正方式：新建独立 set key（如 `czx_skill_node_set_kerrigan`），并完整复制 `character_skill_node_set_items_tables` 中原 set 的所有 node key 到新 set；`character_skill_node_sets_tables` 指向新 set 与新的 `agent_subtype_key`。
3. 该规则已写入 `SKILL.md`「高风险禁区」；后续新建英雄/领主复用他人技能树时按此执行。

## 2026-09-06 实测反馈：RPFM 5.0.6 server 在 WH3 dependencies 缓存问题

1. 通过 `rpfm_server` WebSocket 对 `czx_swarm_expansion` 跑 `DiagnosticsCheck`，发现当前 `SetGameSelected("warhammer_3", true)` 后 `asskit_tables` 为空、vanilla packed files 只有 `data/manifest.txt` 的 ~233 个松散文件，`.pack` 中的 DB 表未进入 dependencies 缓存。
2. `LoadAllCAPackFiles` 能打开全部 CA pack，但 diagnostics 的 reference 解析仍不把它们作为依赖参考表使用。
3. 结论：本环境下大量 `NoReferenceTableNorColumnFoundNoPak` 不能直接当作真实引用错误，应同时使用 `gamedata/` 或 Python 交叉验证；已写入 `references/rpfm_and_verification_workflow.md`。

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

## 2026-07-12 自造模型兵种管线文档化

1. 新增 `references/custom_model_unit_pipeline.md`：外部 GLB → 绑骨 → RMV2 → DB → 数值对标 → 技能链克隆 → 分层验收的端到端流程，含形态→骨架对照表与坑速查。
2. `references/tsv_format.md` 新增「克隆原版数据行」（按列名对齐、junction 整行去重）与「新单位数值对标法」（供体选择、每模型 HP、自爆单位定价）。
3. `references/unit_creation_workflow.md` 顶部加交叉引用：外部模型先走 custom_model_unit_pipeline 再做 DB 链。
4. `SKILL.md` 路由表与 `MANIFEST.md` 同步登记新文档。

## 2026-09-13 载具单位管线补充

1. custom_model_unit_pipeline.md 骨架表补 heavyquadruped01（Stegadon，鞍座骨撑高包围盒，fit 须用 x 轴）与 steamtank01（战争机器，25 骨含 barrel_*/wheel_*；donor 在 warmachines.pack）。
2. 同文档新增「5a 载具/战争机器单位的特殊链路」：引擎单位视觉网格走 land_units.engine -> battlefield_engines.model = VMD 名；unit_variants.variant 是乘员 VMD（原版蒸汽坦克用 wh_emp_state_troops）；articulated_record 复用原版车轮关节；main_units 主键为 unit 列，坦克供体按 land_unit 匹配。

## 2026-09-13 供体权重转移管线

- 新增 tools/transfer_weights.py：原版同骨架 RMV2 → 我们 GLB 的 CA 手工权重转移（bbox 归一化 + 最近面重心插值 + 面邻接平滑），取代手写几何蒙皮成为首选蒙皮方案。
- 新增 tools/dump_donor_groundtruth.py + tools/blender_donor_render.py：原版供体真值渲染（验证渲染管线可信后再评权重）。
- 新增 tools/rigidify_core.py：球状躯干刚性化（爆虫大球囊 → rear/spine 骨，--ymin 高度阈值）。
- 新增 scratch/_find_hu1b_donors.py 类扫描器：按骨架名扫 CA pack 找供体 RMV2（只读 160B 头）。
- 发现 RMV2 v32 双布局：f32 pos（兽主）vs f16x3 pos（Ghorgon，boneidx@8/bonew@12），bonew 0xFF 空槽需清零。
- hu1b 供体要多件合并（wardancers head+torso+legs），排除披风/武器件。
- 详见 references/custom_model_unit_pipeline.md §3a。

