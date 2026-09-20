# 启动崩溃、Bad Mods 校验与加载顺序诊断

适用于：游戏启动数秒到数十秒内崩溃、弹出 "The following mods cause a crash to the Database" 对话框、需要定位是哪一个 MOD / 哪一行 DB 记录导致的问题。

## 一、先分清崩溃类型

| 类型 | 特征 | 产物 |
|---|---|---|
| DB 校验失败（Bad Mods） | 窗口标题 `Crash report`，对话框列出 pack + 表 + 记录 | `%APPDATA%\The Creative Assembly\Warhammer3\crash_report\bad_mods_report.txt` 被刷新 |
| 原生崩溃（native crash） | 游戏进程直接消失或闪退 | `crash_report\` 新增 `D<日期>_T<时间>.mdmp` + `.stack.txt` |
| 启动失败/未进窗口 | 进程不出现或立即退出 | 无 mdmp、无 bad_mods 报告；看 `logs\modified.log` 与启动器日志 |

注意：Bad Mods 对话框弹出时**也可能**同时写出 .mdmp；判断标准以 `bad_mods_report.txt` 是否被本次启动刷新为准（比较文件 mtime 与启动时间）。`[实测/需随版本复查]`

## 二、读 `bad_mods_report.txt`

```text
first_invalid_database_record:<set_key><item_key>
first_invalid_database_table:<表目录名>
first_invalid_packfile:<出错 pack 文件名>
BadMods
<出错 pack 文件名>
```

- `first_invalid_database_record` 把联合主键直接拼接打印，例如 `cth_yinyin_nodeset` + `wh3_main_skill_node_cth_yinyin_magic_1_5` 表示 `character_skill_node_set_items` 中 (nodeset, node) 这一行。
- 报告指向的是**第一条无效行所在的 pack**，不等于"这个 pack 是坏的"。常见根因是：该行引用的 key 未被任何已加载 pack 提供（悬空外键）。
- 游戏按文件路径/表逐一校验；修复第一处后可能暴露下一处错误，需迭代。
- 校验失败的行不会进入合并后的表；依赖它的后续表也可能连锁报错。

排查流程：

1. 从报告取表名与记录 key。
2. 在所有启用 pack 中搜 `db\<表名>\` 片段，定位该行属于哪个片段。
3. 检查该行每个外键列引用的 key 是否在对应表中存在（原版 `gamedata/db/` + 启用 pack 提供的行）。
4. 若引用 key 由其他 pack 提供，检查该 pack 是否真的加载了（`logs\modified.log` 中是否有 `Mod: <pack>`），以及同名片段是否被遮蔽（见第四节）。
5. 若引用 key 已被上游 MOD 删除/改名，则该 pack 已过期：换兼容版本、联系作者或移除 `[实测案例见第八节]`。

## 三、读原生崩溃 dump

- `crash_report\D<date>_T<time>.mdmp` 内含异常流：`0xc0000005` = 访问违例；参数通常为 `[读写标志, 出错地址]`；`0x0` 读空指针最常见。
- 崩溃地址 `0x14xxxxxxx` 位于 `Warhammer3.exe` 代码段；同一根因多次崩溃地址通常一致或相近。
- 若多次原生崩溃地址相同、而换 MOD 组合后地址变化，说明不是同一根因，不要合并归因 `[实测/需随版本复查]`。
- 原生崩溃阶段（pack 解析 / DB 合并 / 资源加载 / UI）大致可用存活时长区分：pack 解析阶段崩溃通常在 5-20 秒内；进战役/主菜单后崩溃多为实体/资源/脚本问题。

## 四、同名 DB 片段的遮蔽规则（实测）

WH3 对 `db\<表>\<内部名>` 这一**完整虚拟路径**做文件级去重：多个 pack 提供同名（同路径）片段时，**只有一个生效**，其余被丢弃——不是逐行合并 `[实测/需随版本复查]`。

- 实测方向：**加载顺序靠前的 pack 胜出**。把 patch pack 移到基础 pack 之前后，patch 的同名片段生效、基础包的同名片段被丢弃。
- 这与"补丁写主 MOD 后面"的习惯表述不矛盾：生效的是优先级更高者，在 Mod Manager/启动器列表中排**前**者优先级更高。
- 后果：补丁 A 在基础包 B 的同名片段上新增了一行 `x`，同时补丁 A 的另一文件引用 `x`——当 B 的片段遮蔽 A 时，`x` 消失，引用行报 invalid database record。**行本身在补丁包里，但引用的行丢了**，报错只指向出问题的行，不提示遮蔽。
- 排查同名片段：列出所有启用 pack 中 `db\<同表>\<同内部名>` 的提供者，按 playset 顺序判断谁赢。

规避/修复手段：

1. **调整加载顺序**：让需要生效的 pack 排前。简单，但对用户依赖"记住顺序"，且第三方更新后易复发。
2. **唯一片段名补丁包**（推荐）：新建小 pack，把必须生效的行复制到 `db\<表>\<唯一内部名>`（如 `zzz_<prefix>_fix`）下。片段名唯一就不会被任何 pack 遮蔽，与加载顺序无关。重复 key 的行与源片段值一致时按主键合并，无害。
3. 修源 pack：直接改基础 MOD 内部名或合并补丁进基础 MOD，适合自有 MOD。

### 4.1 不同名片段、同 key 行冲突：pack 加载顺序靠**后**者胜出（实测）

当两个**不同名**片段给同一张表提供**相同主键**的行时，裁决看 **pack 在 playset 中的位置、后者覆盖前者**（字典合并语义），与片段文件名无关——`!` 前缀对 DB 行冲突**无效**（`!`/`#` 前缀只影响 loc 同 key 排序，见 9.1）。

- 实测（2026-09-13，PSW Horde）：`!!Prayer_of_star_witch.pack`（playset pos 106）的 `db\military_force_type_horde_details_tables\psw_行动关联游牧表`（`PSW_HORDE` 行 `slot_cap=14`）与 `zzz_psw_merged.pack`（pos 94）的补丁行（`slot_cap=30`）冲突。片段名先后试过 `zzz_psw_mixu_compat` 与 `!!czx_psw_mixu`，游戏内 `BuildingSlotList.Size` 均为 14 → **主包行两次都胜出，片段名顺序不影响结果**。对策是把行移到排在主包之后的 pack（如 pos 135 的 `zzz_czx_auto_tools`）让后者覆盖 `[实测，待最终进游戏复核]`。
- 推论：补丁 MOD 要覆盖第三方 MOD 的某几行时，**补丁 pack 必须排在被补丁 pack 之后**；这与"同路径文件遮蔽靠前胜出"方向相反——同一个补丁若同时需要 Lua/twui 遮蔽（要排前）和 DB 行覆盖（要排后），只能拆成两个 pack。
- `remove=true` 的 junction 行（`remove` 不在主键里）与被删行共享主键，同样受此规则约束：想让 remove 行生效，所在 pack 也要排在被删方之后。
- 同名（同路径）片段仍按上节"文件级遮蔽"处理（靠前 pack 胜出、后者整个文件被丢弃），与本节"同 key 行级冲突"是两个层面，方向相反。

