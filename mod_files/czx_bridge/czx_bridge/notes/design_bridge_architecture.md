# czx_bridge —— WH3 ↔ 外部进程桥接 MOD 架构设计

> 2026-09-16 立项：独立 MOD，定位类似 RimWorld 的 **RimTalk**——游戏内 agent + 外部服务的双向桥。
> **本 mod 不做任何战术决策**：它只负责"把游戏状态运出去、把外部指令运进来"。
> 首个消费方：`czx_battle_tactical_commander`（v2+）；其它潜在消费方：战绩仪表盘、直播 overlay、未来 LLM 指挥官、回放分析工具。

---

## 1. 定位与边界

```text
┌──────────── 游戏进程 ────────────┐      ┌───────── 外部 ─────────┐
│  czx_bridge (Lua agent)          │      │  bridge daemon (Python) │
│    ├─ 状态采集器（通用快照）       │ ⇄ ⇄ │    ├─ 状态解析/落库       │
│    └─ 指令摄入器（外部命令应用）   │      │    ├─ 后端适配器（LLM等） │
│                                  │      │    └─ 客户端 API        │
│  czx_tactical_commander (Lua)    │      │                         │
│    └─ 本 mod 的一个消费者         │      │  任意外部工具            │
└──────────────────────────────────┘      └─────────────────────────┘
```

- **桥 = 传输层**，消费方各自实现自己的决策；
- bridge 对消费方暴露的是 Lua 侧注册接口 + 外部侧 socket/文件协议；
- czx 的纯 Lua 决策核心不依赖 bridge——**bridge 是增强件，czx 没它也能跑**（fail-safe 解耦）。

---

## 2. 传输通道盘点（出/入）

