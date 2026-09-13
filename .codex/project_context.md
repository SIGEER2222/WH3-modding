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
- `zzz_czx_swarm_expansion.pack` / `zzz_czx_swarm_units.pack`：当日重建后疑似启动原生崩溃元凶，当前为 `.DIS` 禁用且已从 playset 移除，待全量回归验证后再决定是否修复重发 `[需验证]`。
- `zzz_psw_merged.pack`：2026-09-12 重建并部署——修复 `psw_06_chaichu.lua` 拆除天赋后 `show_advice("psw_chaichu_done")` 无 advice_threads/advice_levels 记录导致的 "Placeholder Body" 卡死弹窗；新增 `advice_threads`/`advice_levels` 片段 + `advice_levels_onscreen_text_1214413929` loc。诊断方法见 `references/ui_popup_and_event_diagnostics.md`。
- `czx_auto_skill_manage.pack`：2026-09-12 新建本地包并部署（mod_id `local:data:19063cd1d67e2e16bb`，playset pos 144）——自动勾选人物技能页"自动分配技能点数"复选框；脚本通过 `SimulateLClick` 点击 `checkbox_auto_management`（Cco 绑定，状态按角色持久化）。源码在 `mod_files/czx_auto_skill_manage/`。
- `Lalolalo9Autoconstruction.pack`（local pack，pos 44）：2026-09-12 已把自动建设默认改为开启——`Lalolalo9AutoConstructionEnabled` 初值与无存档值 else 分支均 `0→1`（源码 `mod_files/lalolalo9_autoconstruction/`，原包备份 `scratch\Lalolalo9Autoconstruction.pack.bak`）。开关按存档持久化，手动关过的存档仍保持关。
- `sm0_recruit_defeated cn.pack`（2855270850）：已在 playset 但必须排在 `sm0_recruit_defeated.pack`（2854819509）**之前**才生效（同路径 loc 整文件遮蔽，靠前胜出）；2026-09-12 已从 pos 80 移到 pos 51，EN 包退到 52。若"战争难民"事件变回英文，先查这两项的相对顺序。
- `zzz_nanu_dynamic_rors_cn.pack`：2026-09-13 新建本地汉化补丁并部署（mod_id `local:data:2bc18e784693bed592`，playset pos 26，位于 `!!_nanu_dynamic_rors.pack` pos 27 **之前**——同路径 loc 遮蔽靠前胜出）。覆盖 Nanu's Dynamic Regiments of Renown（工坊 3278112051）全部 9 个 loc 文件共 3260 行中文；源码 `mod_files/zzz_nanu_dynamic_rors_cn/text/db/`，生成器与手工词典在 `scratch/_translate_nanu.py` + `scratch/nanu_loc/_manual_dict.py`（如 mod 更新出新文本，重跑生成器并把 miss 补进词典）。已知限制：脚本拼接的随机兵种名不在 loc 中，无法汉化。
- playset 重复项：`steam:3018964477:!!prayer_of_star_witch.pack` 在 pos 9 与 pos 106 各出现一次，`!!prayer_of_star_witch_movie.pack` 在 pos 10 与 pos 58 重复——`state.db` 的 `playset_items` 有重复行 `[需验证：是否为管理器 UI 双预设合并残留]`。
- 同名 `db` 片段跨 pack 遮蔽规则：加载顺序靠前 pack 胜出（实测）。Yin-Yin 系 `!cth_yinyin_expedition.pack` 必须排在 `cth_yinyin_pol.pack`/`!cth_yinyin_pol.pack` 之前，或依赖上述 fix pack。

## Codex 工作方式

需要生成或修改 WH3 MOD 内容时，先阅读 `warhammer-mod-development_generic/SKILL.md`，再按任务类型读取对应 reference：

- 新增/派生兵种、坐骑、武器、兵牌、porthole：`references/unit_creation_workflow.md`
- TSV/DB：`references/tsv_format.md`、`references/naming_conventions.md`
- Lua：`references/lua_api.md`
- effect/effect bundle：`references/common_effect_keys.md`
- 目录与原版查证：`references/project_structure.md`
- RPFM、日志、网页核验：`references/rpfm_and_verification_workflow.md`

当用户反馈“这样不对”“RPFM 报错”“游戏日志报错”“以后按这个规则来”时，判断是否需要更新 development 指南。更新流程见 `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md`。