## 五、data 目录 pack 的加载语义

- 游戏 `data\*.pack` 只有在启动清单里有 `mod "<name>.pack";` 行时才被挂载；不在清单中的文件在 `logs\modified.log` 记为 `<name> unknown file`，**不加载** `[实测/需随版本复查]`。
- 因此 Mod Manager 的 playset 中 `local:data:*` 条目对应 data 目录 pack 的 mod 行；把它移出 playset 即等于禁用。
- 快速禁用 data pack：重命名为非 `.pack` 后缀（如 `.DIS`、`.bak`）。`.bak`/`.dis` 文件同样会出现在 modified.log 的 `unknown file` 列表中，属正常。
- `!!!!wyccc_runtime_options.pack` 由 Mod Manager 每次启动重写，勿手动编辑；被进程占用导致写失败时先杀残留 `Warhammer3.exe`。

## 六、Pack / DB 片段二进制速查（脚本诊断用）

PFH5 pack 头（实测，WH3 当前版本）`[实测/需随版本复查]`：

```text
offset 0   'PFH5'                    4B magic
offset 4   u32  pack type            mod pack = 3
offset 8   u32  0                    保留
offset 12  u32  dep_count            pack 依赖区字节数
offset 16  u32  file_count
offset 20  u32  index_size           文件索引区字节数
offset 24  u32  pack 标识/时间戳     任意值即可
offset 28  dep 区 → index 区 → 文件数据区
index 项 = u32 size + u8 flag(0x00) + name + '\0'
```

DB 表片段（packed file 内容）：

```text
FD FE FC FF                       magic
u16 guid_len (=36) + utf16le GUID  片段实例标识
可选: FC FD FE FF + i32 version    版本化表
u8  0x01                           标志位(恒为 1)
u32 row_count                      行数
行数据                             按表 schema 列序
```

- 版本化表必须写与原版一致的 version 值（如 `character_skill_nodes` ver 6、`character_skill_node_links` ver 3）；写错版本游戏按旧 schema 解析会行错位或直接崩溃。
- v0/无版本表 flag 字节同样写 `0x01`（写 `0x00` 曾导致启动崩溃，见 `rpfm_and_verification_workflow.md` 实测案例）。
- 脚本化 patch：复制源片段原始字节 → 重写 GUID 字符串 → 改为唯一内部名 → 按 PFH5 索引格式封包即可。本次 `!czx_yinyin_expedition_fix.pack` 即按此生成，已验证可通过校验。

## 七、启动二分排错纪律

实测中踩过的坑，二分前必须先清场 `[实测/需随版本复查]`：

1. 只保留一个 Mod Manager 后端实例；UI/后端并发会回写 playset，二分结果作废。
2. 每次启动前杀残留 `Warhammer3.exe`，等 3-5 秒释放 `used_mods.txt`/runtime pack 文件锁。
3. data 目录的自定义 pack 全部参与或全部排除，保持一致；中途增删 data pack 会污染每一轮对比。
4. 区分结果类型：`bad_mods`（校验弹窗）≠ `native-crash`（mdmp）≠ `exited` ≠ `alive`。含缺失依赖的小集合会报 badmods，不能用来判定 native crash 归因。
5. "全集减去一组"（leave-one-out）比"只启用一组"更少假阳性：小集合容易因缺依赖直接报 badmods。
6. 若二分无论怎么收敛都指向位置 0，怀疑多元凶：改用"每块单独启用"的 chunk 法，每块都可能崩的才是真凶所在块。
7. 每轮记录：启用集合、窗口标题、是否新增 bad_mods_report、mdmp 文件名、异常码/地址、存活秒数。

## 八、实测案例索引（2026-09-12）

### 8.1 Yin-Yin expedition 悬空引用

- 报错：`character_skill_node_set_items_tables` 中 `(cth_yinyin_nodeset, wh3_main_skill_node_cth_yinyin_magic_1_5)`，指向 `!cth_yinyin_expedition.pack`。
- 根因：EXP 包在自己 `db\character_skill_nodes_tables\cth_yinyin` 片段（64 节点）里新增 `magic_1_5`；基础包 `cth_yinyin_pol.pack` 的同名片段只有 63 节点。EXP 排在基础包之后 → 基础包片段遮蔽 EXP → `magic_1_5` 丢失 → set_items 行悬空。
- 修复：`!czx_yinyin_expedition_fix.pack`（data 目录，加入 playset）用唯一片段名 `zzz_yinyin_exp_fix` 复制 EXP 的 nodes/links/set_items 与基础包的 node_sets 片段，保证无论遮蔽方向如何该行引用都完整。已验证 133+ 全量启动不再报该错。
- 教训：**补丁 MOD 在自己同名片段里加新行、又在别处引用这些行，是对加载顺序最脆弱的结构**；给第三方 MOD 做补丁时，新 key 尽量放唯一片段名。

### 8.2 过期兼容包：TLA warband upgrades

- 报错：`unit_to_unit_group_junctions_tables` 中 `wh3_deer24_hailongjiajun + TLA_cth_deer24_YUEGONG`，指向 `cth_deer24_units_TLA_warband_upgrades.pack`。
- 根因：上游 `DEER24Cathay.pack` 新版本删除/改名了 `wh3_deer24_hailongjiajun` 单位组，旧兼容包仍引用 → 悬空。
- 修复：上游作者已发布 Pinkbee 重制兼容包（item 3432190138）；移除旧包（item 3034203267）、订阅新包后通过。
- 教训：bad_mods 报告指向兼容包时，优先查上游 MOD 更新日志与重制版，而不是修兼容包本身。

### 8.3 疑似原生崩溃元凶：自研 swarm pack

- 现象：DB 校验通过后约 14s 原生崩溃 `0xc0000005`（地址 `0x1404926f0`，参数 `[0x0, 0x3e8]`）；全部 data pack 禁用后同配置仍偶发，进一步定位中。
- 时间线：`zzz_czx_swarm_expansion.pack`（70MB）于当日 08:04 重写，崩溃自当日上午开始出现；`zzz_czx_swarm_units.pack` 为同日重建变体。
- 状态：`[需验证]` 两个 swarm pack 当前已禁用（`.DIS`）并从 playset 移除，等待全量回归确认。
- 教训：自研 pack 当日重建后立即开始崩溃时，优先怀疑新构建产物本身（资源/表/二进制），而不是先怀疑他人 MOD。

## 九、本地化（loc）键覆盖与"界面显示英文"诊断（实测）

触发：MOD 人物/单位的名称、传记、特性描述在游戏里中英混杂（一部分中文、一部分英文），或翻译补丁完全不生效。

### 9.1 loc 覆盖规则：文件级遮蔽 + 文件名排序（实测修正）

实测（2026-09-12 第二次修正）证明 loc 是**两层机制**，不只是"靠前 pack 赢"：

