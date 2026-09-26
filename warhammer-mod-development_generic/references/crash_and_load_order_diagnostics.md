# 启动崩溃、Bad Mods 校验与加载顺序诊断

适用于：游戏启动数秒到数十秒内崩溃、弹出 "The following mods cause a crash to the Database" 对话框、需要定位是哪一个 MOD / 哪一行 DB 记录导致的问题。

## 一、先分清崩溃类型

| 类型 | 特征 | 产物 |
|---|---|---|
| DB 校验失败（Bad Mods） | 窗口标题 `Crash report`，对话框列出 pack + 表 + 记录 | `%APPDATA%\The Creative Assembly\Warhammer3\crash_report\bad_mods_report.txt` 被刷新 |
| 原生崩溃（native crash） | 游戏进程直接消失或闪退 | `crash_report\` 新增 `D<日期>_T<时间>.mdmp` + `.stack.txt` |
| 启动失败/未进窗口 | 进程不出现或立即退出 | 无 mdmp、无 bad_mods 报告；看 `logs\modified.log` 与启动器日志 |

注意：Bad Mods 对话框弹出时**也可能**同时写出 .mdmp；判断标准以 `bad_mods_report.txt` 是否被本次启动刷新为准（比较文件 mtime 与启动时间）。`[实测/需随版本复查]`

**首查顺序（2026-09-25 固化，禁止跳步）**：

0. `Get-WinEvent -FilterHashtable @{LogName='System'; Id=2004}`——与 dump 同秒命中即 **OOM** 定案（§10.10/10.19/10.21），不要去二分 pack；顺手查 `Select-String preferences.script.txt -Pattern 'minimise_memory_usage'` 是否被干净退出写回（§10.19）。
1. `bad_mods_report.txt` 被本次启动刷新 → DB 校验路线（§二）。
2. 有新 `.mdmp` → 原生崩溃，读**内层**异常码并按 §三的签名表分流（§三）。
3. 两者都无、进程起不来 → 启动层：`steam_api64.dll` 完整性（§10.17/10.24）、Steam 客户端是否在跑（stub 两段式 `+0x4926f0`，§10.26）。
4. **vanilla/空 modlist 也崩** → 根因在 AppData 缓存或系统环境，不在 modlist：先 grep `battle_preferences`/`army_setups` 里的 mod key（§10.14），再怀疑注入层/驱动/引擎竞态（§10.16、§10.31 环境签名）。
5. 排查全程先确认**无第二个会话在拉起游戏/部署 pack**——并发压测与半写 mmap 是已实锤的归因污染源（§10.12、§10.27）。

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

- **首选 `tools/wh3diag.py crashes [--last N] [--stack] [--regs]`**：自动列出 dump 异常码、故障地址→`Warhammer3.exe+0x偏移` 签名、params、上下文寄存器与 `.stack.txt` 符号链，不必手写 mdmp 解析。
- `crash_report\D<date>_T<time>.mdmp` 内含异常流：`0xc0000005` = 访问违例；参数通常为 `[读写标志, 出错地址]`；`0x0` 读空指针最常见。
- 崩溃地址 `0x14xxxxxxx` 位于 `Warhammer3.exe` 代码段；同一根因多次崩溃地址通常一致或相近。
- 若多次原生崩溃地址相同、而换 MOD 组合后地址变化，说明不是同一根因，不要合并归因 `[实测/需随版本复查]`。
- 原生崩溃阶段（pack 解析 / DB 合并 / 资源加载 / UI）大致可用存活时长区分：pack 解析阶段崩溃通常在 5-20 秒内；进战役/主菜单后崩溃多为实体/资源/脚本问题。

**签名速查表**（2026-09-25 汇总；外层 `0xc0000409 @ +0x10da8f1` 只是通用 fail-fast 外壳，**不是根因**，一律读内层）：

| 内层签名 | 判定 | 首查/详见 |
|---|---|---|
| `0xe06d7363`（param0=`0x19930520`） | `std::bad_alloc` = OOM | Event 2004；commit 上限核算 §10.21；prefs 降档 §10.19 |
| `0xc0000005` 读 `0x20` @ `+0x1a0be3b` | battle init 空指针 | AppData `battle_preferences`/`army_setups` 悬空单位 key §10.14；Lua 首帧写 gfx 偏好 §10.30 |
| `+0x2ccd917` | matched-combat 套件查表返回 -1 | 自造动画 bin 内部名规则 §10.34 |
| `+0x2cfe551`（`mov ebx,[r13+0x5a0]`，r13=null） | battle setup 序列化空对象 | vanilla 同崩=环境竞态，勿二分 §10.23 |
| `+0x157acc6` 读 `null+0x18`（战役/存档加载 ~15-20s） | 战役初始化单位→技能映射空指针 | junction 表悬空 key §10.35 |
| `+0x52a21a`（9.0 挂载期） | 过期/不兼容 pack | 前端二分 §10.31 |
| `+0x538a0a`（9.0 挂载完成后） | junction/引用悬空 key | 嫌疑包 DB 审计 §10.31/10.33 |
| `+0x1a957e7` / `+0x4e5b30`（9.0，vanilla 同崩） | 环境级早期 init | 非内容问题 §10.31 |
| `+0x4926f0`（stub 期，进程仅 1-4GB） | 启动 stub 空指针/Steam 握手失败 | Steam 客户端是否在跑 §10.26 |
| rip=堆地址、`param0=8`（DEP exec） | UAF 坏虚表调用 | 监听器级联竞态 §10.12a/10.13/10.36 |
| `0xc000041d`（ntdll 回调） | fatal user callback | TSF/IME/overlay 交互 §10.11 |

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

**首选 `tools/wh3diag.py`**：`ls`/`meta`/`cat`/`db`/`which` 已封装下列格式解析（`export_gamedata.py` 提供 `read_pack_header`/`iter_pack_index`/`read_pack_payload`/`decode_db_table` 原语）。下表仅在其不满足需求时作手写参考。

PFH5 pack 头（实测，WH3 当前版本）`[实测/需随版本复查]`：

```text
offset 0   'PFH5'                    4B magic
offset 4   u32  pack type            mod pack = 3
offset 8   u32  dep_count            依赖项个数（非保留字段）
offset 12  u32  dep_size             依赖区字节数（NUL 分隔 UTF-8 串）
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

> **⚠️ Update 9.0 起该入口已废（2026-09-25 实测，详见 §10.31）**：vanilla 空 modlist + 合法 XML 也定死 `+0x1a957e7`/`+0x1a0be3b`，与 mod 无关——不能再当二分/回归基线。改用前端启动二分 `Warhammer3.exe <modlist.txt>;`，判据 = 新 dump + `modified.log` 挂载行数（进程存活≠成功，"press any key" 假存活坑）。本节命令行细节仅适用于 8.1.1 及更早版本。

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
- **判据速查**：`tools/wh3diag.py crashes --regs` 直接打印异常码/params/寄存器；手工解析时——header offset 12 取 StreamDirectoryRva（不是 8！），目录项 12B×N，`type==6` 为异常流；ExceptionRecord 在 off+8（code u32/flags u32/record u64/address u64/nparams u32），参数从 off+40 起各 8B。`0xc0000005` 的 param0：0=read、1=write、**8=execute**。
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

