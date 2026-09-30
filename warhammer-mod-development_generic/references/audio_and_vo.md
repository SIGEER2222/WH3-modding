# 音频与语音（VO）接入

WH3 音频引擎是 **Wwise**。两类触发对象：

- **Dialogue_Event**：语音（VO）专用。按 State 路径（如 `VO_Culture.VO_Actor.VO_Battle_Selection`）在决策树里查出具体 `.wem`。命名如 `battle_vo_order_attack`、`campaign_vo_selected`。
- **Event**：普通音效/音乐/UI/电影。命名如 `Play_*`、`UI_*`、`Global_Music_*`、`Battle_*`。

## 资源形态（原版 pack 实证）

| 原版 pack | 内部路径 | 内容 |
|---|---|---|
| `audio_base_bnk.pack` / `audio_<lang>_bnk.pack` | `audio/wwise/*.bnk` | Wwise soundbank（事件/容器/状态/决策树定义） |
| 同上 | `audio/wwise/*.dat` | `audio_rules_{battle,campaign}_{conversation,order}_vo.dat`、`event_data__core.dat`、`bank_splits.dat` 等规则数据 |
| `audio_<lang>.pack`（en/cn/fr…） | `audio/wwise/<lang>/<wem_id>.wem` | 语音媒体文件，按 Wwise source id 命名；中文包 `audio/wwise/chinese/*.wem` |
| 同上 | `audio/sound_settings.xml`、`audio/scripts/*_music.dat` | 全局设置与音乐脚本 |

MOD 包内对应放 `audio/wwise/<mod名>.bnk` + `audio/wwise/<语言>/<id>.wem`。

## 单位战斗语音链路（"兵牌"所指单位）

DB 字段→Wwise 状态/对象：

| DB 字段 | 指向 | 说明 |
|---|---|---|
| `main_units.audio_voiceover_actor_group` | `audio_vo_actor_groups.name` | **主开关**。组的 `vo_actor_1..15` 列填 `VO_Actor` state 名（`wh*_vo_actor_*`）；`container=random` 时随机选一个 actor，`cooldown_overlap` 控制重叠冷却。单领主组通常 name=actor 一对一；小兵组如 `wh3_main_vo_actor_Kislev_Male_Unit` 含 male1/2/3… 多个变体 |
| `main_units.audio_voiceover_culture` | `VO_Culture` state | `wh*_vo_culture_*`，由 Wwise 侧定义，DB 无对应表 |
| `main_units.audio_voiceover_culture_override` | `VO_Culture` | 特殊覆盖，常用 `vo_culture_None` |
| `main_units.has_spoken_vo` | flag | 是否有口语 VO |
| `main_units.vo_is_dragon` / `vo_is_dinosaur` | flag | 龙/恐龙特殊 VO 处理 |
| `land_units.selection_vo`、`selected_vo_secondary`、`selected_vo_tertiary` | `VO_Battle_Selection` state | `vo_sel_*` 键（约 300 种：`vo_sel_default`、`vo_sel_ksl_kossars`…），由 soundbank 内定义，DB 无表 |
| `land_units.man_entity` | `battle_entities.key` | 实体级音频入口 |
| `battle_entities.audio_entity_type` | `audio_entity_types.key` | 实体声音类型 |
| `audio_entity_types.actor_type` | `audio_entity_actors.key` | 实体语音池（`actor_switch` + `number_of_actors`） |
| `audio_entity_types.*_random_vocalisation` | `audio_entity_random_vocalisations.event` | 跑动/疲劳/闲置随机发声（`Battle_Individual_Vocalisation_*`） |
| `audio_entity_types.material`/`switch`/`*_looping_sound` | `audio_materials`/`audio_switches`/`audio_entity_looping_sounds` | 脚步材质、循环声 |

**variant mesh 级覆写**（`.variantmeshdefinition` 的 `<META_DATA>`，实测样例 `references/luke_hero/`）：

- `audio_entity_type:<key>` —— 改该模型实例的实体声音类型（如给英雄挂 `wh2_dlc14_brt_repanse_de_lyonesse_LORD`）
- `audio_actor_id:actor_05` —— 在 `audio_entity_actors` 池里指定具体 actor
- `audio_armour_type:plate`、`audio_melee_weapon_type:sword` —— 护甲/武器打击音

武器/弹药/护甲打击声链路：`melee_weapons.melee_weapon_type`+`audio_type`、`unit_armour_types.audio_type`、`projectiles.projectile_audio` → `audio_melee_weapon_types`/`audio_armour_types`/`audio_projectiles` 等。

## 战斗 Dialogue_Event（选摘）

完整清单见 tw-modding wiki `Audio_modding`；缺失的条目回退 `battle_vo_order_generic_response`。

