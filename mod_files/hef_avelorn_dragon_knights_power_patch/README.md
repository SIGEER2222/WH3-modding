# hef_avelorn_dragon_knights_power_patch

阿瓦隆龙骑士威力加强补丁。

本补丁通过覆盖 `hef_avelorn_dragon_knights` 主 MOD 的同 key DB 行实现，不直接修改主 MOD 源文件。使用时需与主 MOD 一起加载，并像汉化补丁一样排在主 MOD 前面以确保覆盖生效。

## 修改内容

- 阿瓦隆龙骑士与伊甸谷之锋：兵模数量 `12 -> 24`。
- 近战攻击、防御各加 20。
- 共用近战武器 `hefadk_hef_star_dragon_quarter`：基础伤害与破甲伤害均 x2。
- 远程弹药 x20。
- 远程 projectile：射程 270，弹速 x2，burst 连发次数 x3，连发间隔 0.1000。
- 星龙吐息技能次数 x2：普通版 `1 -> 2`，伊甸谷之锋 `2 -> 4`。

## 文件说明

仅包含最小必要 DB 覆盖行，不包含 Loc、UI、脚本或资源文件。

Workshop 发布材料见 `workshop_release/avelorn_dragon_knights_v0.1/avelorn_dragon_knights_power_patch/`。