### 10.19 `0xc0000409 @ 0x10da8f1` 的另一条归因路径：AppData preferences 被重置回高画质 → 提交内存耗尽（2026-09-21 定案）

- **现象**：重装后"验证矩阵全过"仅维持到当天凌晨；09-21 01:03–06:39 又产生约 80 个 dump，`script_log` 每次都是 148B stub（`battle_scripted.lua loaded` 一行即死），外层签名恒为 `Application Error 1000 / 0xc0000409 @ Warhammer3.exe+0x10da8f1`。**这次没有内层 `0xc0000005`**：异常流只有一条记录，`ExceptionParameters[0]=0x7` = `FAST_FAIL_FATAL_APP_EXIT`，即进程自己调用 fail-fast 终止，不是野指针。
- **定案证据**：每次崩溃同一秒都有 System **`Event 2004`（Windows 内存资源耗尽）**——`Warhammer3.exe` 提交内存 **40.5 / 40.6 / 40.9 / 43.3 / 43.8 / 46.0 / 46.2 / 46.5 GB**；本机物理内存仅 **15.8GB**，pagefile `C:\pagefile.sys` 初始 40GB/最大 48GB，**总提交上限约 63.8GB**，同时还有 Devin.exe/steamwebhelper 等吃掉数 GB。OOM 与 §10.10 同源。
- **触发开关**：`%APPDATA%\The Creative Assembly\Warhammer3\scripts\preferences.script.txt` 在重装/画质重调后被写成 `minimise_memory_usage false` + `gfx_texture_quality 3`(ultra) + `gfx_unit_size 3`(ultra)；而通过全验证矩阵的同目录备份 `preferences.script.txt.bak_reinstall_test` 是 `minimise_memory_usage true` + `gfx_texture_quality 2`。**同一套 playset，只差这三个键就决定崩不崩**（§10.10 实测：开 `minimise_memory_usage` 后私有提交从 ~28GB 降到 15.3GB）。
- **修复**：把 `minimise_memory_usage` 改回 `true`（无画质代价，只增加加载时间），改前备份 `preferences.script.txt.bak_<时间戳>`。若仍崩，再降 `gfx_texture_quality`/`gfx_unit_size` 到 2。
- **判据速查（务必先看事件日志）**：`Get-WinEvent -FilterHashtable @{LogName='System'; Id=2004}` 命中且时间点与 dump 对齐 → 是 OOM，不是 Mod/DB/悬空 key，**不要去二分 pack**。反之没有 2004 才回退到 §10.14（悬空单位 key）/§10.18（缺 battle_skeletons）那条路。
- **教训**：重装/还原/画质调整都会重写 AppData preferences；每次装机后必须复查 `minimise_memory_usage` 与贴图/单位规模档位。16GB 物理内存 + 百余项单位类 Mod 的机器没有余量跑 ultra + `minimise_memory_usage false`。

#### 10.19 修正：只开 `minimise_memory_usage` 不够，必须同时降贴图/单位档位（2026-09-21 06:50 实测）

- **反例**：09-21 06:29–06:49 的崩溃批次里 `minimise_memory_usage` **已经是 true**，但 `gfx_texture_quality 3`、`gfx_unit_size 3`、`gfx_unit_quality 3` 仍是 ultra，`Warhammer3.exe` 照样提交到 **43.3 / 43.8 / 47.1 GB** 并被 Event 2004 判死。即 ultra 贴图档（自造单位 pack 里 swarm 170MB + digimon 69MB 的 dds）单独就能把降内存后的余量吃光——`minimise_memory_usage` 只降缓存，不降资产分辨率。
- **键名别搞错**：减负要动的是 `gfx_texture_quality`、`gfx_unit_size`（单位规模，不是 `gfx_unit_quality`）、`gfx_unit_quality`、`gfx_effects_quality` 等；`gfx_unit_size` 与 `gfx_unit_quality` 是两个独立键，都要降。
- **OOM 的内层签名不唯一**：本批 dump 同时出现 `0xe06d7363`（C++ 未捕获异常，param[0]=`0x19930520`，典型 `bad_alloc`）与 `0xc0000005 @ 0x14182fb2b`；两者都是同一 OOM 的不同落点。**归因以 Event 2004 是否同秒为准，不要按异常码分派到不同根因**（纠正 §10.11 表里把这两行分开列的印象）。
- **可复用脚本**：`tools/set_memory_safe_prefs.py [--level 2|1] [--dry]`，幂等地把上述键设为安全值并备份带时间戳的 `.bak_*`；Windows Python 运行。装机/画质被重置后跑一次即可，不必手改。
- **写入时机坑**：游戏实例正在运行时改 `preferences.script.txt`，其**干净退出会把内存里的旧值写回文件**，改动被静默覆盖（本次实测：01:32 落盘的 `minimise_memory_usage false` 在 06:48 的实例退出后变成 true）。改档位应在游戏关闭后做，改完复查一次；崩溃退出则不会写盘，改动保留。

### 10.20 测试通过判据：进主菜单不算过，必须进自定义战斗（2026-09-21 用户规则）

- **"进程活着到主菜单"不是通过**。无参数启动到主菜单只证明引擎初始化没崩，不代表战斗初始化路径正常。
- **通过 = `game_startup_mode battle <xml>` 成功进入战斗**：游戏进程存活超过战斗初始化期（实测 >30s 即过了最脆弱窗口），且无新 crash_report mdmp。
- **间歇性**：同一 vanilla XML + 空 modlist，同一机器同一分钟内可崩可过（+0x1a0be3b null+0x20）——引擎竞态，非内容问题。**单次通过不能下"已修好"结论；连续 3 次通过才算基线绿。**
- **空 modlist 语义陷阱**：`Warhammer3.exe game_startup_mode battle <xml> ; ;`（两个分号之间为空）可能不等价于"不加载 mod"——游戏可能回退到扫描 data\ 全部 pack。用 `--mods packs:<file>` 写一个至少含一个 mod 行的 modlist 文件来控制变量。
- **OOM 与竞态叠加**：`--mods full`（114 项 playset）→ bad_alloc（45.5GB commit + Event 2004）；`--mods none` → 间歇 +0x1a0be3b。两个根因并存时，先修 OOM（prefs/baseline），再看剩余崩溃是否为竞态。
- **判据速查**：`alive_after_Ns=True && new_dumps=0` = 过；`new_dumps=1` 且 `+0x1a0be3b` = 竞态重试；`new_dumps=1` 且 `0xe06d7363`/`0xc0000409` + Event 2004 = OOM 未修好。
- **9.0 修正**：`game_startup_mode battle` 入口在 9.0 本身不可用（§10.31）；本节"必须实际进战斗"的判据精神不变，改由前端启动二分 + 存档战役实战承载。