- 指令：`battle_vo_order_select`（`VO_Culture.VO_Actor.VO_Battle_Selection.VO_Battle_Order_Urgency.VO_Faction_Leader`）、`_attack`、`_move`、`_halt`、`_special_ability`（含 `VO_Battle_Special_Ability`）、`_guard_on/off`、`_skirmish_on/off`…
- 对话/反应：`battle_vo_conversation_proximity`（`VO_Actor.VO_Actor`，领主接近互动）、`_clash`、`_own_unit_routing`、`_environment_*`…
- 规则文件：`audio_rules_battle_conversation_vo.dat` / `audio_rules_battle_order_vo.dat`。

## 领主/英雄战役地图语音链路

| 位置 | 字段 | 说明 |
|---|---|---|
| `agent_subtypes.audio_voiceover_actor_group` | `audio_vo_actor_groups.name` | 大地图选中/移动/攻击/姿态/外交等 `campaign_vo_*` 全走这里（例：`wh3_main_ksl_katarin` → `wh3_main_vo_actor_Kislev_Katarin`） |
| `agent_subtypes.audio_vo_culture_override` | `VO_Culture` | 原版仅个别角色用，一般留空 |
| `agent_subtypes.spam_click_vo_enabled` | bool | 连点语音（"戳领主"彩蛋） |
| `agent_subtypes.audio_force_contextual_vo` | bool | 强制情境 VO |
| `factions.audio_voiceover_culture` | `VO_Culture` | 派系级默认 |
| `factions.default_audio_actor_vo_group` | `audio_vo_actor_groups` | 派系默认 actor 组（外交/兜底） |
| `factions.override_target_unit_vo_culture` | | 目标单位 culture 覆写 |
| `mounts.voiceover` | `VO_Culture` | 坐骑自身 VO culture（会叫的坐骑） |
| `mounts.audio_armour_type` | `audio_armour_types` | 坐骑护甲音 |

战役 `campaign_vo_*` Dialogue_Event 的 State Path 基本是 `VO_Actor`（`campaign_vo_move`/`attack`/`ship_dock` 追加 `VO_Campaign_Order_Move_Type` 区分陆地/海上移动）。

**接近对话系统**：`campaign_vo_cs_conversation_mappings` 把 `campaign_vo_cs_proximity` 事件映射到 instigating/target 两个 actor（如 Ghoritch↔Throt）。

**DB 触发的叙事 VO**：

- `incident_vo_events` / `dilemma_vo_events`：incident/dilemma → `vo_event`（`Play_*`）+ `actor_group` + `delay`
- `audio_ritual_dialogue_events`：仪式 started/completed → `campaign_vo_cs_*`
- `audio_pooled_resource_tooltip_dialogue_events`、`audio_pre_battle_unit_targeted_abilities`（pre-battle 技能 → `apply_dialogue_event`）
- 顾问语音走 `advice_threads`/`advice_levels`（`advisor_name`、`audio_clip`），链路见 `ui_popup_and_event_diagnostics.md`

**Lua 接口**（原版脚本实证）：

```lua
cm:trigger_campaign_vo(sound_event, character_lookup, delay)   -- 触发 Play_* 语音事件
cm:add_character_actor_group_override(character, group_key)    -- 动态换角色 actor 组（序章 Yuri 分阶段换声）
-- 监听脚本触发 VO 的播放状态（事件名按派系脚本命名，勿照抄后缀）：
core:add_listener(name, "ScriptTriggeredVOStartingPrologue", cond, cb, true)
core:add_listener(name, "ScriptTriggeredVOFinished", cond, cb, true)
```

## 自定义语音资产管线

两条路线（tw-modding wiki `Audio_modding` 官方说明）：

1. **AssetEditor 音频工具**（本机 `tools/AssetEditor/`，v0.78+）：Audio Explorer 可查任意 Dialogue_Event 的 State 路径与原版配音内容；Audio Project Compiler 用模板产 `.bnk`；Dialogue Event Merger / Bnk Patcher / Dat Builder / wav↔wem 转换器配套。优先路线。
2. **原生 Wwise 工程**：自建工程产 `.bnk`，再用 `merge_wwise_dialogue_events.py`（社区脚本）把 vanilla Dialogue_Event 决策树合并进来——**只放自定义 bnk 会遮蔽同名 vanilla 决策树，导致原版语音丢失**；bus ID 需二进制替换成原版值。

命名惯例（对照原版键）：`wh3_main_vo_actor_<Race>_<Name>`、`wh3_main_vo_culture_<Race>`、`vo_sel_<unit_key>`、事件 `campaign_vo_*`/`battle_vo_*`/`Play_*`。

## AI 配音（TTS / 语音克隆）管线

给新领主/单位配中文或英文语音的当前主流方案（2026-09 调研）：

