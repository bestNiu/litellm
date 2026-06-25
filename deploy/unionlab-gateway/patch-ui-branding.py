#!/usr/bin/env python3
from pathlib import Path

UI_ROOT = Path(__file__).resolve().parent / "custom-ui"
BRAND_NAME = "unionlab-gateway"
LOGO_IMG_JS = (
    '(0,t.jsx)("img",{src:"/get_image",alt:"unionlab-gateway",'
    'className:"h-16 mx-auto object-contain"})'
)
LOADING_LOGO_JS = (
    '(0,t.jsx)("img",{src:"/get_image",alt:"unionlab-gateway",'
    'className:"h-10 object-contain"})'
)

REPLACEMENTS = [
    ("LiteLLM Dashboard", BRAND_NAME),
    ("LiteLLM Proxy Admin UI", f"{BRAND_NAME} Admin UI"),
    ("Access your LiteLLM Admin UI.", f"Access {BRAND_NAME} Admin UI."),
    ('alt:"LiteLLM Brand"', f'alt:"{BRAND_NAME}"'),
    ("Thanks for using LiteLLM!", f"Thanks for using {BRAND_NAME}!"),
    (
        '<div class="text-lg font-medium py-2 pr-4 border-r border-r-gray-200">🚅 LiteLLM</div>',
        '<div class="py-2 pr-4 border-r border-r-gray-200"><img src="/get_image" alt="unionlab-gateway" class="h-10 object-contain" /></div>',
    ),
    (
        '(0,t.jsx)(G,{level:2,children:"🚅 LiteLLM"})',
        f'(0,t.jsx)("div",{{className:"text-center",children:{LOGO_IMG_JS}}})',
    ),
    ('children:"🚅 LiteLLM"', f"children:{LOADING_LOGO_JS}"),
]


def patch_file(path: Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return False

    original = text
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    if not UI_ROOT.is_dir():
        raise SystemExit(f"UI directory not found: {UI_ROOT}")

    changed = 0
    for path in UI_ROOT.rglob("*"):
        if path.is_file() and path.suffix in {".js", ".html", ".txt"}:
            if patch_file(path):
                changed += 1

    print(f"Patched {changed} files under {UI_ROOT}")


if __name__ == "__main__":
    main()