> **2026-09-16 证据更新**：`io.open` 双向可用性已由本机实证材料基本确认，不再是最高优先未知项——
> - campaign：`io.open` 读+写、`os.getenv`/`os.execute` 均为 **CA 官方脚本在用**（`gamedata/script/campaign/mod/{battle,building,siege,waaagh}_logging.lua` 写 `%APPDATA%\The Creative Assembly\Warhammer3\logs\` CSV）；MCT（groovy_mct）`mct_save.lua` w+/r+ 持久化。
> - battle：**RLH**（Random_Legendary_Heroes_Arthas.pack，`script/battle/mod/`）`io.open(log_file,"w"/"r"/"a")` 产出 `RLH_battle_log.txt` 逐单位位置快照——T1 遥测等价物已实跑；**AI General 3**（pancake）运行期 `io.open("./mod_config/aigeneral_config.txt","r")` 读外部配置改行为——T2 指令摄入等价物已实跑。
> - 相对路径 `./` 解析到游戏根目录；`%APPDATA%\The Creative Assembly\Warhammer3\` 亦可写。
> - 剩余实测项缩小为：并发读写纪律（daemon 写完即关 / tmp+rename，agent 侧失败 fail-closed）、`os.time`/`os.clock` 在 battle VM、高频逐行写的性能上限、F2.1 UI 注入通路。

### 2.1 出方向（游戏 → 外部）

| 通道 | 可行性 | 说明 |
|---|---|---|
| `out()` → 脚本日志 | ✅ 已实证 | 所有 battle mod 都在用；daemon tail 日志解析结构化行即得遥测流 |
| `io.open` 写文件 | ✅ 已实证（2026-09-16） | campaign=CA 官方 logging 脚本；battle=RLH 遥测日志实跑。首选通道，直接产 JSONL |
| `serialise_state`/SVR | ⚠️ 进程内 | ScriptedValueRegistry 只在游戏内跨上下文传值，不出进程 |
| 外部读进程内存 | ⚠️ 技术可行 | 无反作弊（单机）但地址随补丁漂移、需逆向——不做主线 |
| 存档/replay | ✅ 仅赛后 | 二进制，只做战后分析 |

### 2.2 入方向（外部 → 游戏）

| 通道 | 可行性 | 说明 |
|---|---|---|
| `io.open` 读文件轮询 | ✅ 已实证（2026-09-16） | battle=AI General 3 读 `mod_config/aigeneral_config.txt` 运行期生效；campaign=MCT 读写 `mct_save.lua`。全双工通道成立：daemon 写 `commands.jsonl`，agent 每 tick 轮询消费 |
| 输入合成（虚拟键鼠） | ✅ 可行 | daemon 模拟热键 → agent 把热键映射成指令（AI General 用相机书签键的先例）。秒级延迟，只做指挥级指令 |
| MCT/配置文件监听 | ✅ 已实证（同上） | AI General 的 `mod_config/*.txt` 文件配置即此模式；MCT 运行期重读仍 `[需验证]` 但文件通道已不依赖它 |
| Pack 热替换 | ❌ | 脚本战斗开始加载一次，无热重载 |
| socket | ❌ | 沙箱无网络库 |

**架构分水岭已越过 = `io.open` 双向可用性确认**，剩余 probe 只验边界（并发/频率/计时 API）：

```text
io.open 可写+可读  → 文件双工 IPC：telemetry.jsonl 出 / commands.jsonl 入
io.open 只写      → 出方向走文件，入方向退化为输入合成
io.open 全封      → 出方向走 out() 日志，入方向只有输入合成
```

---

## 3. 分级服务能力

| 级 | 服务 | 依赖 | 状态 |
|---|---|---|---|
| T0 | 关闭 | 无 | 任何时候可整体禁用，消费方各自 fail-safe |
| T1 | **遥测广播**（状态出） | out() 或 io 写 | ✅ 无依赖即可做，第一交付物 |
| T2 | **指令摄入**（命令入） | io 读 或 热键 | 待 probe；intent 级指令，秒级延迟 |
| T3 | 微操级外部控制 | — | **不做**：延迟/冲突不可控，且偏离 mod 定位 |

### T1 协议（结构化行）

```text
SNAP|t=12.3|u=wh_main_emp_inf_spearmen_0|x=..|y=..|hp=0.82|state=idle|ctrl=player|tgt=..
DEC |t=12.3|mod=czx|act=charge|u=..|tgt=..|score=..|reason=..
SYNC|t=12.3|army_a=..|army_b=..|phase=mid
```

- 每 tick 一行汇总 + 按需单位行；控频率防 IO 拖帧；
- 版本化协议头（`SNAP2|` 等）方便 daemon 兼容升级。

### T2 指令语义（白名单制）

外部指令只能是**意图级**，agent 侧做 schema 校验 + 消费方自己的 Governor 二次把关：

```text
set_doctrine  value=rush                  换 doctrine
set_intent    unit_scope=all value=..     意图切换
retreat       unit=<unit_key>             撤退令
config        key=idle_kick value=false   配置热改
```

- 不做单位级 move_to 坐标指令——那是 T3，砍掉；
- agent 校验失败 = 丢弃 + 日志，fail-closed。

---

## 4. 与消费方的接口

### Lua 侧（游戏内，其他 mod 接入）

```lua
-- 消费方注册遥测源与指令处理器
CZX_BRIDGE.register_source("czx", snapshot_fn)              -- 每 tick 调
CZX_BRIDGE.register_handler("czx", function(cmd) ... end)   -- 指令分发
```

- bridge 只认注册过的 mod，指令按 mod 字段路由；
- czx 不注册时 bridge 照常工作（给纯外部工具用）。

### 外部侧（daemon 对客户端）

- T1：解析后的状态流暴露为本地接口（stdout/HTTP/socket 择一，实现时再定）；
- T2：客户端通过 daemon 提交指令 → daemon 写入指令文件/发合成输入。

---

## 5. 离线 Replay Harness（桥的天然副产品）

T1 的遥测流本身就是录像带：

```text
局内：SNAP 帧流 → 落盘
离线：lua.exe 加载决策模块 + 帧序列 → 重放 DECISION
```

- 先例：Unified Tactics 在 LuaJIT + Lua 5.1 双环境回归；官方 `serialise_state` 可序列化战场状态注入；
- 收益：调权重/改决策离线重放已录战斗，不用反复开游戏；
- 前提（对 czx 的要求）：决策核心纯函数化，与 unit/uc API 隔离——本就是 RFC 的模块边界。

---

## 6. 风险与边界

| 项 | 评估 |
|---|---|
| 反作弊/封号 | WH3 无 EAC，单机环境；但 T3 外部微操已接近外挂，定位上不做 |
| `io`/`os` 沙箱 | 双向可用性已实证（2026-09-16）；剩余边界：并发读写、写频率、battle VM 计时 API |
| 热键合成稳定性 | 依赖游戏焦点/输入法状态，做 intent 级可以，精密操作不行 |
| 遥测性能开销 | `out()` 高频写有 IO 成本——每 tick 一行汇总，别逐单位逐 tick |
| 版本漂移 | 内存读取方案随补丁漂移——不写就不用管 |
| 兼容性 | 与 battle AI mod 无控制权冲突（桥不下 UC 指令），天然可共存 |

---

## 7. 交付顺序

```text
v0.1  T1 最小版：out() 结构化遥测 + Python tail 解析器（零依赖可跑）
v0.2  probe 完成后：io 可用则切文件协议 + T2 指令摄入
v0.3  daemon 客户端 API（本地接口暴露状态流）
———
czx v2 作为首个消费方对接；LLM 指挥官等更远的消费者排在 czx 验证之后
```

**一句话**：桥是独立基础设施——它把"游戏内数据能不能出来、外部指令能不能进去"这一个工程问题解决掉，czx 和未来的 AI 指挥官都只是它的客户端。第一步是探 `io.open`，结果决定桥的上限。