| 方案 | 克隆方式 | 特点 | 显存 |
|---|---|---|---|
| **GPT-SoVITS**（RVC-Boss，v2ProPlus/v4） | 5s 零样本 / ~1min 微调 | 微调后音色最像"同角色新台词"；自带人声分离+ASR 自动打标 WebUI，适合做数据集 | 推理 ~4GB，微调更多 |
| **IndexTTS-2 / 2.5**（B站） | 3s 零样本 | **音色与情感解耦**：可用情感参考音频或文本描述控制（怒吼/嘲讽），正好覆盖战斗吼叫；时长可控 | ~8GB，合成较慢 |
| **CosyVoice 3.0**（阿里，Apache 2.0） | 3s 零样本 | 部署最简单；instruct 指令控情感/语速/方言；0.5B 轻量 | ~4GB |
| Qwen3-TTS / Fish Speech / VoxCPM | 零样本/声音设计 | VoiceDesign 可"文字描述造音色"；Fish 多语言保真度高 | 2-6GB |
| 云服务：ElevenLabs / Fish Audio / MiniMax / 豆包 | 网页/API | 质量上限最高但收费、需联网；英文情感表达 ElevenLabs 仍最强 | 无要求 |

**推荐流程**（克隆已有角色出新台词）：

1. 提取原版 `.wem` → wav：AssetEditor Audio Explorer 定位角色语音，或 vgmstream 批量转 `audio_<lang>.pack` 里的 wem。
2. 建数据集：干净人声（必要时 UVR 分离去 BGM），按句子切片+标注（GPT-SoVITS WebUI 一键完成）。
3. 生成：GPT-SoVITS 微调拿音色；语气平的样本用 IndexTTS-2 情感向量或 CosyVoice instruct 补战斗语气；每条指令多生成几版供随机容器挑选。
4. 后处理：响度对齐原版（归一化）、裁静默、wav → AssetEditor Audio Project → 编译 `.bnk` + `.wem` → 打进 pack `audio/wwise/`。
5. 变体路线：录自己声音/普通 TTS → RVC/Seed-VC 音色转换，适合战斗喘息、喊叫类非台词音。

**注意**：克隆原版角色配音出新台词在 Workshop 属常见灰色做法（已有 AI 配音 MOD 先例），免费发布一般无碍，但商用/收费需自行评估授权 `[需验证]`。

### 本机已实测可用的管线（2026-09-13）

- **wem→wav**：`scratch/tts_lab/vgmstream/vgmstream-cli.exe`（r2117 win64 已下载到工作区）；`vgmstream-cli -o out.wav in.wem`，原版 wem 为 Wwise Vorbis，vgmstream 通吃。
- **wem→文本**：`faster-whisper`（small，CPU int8）转写参考音台词，CN/EN 均可用；CN 包 `audio_cn.pack` 只有 ~1600 个 wem（顾问/叙事语音），单位/领主语音在 `audio_en.pack`（含 `campaign_vo_cs_proximity` 领主间对白）。
- **克隆已跑通（中文，同参考音同台词横向对比）**：Qwen3-TTS-0.6B-Base `generate_voice_clone`（`clone_qwen_advisor.wav`，用户试听评为当前最佳）、Qwen3-TTS-1.7B-Base（`clone_qwen17b_advisor.wav`）、Spark-TTS-0.5B（`cli/SparkTTS.py inference(text, prompt_speech_path, prompt_text)`，`clone_spark_advisor.wav`）、IndexTTS-2（`infer(spk_ref, text, out)`，`clone_idx_advisor.wav`）。四者台词均无误读（whisper 回验通过）。
- **原创已跑通**：Qwen3-TTS-1.7B-VoiceDesign（`generate_voice_design(text, instruct)` 文字描述造音色，`orig_qwen_voicedesign.wav`）、Spark-TTS 参数造声（`inference(text, gender='male', pitch='low', speed=...)`，`orig_spark_male.wav`）、edge-tts（云端免费，`zh-CN-YunjianNeural` 等，偶发 NoAudioReceived）。
- **情感控制已跑通**：IndexTTS-2 `infer(..., use_emo_text=True, emo_text='怒吼，充满杀气')` → `clone_idx_advisor_angry.wav`，QwenEmotion 正确识别 angry=0.95，是战斗吼叫台词的关键能力。
- **失败/弃用**：F5-TTS 中文克隆质量差，已被用户弃用并删除；VoxCPM2（voxcpm 2.0.3）三种模式均输出与文本无关的幻觉语音（"我會打死你"复读），包有 tokenizer/实现 bug，不可用。
- **坑**：① torchaudio≥2.9 的 `torchaudio.load/save` 强制走 torchcodec，缺 FFmpeg dll 即崩；**通用解法是 monkeypatch `torchaudio.load/save` 到 soundfile**（见 `scratch/tts_lab/indextts_clone.py` 顶部）。② hf-mirror 的 `snapshot_download` 个别文件 HEAD 请求必失败（HF_ENDPOINT 不生效时），**直接 curl `hf-mirror.com/<repo>/resolve/main/<file>` 逐文件下载更稳**；大文件必须对比 `x-linked-size` 响应头校验完整性（gpt.pth 3.5GB 曾静默截断到 800MB）。③ HF cache 在 Windows 无符号链接权限时设 `huggingface_hub.file_download._are_symlinks_supported_in_dir[cache_dir]=False` 走复制模式；C: 盘紧张就把 `HF_HOME` 指到 E:。④ IndexTTS-2 vendored 的 GPT2 代码与 transformers≥4.56 不兼容（`QuantizedCacheConfig`/`_crop_past_key_values`/`forced_decoder_ids` 等已删），本机工作区 `scratch/tts_lab/index-tts-main` 已打补丁可跑（CPU 单条约 100-120s，RTF≈25）。⑤ descript-audiotools 会把 protobuf 降到 3.19 弄崩 onnxruntime——装完记得 `pip install --upgrade protobuf`。
- 环境：`C:\Users\22448\venvs\wh3tts`（torch 2.11.0+cu128 GPU 版 + qwen-tts + sparktts 源码 + indextts 源码 + faster-whisper + edge-tts）；**推理一律 GPU 优先（用户规则）**，RTX 2070 8GB 上 Qwen 克隆 ~11s/条、IndexTTS-2 ~11-24s/条、Spark 秒级。HF 缓存在 `scratch/tts_lab/hf_cache/`（E:）；产出样例在 `scratch/tts_lab/out/`。GPU 版 torch 装法：`pip install "torch==2.11.0+cu128" "torchaudio==2.11.0+cu128" --index-url https://download.pytorch.org/whl/cu128`（PyPI 的 win wheel 是 CPU 版，必须走 pytorch 官方 index；首次要加 `--force-reinstall --no-deps` 覆盖同版本号 cpu 包，再不带 no-deps 补依赖）。

