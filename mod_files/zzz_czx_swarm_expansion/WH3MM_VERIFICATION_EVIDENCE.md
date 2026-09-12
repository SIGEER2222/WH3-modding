# wh3mm / 单位查看验证证据

## 结论

用户指出在 wh3mm 单位查看中看不到飞龙和蟑螂。核对后确认，之前的原因是 `czx_swarm_expansion.pack` 在当前 WH3 preset 中被禁用，不是 pack 文件不存在。

## 证据 1：实际启用状态

检查文件：

```text
C:\Users\22448\AppData\Roaming\wh3mm\config.json
```

原状态：

```json
{"name":"czx_swarm_expansion.pack","isEnabled":false}
```

位置：当前 WH3 preset 第 128 项。

本体：

```json
{"name":"Imperial Arbiter.pack"}
```

位置：当前 WH3 preset 第 82 项。

因此原先的有效加载状态是：

```text
Imperial Arbiter.pack       enabled
czx_swarm_expansion.pack    disabled
```

## 证据 2：wh3mm 确实打开了单位查看，但没有读取补丁

日志：

```text
C:\Users\22448\AppData\Roaming\wh3mm\logs\main.log
```

关键记录：

```text
22:19:58 reading from existing pack ...\3656495027\Imperial Arbiter.pack
22:19:58 Imperial Arbiter.pack file opened
22:20:49 setting tab unitViewer
```

同一段日志中没有：

```text
czx_swarm_expansion.pack
```

这说明 wh3mm 当时确实进入了 Unit Viewer，但数据源中只有本体 pack，所以能看到跳虫、刺蛇、雷兽，却不可能看到补丁新增 key。

## 证据 3：补丁文件本身存在

```text
E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data\czx_swarm_expansion.pack
```

当前最终版本（`mod_output`）文件大小：108795 bytes；包含 49 个内部文件（29 张 DB 表、1 个 Loc、4 个带透明圆角的能力图标和 15 个单位/角色图片资源）。

对应源输出：

```text
E:\Code\WH3-modding\mod_output\czx_swarm_expansion.pack
```

因此问题不是“文件没有生成”或“文件没有复制”，而是“文件存在但没有被当前 wh3mm preset 启用”。

## 证据 4：pack 内确实包含新增单位

pack 解码和源 TSV round-trip 已通过。源 DB 行：

```text
main_units_tables:
  czx_feilong
  czx_zhanglang

land_units_tables:
  czx_feilong
  czx_zhanglang

unit_variants_tables:
  czx_feilong
  czx_zhanglang
  czx_kerrigan
  czx_kerrigan_lord

ability mappings:
  czx_ability_mutalisk_regeneration -> czx_feilong
  czx_ability_roach_regenerative_tissue -> czx_zhanglang
  czx_ability_zergling_adrenal_glands -> gou
  czx_ability_ultralisk_frenzied -> leishou

Kerrigan skill nodes:
  czx_kerrigan_psionic_lash -> czx_skill_node_kerrigan_psionic_lash
  czx_kerrigan_psionic_storm -> czx_skill_node_kerrigan_psionic_storm
  czx_kerrigan_assimilation -> czx_skill_node_kerrigan_assimilation
```

招募记录：

```text
wh_main_emp_forges_1 -> czx_feilong
wh_main_emp_forges_1 -> czx_zhanglang
wh_main_emp_forges_2 -> czx_feilong
wh_main_emp_forges_2 -> czx_zhanglang
wh_main_emp_forges_3 -> czx_feilong
wh_main_emp_forges_3 -> czx_zhanglang
wh_main_emp_forges_4 -> czx_feilong
wh_main_emp_forges_4 -> czx_zhanglang
```

Unit set：

```text
czx_feilong  -> skv_chongzu
czx_zhanglang -> skv_chongzu
```

## 已执行的配置操作

经用户授权，已将以下两个配置文件中的目标 preset 条目启用；wh3mm 保存后会省略启用项的 `isEnabled` 字段（只有禁用项明确写 `isEnabled=false`）：

```text
C:\Users\22448\AppData\Roaming\wh3mm\config.json
E:\Download\wh3mm-win32-x64-2.25.1\config.json
```

当前状态已核对为：

```text
czx_swarm_expansion.pack -> preset 中存在，且没有 isEnabled=false
```

## 关于“启用后单位查看”的限制

本次自动化 shell 会话中，重启 wh3mm 后进程立即退出，没有生成新的 `main.log` 记录，因此没有伪造“已经在 UI 中看到新单位”的结论。

下一次 wh3mm 正常启动并加载当前 preset 后，日志应至少出现：

```text
reading from existing pack ...\data\czx_swarm_expansion.pack
czx_swarm_expansion.pack file opened
setting tab unitViewer
```

然后 Unit Viewer 中才有条件显示：

```text
czx_feilong
czx_zhanglang
```

这部分需要 wh3mm 在正常桌面会话中重新启动一次才能完成最终 UI 证据闭环。

最终 108795-byte pack 已覆盖到游戏 `data/`。两个文件当前 SHA-256 一致：

```text
6CA1019DD28F9E7BD4723149B76D5637C90AA234A5BAD413F4AA7A090B7012A0
```

## 模型证据

本地检索过 `E:\SC2\SC2new\StarCraft II\`、`E:\Download\`、工作区和 WH3 data，未找到 `.m3`、`.m3a`、`SC2Mod`、`variantmeshdefinition`、`wsmodel` 或 `rigid_model_v2` 的 SC2/Zerg 模型源。

因此当前没有导出的 SC2 3D 模型；最终 pack 中的模型仍是 WH3 donor 引用，本次新增的只是 PNG 兵牌、技能图标和 DB 资源链。
