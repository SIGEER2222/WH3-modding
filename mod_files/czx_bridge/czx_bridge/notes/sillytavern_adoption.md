# SillyTavern 规范采纳方案（角色卡 V2 + World Info）

> 2026-09-16。源：SillyTavern `spec-v2.d.ts` + 官方 World Info 文档 + sillycard 字段拆解系列。
> 核心判断：**角色卡 V2 + lorebook 是成熟的内容范式，直接采纳为我们的"人设卡 + 世界观书 + 台本触发"格式**——离线台本选择本质就是 lorebook 的关键词→内容注入，同构到可以复用其生态。

---

## 1. SillyTavern 的两套数据结构

### Character Card V2（角色卡）

```json
{
  "spec": "chara_card_v2",
  "data": {
    "name": "", "description": "", "personality": "", "scenario": "",
    "first_mes": "", "mes_example": "",
    "system_prompt": "", "post_history_instructions": "",
    "alternate_greetings": [],
    "character_book": { ... },
    "tags": [], "creator": "", "character_version": "", "extensions": {}
  }
}
```

### World Info / Lorebook（世界书）

```text
book:  { name, scan_depth, token_budget, recursive_scanning, entries[] }
entry: { keys[]        ← 触发关键词（对话/事件中出现才激活）
         secondary_keys[] + selective(AND/NOT 逻辑)  ← 双条件触发
         content       ← 命中后注入的文本
         constant      ← 总是注入（世界底色）
         insertion_order / position(before_char/after_char/@depth)
         priority      ← 预算超限时谁先被丢
         scan_depth    ← 往回扫多少条上下文
         recursive     ← 注入的内容还能再触发别的条目 }
```

**机制本质**：`条件(关键词组合) → 注入内容` + 预算/排序/递归——**这正是我们离线版"事件条件 → 台本行"需要的触发器模型**。SillyTavern 已经替我们把 schema 设计、边界情况（双键、递归、优先级淘汰）全部趟完了。

---

## 2. 映射：我们的内容模型 = 卡 V2 + lorebook

| SillyTavern | czx_bridge 对应物 | 说明 |
|---|---|---|
| Character Card | **领主人设卡 `CZX_PERSONA`** | description/personality/system_prompt=口吻硬规则；mes_example=示例台词；alternate_greetings=轮换变体（天然支持"同事件不重复"） |
| `character_book` | **领主私有 lore**（他的仇恨、战争、夙怨） | 随卡打包，不污染全局 |
| World Info 全局书 | **`CZX_LORE` 世界观书** | 派系/机制/地名/恩怨条目，keys=派系key、地名、事件类型 |
| lorebook entry | **`CZX_TALK` 台本行** | keys=事件+条件，content=台词；`selective` 实现"矮人 AND 八峰山"双条件 |
| constant entry | 世界底色条目（WH 基调红线） | 永远注入 prompt/台本池底 |
| scan_depth | 事件回溯窗口 | 最近 N 个游戏事件参与匹配 |
| token_budget | 台词选择预算/冷却容量 | 离线版=频道配额；在线版=真实 token |
| recursive_scanning | 连锁触发（宣战事件→再加载"旧恨"条目） | ⚠️ 先不开，v1 防雪崩 |
| prompt 组装(卡+书+历史) | **台本渲染管线 / LLM prompt 组装器** | 同一套数据，离线选句、在线拼 prompt |

### 差异点（不照搬的部分）

| ST 有、我们不用 | 原因 |
|---|---|
| 对话历史（chat history） | 离线版无对话；在线版对话树（dilemma）才需要，作用域限在对话会话内 |
| 正则后处理/深度注入 | 复杂度不值，第一版砍掉 |
| 群聊（Group Chat） | 多人对话=恩怨对白两行结构就够，v1 不做群聊仲裁 |

---

## 3. 落地 Schema（烘焙进 Lua 的运行时形态）

```lua
-- 人设卡（从 chara_card_v2 JSON 转换）
CZX_PERSONA["malekith"] = {
    unit_key   = "wh2_main_def_cha_malekith_0",   -- extensions 里的游戏键
    faction    = "wh2_main_def_naggarond",
    race       = "dark_elf",
    desc       = "巫王……（description）",
    personality= "冰冷傲慢，千年怨毒，称对手为篡者（personality+system_prompt 合并）",
    examples   = { "…", "…" },                     -- mes_example 拆条
    openers    = { "…", "…" },                     -- alternate_greetings → 开场轮换
    tags       = {"legendary", "sorcerer", "eternal_grudge"},
}

-- 世界观书/台本行统一为 lorebook entry
CZX_LORE = {
  { keys={"eight_peaks"}, secondary={"dwarf"}, cond="AND_ANY",
    content="八峰山：贝勒加一族世仇之地……", priority=90 },
  { keys={"war_declared"}, secondary={"malekith"},
    content="纳迦隆德的耐心已到尽头……", kind="line", channel="dilemma" },
}
```

- `kind="line"` 的 entry = 台本行（被选中后注入 UI）；其余 = 上下文 lore（拼 prompt 用，或给 daemon）
- 生成器负责：JSON 卡/lorebook → 校验（人设卡 lint）→ Lua 表

## 4. 白嫖社区生态（采纳 V2 的最大红利）

- chub.ai 等站已有海量角色卡（含战锤角色）；**作者可以直接用 V2 JSON 写领主卡**，生成器转换入库
- 写卡工具（card 编辑器、lorebook 编辑器）现成——内容作者零学习成本
- 我们的扩展字段（unit_key/faction/cond/channel）放 `extensions` 字段——**V2 规范明保证留未知字段**，不破坏兼容性

## 5. 执行动作

- [ ] 定 `CZX_PERSONA`/`CZX_LORE` 最终字段表（上面为草案）
- [ ] 台本样稿 `talk_scripts_sample.md` 改写为 lorebook entries 格式重存一版
- [ ] 生成器需求：`card_v2.json + lorebook.json → czx_talk.lua`（与 unit_profile 生成器同管线）
- [ ] 内容规范：人设卡 lint 规则（语癖命中检查、禁写项检查、长度检查）