1. **同虚拟路径**（如两个 pack 都有 `text\db\##SFO_effects__.loc`）：与 DB 片段同规则，**靠前 pack 的整文件遮蔽**靠后 pack 的同名文件——洛阳侯 SFO 汉化包 `!!@luoyanghou_SFO_hanhua.pack` 正是靠同名 `##SFO_*.loc` 整文件替换 SFO 英文 loc 工作的。
2. **不同文件名、同 loc key**：按**文件名排序**决胜负，`!`/`#` 前缀越多优先级越高（`!!!!!!!wwd_x.loc` 胜 `!!!x.loc` 与 `##x.loc`）。`CathayENGLISH` 全部文件用 6-7 个 `!` 前缀，即使 pack 排在本体之后、中文守护包（`!!!czx_`）排在它之前，其 key 仍胜出 → 这就是守护包 v1（单文件 `!!!czx_deer24_cn_restore.loc`）对 `wwd_character` 键失效的原因。
- 推论：**loc 补丁的正确做法是同名文件遮蔽**——补丁包内用与被补丁包完全相同的 `text\db\<名>.loc` 路径放修正后的条目，再把补丁 pack 排到本体之前；只要文件遮蔽生效，与逐键排序无关，最稳。
- 实测（2026-09-12）：`CathayENGLISH.pack` 在 `used_mods.txt` 第 144 行、`DEER24Cathay.pack` 在第 160 行；EN 包 `!!!!!!wwd_character.loc` 以文件名排序赢过本体 `!!!!wwd_character.loc` 与守护包 `!!!czx_*.loc`。修复版 `!!czx_deer24_cn_restore_v2.pack` 内置与 EN 包完全同名的 14 个 loc 文件做整文件遮蔽。
- MOD 的 `.loc` **不按客户端语言分流**：原版 `local_xx.pack` 只加载客户端对应语言；MOD 内 loc 对所有语言客户端生效。因此 EN 翻译包在中文客户端同样覆盖中文本体 → 中英混杂"反向污染"。中文客户端玩中文本体 MOD 时应禁用第三方 EN 翻译包；反之亦然。

### 9.2 诊断流程

1. 截图提取显示原文（如 "Skaven ally"、传记中的特征词），再从 spawn 脚本/db 表拿内部 key（如 `char_id`、`names_name_<id>`）。
2. 在启用 pack 中搜该 key 与显示文本：
   - **`.loc` 二进制的显示文本是 UTF-16LE**：`'Skaven ally'.encode('utf-16-le')` 才能命中；按 UTF-8 搜英文/中文都会漏检。
   - key 字符串同样可能为 UTF-16LE，建议 u8/u16 双编码搜索。
   - 可跳过 `.dds/.png/.rigid_model_v2/.wem/.anm` 等纯资源文件加速全工坊扫描（约 19GB/400 pack 几分钟可扫完）。
3. 对每个命中 pack 在 `used_mods.txt` 中比对行号位置，判定谁覆盖了谁。

### 9.3 实测案例（2026-09-12）：CathayENGLISH 覆盖中文本体

- 现象：DEER24 系领主"叶晟·缙绅逆臣"（`deer_cth_nicheng`，name id `names_name_624400099`）详情面板中英混杂：faction effect（"Start the game with a Skaven ally"）、bio（"orchestrated the two coups"）、trait（"Yin-Yang Protectors / Imperial Agents"）为英文，近战攻击等其它行为中文。
- 根因：工坊 `CathayENGLISH.pack`（item 2860213243）是 DEER24 系列的 EN 翻译补丁，`text\db\!!!!!!!wwd_units.loc`、`!wwd_faction_leader.loc`、`!wwd_traits.loc` 等覆盖了本体中文 loc 对应 key；未被覆盖的键仍显示中文。
- 本体 `DEER24Cathay.pack` 自带中文 loc（`!!!!!!wwd_incident.loc`、`!!!!wwd_character.loc` 含 `缙绅逆臣`），文本并未缺失；EN 包在 `used_mods.txt` 中排在本体之前故胜出。
- 修复：中文客户端在 Mod Manager 取消勾选 CathayENGLISH（或确认要英文时保持其排在本体之前）。

## 十、自动化战斗实测与动画资源验证（2026-09-19，`[实测/需随版本复查]`）

### 10.1 `game_startup_mode battle` 无人值守战斗测试

验证过的工作方式：直接跳过主菜单把单位送进战斗，比"启动到主菜单"强得多——能实测单位生成、模型渲染、弹药消耗、交战、阵亡全流程。

```text
Warhammer3.exe game_startup_mode battle <xml文件名> ; <modlist文件名>;
```