### 10.21 commit 上限容量核算：满 playset 在 52GB cap 下结构性跑不动（2026-09-21 定案）

- **核算公式**：`commit_limit ≈ 物理RAM + pagefile`。本机 16GB + 系统托管 36GB = **52GB**。`Get-Counter '\Memory\Committed Bytes','\Memory\Commit Limit'` 直接读。
- **满 playset 需求实测**：WH3 进程 Event 2004 反复记到 40-51GB commit（18:23=40.85GB、15:5x-16:00=51GB）。脚本化 `--mods full` bad_alloc 于 45.5GB；真实 `wyccc_launch_mods.txt` 启动同样 bad_alloc（0xe06d7363，param 0x19930520）。
- **基线占用**：883 个进程合计私有字节 ~35.9GB（97 python + 42 devin = AI 会话 spawn 树各 ~2.7/2.4GB，其余为浏览器/steamwebhelper/AweSun/GameViewer/Huorong HipsDaemon/QQ拼音长尾）。内核 pool 仅 ~1.4GB 正常。
- **结论**：余量 `52 - ~33基线 ≈ 19GB` < 满 playset 需求 40-50GB → **必然 bad_alloc/OOM**，与是否竞态无关。vanilla 战斗（~7GB）塞得进余量故能过。
- **回归点**：9-19 手动 pagefile 48GB（cap~64GB）时满 playset 能加载（那时崩的是战斗峰值撞 64GB）；9-21 改回系统托管 36GB（cap 52GB）后，满 playset **连加载都过不去**。缩 cap 是本次"打不开"的回归因。
- **修复方向（cap 52GB 下满 playset 无解）**：① 抬 commit 上限=加大 pagefile（治本，需用户决策）；② 砍 playset；③ 压基线 commit（杀 AI 树+浏览器最多省 ~10GB，对 45GB 需求不够）。
- **与 null-deref 竞态区分**：`+0x1a0be3b`/`+0x2cfe551`/`+0x1ad5c65` 崩溃时游戏 commit 仅 1-4GB、系统 committed ~38GB 未触顶 → 与 commit 无关，是独立的引擎 init 竞态。**判据**：dump code=0xe06d7363 → OOM/commit；code=0xc0000005 + params(0,小偏移) → null-deref 竞态。

### 10.22 自定义单位包的随机军池扇出会把小 pack 放大成 OOM（2026-09-21，实测/需随版本复查）

- **A/B 结果**：114 项 playset 同时加载 `zzz_czx_dgm_patch`、`zzz_czx_digimon`、`zzz_czx_pokemon`、`zzz_czx_swarm_units` 及两个小包 `!!ia_all_factions`、`@z_all_agent_actions` 时，新战役初始化命中 Event 2004，WH3 commit 达 42.96GB；用户禁用这 6 项后，107 项清单于 21:52 启动并完整加载 356 个脚本，运行约 109.7s 无新 dump。
- **根因形态**：磁盘体积不是充分指标。原始源表把 50 个 DGM 单位扩展到 5250 行 `units_to_groupings_military_permissions`、5955 行 `building_units_allowed` 和 50 行 `cdir_military_generator_unit_qualities`；swarm 为 1500/4270 行，Pokemon 为 728/1011/7 行。单位、建筑、军事组和随机军生成器的全派系交叉引用会在 campaign load 运行时展开。
- **修复策略**：`tools/trim_custom_unit_campaign_pools.py --apply` 备份并清空这些战役扇出表，只保留 `main_units`、模型/动画链和 `units_custom_battle_permissions`，因此三个单位包和 DGM mini patch 变为“自定义战斗可用、战役建筑招募/AI 随机军默认关闭”的安全版。若以后需要战役使用，应新增低扇出的指定人类派系接入，不要恢复全派系/全建筑笛卡尔积。
- **验证**：安全包的 `wh3diag.py db` 显示上述扇出表均为 0 行；DGM/swarm/Pokemon 的自定义战斗权限仍分别为 1250/400/175 行。`audit_dangling_refs.py` 无新增 ERROR；该修复需通过 Mod Manager 重启后再做连续 3 次 battle/campaign 回归，单次进主菜单不算通过。
- **低扇出战役接入**：[实测/需随版本复查] 当前方案把 DGM 50、swarm 16、Pokemon 7、DGM mini patch 2 个单位各自只挂到原版 Vampire Counts 一级建筑 `wh_main_vmp_necromancers_1`，并各加一条 `wh_main_group_vampire_counts` 军事组和一条 `units_to_exclusive_faction_permissions` → `wh_main_vmp_vampire_counts`。安全包中对应行数为 50/16/7/2，不恢复全派系×全建筑扇出；用户可在死灵法师一级建筑的招募栏使用这些单位。工具：`tools/add_vampire_custom_unit_access.py`。
- **资产总量阈值**：[实测 2026-09-21/需随版本复查] 同一台机器在 52.5GB commit 上限、level1 画质下，DGM+mini patch+swarm（110 项 playset）能完整进入 savegame 阶段；再加入 Pokemon（111 项）会在 campaign load 把 WH3 commit 推到 43.65GB 并命中 Event 2004。低扇出 DB 表不能抵消全部模型/动画/贴图资源的运行时内存，单位包应支持按组合启用。
- **Bhashiva preset 独立触发器**：[实测 2026-09-21/需随版本复查] `battle_preferences/.singleplayer.battle_preferences` 清空后仍会自动生成 `wh3_cp1_bhashiva_qb1`，并重复触发 `+0x1a0be3b`；将等长 preset key 替换为普通原版 `wh3_cth_desert_01_01` 后新启动不再出现该 null-deref，但仍需把 OOM 与 battle init 路径分开判定。
- **基础兵种包/解锁补丁拆分**：[实测/需随版本复查] 基础包只维护 `main_units`、模型/动画、custom battle 权限；DGM/swarm/mini patch 的 Vampire Counts 接入集中放入 `zzz_czx_vmp_unit_unlock.pack`（68 行，依赖三个当前稳定基础包），Pokemon 另有可选 `zzz_czx_vmp_pokemon_unlock.pack`（7 行，仅依赖 Pokemon 基础包）。这样更新单位资源不会覆盖招募接入，且启用主补丁不会自动把 Pokemon 拉回 playset。

### 10.23 纯净播放集仍复现普通战斗 init 空指针（2026-09-21 实测）

- 通过 Mod Manager 新建并切换 `WH3_diag_vanilla_0921` 空播放集，实际 `wyccc_launch_mods.txt` 仅包含 `!!!!wyccc_runtime_options.pack`；`used_mods.txt` 为 0 个游戏 MOD。
- 从该播放集主菜单新开 Vampire Counts 战役并触发普通战役战斗，仍稳定产生 148B `script_log` stub：只写入 `battle_scripted.lua loaded: a new battle is being initialised`，随后 `0xc0000005` 读 `0x20 @ Warhammer3.exe+0x1a0be3b`。
- 该轮提交约 21GB、提交上限约 56GB，未出现新的 System Event 2004；因此不是 OOM，也不是 DGM/swarm/解锁补丁、旧存档或旧 `battle_preferences`/`army_setups` 军表造成的内容问题。
- [实测/需随版本复查] 退出 QQ 拼音辅助进程后重新启动纯净播放集，辅助进程在游戏启动后自动重新出现；最新崩溃栈本身只含 Warhammer3/ntdll/KERNEL32，未出现 QQ 拼音栈帧。下一步应转向 Steam/NVIDIA 覆盖层、第三方安全软件注入与游戏安装/驱动环境 A/B，不再继续修改自定义单位表。

