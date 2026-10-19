#!/usr/bin/env python3
"""Generate a local-only, zero-dependency browser MVP without touching existing apps."""
from __future__ import annotations

import argparse
import html
from pathlib import Path
import re
import sys

PAGE = r"""<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>__TITLE__ — MVP</title>
  <style>
    :root { font: 16px/1.55 system-ui,-apple-system,"Segoe UI",sans-serif; color:#17222f; background:#f6f8fb; }
    * { box-sizing:border-box; }
    body { margin:0; padding:28px 16px; }
    main { margin:0 auto; max-width:720px; }
    h1 { font-size:clamp(1.7rem,5vw,2.5rem); margin:0 0 10px; letter-spacing:-.03em; }
    p { margin:0 0 22px; color:#586675; }
    .panel { border:1px solid #dce3e9; border-radius:18px; background:white; padding:clamp(18px,4vw,32px); box-shadow:0 9px 24px #1d35430d; }
    form { display:flex; gap:10px; flex-wrap:wrap; margin-bottom:18px; }
    input { flex:1; min-width:180px; font:inherit; padding:12px 14px; border:1px solid #8f9fae; border-radius:10px; }
    button { font:inherit; font-weight:600; cursor:pointer; border:1px solid #c4ced8; border-radius:10px; background:white; padding:11px 15px; }
    button.primary { background:#153b54; border-color:#153b54; color:white; }
    button:focus-visible,input:focus-visible { outline:3px solid #58a9ee; outline-offset:2px; }
    ul { list-style:none; padding:0; margin:0; }
    li { padding:11px 0; border-top:1px solid #e8edf2; display:flex; gap:10px; align-items:center; }
    li span { flex:1; overflow-wrap:anywhere; }
    li.done span { text-decoration:line-through; color:#697784; }
    li button { padding:6px 10px; }
    .status { font-size:.9rem; color:#536579; margin:5px 0 14px; }
    .notice { margin-top:22px; font-size:.85rem; }
    @media (prefers-reduced-motion: no-preference) { button { transition:background .15s; } button:hover { background:#eef3f7; } button.primary:hover { background:#245c7e; } }
  </style>
</head>
<body>
  <main>
    <h1>__TITLE__</h1>
    <p>하루 MVP 실험용 시작 화면 · 설치 없이 바로 사용</p>
    <section class="panel" aria-label="실행 항목">
      <form id="item-form">
        <label for="item-input" style="position:absolute;left:-10000px">새 실행 항목</label>
        <input id="item-input" name="item" maxlength="120" required placeholder="할 일을 입력하세요" autocomplete="off">
        <button class="primary" type="submit">추가</button>
      </form>
      <div class="status" id="status" aria-live="polite"></div>
      <ul id="items" aria-label="실행 목록"></ul>
    </section>
    <p class="notice">주의: 데이터는 현재 브라우저에만 저장됩니다. 회원가입·결제·공유·서버 기능이 없는 시제품입니다. 민감한 개인정보나 실제 주문 정보를 입력하지 마세요.</p>
  </main>
<script>
"use strict";
(() => {
  const key = "__STORAGE_KEY__";
  const list = document.getElementById("items");
  const form = document.getElementById("item-form");
  const input = document.getElementById("item-input");
  const status = document.getElementById("status");
  let items = [];
  try {
    const saved = JSON.parse(localStorage.getItem(key) || "[]");
    if (Array.isArray(saved)) {
      items = saved.filter(x => x && typeof x.label === "string" && typeof x.done === "boolean").slice(0, 200);
    }
  } catch { items = []; }
  function persist() {
    try { localStorage.setItem(key, JSON.stringify(items)); }
    catch { status.textContent = "브라우저 저장이 제한되어 현재 화면에만 유지됩니다."; }
  }
  function render() {
    list.replaceChildren();
    const completed = items.filter(x => x.done).length;
    status.textContent = "전체 " + items.length + "건 · 완료 " + completed + "건";
    items.forEach((item, index) => {
      const li = document.createElement("li");
      if (item.done) li.className = "done";
      const toggle = document.createElement("button");
      toggle.type = "button";
      toggle.textContent = item.done ? "되돌리기" : "완료";
      toggle.setAttribute("aria-label", item.label + (item.done ? " 미완료로 변경" : " 완료 처리"));
      toggle.addEventListener("click", () => { item.done = !item.done; persist(); render(); });
      const label = document.createElement("span");
      label.textContent = item.label;
      const remove = document.createElement("button");
      remove.type = "button";
      remove.textContent = "삭제";
      remove.setAttribute("aria-label", item.label + " 삭제");
      remove.addEventListener("click", () => { items.splice(index, 1); persist(); render(); });
      li.append(toggle, label, remove);
      list.append(li);
    });
  }
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const label = input.value.trim();
    if (!label || label.length > 120 || items.length >= 200) return;
    items.push({ label, done: false });
    input.value = "";
    persist();
    render();
    input.focus();
  });
  render();
})();
</script>
</body>
</html>
"""

README = """# __PROJECT_NAME__ — Zero-Cost Local MVP

## Run
Open index.html in a modern browser. There are no dependencies, accounts, API keys,
servers, analytics, billing, or installation steps.

## Scope
This starter implements a functioning local task-list user flow with add, complete,
delete, and browser-only persistence. It is intentionally NOT a production SaaS:
no authentication, multi-user database, payment, backup, moderation, audit or
secure server-side data processing exists.

## Next step
Replace the sample task-list domain with one validated core customer journey.
Write acceptance criteria and tests, then add a real backend separately only
after deployment costs, security, privacy, and market validation are reviewed.
Never treat localStorage as a source of truth for financial or user account data.
"""


def generate(name: str, destination: Path) -> None:
    clean_name = " ".join(name.split()).strip()
    if not clean_name or len(clean_name) > 80:
        raise ValueError("Project name must be 1–80 characters")
    if destination.exists() or destination.is_symlink():
        raise FileExistsError(f"Destination already exists (no overwrite): {destination}")
    dest = destination.expanduser().resolve()
    slug = re.sub(r"[^a-z0-9]+", "-", clean_name.lower()).strip("-")[:48] or "mvp"
    dest.mkdir(parents=True, exist_ok=False)
    output = PAGE.replace("__TITLE__", html.escape(clean_name, quote=True)).replace(
        "__STORAGE_KEY__", "zero-cost-mvp:" + slug
    )
    (dest / "index.html").write_text(output, encoding="utf-8")
    (dest / "README.md").write_text(
        README.replace("__PROJECT_NAME__", clean_name), encoding="utf-8"
    )
    print(f"Created zero-dependency browser MVP in: {dest}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True, help="App display name")
    parser.add_argument("--destination", required=True, type=Path, help="New directory only")
    args = parser.parse_args()
    try:
        generate(args.name, args.destination)
    except (ValueError, FileExistsError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
