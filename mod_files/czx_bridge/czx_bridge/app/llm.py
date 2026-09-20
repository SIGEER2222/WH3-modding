"""llm.py — OpenAI 兼容后端适配器（可选）。无 key 时一切走离线台本。

环境变量：
  CZX_LLM_BASE   默认 http://localhost:11434/v1（Ollama）
  CZX_LLM_KEY    API key（本地模型可留空）
  CZX_LLM_MODEL  默认按后端自取或 qwen2.5:7b
"""
import json, os, urllib.request, urllib.error


def configured():
    return bool(os.environ.get("CZX_LLM_KEY") or os.environ.get("CZX_LLM_BASE") == "http://localhost:11434/v1"
                or os.environ.get("CZX_LLM_LOCAL") == "1")


def chat(system, user, model=None, timeout=30):
    base = os.environ.get("CZX_LLM_BASE", "http://localhost:11434/v1")
    key = os.environ.get("CZX_LLM_KEY", "")
    model = model or os.environ.get("CZX_LLM_MODEL", "qwen2.5:7b")
    body = json.dumps({
        "model": model,
        "messages": [{"role": "system", "content": system},
                     {"role": "user", "content": user}],
        "temperature": 0.8, "max_tokens": 120,
    }).encode("utf-8")
    req = urllib.request.Request(base.rstrip("/") + "/chat/completions",
                                 data=body,
                                 headers={"Content-Type": "application/json",
                                          "Authorization": f"Bearer {key}"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            data = json.loads(r.read().decode("utf-8"))
        return data["choices"][0]["message"]["content"].strip()
    except (urllib.error.URLError, KeyError, IndexError) as e:
        return None  # 调用方负责台本兜底