### 10.24 重装后第三方 `steam_api64.dll` 再次覆盖官方 DLL（2026-09-21 实测）

- 用户反馈“卸载重装后好了一段时间，之后复发”。随后核对游戏目录发现 `steam_api64.dll` 为 3,511,296B，SHA1 `980ea8cce849c7dbd529786058851800028c2930`，与工作区 `steam_api64_goldberg.bak` 完全相同；同目录 `steam_api64_o.dll` 为 298,856B，SHA1 `40d0ae44e090db49b2309fb152fbd3e11124a376`，且仍存在 `cream_api.ini`。
- 这解释了重装后的暂时改善：重装恢复了官方 Steam API，后续第三方 DLL/配置又被放回。诊断修复已把第三方 DLL 与 `cream_api.ini` 备份到 `scratch/crash_20260921/`，用官方 `steam_api64_o.dll` 恢复 `steam_api64.dll`，并将 ini 改名为 `cream_api.ini.disabled`；修复后官方 DLL SHA1 已核验一致。
- [实测/需随版本复查] 进行 WH3 原生战斗 A/B 时必须先确认 `steam_api64.dll` 是官方版本；Steam API shim/解锁配置应与 MOD 内容问题分开，不能把第三方启动层覆盖误判为兵种 DB 崩溃。

### 10.25 重装后恢复本地 MOD 的指纹/文件名映射（2026-09-21 实测）

