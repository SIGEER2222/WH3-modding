# 脱机版 Talk Mod 设计（离线内容驱动）

> 2026-09-16 定位修正：**第一版完全不需要 LLM/daemon**——全部内容是离线预写台本，事件触发→查库→注入 UI。外部 LLM 降级为可选增强层（有 daemon 时生成变体，没有时用台本）。
> 这样 mod 本身=纯 Lua + 内容表，无外部依赖、无 key、装上即生效——是"永不白装"的最稳形态。

---

## 1. 架构（脱机形态）

```text
游戏事件钩子 (campaign/battle listener)
   ↓
触发判定器（事件类型 × 说话人 × 上下文条件）
   ↓
台本库 CZX_TALK（按 [事件][人设][条件] 索引的台词表，生成器烘焙进 Lua）
   ↓
冷却/去重/轮转（同事件不重复同一句，变体轮转）
   ↓
UI 注入（campaign: dilemma/event feed；battle: infotext/floating text [需验证通路]）
```

- **无 io/daemon 依赖**：io.open 探测照旧做，但只影响"增强层"不影响本体
- 台本即数据：后续上 LLM 时，同一张表的"条件+人设"字段直接复用做 prompt 参数

## 2. 内容 Schema（生成器输入）

```lua
CZX_TALK.events = {
  war_declared = {
    channel = "dilemma",          -- dilemma | event_feed | battle_bark
    cooldown_turns = 0,           -- 每事件类型节流
    priority = 80,                -- 同 tick 多事件时排序
  },
  ...
}

CZX_TALK.lines = {
  war_declared = {
    { speaker="wh3_main_emp_karl_franz", cond={weaker_than=true},
      text="……" },
    { speaker="*", faction="wh_main_empire", ... },   -- 派系 fallback
  },
}
```

条件字段：`target_race` / `target_faction` / `rival_of`（恩怨对）/ `weaker_than` / `location` / `phase`——复用克制模型里的 composition 数据可进一步加 `army_comp` 条件。

## 3. 场景清单（首发台本集）

| 编号 | 场景 | 触发 | 注入 | 台本规模 |
|---|---|---|---|---|
| T01 | **被宣战·领主宣战檄文** | campaign 敌对派系宣战 | dilemma | 每派系 3-5 条 + 恩怨对专属 |
| T02 | **开战阵前喊话** | battle 部署完成 | battle_bark | 恩怨对白 + 派系通用 |
| T03 | **名城陷落/失守** | 关键城市易手 | event_feed + dilemma | 地名锚点专属台本 |
| T04 | **领主阵亡/重创** | battle 敌我领主倒地 | battle_bark | 胜方嘲讽 + 己方阵痛 |
| T05 | **回合末·世界彼端** | 回合结束 | event_feed | 远方大事一句话转播，按在场派系轮转 |
| T06 | **巨兽/召唤入场解说** | battle 大场面 | battle_bark | 解说员腔 + 敌我双视角 |
| T07 | **事务官汇报** | 英雄行动成败 | event_feed | 职业模板（猎巫人/法师/刺客…） |
| T08 | **大仇恨清算**（矮人专属样板） | 仇恨清单结清 | dilemma | 仇恨之书腔，机制→叙事样板 |
| T09 | **溃逃潮 barks** | battle 成片溃逃 | battle_bark | 幸存者恐慌 + 追击方嘲讽 |
| T10 | **胜负判定评词** | battle 结束 | dilemma/结算页 | 胜/败/惨胜/惜败四态 |

台本首发写作范围：T01/T02/T03/T05 四个高曝光场景先行，每场景选 8-10 个高人气派系领主。

## 4. 人设卡规范（写台本前先写卡）

每位领主一张卡：`口吻规则 + 语癖 + 禁写项 + 示例 3 句`。示例见 `talk_scripts_sample.md`。

- 一致性检查靠人设卡 lint：台本过卡时才入库
- 无名领主/事务官走"职业×文化"二维模板（如 帝国猎巫人、震旦玉血法师）

## 5. 上下文供给（离线版也要的最小数据）

台本选择需要的游戏内事实（这些 battle/campaign API 都可得）：

```text
speaker:  宣战方/守方领主 key、派系、种族
rival:    是否存在 lore 恩怨对（§台本 cond.rival_of）
place:    城市 key/地标/省
strength: 战力对比（弱对强宣战 vs 强凌弱）
battle:   兵种构成关键词（敌有巨兽/我方炮兵优势…）
```

## 6. 与在线层的边界

```text
离线台本层（本 mod 本体，必须自洽成立）
   ↑ 增强
daemon/LLM 层（可选）：同条件生成变体 → 走同一注入通道
   → 查无 daemon 时自动全台本兜底
```

验收标准：断网/无 daemon 状态下，全事件链台本轮转正常，观感不空洞。
