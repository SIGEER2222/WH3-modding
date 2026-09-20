# RimTalk 参考拆解 → WH3 映射

> 2026-09-16。源：RimTalk GitHub README + Workshop 页（jlibrary/RimTalk，1.5/1.6 版，多 fork 活跃）。
> 目的：RimTalk 的实际设计逐项拆出来，映射到 WH3 能做什么/怎么做/差在哪。用户未最终定形态前，以"忠实复刻"为基准线。

---

## 1. RimTalk 实际是什么（拆解）

### 核心循环（全部功能的地基）

```text
游戏内事件/状态(小人的想法、行为、心情、特质、关系、环境)
   → 按模板拼 prompt（Scriban 模板 + 上下文过滤器 + 事件过滤器）
   → 调 AI 提供商（云端/本地/Player2）
   → 生成台词 → 头顶气泡显示（依赖 Interaction Bubbles 前置 mod）
```

### 功能面（真实清单）

| RimTalk 功能 | 细节 |
|---|---|
| 上下文对话 | 读取 mood/traits/relationships/当前动作/环境 → 台词符合当下情境 |
| **提示词预设系统** | SillyTavern 式条目：role(System/User/Assistant)、position、in-chat 深度；预设库可增删改、导入导出；Simple/Advanced 双模式 |
| **Scriban 模板引擎** | C# 式逻辑、循环、条件、直接访问游戏对象（pawn/map/Find） |
| **Context Filter（上下文过滤器）** | 预设档位 Essential/Standard/Comprehensive/Custom；token 优化开关；pawn 上下文数量上限；历史深度；逐字段开关（种族/基因/派系/背景/特质/技能/健康/心情/想法/关系/装备 + 时间/季节/天气/财富等环境项） |
| **Event Filter（事件过滤器）** | 选择哪些游戏消息/信件进入上下文，分类勾选，安全默认值 |
| 多后端 | Gemini/OpenAI/DeepSeek/Grok/GLM/OpenRouter/Qwen/Player2/自定义 BaseURL/本地(Ollama,LM Studio)；Simple 模式单 key，Advanced 模式多配置 |
| 玩法过滤器 | talk 间隔冷却；独白开关；派系/囚犯/奴隶/婴儿/非人开关；玩家对话模式（关/手动/AI 驱动）；征召/睡觉时是否显示；游戏加速时禁用 AI；心情/社交效果开关 |
| **扩展 API** | `ContextHookRegistry.RegisterContextVariable/RegisterPawnVariable/RegisterPawnHook`——别的 mod 往上下文/prompt 里注入变量 |
| **Add-on 生态** | Expand Memory（长期记忆+时间线 UI）、Expand Actions（对话触发游戏动作）、Expand Literature（AI 生成书籍/艺术品描述）、TTS、DynamicColors、Event+ |
| 零门槛上手 | 免费 Gemini key → 粘贴 → 就能玩；Player2 App 免 key 一键 |

---

## 2. WH3 平台差异（关键约束）

| RimTalk 的前提 | WH3 的现实 | 影响 |
|---|---|---|
| C# mod 进程内直接 HTTP | Lua 沙箱无网络 | **daemon 必须存在**——AI 调用只能在外部做，桥的两层结构是平台逼的，不是设计偏好 |
| Interaction Bubbles 前置 mod 提供气泡 UI | WH3 无现成气泡系统 | 文本注入通路要另找：battle 侧 Infotext/advice/floating text `[需验证]`；campaign 侧 event feed/dilemma/advisor |
| 小人 = 一等对象，thoughts/mood/relations 全可读 | battle 单位只有战术状态；campaign 领主有特性/属性但无"想法" | WH3 的"对话主体"不是小人，是**领主/军队/派系**——人设源是 faction+lord 特性，粒度更粗 |
| RimWorld 是叙事沙盒（对话即玩法） | TW 是战略+战术游戏 | 对话在 WH3 是**点缀层**不是主玩法；真正主战场是"外部 AI 决策辅助"（czx 场景） |

---

## 3. 逐功能映射表

