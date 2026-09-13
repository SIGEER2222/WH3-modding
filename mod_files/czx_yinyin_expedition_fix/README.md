# czx_yinyin_expedition_fix

`!cth_yinyin_expedition.pack`（Workshop 3670461603）悬空引用修复补丁。

## 问题

EXP 包在自己 `db\character_skill_nodes_tables\cth_yinyin` 片段中新增节点
`wh3_main_skill_node_cth_yinyin_magic_1_5`（64 节点），而基础包
`cth_yinyin_pol.pack`/`!cth_yinyin_pol.pack` 的同名片段只有 63 节点。
同名 DB 片段跨 pack 做文件级去重、加载顺序靠前 pack 胜出：当 EXP 排在基础包
之后时其 nodes 片段被遮蔽，`magic_1_5` 丢失，EXP 的
`character_skill_node_set_items` 行 `(cth_yinyin_nodeset, magic_1_5)` 悬空，
游戏报 Bad Mods 弹窗。

## 方案

补丁包用唯一片段名 `zzz_yinyin_exp_fix` 重新声明以下片段，与加载顺序解耦：

| 表 | 来源片段 | 行数 |
|---|---|---|
| `character_skill_nodes_tables` | EXP `cth_yinyin`（含 magic_1_5） | 64 |
| `character_skill_node_links_tables` | EXP `cth_yinyin`（含 magic_1_5 挂接） | 85 |
| `character_skill_node_set_items_tables` | EXP `cth_yinyin` | 60 |
| `character_skill_node_sets_tables` | 基础包 `cth_yinyin` | 7 |

片段字节原样复制、仅重写 GUID，重复主键行与原片段值一致，按主键合并无害。

## 重建

```powershell
python build_patch.py
```

脚本从本机 Workshop 目录读取 EXP 与基础包，生成
`!czx_yinyin_expedition_fix.pack` 并写入游戏 `data\`。

## 使用约束

- pack 必须出现在启动清单 `mod` 行（playset 中 `local:data:` 条目）；仅放
  `data\` 不加载。
- 若 EXP 或基础包更新（行结构变化），应重新运行 `build_patch.py` 同步内容。
- 游戏版本更新后按 `[实测/需随版本复查]` 复核相关表 version 是否仍匹配。
