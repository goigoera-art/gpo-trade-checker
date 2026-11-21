#!/usr/bin/env python3
"""Обновляет цены, названия и картинки с https://gpovalues.com/browse/ (то же, что update.ps1, но для GitHub Actions)."""
import html, json, os, re, sys, urllib.request
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.abspath(__file__))
IMG_DIR = os.path.join(ROOT, "images")
VER_FILE = os.path.join(IMG_DIR, "versions.json")
UA = {"User-Agent": "Mozilla/5.0"}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        return r.read()


def main():
    page = get("https://gpovalues.com/browse/").decode("utf-8")
    m = re.search(r'<time class="num" datetime="([^"]+)"', page)
    if m:
        dt = datetime.fromisoformat(re.sub(r"(\.\d{6})\d+", r"\1", m.group(1)))
        stamp = dt.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    else:
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    os.makedirs(IMG_DIR, exist_ok=True)
    old = {}
    if os.path.exists(VER_FILE):
        with open(VER_FILE, encoding="utf-8-sig") as f:
            old = json.load(f)
    ver, items = {}, []

    for part in re.split(r"(?=<tr data-slug=)", page)[1:]:
        part = part.split("</tr>", 1)[0]
        tag = part.split(">", 1)[0]
        a = dict(re.findall(r'data-([a-z-]+)="([^"]*)"', tag))
        slug = a["slug"]
        src_m = re.search(r'<img src="([^"]+)"', part)
        img = ""
        if src_m:
            src = html.unescape(src_m.group(1))
            path = os.path.join(IMG_DIR, slug + ".webp")
            if not os.path.exists(path) or old.get(slug) != src:
                try:
                    data = get("https://gpovalues.com" + src)
                    with open(path, "wb") as f:
                        f.write(data)
                except Exception as e:  # картинка не критична
                    print(f"картинка не скачалась: {slug}: {e}", file=sys.stderr)
            if os.path.exists(path):
                img = f"images/{slug}.webp"
                ver[slug] = src
        items.append({
            "slug": slug, "name": html.unescape(a.get("name", "")), "code": a.get("shortcut", ""),
            "rarity": a.get("rarity", ""), "value": int(a.get("value", "0") or 0),
            "demand": a.get("demand", ""), "type": a.get("type", ""), "img": img,
        })

    if len(items) < 50:
        sys.exit(f"нашлось всего {len(items)} предметов — похоже, сайт поменял вёрстку, данные не трогаю")

    js = "var ITEMS = " + json.dumps(items, ensure_ascii=False, separators=(",", ":")) + f";\nvar UPDATED = '{stamp}';\n"
    with open(os.path.join(ROOT, "items.js"), "w", encoding="utf-8", newline="\n") as f:
        f.write(js)
    with open(VER_FILE, "w", encoding="utf-8", newline="\n") as f:
        json.dump(ver, f, separators=(",", ":"))
    print(f"OK: {len(items)} предметов, цены на {stamp}")


if __name__ == "__main__":
    main()
