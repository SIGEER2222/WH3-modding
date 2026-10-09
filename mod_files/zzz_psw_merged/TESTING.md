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