- `<xml文件名>` 是**裸文件名**，在游戏 `data\` 目录下查找（不是路径、不要加 `opt:` 前缀——`opt:<绝对路径>` 会触发 `0xC0000409` 崩溃）。
- `<modlist文件名>` 同样裸文件名、放游戏根目录，格式为 Mod Manager 清单格式：`add_working_directory "<dir>";`（data 之外的去重目录）+ `mod "<pack名>";` 逐行列出。不要写 `used_mods.txt`（会被 Mod Manager 重写），用自有文件名如 `czx_launch_mods.txt`。
- 战斗 XML 结构：`<battle>` → `<alliance><army><faction>` + `<deployment_area>` + 若干 `<unit><unit_type type="<main_units key>"/>` → `<victory_condition>` → `<battle_map_definition><name>terrain/battles/<地图>/` → `<skip_deployment/>` + `<skip_results/>` 实现全无人值守（跳过部署与结算屏）。
- `<unit_type>` 用 **main_units 表的 key**（非 land_units key）。
- 环境变量 `SteamAppId=SteamGameId=1142710`；`data\` 下需有 `!!!!wyccc_runtime_options.pack`（至少含 `enable_script_logging` 才有 `script_log_*.txt`）。
- 脚本探针：在 pack 内放 `script\battle\mod\<x>.lua` 周期性 `out("CZX_PROBE ...")` dump 每个 unit 的 `type/is_idle/is_in_melee/ammo_left/number_of_men_alive`，写进 `script_log_*.txt` 即可无人值守断言"单位是否生成、是否交战、弹药是否消耗"。
- 现成 harness：`scratch/czx_battle_test/`（`gen_battle_xml.py` 生成 XML、`launch_autotest.py` 从当前 playset 构建 modlist 并拉起游戏）。

### 10.2 wh3mm `launch_game` 会污染当前 playset（实测坑）

`backend.api.API.call("launch_game", [mod_ids, token, ""])` 会把传入的 `mod_ids` 直接写回 `state.db` 的 `playset_items`（当前 playset 被替换为测试子集）。用子集跑完测试后**真实 playset 已丢失**，必须事先备份 `state.db`、测后恢复（恢复 `playset_items` + `app_state` 的 `enabled_order:warhammer3` + `playset_hidden_mods`）。仅读 `get_bootstrap`/`scan_mods` 拿 `enabled_order` 不污染。

### 10.3 `animations/database/battle/bin/` 的真实约定（实测）

原版与成熟 MOD 的自定义骨骼动画走 **`*.bin` 片段**，不是 `.animpack`：

- 原版：`anim.pack` 里 `animations/animation_culture_packs/*.animpack`（每文化一个合并大库）+ `animations/database/battle/bin/animation_tables.animpack`（主索引）；`anim2.pack` 里 `animations/database/battle/bin/<skel>.bin` 数百个**编译后片段**。
- MOD 添加新骨骼的标准产物：`animations/database/battle/bin/<唯一名>.bin`（片段内含骨骼名、anim 剪辑路径列表、audio `.snd.meta` 引用、persistent meta）+ `animations/skeletons/<skel>.anim` + `.bone_inv_trans_mats` + `.anm.meta` + `animations/battle/<skel>/*.anim` 原始剪辑。样例：`zzz_czx_digimon4.pack`（104 个 `czx_dgm_*.bin`）、`zzz_czx_swarm_units2.pack`（`czx_cst_promethean.bin`）。
- `.bin` 片段可由 vanilla 供体改出来：复制原版 `.bin` 字节 → 替换骨骼名字符串 → 把 `animations/battle/<旧skel>/...` 剪辑路径改指到自己 `.anim`（audio 的 `.snd.meta` 保留原骨骼路径）。
- **改写必须按"存在性"选择** [实测 2026-09-19]：对 u16 长度前缀串逐条判断——裸骨架名、`animations/skeletons/` 引用、以及改写后确实存在于本包的 `.anim` 剪辑路径才改名；`.anm.meta`/`.meta`/`.snd.meta`/`.xml` 与本包未提供的剪辑（matchup death、face、hands、docking 等）一律保留 donor 原版路径。`tools/digimon_batch.py` 的 `patch_animsuite_bin()` 即此实现；裸 `raw.replace(tmpl, sk)` 曾把 digimon 104 个 bin 的全部 meta/audio 引用改成不存在的 `czx_*` 路径（每 bin ~129 条悬空）。修复后整包引用 0 缺失。
- **缺失引用在加载期被容忍**（实测反直觉）：`zzz_czx_swarm_units3.pack` 的展开式 bin `czx_empire_sword_rifle.bin`（111KB）有 249 条引用指向不存在的文件（含 185 条 `czx_marine/*.anim`），该包正常加载运行——缺失引用顶多导致对应剪辑不可用，不是启动崩溃原因。但保留 donor 路径能让 matchup death 等剪辑直接播原版动画，功能上严格更优。
- **`db_validation.log` 的 `BATTLE_SKELETONS_TABLE bad entry czx_*` 是非致命噪音**：swarm 的 4 个 `czx_*` 骨架（czx_ms/czx_marine/czx_dehaka1/czx_stank01）同样全被拒但该 MOD 正常工作——校验器不认识 MOD 注册的 rig，行仍生效。勿据此判死。
- **bin 第一个 u16 长度前缀串是 animsuite 注册名，必须等于 `battle_animations_table.key`（=bin 文件名）** [实测 2026-09-19]：swarm 的 bin 首串 = 自身 key（`czx_cst_promethean` 等）；digimon 的 104 个 bin 此前首串全是 donor 名（83 个都叫 `hu1_empire_sword_and_shield`），互相撞名且与 vanilla key 冲突，导致 czx_* 套件注册不上、其内声明的骨架全部失效、单位 `man_animation` 悬空。修复：`scratch/fix_dgm_bins3.py`（重写 token0 + 长度前缀），生成器侧 `digimon_batch.py` 已加 `set_animsuite_name()`。验证方法：读 bin offset8 的 u16 长度串，应等于文件名去 `.bin`。

### 10.4 悬空 `.animpack` manifest 不致命（实测反直觉结论）

`dgm_digimon.pack` 在 `animations/database/battle/bin/` 放了 50 个 `chr0XX.animpack`——这是 **manifest**（首字符串即 `animations/database/battle/bin/chr0XX.bin` 的引用 + 动画表名 + locomotion graph + 剪辑路径列表），但它引用的 `chr0XX.bin` 片段在 pack 内和原版都不存在。实测结果：

- 单独加载该 pack 可进主菜单；并入 110+ MOD 全栈也能跑完整场脚本战斗不崩。
- DB 里 `battle_animations_table`/`battle_skeletons` 的 `chr0XX` 行被正常注册，单位能生成、移动、交战、阵亡，兵牌图标正常。
- **未证实项**：缺失 `.bin` 时骨骼动画是否真正播放（低分辨率截图无法判定姿态）；按格式推断单位很可能以缺省/冻结姿态运动——后续自定义骨骼包**必须产出 `.bin` 片段**，`.animpack` manifest 不能替代 `[需验证：进游戏近景确认动画姿态]`。

### 10.5 Pack 内路径重复前缀缺陷（实测）

外部分发的 pack 可能出现整个资源前缀被重复一层（`animations/animations/...`、`ui/ui/...`、`variantmeshes/variantmeshes/...`，本例 806/833 文件受影响）。游戏按约定路径查资源，重复前缀等于资源不存在但**不报 bad_mods**（非 DB 引用），症状是缺模型/图标/动画。验证 pack 时必须做"路径白名单前缀"检查：顶层目录只应出现 `db/ text/ animations/ ui/ variantmeshes/ meshes/ script/ audio/` 等已知根。

### 10.6 `battle_entities_tables` schema v39

本地 `schema_wh3.ron` 只有到 v38；实测 v39 = v38 全字段顺序不变 + 末尾追加 `stop_before_turn`（bool）。解码缺失版本时先 diff 相邻版本 vanilla 导出表再补字段，不要猜。

### 10.7 D3D 全屏截图

`PrintWindow` 对游戏 D3D 窗口只得全黑位图。可行做法：`SetForegroundWindow` 后用**屏幕 DC** `BitBlt` 抓窗口矩形（游戏窗口化/无边框且可见时有效），窗口标题是 `Total War: WARHAMMER 3`（不是 III）。

### 10.8 battle 模式连续 init 崩溃排查（2026-09-19 实测）

现象：`game_startup_mode battle <xml> ; <modlist>;` 上午正常工作（两场完整战斗），之后连续 6+ 次死于 battle init（`script_log` 仅 148B = `battle_scripted.lua loaded` 一行）或 frontend 首帧后，无窗口无错误框。

已排除项 [实测/需随版本复查]：

- 非 modlist 问题：3-mod 最小集与 109-mod 全集同样死；`modified.log` 的 `Mod:` 行有时为 0（modlist 未被消费）有时正常。
- 非 pack 损坏：PFH5 索引逐条走查（`count@+16`，条目 = `size(4)+flag(1)+path\0`，数据区紧随索引）确认 `zzz_czx_digimon.pack`(226MB)/`zzz_czx_swarm_units2.pack`(231MB) 结构完整。
- 非 XML 残留/`battle.xml` 保留名/`no_clean_exit`/`battle_preferences` 半成品。
- 非 `is_ai_controlled`/脚本逻辑：死在脚本加载前。
- **嫌疑最大：构建与挂载写竞争**——`zzz_czx_digimon.pack` 在崩溃窗口期被 rebuild（mtime 08:24/08:35），226MB 重写期间游戏挂载它极可能崩。教训：**不要在游戏进程拉起前后重建/部署大 pack**；部署完等写盘落稳再启动。
- `;;` 空 modlist 参数会导致游戏在 ~255MB RSS 处挂死（无日志）——modlist 参数至少要给一个文件名。
- 备用可靠路径：`launch_autotest.py --menu`（裸启动+modlist）→ 主菜单 → 战斗 → 遭遇战(电脑) → 开始战斗。游戏 UI 是 D3D 自绘，UIA 拿不到控件，用屏幕坐标点击（`_click.ps1` + `_shot_full.ps1` 截图定位，2560x1440 屏）。

### 10.9 PFH5 快速完整性校验（免 RPFM）

pack 文件数在偏移 +16；索引从 +28 开始，每条 = `size(u32)` + `flag(u8)` + `path\0`；全部文件内容紧随索引顺序排列。校验：`sum(sizes) + 索引末尾 == 文件大小` 即完整；超出即截断/半写。脚本见 `scratch/czx_battle_test/` 相关片段。

### 10.10 `0xc0000409` 固定偏移闪退 = 提交内存耗尽（2026-09-19 定案）

现象：启动后 ~60s 无窗口闪退，WER 报 `Warhammer3.exe 异常代码 0xc0000409 偏移 0x10da8f1`，一天内同签名十数次。

**决定性证据链**：每次崩溃同秒都有 `System` 日志 `Resource-Exhaustion-Detector id=2004` 事件，报 `Warhammer3.exe 使用了 35-42.7 GB`。机器仅 16GB 物理内存 + ~20GB 动态 pagefile，提交上限 ~36GB——campaign_load 阶段的 Random Army Manager 全军生成（200+ mod 的兵池）瞬态提交 35-42GB 直接顶爆上限，引擎分配失败走 fail-fast（固定偏移 = 同一条 OOM abort 路径）。

要点：

- **间歇性原因**：同一存档/modlist 有时幸存（基线提交 17-25GB 浮动，峰值刚好擦线）；script_log 在崩溃时固定截断于 `chaos_besiegers_tze_2` 生成中段（log 有缓冲，截断点≠真实死亡点）。
- **与 mod 内容无关**：3-mod 最小集同样崩；digimon pack 当时甚至不在 modlist。排查 mod 前先看 RES 事件。
- **修法**：pagefile 调大（init 40GB/max 48GB，需管理员）。`Win32_PageFileSetting` 的"系统管理"项（init=0/max=0）`Set-CimInstance` 改不动、`New-CimInstance` 可能拒绝大 InitialSize——可靠路径是直写注册表 `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management` 的 `PagingFiles`（MultiString）= `C:\pagefile.sys 40960 49152`，并把 `Win32_ComputerSystem.AutomaticManagedPagefile` 置 false；**重启后才生效**，用 `Win32_OperatingSystem.TotalVirtualMemorySize` 验证（应 ~56GB+）。脚本：`scratch/crash_20260919/fix_pagefile3.ps1`（2026-09-19 实测成功）。16GB 内存跑 200+ mod 全集本质超限，长期应减 mod 或加内存。
- **附带发现**：`launch_game` API 会因 playset 里的悬空 `local:data:` id（文件已删）直接拒绝启动——`update_playset` 清掉即可。
- **看门狗部署也有竞态**：检测"游戏退出→立即部署"会撞上用户秒速重开（本次实测：退出→部署→11s 后新进程→60s 后同签名崩）。正确做法：退出后等 ≥90s 确认没有重开再写 `data\`；看门狗模板见 `scratch/watch_and_fix.ps1`（v2）。
- 管理器后端同秒起两个 `main.py` 进程是正常架构（前后端分离），不算重复实例。
- **决定性对照（同日 11:3x）**：`--modlist` 只挂 runtime 包跑纯原版战斗 XML，引擎仍在 init 期瞬态提交 38.2GB 并同签名崩溃——**零 mod 也 OOM**，证明该环境下崩溃与 mod 内容彻底无关，是系统 commit 上限（36.2GB）低于引擎战役/战斗初始化瞬态需求（~38-42GB）所致。pagefile 是唯一有效修法。
- **诊断套路**：`System` 日志查 `Resource-Exhaustion-Detector 2004` → 有同秒事件即 OOM 定案，不用再二分 mod；没有同秒事件才怀疑内容。
- **修正（2026-09-19 晚实测）**：RES 2004/OOM 签名**不等于与 mod 无关**——损坏/畸形的 mod 包能把引擎提交顶到远超基线的量级（当日案例：数码宝贝系 pack 加载时 WH3 单进程提交冲到 55.4GB，63GB 上限仍被打爆；用户禁用该包后立即恢复正常）。判别法：给足 pagefile 后若 RES 事件仍与崩溃同秒、且提交量随某包出现而暴涨（基线 ~38-42GB → 55GB+），就是**mod 驱动的内存爆炸**，不是系统上限问题——直接二分/禁用嫌疑包定位，而不是继续加 pagefile。pack 级预检可做 PFH5 完整性 + DB 片段 `row_count` 合理性扫描（畸形行数会让引擎按行数预分配巨内存）；均正常仍爆炸时嫌疑转向 `.bin` animsuite / variantmesh / anim 引用链。

### 10.11 同日多签名叠加与 `0xc000041d`（2026-09-19 晚间实测）

同一天崩溃可以是多个独立根因叠加，**必须按签名分组再归因**，不能用上午的结论套晚上的崩溃：

| 签名 | 判定 | 说明 |
|---|---|---|
| `0xc0000409 @ 0x10da8f1`（WER `Sig[6]=异常代码`/`Sig[7]=偏移`） | OOM fail-fast | 同一固定偏移 = 同一条 abort 路径；RES 2004 只在持续耗尽时记，**瞬态尖峰崩溃可没有同秒事件**，以 WER 签名偏移为准 |
| `0xe06d7363`（KERNELBASE RaiseException，param[0]=0x19930520） | C++ 未捕获异常 | 与 RES 事件同秒出现时是 bad_alloc 类 OOM 表现 [需验证] |
| `0xc0000005 @ 0x14182fb2b` 读 `0x0`，script_log 仅 148B（`battle_scripted.lua loaded`） | init 期空指针 | 连发同地址 = 确定性 init 失败；本日出现于并行会话连续重建 pack/改写 modlist 期间的 battle autotest 启动 |
| `0xc000041d` ntdll+0x5b221（WER 报 ntdll.dll；mdmp 内层 `0xc0000005` 读野指针 `0x4c00000054`/`0xffffffffffffffff`） | 窗口回调内未处理异常（fatal user callback） | stack.txt 链：`Warhammer3→gameoverlayrenderer64→USER32→win32u→MSCTF→textinputframework→KERNELBASE→ntdll`；两次均死于战役载入 ~2min、HUD 建 `search_panel`（含文本输入框，触发 TSF/IME 初始化）+`advice_interface` 打开期间 [需验证：内存压力下的分配失败 vs IME/overlay 交互 bug] |

要点：

- WER `Report.wer`（`%ProgramData%\Microsoft\Windows\WER\ReportArchive\AppCrash_Warhammer3.exe_*\`，UTF-16）的 `Sig[3]` 故障模块 + `Sig[6]` 异常码 + `Sig[7]` 偏移是最干净的签名来源；mdmp 异常流（stream 6）可脚本化：`scratch/crash_20260919/parse_mdmp.py`；故障地址归属模块用 stream 4 模块表（MINIDUMP_MODULE.ModuleNameRva 在条目 +20）：`find_module.py`。
- mdmp 异常码与 WER 异常码可能不同（mdmp 记内层首错，WER 记最终 fatal）；两者都看一眼。
- **并行会话/看门狗在游玩期间重建部署 pack + 拉起测试实例**是当日实测的崩溃放大器：`deploy()` 的 `shutil.copy2` 是就地覆盖写；游戏对 pack 的 mmap/流式读取遇上半写文件会产生野指针类崩溃（DEP exec、读垃圾地址），签名杂。诊断期先确认 `data\` 与 `mod_output\` 的 mtime 是否与崩溃时刻重叠、是否有别的自动化在写。
- 当时 pagefile 实际仍是系统托管 ~30GB（commit 上限 ~45GB）——`fix_pagefile_admin.bat` 未真正执行（`Win32_PageFileSetting` 仍 0/0）。判断修复是否生效看 `TotalVirtualMemorySize`，不是看脚本存在与否。

### 10.12a 末回合 rebels 上下文崩溃的两歧签名（2026-09-19 深夜）

- `D2026-09-19_T19-32-45`：内层 `0xc0000005` **exec** `0xf63d8c20`（不在任何模块内 = 坏函数指针/虚表被破坏），外层 WER `0xc0000409 @ 0x10da8f1`，**无同秒 RES 事件**。与 18:25 崩溃同签名同场景（均为 `Turn: 10(rebels)` 处理段）——同存档同回合可复现。
- rebels 回合处理每回合都有 psw Lua 错误风暴（turn6-9 同样几百条且不崩）——Lua 错误全被 `safeCall`/`xpcall` 兜住，**不能直接造成原生崩溃**；但每条错误走 `cm:log_event_error` + `cm:draw_2d_text` 原生路径，数千条红字绘制是潜在放大器。`!psw_crash_guard.lua` v8 已包：`psw_faction_has_effect_bundle` 对 `cm:get_faction` 返回 false 的派系直接返回 false（rebels 等非法派系不再炸 `:157` 风暴），并限流 `cm.draw_2d_text` 前 20 条。
- `cm:get_faction("rebels")` 返回 **boolean false**（rebels 不在常规派系表）——所有 `cm:get_faction(name)` 结果使用前必须判 `not f or f == false`。
- 已开 HKCU `LocalDumps\Warhammer3.exe`（DumpType=2 → `%LOCALAPPDATA%\CrashDumps` 全量 dump，免管理员）——minimal mdmp 无线程上下文/栈内存时靠它拿真栈。
- 与 10.12 的 OOM 解释并存：exec-到未映射地址更偏堆破坏/UAF，而 `0x10da8f1` 外层若是通用 fail-fast 兜底则两种根因都可能；RES 2004 是周期采样，瞬时尖峰可能漏采，**没有 RES 不等于排除 commit 尖峰**。[需验证]

### 10.12 过回合崩溃同样是 OOM 签名；无 digimon 也会爆（2026-09-19 晚续）

- **过回合是 commit 峰值时刻**：自动存档序列化整个世界 + 全 AI 派系回合处理 + 单位生成爆发（单回合日志记到 1000+ `UnitCreated`/`UnitTrained`）。110-mod 栈新战役回合处理 WH3 单进程冲到 **51.6GB**（RES 2004 实测）——比 campaign_load 基线（~38-42GB）还高 10GB+，且**不含 digimon 包**（已确认 `unknown file` 未挂载）。聚合规模本身就超限，不是单包问题；当日全部新重建 pack 过 PFH5 完整性 + `row_count` 合理性扫描均 OK。
- **核算方法**：`Get-Counter '\Memory\Committed Bytes','\Memory\Commit Limit'`——本机上限 63.8GB、空闲常驻 ~14GB → WH3 实际可用 ~49GB，峰值 51.6GB 必炸。WER 外签名仍是 `0xc0000409 @ 0x10da8f1`；mdmp 内层可为 `0xe06d7363`（bad_alloc）或 `0xc0000005` 野指针 exec/read（分配失败污染状态的表现），外签名一致即归因 OOM，不必因内层签名杂而改判。
- **并行 autotest 实例是活的放大器（再实证）**：诊断期间抓到 `Warhammer3.exe game_startup_mode battle zz_dgm_patch_test.xml`（PID 5124，19:50:54 起）+ bash watcher（`sleep 55` 轮询 script_log）在崩溃循环中反复拉起——每个 WH3 init 瞬态 ~38GB，与用户游玩进程并发时双进程即爆。诊断时先跑 `Get-CimInstance Win32_Process` 搜 `Warhammer3|watch|build_pack` 命令行确认有无第二个会话。
- **prefs 杠杆（免提权）**：`%APPDATA%\The Creative Assembly\Warhammer3\scripts\preferences.script.txt` 直接编辑即对下次启动生效——`gfx_texture_quality`（0-3，Ultra=3→High=2 可省可观 commit）、`minimise_memory_usage true`（降内存缓存、代价是加载变慢）。注意 **`SetPrefAs*` 只在干净退出时写盘**：崩溃循环中脚本改的 pref 永远不落地（本例 mod 设了 quality=2 但文件仍是 3）；且 mod 里 `SetPrefAsBool('minimise_memory_usage', false)` 会每局覆盖文件值，要翻转须改 mod 源。
- pagefile 已 48GB 上限（C: 仅剩 ~33GB 空闲，再扩受限）；根治靠减 mod 或加内存。

### 10.13 `0xc0000409 @ 0x10da8f1` 是通用 fail-fast 落点，不是 OOM 专属（2026-09-20 修正）

- **关键修正**：`minimise_memory_usage`+贴图降档生效后，WH3 私有提交稳定在 **15.3GB**（上限 63.3GB，系统当时总用 ~40GB），游戏**照崩**，WER 外签名仍是 `0xc0000409 @ 0x10da8f1`——该固定偏移是引擎统一的 fail-fast 兜底，不是 OOM 专属信号。归因前必须读 mdmp 内层异常流：本次 `0xc0000005`，**param[0]=0x8 = 执行（DEP）**，param[1]=目标地址 `0x973d8a00`/`0x31f0b51c0`（堆段垃圾地址）——引擎经坏函数指针/虚表槽间接调用，典型 use-after-free / 接口对象已死仍被回调。
- **判据速查**：mdmp exception stream 解析——header offset 12 取 StreamDirectoryRva（不是 8！），目录项 12B×N，`type==6` 为异常流；ExceptionRecord 在 off+8（code u32/flags u32/record u64/address u64/nparams u32），参数从 off+40 起各 8B。`0xc0000005` 的 param0：0=read、1=write、**8=execute**。
- **崩溃窗口画像（两次一致）**：过回合事件级联中段——单会话 8500+ `UnitCreated`（`src=province_recruitment`→`no_commander`，AI 征兵集中交付）+ `CharacterCreated`→trait 监听器 + psw 每派系监听器错误风暴 + LL_BUILD 每事件×全定居点扫描。**间歇性**：同存档同一回合有时能过——竞态特征，疑似级联中某对象先死后被另一监听器原生调用。
- **psw 错误风暴根因**（`!!Prayer_of_star_witch.pack`，sm0_log 每秒几十条）：`psw_英雄.lua`/`psw_天赋效果.lua` 等几十个 `FactionTurnStart` 监听器条件函数**先**解引用 `psw_main_data.player_data[faction_name]` / `faction:pooled_resource_manager():resource(x):value()`，**后**才判 `is_human()`——这些监听器语义上只对玩家派系有意义，却为 ~100 个 AI 派系（含 `rebels`）每回合全部执行一遍。
- **v9 熔断模式（已落地 `!psw_crash_guard.lua`）**：文件顶层包 `core.add_listener`——`debug.getinfo(cond,"S").source` 命中原版 psw 文件名且事件为 FactionTurnStart/FactionTurnEnd 时，给条件函数套"取不到派系或非玩家→早退 false"前置检查。要点：① 守卫文件须先于目标文件加载（pack 顺序靠前）；② 只在**文件顶层**包，不能放 first_tick（注册早已发生）；③ `core.add_listener` 是 `core_object` 方法，转发须带 `self`；④ 匹配用完整文件名（`psw_英雄.lua`），防止误伤同前缀自家文件（`psw_天赋.lua` vs `psw_天赋效果.lua`）。
- **教训**：探针自己也是负载——`czx_debug_recruit` 全局 `UnitCreated` 监听每条再做 ~10 次 pcall 原生调用，8500 条/会话等于往级联里再灌一份原生调用量，诊断后已停用（文件内 `CZX_DEBUG_RECRUIT_ENABLED` 开关）。
- **未决**：哪个具体调用把死接口送进引擎尚未定案；若 v9 后仍崩，下一步是同存档禁 `!!Prayer_of_star_witch.pack`（+movie）做 A/B 归因。

### 10.14 `battle_preferences` 悬空单位 key = 全部战斗 init 定死（2026-09-20 定案）

现象：全天 67 个 dump，**每一次进战斗都崩**——战役→战斗过渡（`popup_pre_battle` 关闭、savegame 序列化完、`clear_campaign_event_callbacks` 后新 script env 打印 `battle_scripted.lua loaded` 一行即死）与 `game_startup_mode battle` autotest 一致；148B stub script_log 是战斗 env 瞬死标志。

- **签名**：内层 `0xc0000005` 读 `0x20` @ `Warhammer3.exe+0x1a0be3b`（约 35/67 次；其余为 pack 重建竞态等杂签名），外层 WER 恒为 `0xc0000409 @ 0x10da8f1`（通用 fail-fast）。**当日无 RES 2004 事件 → 排除 OOM**。
- **根因**：`%APPDATA%\The Creative Assembly\Warhammer3\battle_preferences\.singleplayer.battle_preferences`（上次自定义战斗军表缓存）里存了 3× `czx_dgm_agumon:wh_main_vmp_vampire_counts:0`。该 key 是数码宝贝包的 main_unit，当日已被改名为 `dgm_chr050_agumon`，且 digimon pack 一度被禁用——**无任何已加载 pack 提供该 key → 战斗 init 读军表时解析出 NULL → 固定偏移解引用崩溃**。
- **为什么二分永远收敛不了**：悬空引用在 `%APPDATA%` 缓存里，**不在任何 pack/modlist 中**——换 mod 组合、甚至纯原版+空 modlist（`zz_empty_mods.txt` 仅 runtime_options）照崩不误。排查死循环时应早查 AppData 缓存文件里的 mod key 引用（`grep -rl 'czx_\|dgm_\|pkm_' %APPDATA%\...\Warhammer3`）。
- **修法**：删除/改名 `.singleplayer.battle_preferences`（游戏自动重建默认）。本次已改名为 `.bak_dead_agumon`，证据存 `scratch/crash_20260920/`。存档本身干净（save 内 0 个 czx_dgm 引用）不受影响。
- **教训**：给自造单位改名/删 key 时，必须同步清理 AppData 侧缓存引用：`battle_preferences`（军表）、`army_setups`（本次干净）、`saved_characters`、存档内的单位引用；改名=删除旧 key，对缓存引用方等同于删单位。
- **判据速查**：同签名同地址反复死于"战斗 init（script_log 仅 battle_scripted.lua loaded 一行）"且与 modlist 内容无关时，先查 `.singleplayer.battle_preferences` 与 `army_setups/` 里的单位 key 是否仍存在。

### 10.15 全局 Lua catch 的边界与部署（2026-09-20，实测/需随版本复查）

- `pcall/xpcall` 只能保护 Lua 层函数：监听器 condition/callback、`cm/bm` 注册的 Lua callback。它不能捕获 `Warhammer3.exe` 已发生的 C++ 访问违例、坏接口解引用、资源/DB 初始化崩溃；原生 dump 仍需按异常码、偏移和阶段单独归因。
- 新增 `zzz_czx_global_lua_guard`：以 `!czx_global_lua_guard.lua` 文件名尽早包住 `core:add_listener`，并尝试包住 `cm:add_first_tick_callback`、`cm:callback`、`bm:callback`、`bm:repeat_callback` 及 battle 注册回调。错误按 tag 计数，前 5 次和每 100 次记录，之后返回安全默认值/不中断事件泵。
- 21:39:22 的内层 `0xc0000005` 读 `0x20 @ exe+0x1a0be3b` 与旧 `battle_preferences` 事故签名相同；21:41:14 最新 dump 改为读 `0x8 @ exe+0x4ba1ae`，两次 WER 外层仍为 `0xc0000409 @ exe+0x10da8f1`。当前没有证据证明 Lua catch 能拦截这类原生崩溃；guard 必须作为降低脚本错误风暴的防线，而不是原生崩溃修复。
- 部署全局 guard 后，必须通过 Mod Manager **重启游戏**才会进入新的 `used_mods.txt`；当前已运行实例不会热加载新 pack。21:47:45 的新实例已在 `used_mods.txt`/`modified.log` 中确认加载 guard；21:48:51 仍产生 native dump，内层为 `0xc0000005` 读 `0x0 @ exe+0x23b01c2`，脚本日志显示崩溃前正在构建 Random Army Manager 的 `chaos_besiegers_tze_2`，证明该 guard 不能拦截本类引擎空对象解引用。不要为了验证强制关闭用户进程。部署期间禁止覆盖正在使用的旧 pack，避免半写文件触发另一类原生崩溃。

### 10.16 空 modlist 仍在 battle init 崩溃：AppData battle_preferences 与输入法注入（2026-09-20，实测/需随版本复查）

- 22:04–22:09 的测试实际是空 modlist：`used_mods.txt` 为空，`wyccc_launch_mods.txt` 只有 `!!!!wyccc_runtime_options.pack`，`modified.log` 唯一 `Mod:` 也是 runtime 包；`zzz_czx_digimon`、`zzz_czx_swarm_units3` 仅为 `unknown file`，没有挂载。
- 空跑连续产生 5 个 dump，脚本日志只到 `battle_scripted.lua loaded`；内层签名多次回到 `0xc0000005` 读 `0x20 @ exe+0x1a0be3b`，WER 外层仍为 `0xc0000409 @ exe+0x10da8f1`，该轮 System 日志无 RES 2004。
- 空跑前的主 `.singleplayer.battle_preferences` 仍保存完整自定义战斗状态（首项 `wh3_cp1_bhashiva_qb1`，混合 Vampire Coast/Bretonnia 军表），虽已无 `czx_dgm_agumon`；先复制到 `scratch/crash_20260920/battle_preferences_20260920_2209.bak` 并改名为 `.bak_empty_run_2209` 后，游戏又从 `army_setups\last_setup_for_wh3_main_brt_aquitaine_classic.army_setup` 重新生成同一类配置。22:15/22:18 仍以相同 `+0x1a0be3b` 崩溃；现已再备份并移出该主 preferences 与该 army setup（`*_2219`），等待下一轮验证。不能把旧 Agumon 修复误当作全部根因。
- 最新 22:09 的 stack.txt 顶层出现 `QQPinyin -> KERNELBASE -> ntdll`，早先同轮 dump 顶层为 `Warhammer3/ntdll`；QQPinyin/TSF 是额外的系统级嫌疑，但单个 stack.txt 不足以定案。若清空 battle_preferences 后仍以相同签名崩溃，应优先做“关闭 QQPinyin/切换系统输入法”的 A/B，再考虑游戏文件/驱动层。
- **“空 modlist”不等于 vanilla 存档**：当前最近存档二进制直接含 `czx_digimon`、`czx_swarm_units3`、`czx_aig3_plus` 等 10 个 Mod 标记；最新 `temp` 战役状态含 55 个 `czx/dgm` 引用。项目默认 `continue_game` 会继续最近存档，因此无 Mod 清单加载该存档仍会在 battle init 读到 Mod 时代数据。纯净对照必须调用 Mod Manager 的 `_launch_game([], token, "")` 只启动到主菜单，或开全新 vanilla 战役，不能调用 `_continue_game`。
- 已实测 `_launch_game([], token, "")`：`save=None`、`ordered_mod_ids=[]`、unit/game data patches 均 `zero_modification`，只挂 runtime options；启动 35 秒后 `Warhammer3.exe` 仍运行且没有新 dump。该结果证明纯净主菜单启动稳定，之前的 crash 发生在带 Mod 存档/战斗状态的 battle init 路径。
- 22:38:24 从该纯净主菜单进入实际 battle init 后仍崩，内层 `0xc0000005` 读 `0x20 @ exe+0x1a0be3b`；前端日志无 gameplay Mod，重新生成的 preferences 首项为 `wh3_cp1_bhashiva_qb1`，双方为 `wh3_main_dae_daemon_prince`。这把问题进一步收敛到 vanilla Bhashiva/custom-battle preset 或其缓存组合；必须与新 vanilla campaign 的普通战斗分开验证。

- 22:45:15 在 `save_games`/`temp`/`resume`/`battle_preferences`/`army_setups` 全部清空后仍以 `+0x1a0be3b` 复现，新生成 preferences 再次指向 `wh3_cp1_bhashiva_qb1` + `wh3_main_dae_daemon_prince`——旧存档与 AppData 军表缓存链整体排除，收敛到 vanilla Bhashiva custom-battle preset 触发当前安装的原生崩溃（疑游戏文件损坏，用户选择卸载重装验证）。

### 10.17 `steam_api64.dll` 缺失/损坏导致启动窗口报错（2026-09-20，实测）

- 截图 `Unable to load library steam_api64.dll` 对应游戏安装目录实际缺少 `steam_api64.dll`，不是 Mod 或 Lua 错误。
- Steam `content_log.txt` 先记录 `Validation: 1 chunks corrupt ... in file "steam_api64.dll"`，后续完整校验记录 `Validation: missing file "steam_api64.dll"`，并将 AppID 1142710 标记为 `Files Missing/Update Required`。
- Steam 客户端重启后重新验证，扫描 90.54GB 游戏目录发现唯一不匹配项为该 298856B DLL，随后 commit 回游戏目录；恢复文件 SHA1=`40D0AE44E090DB49B2309FB152FBD3E11124A376`。若验证被 `App Running` 残留状态暂停，先通过 Steam 客户端重启清状态，再重新验证；不要从第三方下载 DLL。


### 10.18 重装后复盘：`czx_inf_marine` 崩溃根因 = pack 缺 `battle_skeletons_tables`（2026-09-21 实测）

- **根因**：`zzz_czx_swarm_units3.pack` 的 `battle_animations_table` 把 `czx_empire_sword_rifle` 映射到骨架 `czx_marine`，但 pack 内**根本没有 `battle_skeletons_tables`**（unit_sets/ui_unit_groupings 同样缺失）——单位在 battle init 解析动画→骨架时拿到空记录，C++ 空指针 `0xc0000005`。这解释了为何改 variant/模型没用：崩的不是网格，是骨架表缺失。
- **版本号陷阱**：源 TSV 元数据写的是 `battle_skeletons_tables;56`、`unit_sets;5`、`ui_unit_groupings;3`，而当前版本游戏/db.pack 实际读 v17/v2/v1。按错版本编码会让游戏跳过整表或读错字段。导出 TSV 时以 pack 内真实 version 为准，不要信源文件头的旧戳。
- **源与包漂移**：`mod_files/zzz_czx_swarm_units` 曾缺凯瑞甘 agent 全套（24 张 db + 45 个资源文件）——包是从更完整的旧源/RPFM 手工状态建的。新增 `tools/sync_pack_to_source.py <pack> <mod> [--wipe]`：把线上 pack 解码回源（真实版本戳、loc 行、全部资产），保证 `mod_files` 重建 == 部署包。
- **同时修复**：`main_units` 里 `cishe`/`gou` 无对应 `land_units`、`leishou` 连 `main_units` 都没有却被 1200+ 行权限/建筑表引用——全删。
- **验证矩阵（全部 `game_startup_mode battle/campaign` autotest，90–120s 无 dump）**：swarm 单包自定义战斗 ✓、digimon+swarm 自定义 ✓、114 项 playset + 原版兵种战斗 ✓、114 项 playset + 自定义兵种战斗 ✓、114 项 playset + IE 战役初始化并跑过回合处理 ✓。
- **遗留**：`!!!wyccc_cn_localization_patch.pack` / `_batch2.pack` 两个本地汉化包全盘无源（`data_loose_quarantine` 只剩 png 和描述元数据），playset 中保持未解析占位；不影响战斗，只是 wyccc 系部分文本回退英文。
- 工坊 `2789850037 @z_all_agent_actions`：重装后单独带它打原版战斗不再崩——此前的二分"罪魁"很可能也是文件损坏而非内容问题，全量 playset 下同样通过。
