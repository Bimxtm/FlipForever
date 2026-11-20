"""Write addon/FlipForever/Locale.lua from app/flipforever/i18n.py (one source of translations).

Run: python tools/gen_locale.py   (build_release.py runs it too)
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "app"))
from flipforever import i18n, luaio  # noqa: E402

OUT = ROOT / "addon" / "FlipForever" / "Locale.lua"


def render() -> str:
    langs = ",\n".join(f"  {{ {luaio.to_lua(code)}, {luaio.to_lua(name)} }}" for code, name in i18n.LANGUAGES.items())
    return f"""-- FlipForever translations. Generated from app/flipforever/i18n.py by tools/gen_locale.py:
-- edit the translations there, not here. English text is the key; anything missing stays English.
local FF = FlipForever

FF.LANGUAGES = {{
{langs},
}}

FF.TRANSLATIONS = {luaio.to_lua(i18n.TRANSLATIONS)}

-- the chosen language, or the game's own language
function FF:Language()
  local s = FlipForeverDB and FlipForeverDB.settings
  local lang = s and s.language
  if lang and lang ~= "" then return lang end
  return GetLocale and GetLocale() or "enUS"
end

function FF:T(text)
  local t = FF.TRANSLATIONS[self:Language()]
  return (t and text and t[text]) or text
end

-- scripts the game only draws when the client itself runs in that language
FF.SCRIPT_LANGS = {{ ruRU = true, koKR = true, zhCN = true, zhTW = true }}
"""


def main():
    text = render()
    if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
        OUT.write_text(text, encoding="utf-8")
        print("Locale.lua updated")
    else:
        print("Locale.lua up to date")


if __name__ == "__main__":
    main()
