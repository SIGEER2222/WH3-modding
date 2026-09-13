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