- Steam 重装 WH3 会清空 `common\Total War WARHAMMER III\` 全部文件（含 `data\` 里所有已部署本地包），但**不会**触碰 `%APPDATA%\The Creative Assembly\Warhammer3\`（battle_preferences、save_games、scripts\mct_* 全保留），也不会触碰 `steamapps\workshop\content\1142710\` 工坊包。
- `local:data:<hash>` 的 mod_id = `sha256(规范化绝对路径)[:18]`（小写、`/` 分隔、含盘符），与文件内容无关——只要把同名 pack 拷回 `data\`，playset 条目自动复活，无需改 `state.db`。
- 部署名 ≠ 源文件名时（`--deploy-name`），名字对不上的 mod_id 可用 `state.db` 的 `load_order_backups.ordered_mod_ids` 配合 `backups\used_mods-*.txt` 对齐求出：`used_mods.txt` 先列全部 `add_working_directory`（每工坊 mod 一行），随后按 playset 顺序列 `mod "X.pack"`，mod_id 索引 i 对应第 `97+i` 行的包名（1 起始，视目录行数而定）。
- 实测：装备管理增强工具实际部署名为 `zzz_czx_ancillary_sell4.pack`（源 `mod_output\zzz_czx_ancillary_sell.pack`）；Lalolalo9 自动建设部署名为 `Lalolalo9Autoconstruction.pack`（源 `lalolalo9_autoconstruction.pack`）。
- 重装前建议先把 `battle_preferences\` 整目录备份清空——重装不清它，旧的自定义战斗预设会原样带进新安装继续触发 `+0x1a0be3b`。

### 10.26 `0xe06d7363` = std::bad_alloc；pagefile 配置不重启不生效（2026-09-22，⚠️ 基线结论已被 10.27 推翻）

- **签名定案**：`0xe06d7363`（参数含 `0x19930520`）是 MSVC C++ 异常抛出码，WH3 语境下即 `std::bad_alloc`。同日纯原版空 modlist（modlist 文件内容仅 `;`，`modified.log` 确认零 pack）进自定义战斗，WH3 单进程 commit 仍达 **~40GB**、系统 commit 51.6/53.8GB——连"零 mod"都在 battle init 的 Deployed→sim 阶段顶到天花板，证明 40GB 级基线 commit 是引擎行为而非 MOD 内容泄漏。
- **pagefile 运行时不会扩**：`Win32_PageFileSetting` 配的 InitialSize/MaximumSize（49152/65536）只在**重启后**重建 pagefile 时生效；运行期 `Win32_PageFileUsage.AllocatedBaseSize` 停在 37583MB。实测用受控分配器把系统 commit 推到 48GB（上限 52.5GB 的 92%）也不触发在线扩容，commit limit 不变。**唯一有效修复 = 管理员设固定大 pagefile（建议 64GB）+ 重启**，上限→~80GB。
- **第二种独立签名 `0xc0000005 @ Warhammer3.exe+0x4926f0`（参数 0x0/0x3e8，进程仅 1–4GB）** = 启动 stub 阶段空指针/Steam 握手失败，与 OOM 无关。WH3 启动是 stub→spawn 子进程→stub 退出的两段式，stub 卡在 ~188MB/2 线程属正常窗口；真失败 = 没有后继进程。Steam 客户端不在运行时直启 exe 大概率死在这条路径；`steam.exe -applaunch 1142710` 可用但属绕过 Mod Manager 的应急手段。
- **battle_autotest.py 的 `wait` 到期会主动 taskkill 游戏**——监控里"进程存活到 N 秒后消失"是工具杀的，不是崩溃；判存活须看 wait 窗口内有无新 dump。
- **排除项**：9400 个 `.anim`（DB+动画、无 mesh 的 136MB 包）跑 4min+ commit 峰 ~23GB 未爆——动画解压是分钟级 CPU 消耗但内存可控；纯 DB+UI 包存活至工具超时；致命组合只在"网格+贴图+动画齐全、commit 顶限"时出现。同一台机器 16GB RAM + 53.8GB 上限下，113 项满 playset 结构性跑不动，与单包正确性无关。
- **处置（已被 10.27 修正）**：内容侧当时判定"已无可修项"是错的——真正根因是 `mod_files` 里的 zstd 容器源文件裸存进 pack（见 10.27）。本条保留作为并发测试污染的反面教材：多会话互抢时的共享 commit 读数会把"独占 7GB"污染成"40GB 基线"。

### 10.27 真凶定案：`mod_files/` 里的 zstd 压缩源文件 = 22–38GB 内存爆炸（2026-09-22 晚，受控 A/B 实锤）

- **推翻 10.26 的"与内容无关"**：10.26 的"零 mod 也 40GB"读数取自多会话并发窗口（共享 commit 互相放大）。独占单实例受控下 vanilla 战斗实测 **6.8–7.3GB** 平顶——基线并不高。真正的爆炸由**pack 内容**驱动。
- **机制**：`mod_files/<mod>/` 里的 `.anim` / `.bone_inv_trans_mats` 等文件若是 `[u32 解压后大小][zstd 帧]`（偏移 4 起为 zstd magic `28 B5 2F FD`）——这是 CA pack 的**条目级压缩容器**，由导出工具按 pack 原始字节 dump 而来。`build_pack.py` 把所有文件按原始字节写入、索引**不置压缩标记**（官方 anim2.pack 的同类条目带 `z` 标记，游戏靠标记解压）→ 引擎把压缩字节当裸格式读 → 头部字段（骨骼数/帧数等）= 垃圾 → 分配暴涨 22–38GB → `0xe06d7363` bad_alloc。
- **受控对照（同日）**：`zzz_czx_pokemon` 仅把 14 个 zstd 骨架 .anim 解压回裸格式，其余不动 → 38GB 爆 → **7.04GB 通过**；`zzz_czx_digimon_v2` 解压全部 9195 个 zstd 文件（296MB 包）→ 29.9–35.3GB 爆 → **7.61GB/150s 到 Deployed**。判据：源文件头 4 字节为小端解压大小 + `28 B5 2F FD`；解压后大小字段校验可验证完整性。
- **修复工具化**：`build_pack.py` 已内置 `read_src_bytes()` 哨卡——入 pack 前自动识别 zstd 容器、解压内容并**回写源文件**（自愈），打印 `!! unwrapped zstd-container` 行。头部大小校验不符时按原样打包并告警。
- **不要顺手压缩回去**：本工具链的 pack 全部条目不压缩，源文件保持裸格式；从 pack 提取文件用 `wh3diag.py cat`（已自动解压），不要用 dump 原始扇区字节的工具。
- **残留教训**：二分排障时若嫌疑文件是 zstd 容器（`.anim`/`.bin`/`.bone_inv_trans_mats`/`.anm.meta` 均可能），"文件存在与否"的二分会同时改变"格式正确与否"两个变量——pokemon 骨架层二分（删 skeletons→仍爆；全删 animations→过）曾误判方向。先 `xxd | head` 看偏移 4 是否 `28 b5 2f fd` 再分层。
- **并存事实仍有效**：`+0x4926f0` stub 期空指针（Steam 不在/互斥竞争/高并发）与 OOM 无关；直启需 `SteamAppId=SteamGameId=1142710` + modlist 含 `!!!!wyccc_runtime_options.pack`（否则 stub 冻结 ~890MB）；两段式 spawn 需盯子进程；autotest 工具到点 taskkill。

### 10.28 Pokemon A/B 变体导致 battle init 空指针（2026-09-22，实测/需随版本复查）

- `stage4_pkmonly.txt` 只加载 runtime options + `zzz_czx_pokemon.pack`，`battle_venu.xml`/`battle_pika_solo.xml` 只生成 Pokemon 单位；崩溃脚本日志为 148B battle stub，mdmp 为 `0xc0000005` 读 `0xfffffff8`、`Warhammer3.exe+0x5c0ce5`，同一时段无 System Event 2004。该批不能归为全合集 OOM。
- A/B 矩阵先后验证了多种错误链：donor `man_animation`/空文化映射、`unit_variants` 把 Venusaur 指向 `pmv001`，以及 `pm003.variantmeshdefinition` 指向 Bulbasaur 模型；这些组合均在 battle init 以同一 `0xc0000005` 读 `0xfffffff8 @ Warhammer3.exe+0x5c0ce5` 崩溃。属性表的 `causes_fear/causes_terror` 变体也未改变结果。真正的必要条件是单位的 variant 链自洽：`land_units.man_animation=pm003`、`unit_variants.variant/unit_card=pmv003`、`variants pmv003 -> pm003`、`pm003.variantmeshdefinition -> pkm_003_venusaur`。
- 修复：恢复 Venusaur 的完整 `pm003` variant/model 链，保留用户当前的 Venusaur armour 实验值，使用 `tools/build_pack.py zzz_czx_pokemon --deploy` 重建/部署。固定组合 `pkm_venu_fixed` 运行 161 秒存活，峰值私有内存 7.74GB，无新 dump；静态验收：PFH5 192 文件、`unit_variants` 7 行、`battle_animations` 7 行、`battle_skeletons` 7 行、文化映射 168 行、pm003 variant mesh 指向 Venusaur 模型。

### 10.29 实际战役闪退：残留 battle_preferences 的旧 agent key（2026-09-22，实测）

- 全合集经 Mod Manager 载入最新存档进入战斗时，内层为 `0xc0000005` 读 `0x20 @ Warhammer3.exe+0x1a0be3b`，`script_log` 为 148B battle stub，无 System Event 2004；同一机器的 vanilla battle、full playset vanilla battle、gou 最小 battle 均可通过。
- AppData 二进制 `%APPDATA%\The Creative Assembly\Warhammer3\battle_preferences\.singleplayer.battle_preferences` 取 ASCII 字符串发现残留 `czx_kerrigan`；当前 swarm 已改为 `Lin_Summon_Servant` 的 `lin_all_kerrigan_zerg`，该缓存属于旧战斗军表状态。已备份并移出为 `.bak_stale_czx_kerrigan_20260922_2153*`，没有删除存档或 army_setups。
- 首次移出缓存后通过 Mod Manager 重新载入同一最新存档，曾进入 campaign/战斗结果面板；但用户随后再次进入战斗，22:38、22:46、22:50 在最新与较早存档上仍复现同一 `+0x1a0be3b`。因此移出 `battle_preferences` 只是排除了一个旧输入，**不是最终修复**；当前剩余问题收敛到 campaign→battle 公共引擎路径、存档战斗上下文或外部注入。后续仍应首查 AppData 二进制 key，再做新战役/覆盖层/第三方注入 A/B，不要继续盲目二分 gameplay pack。

### 10.30 campaign→battle 闪退由 Fast End Turn 包触发（2026-09-23，[实测/需随版本复查]）

- 复现签名仍为 `0xc0000005` 读 `0x20 @ Warhammer3.exe+0x1a0be3b`、148B `battle_scripted.lua` stub；新 dump `D2026-09-23_T07-15-00.mdmp` 无同刻 Event 2004。测试经 Mod Manager 使用同一战役存档，并在 `popup_pre_battle` 中明确点击手动战斗按钮，避免把“停在预战界面”误判为通过。
- 受控对照：①稳定基线（AIG3 Plus 保持加载、7 个近期包未加载）战斗运行 606 秒正常结束；②虫群+数码宝贝+VMP 虫群解锁通过，battle-start 钩子执行且存活 >60 秒；③数码宝贝+Pokemon+VMP Pokemon 解锁通过，存活 >45 秒；④仅 Global Lua Guard 对照通过；⑤重新加入 Fast End Turn（不加载 Global Lua Guard/Pokemon 对）后复现同一 `+0x1a0be3b`；Fast End Turn+Global Lua Guard 组合也复现。AIG3 Plus 在成功基线中已实际加载，因此不是单独触发包。
- 最终回归：原 114 项完整集仅排除 `zzz_czx_fast_end_turn.pack`（113 项），其余待测包均加载；同一存档手动进入战斗，`battle-start hidden ability guard completed` 于 27.4 秒出现，实例继续存活 >60 秒，无新 dump、无 Event 2004。
- 源码级 A/B（同存档、同一播放集、同路径手动点战斗）：①保留全部 4 条 `SetPref` 写入、去掉 `_apply_all` UI 回调 → 仍崩（`D2026-09-23_T08-03-47`），排除 UI 点击为必要触发；②4 条 `SetPref` 全删、保留 UI 回调 → 进入战斗并存活；③仅保留 `SetPrefAsBool('fast_forward_end_turns', true)` + UI 回调 → 同一存档手动进入战斗，battle-start hook 26.5 秒执行、64 个 battle 脚本枚举完成、进程存活 >10 分钟无新 dump。**触发组收敛为三条图形/内存偏好写入**：`SetPrefAsInt('gfx_texture_quality', 2)`、`SetPrefAsBool('gfx_unlimited_video_memory', false)`、`SetPrefAsBool('minimise_memory_usage', true)`（组内未再单条隔离）。
- 修复：`mod_files/zzz_czx_fast_end_turn/script/campaign/mod/czx_fast_end_turn.lua` 的首帧回调不再写图形/内存偏好，只保留 `fast_forward_end_turns` 开关与 `_apply_all`（把 armies/heroes/fleets 速度下拉设为 Fastest）。图形/内存档位改由 `tools/set_memory_safe_prefs.py` 在游戏关闭后离线管理，避免战役首帧运行时切换渲染器状态。`notes/pack_notes.txt` 已同步改述。
- 稳定播放集 `WH3 Campaign Stable`（原 `WH3 Campaign Stable Fast Off` 改名）现为 114 项、含修复后 Fast End Turn；原 114 项《全合集-非震旦》和《测试2》保留。注意：pack 名不变，旧播放集里引用同一 `local:data` id 的条目加载的就是修复版。
- 后续遇到相同签名，除检查战斗缓存外，也应对照实际启动的 `wyccc_launch_mods.txt`/`modified.log`；管理器界面当前播放集可能已在游戏启动后变化。回归必须点击手动战斗按钮，并以新 dump、battle-start 日志和持续存活共同判断。教训：campaign 首帧 `SetPrefAs*` 改 `gfx_*`/`minimise_memory_usage` 这类渲染/内存偏好可使后续 battle init 以 `+0x1a0be3b`（读 `0x20`）崩——此类全局偏好不要在 Lua 首帧动态改写。

### 10.31 Update 9.0 大版本闪退：pack 挂载期 `+0x52a21a` 签名与前端二分法（2026-09-25 定案）

- **背景**：2026-09-25 晨 Steam 自动把 8.1.1→9.0（build 25509431，`Warhammer3.exe` 与全部 vanilla pack 重下 ~60GB），为 8.1.1 调好的 116 项 `WH3 Campaign Stable` 播放集整体失效。无 Event 2004 → 非 OOM；无 148B script stub → 死得比脚本枚举更早。
- **新签名**：`0xc0000005` 读 `0x20` @ `Warhammer3.exe+0x52a21a`，发生在 pack 挂载阶段（`modified.log` 截断于挂载中段、`script_log` 根本未生成、`mp_log.txt` 只到 Clockwork/EOS init）。区别于 battle-init 的 `+0x1a0be3b` 与旧档载入的 `+0x243ae98`（读 `0xb0`）。
- **`game_startup_mode battle` 在 9.0 上不可用作二分基线（重要修正 §10.20/10.16）**：空 modlist + 各种合法阵营/兵种组合的 XML（震旦/基斯里夫/帝国/VMP 新 key）均定死于 `+0x1a957e7`（读 `0x20`）或 `+0x1a0be3b`，与 mod 无关——脚本化战斗入口本身在 9.0 有引擎级问题。**改用前端启动二分**：`Warhammer3.exe <modlist.txt>;`（或 `czx_launch_mods.txt`/`wyccc_launch_mods.txt` 生成法），判据 = 新 dump 有无 + `modified.log` 挂载进度 + `mp_log.txt` Clockwork 行。每组跑 2 次。
- **二分收敛路径**：116 项 → 嫌疑集 24（当日更新包，全清白）→ 对半 55/55 → `f1_b` 崩 → 27/28 两败 → 13/14 → 逐块收，最终实锤 **8 个**（分属两个签名）：
  - `+0x52a21a` 组（挂载期崩）：`!!!!!!!!!!!!!!!!unique_faction_ui_iii.pack`（ws 2789999718）单独回加即崩；SFO 全家 `sfo_grimhammer_3_main`(2792731173)、`sfo_warband_upgrade`(3683416886)、`!!fesir_warband_upgrades_sfo`(3743536241)、`!!sfo_tla_upgrade`(2902803962)、`tla_upgrade_brt`(2853239091)——主包单独回加即崩；`longer.pack`(3430887175) 声明依赖 SFO 主包，**不能当"非 SFO"组测**。
  - `+0x538a0a` 组（全部挂载完成后崩）：`zz_diag_junction.pack`（**本地自制诊断包**，内含 `unit_attributes_to_groups_junctions` 行指向 WH2 Tomb Kings 组 `wh2_dlc09_tmb_art_casket_of_souls_0`——WH3 不存在的悬空 key，单包必崩）。此包上午 10:24 才为诊断目的加入播放集，首轮二分只清掉了 SFO 签名，残留第二签名差点被误判为"组合问题"。
- **教训：双签名=双元凶**。移除 SFO 组后若仍崩但签名变了（`+0x52a21a`→`+0x538a0a`），说明第一组已清、另有真凶——继续按新签名二分，不要回头怀疑已排除项。诊断期间新增的测试包（diag/fixture 类）本身也会变成新元凶；二分前先把"会话中临时生成的包"列入嫌疑。
- **已排除（本轮清白）**：当日更新的 ~24 个工坊包（Lin 系/nanu RoR/TLA 主表等）、`twwh3-memreader.pack`（pack 级未复现；但其配套 `twwh3-memreader.dll` 是硬偏移原生注入物，版本边界仍属高危，建议同步停用）、CreamAPI（官方 `steam_api64.dll` 298,856B 下同样复现）、AppData battle_preferences/存档缓存、画质 OOM、两个 PSW 大包（单测存活）。
- **独立遗留问题**：8.1.1 老战役存档在无 mod 下 `campaign_load` 也崩（`+0x243ae98` 读 `0xb0` / `+0x52a21a`），与 pack 挂载崩溃是两条线——老档兼容性需单独验证，不能用来说明 mod 问题。
- **落库修法（不停 app 可生效）**：备份 `state.db` → `delete from playset_items where playset_id=? and mod_id in (...)` → 按 position 重排 → 同步删 `app_state` 里 `enabled_order:warhammer3` JSON 对应条目。后端 `storage.get_enabled_order` 每次新建 sqlite 连接读库，**不用重启 Mod Manager** 即按新列表生成 `wyccc_launch_mods.txt`；但 UI 展示可能为旧缓存，让用户重启 app 核对更稳。
- **前端通过判据的坑（假存活）**：前端挂载完成后进程会停在"press any key"画面等输入——RSS ~1.18GB、CPU≈0 维持不动，看起来像卡死其实是正常待机。**判据 = 无新 dump 且 `modified.log` 挂载行数达到列表数**，不能只看进程存活；纯 Popen 拉起不按键会一直停在那里，属预期。要区分"假死"可用 wmic 查 CPU 增量 + RSS 是否持续增长。
- **教训**：大版本更新后的"挂载期空指针"二分要按 mod_id 切 `enabled_order` 并依赖感知分组（先 `wh3diag.py meta <pack>` 查 rpfm_reserved 依赖）； scripted-battle autotest 的崩溃签名与前端挂载崩溃签名要分开记录，不能混用判据。

### 10.32 Update 9.0 扩展包兼容补丁：版本升位 + 改名键 + 过期 twui（2026-09-25 晚）

- **DB 版本错位修法（纯追加列场景）**：9.0 多数表升版只是**末尾追加列**（`missile_weapons` v11→v12 加 `hide_secondary_range_ammo_statistics_ui`、`battle_vortexs` v19→v20 加 `subsequent_vortex`/`subsequent_vortex_delay`、`land_units` v53→v54 加 `default_guard_mode` 等）。修法 = 按旧版 schema 解码 → 新列填 vanilla 典型默认（bool=`false`、数值=`0`/`0.0`、引用=`''`，`land_units_to_unit_abilites_junctions.culture` 用通配 `'*'`，`ritual_targets.max_range_ap` 用 `-1`）→ 以**同内部路径** TSV 重编码进补丁包，靠前遮蔽原分片。审计脚本：`scratch/_ver_report_all.py`（逐包对 vanilla 头版本）、`scratch/_verify_90fixes.py`（补丁逐行回读比对）。
- **v0（无版本标记）表在 9.0 仍合法**：`units_to_groupings_military_permissions`/`cai_construction_system_building_values` 等 vanilla 仍是 markerless v0——重编码非错位表时保持 v0（meta `;0;`），不要顺手升位。而 `land_units_to_unit_abilites_junctions`/`special_ability_groups_to_units_junctions`/`slot_sets` 已从 v0 升到 v1，mod 的旧 v0 分片需升。
- **9.0 已确认的 vanilla 键改名/删除**（悬空外键审计 `scratch/_audit_refs.py` 发现，RON 的 `is_reference` 元数据可用）：
  - `building_chains`：`wh3_main_sla_cav` → `wh3_dlc27_sla_cav_tormentors`；levels `wh3_main_sla_cav_1/2/4` → `wh3_dlc27_sla_cav_{1,2,4}_tormentors`（无 _3）。
  - `groupings_military`：`wh3_dlc20_group_chs_festus` → `wh3_dlc20_group_chs_festus_glottkin`（Festus 并入 Glottkin 组）。
  - `unit_sets`：`skv_infantry` 解散（最接近 `skv_all`）、`vmp_corpses` → `vmp_corpse_units`、`wh2_dlc11_emp_spearmen_swordsmen_flagellants_halberdiers` → `emp_infantry`。
  - `building_levels`：`wh3_main_ksl_ice_guard_1` 删除（仅剩 `_2`）——无对应键时留死行比错配安全。
  - **改名后必须按表主键去重**：arthas `unit_set_to_unit_junctions` 改名后产生 7 个 (unit_record,unit_set) 重复对，需丢弃（`scratch/_dedupe.py`）。
- **过期 twui 遮蔽**：mod 常把**整份旧版 vanilla twui**打进包里当遮蔽物。判定法：正则抹掉 GUID 后做行集合 diff，若 mod-only 只有坐标/尺寸/GUID 噪声且无 mod 自有内容（搜 mod 前缀 token=0），直接用**当前 vanilla 文件**同路径遮蔽即修复。psw 的 `dlc24_formless_horror.twui.xml` 是 v141 旧拷贝（vanilla 已 v142），arthas 的 `dilemma.twui.xml` 虽标 v142 但缺 9.0 新增的 182 行且用了旧 `CanMakeChoice( StoredContext("CcoCdirEventsDilemmaChoiceDetailRecord").ChoiceKey )` 签名——9.0 已改为 `dilemma.CanMakeChoice( choice_record.ChoiceKey )`，旧签名会导致 dilemma 按钮失效。
- **xiang 的 `character_details_panel*.twui.xml` 是真改写**（LayoutEngine 全换 HorizontalList + armory 常显 hack），不能遮蔽还原——版本已是 v142 保留原样。判断“是拷贝还是改写”就用抹 GUID diff。
- **build_pack.py 编码器缺口已补**：`ColourRGB`/`ColourU32`/`I16`/`I24`（ritual_targets 用到 ColourRGB，原来是 NotImplementedError）。
- **部署**：6 个补丁包 `czx_{luke,psw,chanliuzi,arthas,boudicca,xiang}_90fix`（每包声明对目标 pack 的依赖），playset 补丁 pos 99-104、目标 pos 105-111 全部“补丁在前”。`pswmv`（movie）与本地 `hero_grants`/`vmp_pokemon_unlock` 审计干净直接回归。

### 10.33 大版本兼容排查的固化流程（`wh3diag.py compat`，2026-09-25 晚定稿）

每次 CA 大版本更新后，对"疑似不适配"的 pack 按此跑一遍，**禁止再写一次性审计脚本**：

1. **先确认基线新鲜度**：`tools/schema/schema_wh3.ron` 与上游 rpfm-schemas 同步（旧 schema 会把新表误判为解码失败）；wh3diag 的 `schema_ron()` 已固定优先项目副本、RPFM appdata 副本兜底。
2. **一条命令审计**（须 Windows Python313，compressed 条目需 zstandard）：

   ```text
   wh3diag.py compat "<pack 名>" [--dep <依赖 pack>]...
   ```

   输出三段报告，分别对应三类不兼容：
   - `stale DB versions`：包内分片头版本 vs 原版当前版本（原版基线 = `data\*.pack` 中无 `*.rpfm_reserved` 的包），并列出升版新增列；
   - `dangling references`：RON `is_reference` 元数据驱动的悬空外键——键域 = 原版 ∪ 本包 ∪ `--dep` 依赖包（mod 自定义键不会误报）；命中 `COMPAT_KEY_RENAMES` 的直接给改名建议；
   - `twui / formats`：同路径遮蔽 vanilla twui 的判定——抹 GUID 行集合 diff，`stale-copy`（过期拷贝）/ `tweak` / `rewrite`（真改写，保留）。
3. **人工复核改名**：`COMPAT_KEY_RENAMES` 只放已验证改名；`dead key` 无安全替代时留死行（如 `wh3_main_ksl_ice_guard_1`）。发现新改名→先确认新键存在→加入 wh3diag 的 `COMPAT_KEY_RENAMES` 常量。
4. **生成补丁源**：

   ```text
   wh3diag.py compat "<pack 名>" --dep <依赖> --emit <fix_mod_name>
   ```

   自动产出 `mod_files/<fix>/`：全部旧表按当前版本重编码为 TSV（按列名映射，列序变化也安全）、已知改名键改写、按 schema 主键去重（自动处理改名撞键）、`stale-copy` twui 用当前 vanilla 同路径落盘、`notes/`（dependencies=目标包名、alias、pack_notes）+ 工坊预览图。
5. **人工检查 TSV**（改名值、新列默认值是否合理）→ `tools/build_pack.py <fix> --deploy`（自动部署 data\ + user_mod_data + playset 尾部）。
6. **playset 排序**：补丁必须排在目标 pack **之前**（靠前遮蔽）。改完 `state.db` 必须重启 Mod Manager，否则内存旧状态会回写覆盖。
7. **验证**（对照 §10.32 的 `_verify_90fixes.py` 思路）：补丁表按当前版本解码、行数与源一致、非改名行逐值回读相同、无重复主键、`which <分片名>` 确认同路径遮蔽、playset_items 与 enabled_order 一致。
8. **归因边界**：审计发现"含有不兼容内容"≠"它就是崩溃元凶"——两类结论分开记录（本次 6 扩展包确有版本错位，但崩溃真凶另属 SFO 组等 8 包）。

已知局限：`stale-copy` 判定是启发式（+mod_only/-van_only 行数），mod 在旧 vanilla 拷贝上小幅改动时也会命中，遮蔽前仍需眼看确认；非 DB 的 anim/rmv2/bnk 头版本检查暂未并入 compat（需要时沿用 §10.32 前的手工比对）。

### 10.34 matched-combat 注册表：自造动画套件遇特定敌人即崩（2026-09-23 晚定案，修法于 9-25 修正）

- **现象**：自定义单位包加载正常，但遭遇**可触发 matched-kill 的敌人**（绿皮等 hu21 系）时崩 `0xc0000005 @ Warhammer3.exe+0x2ccd917`；基斯里夫/帝国/震旦敌人不触发——曾因敌人种类不确定被误判为"随机崩"。
- **根因**：自定义动画套件 bin 的**内部套件名**未注册进 vanilla `animations/matched_combat/attila_generated.bin` 注册表，matched 查询返回 -1 → 空解引用。
- **修法（初版，后被修正）**：当日把每个带 matched 引用的 bin 内部名改成 donor 的 vanilla 套件名（`emp_sws1`→`hu1_empire_sword_and_shield`、`sn1_serp`→`sn1_serpent`、`bi1_eagl`→`bi1_eagle`、`empire_sword_rifle`→`hu1_dlc25_empire_sword_hochland_long_rifle`、`dlc17_ghorgon`→`hu11b_dlc17_ghorgon`、`cst_promethean`→`cr1_cst_promethean`），崩溃消除（亚古兽 vs 绿皮兽人 75s 零崩）。
- **9-25 修正（marine 不开火案定案）**：内部名撞 vanilla 套件名会**遮蔽原版套件**（曾把 `czx_empire_sword_rifle` 写成 vanilla 注册名导致原版火枪手失效）。正确规则 = **内部名 == animpack 条目文件名 stem == `battle_animations_table.key`**；attila 注册表实际按**剪辑名前缀**索引而非套件名——bin 内剪辑路径指向真实存在的剪辑即可，套件名保持自有 key 不再触发查表失败 `[实测/需随版本复查]`。
- **补丁法**：bin blob offset 8 处是 u16 长度前缀字符串——**重写时必须同步更新长度**，只换字符串不更新长度会让头部解析错位产生隐性损坏。套件命名细则另见 `asseteditor_animation_workflow.md` 进包链路节。

### 10.35 战役/存档加载 ~15-20s 定死：junction 表悬空 key（2026-09-24 收官定案）

- **现象**：所有存档加载与新战役初始化 ~15-20s 必崩 `0xc0000005`（`+0x157acc6` 读 `null+0x18`）；自定义战斗正常；去掉 `zzz_czx_pokemon.pack` 即存活。
- **根因**：`land_units_to_unit_abilites_junctions` 有一行 `pkm_solar_beam → pkm_003_venusaur`，但真实技能键是 `pkm_003_solar_beam`——9-23 技能重命名时漏改 junction。战役初始化解析"单位→技能"映射时取空指针即崩。**战役加载路径会校验 junction，自定义战斗不校验**——单测战斗全绿不代表战役安全。
- **二分方法学教训**：字节级 pack 子集二分（`pack_subset.py` 抽部分 db 表重打包）会**制造新的悬空引用**——main+land 双子集崩溃其实是缺 variants/weapons 支撑表的假阳性。正确二分法 = 从 **TSV 源按行重建**子集（`scratch/mk_pkm_row_subset.py` 模式）保证引用闭包完整；再用"部署包 vs TSV 重建包逐字节比对（除 GUID 全同）"证明崩源在未重建表里。
- **审计工具教训**：`tools/audit_dangling_refs.py` 当天曾正确报告 `pkm_solar_beam` 悬空，被误判为误报（"其实 `pkm_003_solar_beam` 存在"）——junction 的 ability 列校验必须**同时**对照包内 `unit_abilities` 键与 vanilla 键，前缀相似≠存在；工具已加 difflib 近似键提示。注意该审计器对 vanilla key 有假阴性，结论须对照 `gamedata/db/`。
- **泛化**：任何"重命名单位/技能/组 key"的操作必须全库搜旧 key 残留（junction/preferences/存档文本化部分）；此类崩溃只需"单位存在+技能链"即可触发，权限表/单位集/资产文件全无关。

### 10.36 AI 回合处理中 UAF 崩溃（2026-09-24，未最终定案）

- **现象/签名**：22:39 与 23:04 两次崩溃同型——`rip`=堆地址（`0x398cfdd80`/`0xbad64020`）、`0xc0000005` params=`[0x8, addr]`（**执行违例**）、rcx/rbx/rip 同页 → 经坏虚表/函数指针调用已释放对象，UAF 特征（同 §10.12a/10.13 族）。
- **现场**：AI 回合处理中叛军 `PendingBattle` 自动结算 + 恶魔英雄批量 `CharacterCreated` + `wh2_main_trait_builder` 刷屏；同一回合在另一会话安全通过 → **非确定性竞态**，不是坏数据。
- **嫌疑清单（未隔离）**：`sm0_recruit_defeated`（回合边界 `spawn_character`×5 + `create_force`×14 批量造英雄）、`wyc_choujiang1` 的 `check_char_valid` 对新生角色无防护直接调 `faction:subculture()`、`wh2_campaign_traits.lua`（no_lazy_trait 遮蔽版）的 `check_exclusion` 对 `faction:culture()` 零防护。
- **排查方向**：给上述监听器条件/回调函数补"取不到派系/角色→早退"空防护（§10.13 v9 熔断模式可复用）；复现依赖特定回合级联，注意**不要杀用户手动拉起的 Warhammer3.exe**（曾因误杀玩家进程中断调查）。
