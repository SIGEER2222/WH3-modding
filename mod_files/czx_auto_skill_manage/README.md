# czx_auto_skill_manage —— 自动勾选"自动分配技能点数"

人物详情面板"技能"页签右上角的"自动分配技能点数"复选框（`checkbox_auto_management`，绑定 `CcoCampaignCharacterAutoManagement`）原版默认**不勾选**，且每个新角色都要手动点一次。

本补丁在以下时机检查该复选框，未勾选则 `SimulateLClick` 模拟勾选：

- `PanelOpenedCampaign` 打开 `character_details_panel` 时
- 面板打开状态下任意 `ComponentLClickUp`（覆盖切换页签、切换左侧角色列表）

勾选状态是**按角色持久化在存档里**的（`IsAutoManaging`），勾选一次后该角色永久生效；脚本只是替用户完成"第一次打开面板时顺手勾上"这个动作。若玩家手动取消勾选，下次打开面板会被重新勾上（即"默认勾选"语义）。

无 DB 改动、无 loc 改动，与所有 MOD 兼容。脚本日志前缀 `[czx_auto_skill_manage]`。
