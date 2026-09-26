---
name: tabbit
description: 驱动本机 Tabbit Browser（AI 浏览器）完成网页任务——打开/接管标签页、执行 Playwright JS、观察页面结构、填表点击、截图、抓取文件。用于任何需要真实浏览器操作的请求：查网页资料、Steam/工坊页面、需要登录态的站点、页面数据提取、UI 自动化验证。本文件记录本机已实测的调用方式；完整 API 契约见全局 skill。
---

# Tabbit Browser（本机已对接，2026-09-25 实测）

`tabbit-cli` 把 Playwright 程序送进 Tabbit Browser 的标签页执行。本机 shell 是 **WSL**，走 Windows interop 调用 exe。

## 调用方式（本机实测路径）

```bash
CLI="/mnt/c/Users/22448/AppData/Local/Tabbit/LocalAgent/bin/tabbit-cli.exe"
"$CLI" diagnose        # 健康检查 + capabilities JSON
```

- Windows 侧等价路径：`%LOCALAPPDATA%\Tabbit\LocalAgent\bin\tabbit-cli.exe`（PowerShell/CMD 场景用）。
- **只调 launcher**，不要直接调 bundle 内的 `E:\Soft\Tabbit Browser\Application\<ver>\TabbitDance\tabbit-playwright-cli.exe`，也不要读 `endpoint.json`。浏览器未启动时 launcher 会自动拉起。
- 浏览器本体：`E:\Soft\Tabbit Browser\Application\Tabbit Browser.exe`（实测版本 1.15.17.0，capabilityVersion 18）。

### 两个实测怪癖（WSL 专属，全局文档未覆盖）

1. **stdout 首行恒为 `TABBIT_PLAYWRIGHT_INSTANCE=<id>`**（launcher 解析实例后打印），JSON 响应从第二行开始。脚本化解析时跳过首行，或 `tail -n +2` / `grep '^{'`。
2. **JS 程序用 bash heredoc 喂 stdin 即可**，不需要全局文档里 PowerShell 的临时文件方案：

```bash
"$CLI" nodejs --task "任务名" --request-id <唯一id> <<'JS'
return {url: page.url(), title: await page.title()};
JS
```

## 核心工作流

命令集：`create, finish, tabs, claim, resume, nodejs, receipt, resource, diagnose`。

```
create --task NAME                          # 建/复用任务，返回标签页清单（不开新页）
nodejs --task NAME --request-id ID          # stdin 收 JS，顶层支持 await/return
        [--tab ID ...] 或 [--group ID]      # 接管用户已有标签页/标签组
        [--timeout-ms 60000-180000]         # 默认 60s
tabs/receipt/resource/diagnose              # 翻页清单 / 等待回执 / 读大结果 / 诊断
finish --task NAME [--discard]              # 收尾释放所有权，默认保留标签页
```

要点（全部实测或摘自全局契约）：

- **task 名会成为标签组可见标题**：用短小可读名（如 `"查工坊页面"`），同一任务所有命令复用同名，包括 finish。`--request-id` 每次调用必须换新（复用旧 id 只返回原回执不重跑）。
- **接管用户标签页**：先 `create` 看清单 → 挑 `tabId`（`currentTabId` 为 null 时按 title/url 匹配）→ `nodejs --tab <id>`。`available`=没人占，`owned`=本任务，`claimed`=别的任务。`--group` 整组接管，与 `--tab` 互斥。
- **新目的地**：直接 `nodejs`（不带选择器），用它自带的初始 `page` 做 `page.goto(url)`，别再 `newPage` 浪费一个标签。
- 程序内全局：`page / context / browser / pages() / usePage(p) / assert / expect / artifactPath(name) / reportIssue(code) / tabbit.*`。词法变量跨调用不保留，要跨调用存 `globalThis`。`return` 只收 JSON 安全值，别返回 Page/Locator。
- 结果 ≤16KiB 在 `result.value` 内联；超限给 `result.resourceId`，用 `resource --resource <id> --offset --max-bytes` 按 `nextOffset` 分页读。上限 64MB。
- 退出码：0=succeeded，70=failed/interrupted，75=queued/running（用 `receipt --wait-ms` 等原请求，别重投）。
- `finish` 默认 `keep:true` 保留标签页成可恢复组；`--discard` 连用户标签一起关，仅在明确要求关全部时用。**每个任务做完必须 finish**。

## 能力速查（diagnose capabilityVersion 18）

| 能力 | 入口 |
|---|---|
| 无障碍结构快照（先看再动手） | `tabbit.observe({frames:"none",maxChars:4000})`；跨 iframe 用 `frames:"all"` |
| 语义定位+操作 | 原生 Playwright：`getByRole/getByLabel/fill/click/check/selectOption` |
| 等待弹窗/新页 | `tabbit.triggerAndWait("popup", () => locator.click())` → `usePage(popup)` |
| 不确定跳转的导航 | `tabbit.triggerAndObserve(trigger, {timeoutMs, settleMs})` |
| 合成粘贴（TSV/大块文本） | `tabbit.pasteText(text,{format:"tsv"})`，不动系统剪贴板，≤1MiB |
| 上传文件 | `locator.setInputFiles("/abs/path")` |
| 截图（仅 PNG） | `return await page.screenshot({fullPage:false})` → 拿 `result.nextAction.path` 给宿主看图 |
| 页面网络抓取 | `page.fetch(url,{as:"json"|"text"|"file",savePath:artifactPath(name)})`，带页面 cookie/CORS |
| 交互诊断 | `tabbit.actionability(locator)` / `tabbit.focusInfo()` / `tabbit.hitTest(...)` |
| 受阻上报 | `reportIssue("AUTHENTICATION_REQUIRED"|"SITE_ACCESS_BLOCKED"|"BROWSER_ERROR_PAGE")` |

未授权的发送/发布/购买/删除**停下来问用户**；登录墙/CAPTCHA 用 `reportIssue` 并保留页面交还用户。

## 深入文档（全局受管 skill，勿改）

完整契约与异常恢复在 Tabbit 自管理的全局 skill（`.tabbit-dance-managed`，更新会被覆盖，不要编辑）：

- `C:\Users\22448\.agents\skills\tabbit\SKILL.md`——完整工作流、分页采集范式、receipt/resource 细节、finish 语义
- `C:\Users\22448\.agents\skills\tabbit\references\advanced-operations.md`——frames、弹窗、对话框、上传、rerender 后 ref 失效、browser-network、限流诊断
- `C:\Users\22448\.agents\skills\tabbit\references\recovery.md`——实例选择、获取失败、finish 恢复、launcher 路由故障

WSL 读法：`/mnt/c/Users/22448/.agents/skills/tabbit/...`。

## 与本仓库的配合

- 抓 `steamcommunity.com` 工坊页：本机直连不通（见 `.codex/project_context.md`），但 **Tabbit Browser 自己可能带代理**——网页核验需求先试 tabbit，不行再回退 `api.steampowered.com` / steamworks 桥接。
- 截图/下载产物落 `scratch/`（`artifactPath` 只给文件名提示，真实路径看返回的 `result.nextAction.path` / `result.path`）。