| RimTalk 功能 | WH3 对应 | 可行性 |
|---|---|---|
| 事件→prompt→气泡 核心循环 | battle 事件流→prompt→Infotext/顾问文本；campaign 事件→dilemma/event feed | ✅ 循环成立，UI 通路 `[需验证]` |
| Scriban 模板 | daemon 侧 Python 模板引擎（Jinja2），游戏侧不碰 | ✅ 换实现不换概念 |
| Context Filter | daemon 侧上下文构建器：快照字段勾选/档位（Essential/Standard/Full）+ token 预算 | ✅ 完全可对齐 |
| Event Filter | agent 侧事件白名单（哪些 EVT 上行）+ daemon 侧再过滤 | ✅ 两层过滤更细 |
| 多后端 provider | daemon 插件适配器：OpenAI 兼容/DeepSeek/Qwen/Ollama/自定义 | ✅ daemon 侧自由 |
| talk 冷却/玩法开关 | agent 注入节流 + daemon 生成节流 | ✅ |
| 扩展 API（别的 mod 注入变量） | `CZX_BRIDGE.register_source/handler/prompt_hook` | ✅ 直接对应——czx 就是第一个扩展方 |
| Add-on 生态 | 消费方 mod 各自独立发布 | ✅ |
| Player2 零门槛 | daemon 侧可接 Player2/本地模型 | ✅ 保留"免 key 可用"路径 |
| 游戏内 item 钩子（VocalLink implant） | WH3 可用特性/装备触发"AI 对话"开关 `[需验证]` | ⚠️ 可做但非必需 |

---

## 4. 如果"忠实复刻 RimTalk"：WH3 版长什么样

### 核心体验（最小垂直切片）

```text
战斗事件（左翼接战/领主阵亡/骑兵冲锋/溃逃）
   → agent 发 EVT 上行
   → daemon：事件 + 战场上下文(阵容/phase/血线) + persona 模板 → LLM
   → 生成一句解说/台词 → 下行 → agent 注入 UI 显示
```

一个"会说话的全战"：领主按派系人设放狠话、解说员报战况——这就是 WH3 版 RimTalk 的最小形态，**不需要 czx 存在也能独立成立**。

### 设置四 Tab 的 WH3 对应（MCT 页）

| RimTalk Tab | WH3 bridge 对应 |
|---|---|
| Basic | MCT 基础页：开关、daemon 连接状态、冷却间隔、玩法过滤（哪些事件触发台词） |
| Prompt Presets | 文本配置文件（不进 MCT——太长）：persona 模板/解说风格，导入导出 |
| Context Filter | MCT 档位页：Essential/Standard/Full 三档 + 字段开关 |
| Event Filter | MCT 多选页：哪些事件上行/触发解说 |

### 关键设计决策（按 RimTalk 反推）

1. **"免 key 能用"是留存关键**——daemon 默认配一个免费后端（本地模型或 Player2 式方案），否则 95% 用户装完就走
2. **人设是内容不是代码**——persona/prompt 模板做成可分享文本包，社区共创是 RimTalk 生态繁荣的原因
3. **冷却与去重是体验底线**——RimTalk 的 talk interval/事件过滤就是为了防刷屏；WH3 战况密度更高，节流参数要更严
4. **扩展点前置设计**——RimTalk 的注册 API 让 add-on 生态成立；bridge 的 register_* 同理，czx 之外的应用场景都靠它

---

## 5. 复刻边界：RimTalk 没有而 WH3 桥有的

RimTalk 只管"说话"；WH3 桥多一层 RimTalk 世界不存在的东西：

- **指令回授（F3）**——RimTalk 的 Expand Actions 是"对话触发游戏内动作"的雏形（招募/约会）；我们的指令通道是它的高配版（意图级命令白名单）
- **战术快照流（F1.1）**——battle 的实时数据流是 RimTalk 的场景里没有的（RimWorld 没有时间敏感的战术层）
- **战役宏观（F1.3/决策）**——回合制战略层是 TW 特有维度

所以 WH3 版 = **RimTalk 的对话循环 + 一条 RimTalk 没有的战术数据高速公路**。形态没想好时，按 RimTalk 做"会说话的战斗"先成立，再逐步长出指令通道。

---

## 6. 建议的第一步（RimTalk 式最小切片）

```text
v0.1-slice：一场战斗里，单位接战/溃逃/领主阵亡三件事
   → EVT 上行 → daemon 用模板拼 prompt → 生成中文台词
   → 下行 → Infotext 显示
只做这一条链，跑通即 RimTalk 复刻成立；czx/指令/仪表全是后话
```