## 技能触发音频（ability → phase_audio → wwise）链路

单位按技能按钮播放自定义音乐/循环音效，纯 DB 无脚本。实测样例：`references/temari_luna_techniques.md`（工坊 3807340793 拆解，§2）。

调用链：

```
unit_special_abilities.<key>          (active_time=曲长秒数；停止按钮另建 ability)
  → special_ability_to_special_ability_phase_junctions
  → special_ability_phases.<key>      (phase_audio=<audio_key>, cant_move=true 站桩)
  → audio_ability_phases.<audio_key>  (unit_removal_event=Stop_*, max_distance=10000)
  → audio_metadata_tags: Play_<id> / Stop_<id> 两行
      (is_persistent_loop=true, play_at_base=true, culling_distance_override=10000)
  → audio/wwise/global_music_<id>.bnk + <wwise数字hash>.wem + event_data__<id>.dat
```

- **停止按钮** = 第二个 ability，其 phase_audio 行带 `stop_event=Stop_*`——停止本体就是播 Stop 事件。
- **节拍/动画同步** = `animations/audio/battle/<id>/<name>.snd.meta`，二进制 SOUND_TRIGGER 记录把 Play/Stop 事件打在动画时间轴（非脚本计时）。
- **互斥**：自定义 ability 用 junction 塞进 vanilla `special_ability_exclusive_toggle_groups` 组（如 `wh3_dlc24_zhangu_war_drum_exclusive_toggle`）即与原版技能天然互斥。
- `main_units.audio_voiceover_culture` 等 VO 字段与 phase_audio 链路互不干扰，可并存。

## 快速接入清单

- **复用原版语音**（最常见，零音频文件）：新单位 `main_units` 行填 `audio_voiceover_actor_group` + `audio_voiceover_culture`；`land_units` 填 `selection_vo` + `man_entity`；领主/英雄另填 `agent_subtypes.audio_voiceover_actor_group`。实测样例：`references/luke_hero` 的 saber 系单位直接挂 `wh2_dlc10_vo_actor_High_Elves_Sisters_of_Averlorn`。
- **自配语音**：自制 `.wem` + `.bnk`（内含自定义 actor/culture state 与决策树路径），DB 字段指向自定义 key。
- **技能播放自定义音乐/循环音效**：`special_ability_phases.phase_audio` → `audio_ability_phases` → `audio_metadata_tags` Play_/Stop_ → `global_music_<id>.bnk`+`.wem`，纯 DB 零脚本；停止=第二个 ability 播 stop_event；动画卡点用 `.snd.meta` SOUND_TRIGGER。完整样例 `references/temari_luna_techniques.md`。
- 兵牌悬停/点击的 UI 音效不属于 VO 链，走 `audio_ui_categories`/`UI_CAM_*` 普通 Event。
