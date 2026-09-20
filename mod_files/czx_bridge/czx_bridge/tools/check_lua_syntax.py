#!/usr/bin/env python3
"""check_lua_syntax.py — 对生成的 czx_talk_data.lua 做括号/字符串平衡校验（无 lua 环境时的轻量检查）"""
import re, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "script", "czx_talk_data.lua")
src = open(target, encoding="utf-8").read()

depth, in_s, esc, bad = 0, False, False, []
for i, c in enumerate(src):
    if in_s:
        if esc: esc = False
        elif c == "\\": esc = True
        elif c == '"': in_s = False
    else:
        if c == '"': in_s = True
        elif c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth < 0:
                bad.append(("extra }", i)); break
if in_s: bad.append(("unclosed string", 0))
if depth != 0: bad.append(("brace depth", depth))

# 粗略 end 平衡（function/if/for/while vs end；repeat/until 单独计）
body = re.sub(r'"(?:\\.|[^"\\])*"', '""', src)          # 去字符串
body = re.sub(r"--[^\n]*", "", body)                     # 去行注释
opens = len(re.findall(r"\b(function|if|for|while)\b", body))  # for/while 的 do 不重复计
closes = len(re.findall(r"\bend\b", body))
reps = len(re.findall(r"\brepeat\b", body)) - len(re.findall(r"\buntil\b", body))
if opens != closes or reps != 0:
    bad.append(("end_balance", f"opens={opens} ends={closes} repeat_unclosed={reps}"))

tops = re.findall(r"^(CZX_\w+) =", src, re.M)
print("file:", os.path.basename(target))
print("brace_depth_end:", depth, "| unclosed_str:", in_s, "| issues:", bad or "none")
if tops: print("top tables:", tops)
sys.exit(1 if bad else 0)
