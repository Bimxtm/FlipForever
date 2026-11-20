"""Read WoW SavedVariables files and write Lua data files."""
from __future__ import annotations

import re

_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_NUMBER = re.compile(r"-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)")
_LONG_OPEN = re.compile(r"\[(=*)\[")
_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
            "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


class LuaError(ValueError):
    pass


class _Parser:
    def __init__(self, text: str):
        self.s = text
        self.i = 0
        self.n = len(text)

    def error(self, msg):
        line = self.s.count("\n", 0, self.i) + 1
        raise LuaError(f"{msg} at line {line}")

    def ws(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif s.startswith("--", self.i):
                m = _LONG_OPEN.match(s, self.i + 2)
                if m:
                    end = s.find("]" + m.group(1) + "]", m.end())
                    self.i = n if end < 0 else end + len(m.group(1)) + 2
                else:
                    nl = s.find("\n", self.i)
                    self.i = n if nl < 0 else nl + 1
            else:
                break

    def file(self) -> dict:
        out = {}
        while True:
            self.ws()
            if self.i >= self.n:
                return out
            m = _NAME.match(self.s, self.i)
            if not m:
                self.error("expected variable name")
            self.i = m.end()
            self.ws()
            if self.s[self.i:self.i + 1] != "=":
                self.error("expected '='")
            self.i += 1
            out[m.group(0)] = self.value()

    def value(self):
        self.ws()
        if self.i >= self.n:
            self.error("unexpected end of file")
        c = self.s[self.i]
        if c == "{":
            return self.table()
        if c in "\"'":
            return self.string(c)
        if c == "[":
            m = _LONG_OPEN.match(self.s, self.i)
            if m:
                close = "]" + m.group(1) + "]"
                end = self.s.find(close, m.end())
                if end < 0:
                    self.error("unterminated long string")
                text = self.s[m.end():end]
                self.i = end + len(close)
                return _fix_bytes(text[1:] if text.startswith("\n") else text)
        m = _NUMBER.match(self.s, self.i)
        if m:
            self.i = m.end()
            t = m.group(0)
            if "x" in t or "X" in t:
                return int(t, 16)
            if any(ch in t for ch in ".eE"):
                f = float(t)
                return int(f) if f.is_integer() and abs(f) < 2**53 and "e" not in t.lower() else f
            return int(t)
        m = _NAME.match(self.s, self.i)
        if m:
            word = m.group(0)
            self.i = m.end()
            if word == "true":
                return True
            if word == "false":
                return False
            if word == "nil":
                return None
            if word in ("inf", "math"):  # rare: math.huge
                return float("inf")
            self.error(f"unexpected word {word!r}")
        self.error(f"unexpected character {c!r}")

    def string(self, quote):
        s = self.s
        self.i += 1
        parts = []
        start = self.i
        while True:
            j = self.i
            while j < self.n and s[j] != quote and s[j] != "\\":
                j += 1
            if j >= self.n:
                self.error("unterminated string")
            parts.append(s[start:j])
            if s[j] == quote:
                self.i = j + 1
                return _fix_bytes("".join(parts))
            # escape
            e = s[j + 1]
            if e.isdigit():
                k = j + 1
                while k < j + 4 and k < self.n and s[k].isdigit():
                    k += 1
                parts.append(chr(int(s[j + 1:k])))
                self.i = k
            elif e == "x":
                parts.append(chr(int(s[j + 2:j + 4], 16)))
                self.i = j + 4
            elif e == "z":
                k = j + 2
                while k < self.n and s[k] in " \t\r\n":
                    k += 1
                self.i = k
            elif e == "\r" and s[j + 2:j + 3] == "\n":
                parts.append("\n")
                self.i = j + 3
            else:
                parts.append(_ESCAPES.get(e, e))
                self.i = j + 2
            start = self.i

    def table(self):
        self.i += 1
        d = {}
        auto = 1
        s = self.s
        while True:
            self.ws()
            if self.i >= self.n:
                self.error("unterminated table")
            c = s[self.i]
            if c == "}":
                self.i += 1
                break
            if c == "[" and not _LONG_OPEN.match(s, self.i):
                self.i += 1
                key = self.value()
                self.ws()
                if s[self.i:self.i + 1] != "]":
                    self.error("expected ']'")
                self.i += 1
                self.ws()
                if s[self.i:self.i + 1] != "=":
                    self.error("expected '='")
                self.i += 1
                d[key] = self.value()
            else:
                m = _NAME.match(s, self.i)
                if m and m.group(0) not in ("true", "false", "nil"):
                    save = self.i
                    self.i = m.end()
                    self.ws()
                    if s[self.i:self.i + 1] == "=" and s[self.i:self.i + 2] != "==":
                        self.i += 1
                        d[m.group(0)] = self.value()
                    else:
                        self.i = save
                        d[auto] = self.value()
                        auto += 1
                else:
                    d[auto] = self.value()
                    auto += 1
            self.ws()
            if s[self.i:self.i + 1] in (",", ";"):
                self.i += 1
        if d and all(isinstance(k, int) for k in d) and sorted(d) == list(range(1, len(d) + 1)):
            return [d[k] for k in range(1, len(d) + 1)]
        return d


def _fix_bytes(text: str) -> str:
    """The file is decoded as latin-1 so byte escapes work; turn it back into UTF-8 text."""
    try:
        return text.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return text


def load_savedvariables(path) -> dict:
    with open(path, "rb") as fh:
        raw = fh.read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    text = raw.decode("latin-1")
    return _Parser(text).file()


def loads(text: str) -> dict:
    return _Parser(text.encode("utf-8").decode("latin-1")).file()


# ---------------------------------------------------------------- writer
def _lua_str(s: str) -> str:
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
    return '"' + s + '"'


def to_lua(value, indent: int = 0) -> str:
    pad = "  " * (indent + 1)
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(round(value, 6))
    if isinstance(value, str):
        return _lua_str(value)
    if isinstance(value, (list, tuple)):
        if not value:
            return "{}"
        inner = ",\n".join(pad + to_lua(v, indent + 1) for v in value)
        return "{\n" + inner + ",\n" + "  " * indent + "}"
    if isinstance(value, dict):
        if not value:
            return "{}"
        rows = []
        for k, v in value.items():
            if isinstance(k, str) and _NAME.fullmatch(k):
                key = k
            else:
                key = "[" + to_lua(k) + "]"
            rows.append(f"{pad}{key} = {to_lua(v, indent + 1)}")
        return "{\n" + ",\n".join(rows) + ",\n" + "  " * indent + "}"
    raise TypeError(f"cannot write {type(value).__name__} to Lua")
