"""FlipForever desktop app (tkinter, no extra installs needed)."""
from __future__ import annotations

import datetime as dt
import os
import re
import subprocess
import threading
import time
import tkinter as tk
import traceback
from tkinter import filedialog, messagebox, ttk

import sys
import webbrowser

from . import demo, engine, i18n, store, updater
from .i18n import tr
from .engine import money
from .version import GITHUB_REPO, VERSION


def _read_doc(name):
    try:
        return (store.APP_DIR / name).read_text(encoding="utf-8")
    except OSError:
        return f"({name} not found)"

BG = "#14171c"
PANEL = "#1c2027"
CARD = "#232833"
FG = "#e6e8eb"
MUTED = "#8b93a1"
ACCENT = "#3ddc97"
GOLD = "#f2c14e"
RED = "#ff6b6b"
STRIPE = "#20252d"
BLUE = "#6aa9ff"
FONT = ("Segoe UI", 10)
FONT_B = ("Segoe UI Semibold", 10)


def ago(t):
    if not t:
        return "never"
    s = int(time.time() - t)
    if s < 90:
        return "just now"
    if s < 5400:
        return f"{s // 60} min ago"
    if s < 172800:
        return f"{s // 3600} h ago"
    return f"{s // 86400} days ago"


def tr_padded(text: str) -> str:
    """tr() for labels with spacing around them ("   search:")."""
    core = text.strip()
    if not core:
        return text
    start = text.index(core)
    return text[:start] + tr(core) + text[start + len(core):]


def translate_widgets(widget) -> int:
    """Translate the fixed texts of every widget below `widget`: labels, buttons, checkboxes and
    table headings. Texts set later from code (status lines, numbers) are not touched."""
    n = 0
    try:
        text = widget.cget("text")
    except (tk.TclError, AttributeError):
        text = None
    if isinstance(text, str) and text:
        new = tr_padded(text)
        if new != text:
            widget.configure(text=new)
            n += 1
    if isinstance(widget, ttk.Treeview):
        for col in widget["columns"]:
            head = widget.heading(col, "text")
            if head and tr(head) != head:
                widget.heading(col, text=tr(head))
                n += 1
    for child in widget.winfo_children():
        n += translate_widgets(child)
    return n


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"FlipForever {VERSION} - by Alix")
        self.geometry("1180x760")
        self.minsize(980, 620)
        self.configure(bg=BG)
        try:
            self.iconbitmap(str(store.APP_DIR / "flipforever.ico"))
        except (tk.TclError, OSError):
            pass
        self.settings = store.Settings.load()
        i18n.set_language(self.settings.language)
        self._restore_window()
        self.protocol("WM_DELETE_WINDOW", self._on_close)
        self.con = store.connect()
        self.realm = None
        self.model, self.ledger, self.learned, self.deals = {}, None, None, []
        self.trends = {}
        self.last_mtime = 0
        self._style()
        self._build()
        self._first_run()
        self.refresh()
        self.after(3000, self._watch)
        self.after(1500, self._startup_updates)

    # ------------------------------------------------------------- window size/position
    def _restore_window(self):
        """Open where you left it - unless that spot is off-screen now (monitor unplugged)."""
        m = re.fullmatch(r"(\d+)x(\d+)([+-]-?\d+)([+-]-?\d+)", self.settings.window or "")
        if m:
            w, h, x, y = int(m[1]), int(m[2]), int(m[3]), int(m[4])
            sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
            if w >= 600 and h >= 400 and -w // 2 < x < sw - 100 and 0 <= y < sh - 100:
                self.geometry(f"{w}x{h}+{x}+{y}")
        if self.settings.window_zoomed:
            try:
                self.state("zoomed")
            except tk.TclError:
                pass

    def _on_close(self):
        try:
            zoomed = self.state() == "zoomed"
            self.settings.window_zoomed = zoomed
            if not zoomed and self.state() == "normal":
                self.settings.window = self.geometry()
            self.settings.save()
        except (tk.TclError, OSError):
            pass
        self.destroy()

    def _language_changed(self):
        name = self.lang_var.get()
        code = next((c for c, n in i18n.LANGUAGES.items() if n == name), "enUS")
        self.settings.language = code
        self.settings.save()
        self.status(f"{name}: " + i18n.TRANSLATIONS.get(code, {}).get(
            "Language changes apply after restarting the app.", "Language changes apply after restarting the app."))

    # ------------------------------------------------------------- styling
    def _style(self):
        st = ttk.Style(self)
        st.theme_use("clam")
        st.configure(".", background=BG, foreground=FG, fieldbackground=PANEL, font=FONT, bordercolor=PANEL)
        st.configure("TFrame", background=BG)
        st.configure("Card.TFrame", background=CARD)
        st.configure("TLabel", background=BG, foreground=FG)
        st.configure("Muted.TLabel", foreground=MUTED)
        st.configure("Card.TLabel", background=CARD, foreground=MUTED)
        st.configure("CardValue.TLabel", background=CARD, foreground=FG, font=("Segoe UI Semibold", 17))
        st.configure("Title.TLabel", font=("Segoe UI Semibold", 16))
        st.configure("H.TLabel", font=("Segoe UI Semibold", 12))
        st.configure("TNotebook", background=BG, borderwidth=0)
        st.configure("TNotebook.Tab", background=PANEL, foreground=MUTED, padding=(9, 7), font=FONT_B)
        st.map("TNotebook.Tab", background=[("selected", CARD)], foreground=[("selected", FG)])
        st.configure("TButton", background=CARD, foreground=FG, padding=(12, 6), borderwidth=0)
        st.map("TButton", background=[("active", "#2d3441")])
        st.configure("Accent.TButton", background=ACCENT, foreground="#08140f", font=FONT_B)
        st.map("Accent.TButton", background=[("active", "#5fe8ac")])
        st.configure("Treeview", background=PANEL, fieldbackground=PANEL, foreground=FG, rowheight=26, borderwidth=0)
        st.configure("Treeview.Heading", background=CARD, foreground=MUTED, font=FONT_B, borderwidth=0)
        st.map("Treeview", background=[("selected", "#2f4a3f")])
        st.configure("TCheckbutton", background=BG, foreground=FG)
        st.configure("TCombobox", fieldbackground=PANEL, background=CARD, foreground=FG, arrowcolor=FG,
                     bordercolor=CARD, lightcolor=PANEL, darkcolor=PANEL)
        st.map("TCombobox", fieldbackground=[("readonly", PANEL)], foreground=[("readonly", FG)],
               selectbackground=[("readonly", PANEL)], selectforeground=[("readonly", FG)])
        st.configure("TNotebook", bordercolor=CARD, lightcolor=BG, darkcolor=BG)
        st.layout("TNotebook", [("Notebook.client", {"sticky": "nswe"})])
        self.option_add("*TCombobox*Listbox.background", PANEL)
        self.option_add("*TCombobox*Listbox.foreground", FG)
        st.configure("TEntry", fieldbackground=PANEL, foreground=FG, insertcolor=FG)
        st.configure("TSpinbox", fieldbackground=PANEL, foreground=FG, arrowcolor=FG)
        # 2.4: sidebar navigation instead of a long tab row (the notebook keeps the pages, its tabs are hidden)
        st.configure("Pages.TNotebook", background=BG, borderwidth=0)
        st.layout("Pages.TNotebook.Tab", [])
        st.configure("Side.TFrame", background=PANEL)
        st.configure("Side.TLabel", background=PANEL, foreground=MUTED, font=("Segoe UI Semibold", 8))
        st.configure("Nav.TButton", background=PANEL, foreground=MUTED, anchor="w", padding=(14, 7), font=FONT,
                     borderwidth=0, focusthickness=0)
        st.map("Nav.TButton", background=[("active", CARD)], foreground=[("active", FG)])
        st.configure("NavOn.TButton", background=CARD, foreground=FG, anchor="w", padding=(14, 7), font=FONT_B,
                     borderwidth=0, focusthickness=0)
        st.map("NavOn.TButton", background=[("active", CARD)])
        st.configure("Page.TLabel", font=("Segoe UI Semibold", 15), foreground=FG)
        st.configure("PageSub.TLabel", foreground=MUTED)

    # ------------------------------------------------------------- layout
    def _build(self):
        top = ttk.Frame(self, padding=(16, 12))
        top.pack(fill="x")
        ttk.Label(top, text="FlipForever", style="Title.TLabel", foreground=ACCENT).pack(side="left")
        ttk.Label(top, text="  " + tr("realm:"), style="Muted.TLabel").pack(side="left", padx=(18, 4))
        self.realm_var = tk.StringVar()
        self.realm_box = ttk.Combobox(top, textvariable=self.realm_var, state="readonly", width=22)
        self.realm_box.pack(side="left")
        self.realm_box.bind("<<ComboboxSelected>>", lambda e: self._realm_changed())
        ttk.Label(top, text="  " + tr("character:"), style="Muted.TLabel").pack(side="left", padx=(14, 4))
        self.char_var = tk.StringVar()
        self.char_box = ttk.Combobox(top, textvariable=self.char_var, state="readonly", width=13)
        self.char_box.pack(side="left")
        self.char_box.bind("<<ComboboxSelected>>", lambda e: self._char_changed())
        ttk.Label(top, text="  " + tr("budget:"), style="Muted.TLabel").pack(side="left", padx=(14, 4))
        self.budget_var = tk.StringVar()
        self.budget_entry = ttk.Entry(top, textvariable=self.budget_var, width=7)
        self.budget_entry.pack(side="left")
        self.budget_entry.bind("<Return>", lambda e: self._budget_changed())
        self.budget_entry.bind("<FocusOut>", lambda e: self._budget_changed())
        self.char_gold = tk.StringVar()
        ttk.Label(top, textvariable=self.char_gold, style="Muted.TLabel").pack(side="left", padx=(4, 0))
        ttk.Button(top, text=tr("Build shopping list"), style="Accent.TButton", command=self.build_plan).pack(side="right")
        ttk.Button(top, text=tr("Import"), command=self.import_now).pack(side="right", padx=8)

        self.status_var = tk.StringVar(value="Ready.")
        bar = ttk.Frame(self, padding=(16, 4))
        bar.pack(side="bottom", fill="x")
        ttk.Label(bar, textvariable=self.status_var, style="Muted.TLabel").pack(side="left")

        body = ttk.Frame(self)
        body.pack(fill="both", expand=True)
        self.sidebar = ttk.Frame(body, style="Side.TFrame", width=200, padding=(0, 8))
        self.sidebar.pack(side="left", fill="y")
        self.sidebar.pack_propagate(False)
        content = ttk.Frame(body, padding=(16, 6, 12, 0))
        content.pack(side="left", fill="both", expand=True)
        head = ttk.Frame(content)
        head.pack(fill="x", pady=(0, 6))
        self.page_title = tk.StringVar()
        self.page_sub = tk.StringVar()
        ttk.Label(head, textvariable=self.page_title, style="Page.TLabel").pack(side="left")
        ttk.Label(head, textvariable=self.page_sub, style="PageSub.TLabel").pack(side="left", padx=(12, 0), pady=(5, 0))
        self.nb = ttk.Notebook(content, style="Pages.TNotebook")
        self.nb.pack(fill="both", expand=True, pady=(0, 4))
        self.tab_dash = ttk.Frame(self.nb, padding=14)
        self.tab_deals = ttk.Frame(self.nb, padding=10)
        self.tab_sell = ttk.Frame(self.nb, padding=10)
        self.tab_hist = ttk.Frame(self.nb, padding=10)
        self.tab_learn = ttk.Frame(self.nb, padding=10)
        self.tab_set = ttk.Frame(self.nb, padding=14)
        self.tab_help = ttk.Frame(self.nb, padding=14)
        self.tab_adv = ttk.Frame(self.nb, padding=10)
        self.tab_gather = ttk.Frame(self.nb, padding=10)
        self.tab_about = ttk.Frame(self.nb, padding=14)
        self.tab_dev = ttk.Frame(self.nb, padding=10)
        for tab, name in ((self.tab_dash, "Dashboard"), (self.tab_deals, "Deals"), (self.tab_sell, "Inventory & selling"),
                          (self.tab_hist, "Trade history"), (self.tab_learn, "What it learned"),
                          (self.tab_adv, "Advisor"), (self.tab_gather, "Gathering"),
                          (self.tab_set, "Settings"), (self.tab_help, "How to use"), (self.tab_about, "About & updates"),
                          (self.tab_dev, "Development")):
            self.nb.add(tab, text=name)
        self._build_nav()
        self._build_about()
        self._build_dev()
        self._build_dash()
        self._build_deals()
        self._build_sell()
        self._build_hist()
        self._build_learn()
        self._build_advisor()
        self._build_gather()
        self._build_settings()
        self._build_help()
        if i18n.language() != "enUS":
            translate_widgets(self)

    # sidebar: pages grouped by what you're doing, with a one-line explanation on top of each page
    NAV = (
        ("TRADING", (
            ("tab_dash", "Dashboard", "profit, stock and what to do next"),
            ("tab_deals", "Deals", "everything worth buying, best first"),
            ("tab_sell", "Inventory & selling", "what you hold and the prices the addon posts at"),
            ("tab_hist", "Trade history", "every buy, post, sale and expiry"),
            ("tab_learn", "What it learned", "sell chances, price accuracy and margin tuning"),
        )),
        ("CHARACTER", (
            ("tab_adv", "Advisor", "your build, gear and next steps"),
            ("tab_gather", "Gathering", "gold per hour by zone and resource"),
        )),
        ("APP", (
            ("tab_set", "Settings", "budget, speed rules and your WoW folder"),
            ("tab_help", "How to use", "the short version"),
            ("tab_about", "About & updates", "news, changelog and updates"),
            ("tab_dev", "Development", "this week's plan, test checklist and roadmap"),
        )),
    )

    def _build_nav(self):
        self.nav_buttons = {}
        self.nav_bars = {}
        self.nav_info = {}
        for section, pages in self.NAV:
            ttk.Label(self.sidebar, text=tr(section), style="Side.TLabel").pack(anchor="w", padx=16, pady=(12, 4))
            for attr, label, sub in pages:
                tab = getattr(self, attr)
                row = tk.Frame(self.sidebar, bg=PANEL)
                row.pack(fill="x", padx=(0, 6), pady=1)
                bar = tk.Frame(row, bg=PANEL, width=3)          # accent marker for the open page
                bar.pack(side="left", fill="y")
                b = ttk.Button(row, text=tr(label), style="Nav.TButton", command=lambda t=tab: self.nb.select(t))
                b.pack(side="left", fill="x", expand=True, padx=(3, 0))
                self.nav_buttons[str(tab)] = b
                self.nav_bars[str(tab)] = bar
                self.nav_info[str(tab)] = (tr(label), tr(sub))
        ttk.Label(self.sidebar, text=f"v{VERSION}", style="Side.TLabel").pack(side="bottom", anchor="w", padx=16, pady=8)
        self.nb.bind("<<NotebookTabChanged>>", lambda e: self._nav_changed())
        self._nav_changed()

    def _nav_changed(self):
        cur = self.nb.select()
        for key, b in self.nav_buttons.items():
            b.configure(style="NavOn.TButton" if key == cur else "Nav.TButton")
            self.nav_bars[key].configure(bg=ACCENT if key == cur else PANEL)
        title, sub = self.nav_info.get(cur, ("", ""))
        self.page_title.set(title)
        self.page_sub.set(sub)

    # about & updates
    def add_shortcuts(self, quiet=False):
        try:
            updater.make_shortcuts()
            self.upd_status.set("FlipForever is on your desktop and in the Start menu.")
        except (updater.UpdateError, OSError, subprocess.SubprocessError) as e:
            if not quiet:
                self.upd_status.set(str(e))

    def copy_bug_report(self):
        text = engine.bug_report_text(self.settings, VERSION)
        self.clipboard_clear()
        self.clipboard_append(text)
        self.upd_status.set("Bug report info copied: versions, setup and the addon's last errors. "
                            "Paste it into your report and add what you did and what happened.")

    def _build_about(self):
        f = self.tab_about
        top = ttk.Frame(f)
        top.pack(fill="x")
        ttk.Label(top, text=f"FlipForever {VERSION}", style="Title.TLabel", foreground=ACCENT).pack(side="left")
        ttk.Label(top, text=f"   by Alix  ·  updates from github.com/{GITHUB_REPO}", style="Muted.TLabel").pack(side="left")
        row = ttk.Frame(f)
        row.pack(fill="x", pady=(10, 0))
        self.upd_check_btn = ttk.Button(row, text="Check for updates", style="Accent.TButton", command=self.check_updates)
        self.upd_check_btn.pack(side="left")
        self.upd_install_btn = ttk.Button(row, text="Install update", command=self.install_update, state="disabled")
        self.upd_install_btn.pack(side="left", padx=8)
        ttk.Button(row, text="Open on GitHub", command=lambda: webbrowser.open(f"https://github.com/{GITHUB_REPO}/releases")).pack(side="left")
        ttk.Button(row, text="Copy bug report info", command=self.copy_bug_report).pack(side="left", padx=8)
        ttk.Button(row, text="Add to desktop and Start menu", command=self.add_shortcuts).pack(side="left")
        self.upd_status = tk.StringVar(value="")
        ttk.Label(f, textvariable=self.upd_status, style="Muted.TLabel", wraplength=1100, justify="left").pack(anchor="w", pady=(8, 0))
        opts = ttk.Frame(f)
        opts.pack(fill="x", pady=(10, 0))
        self.auto_upd_var = tk.BooleanVar(value=self.settings.auto_check_updates)
        ttk.Checkbutton(opts, text="Check for updates when the app starts", variable=self.auto_upd_var,
                        command=self._save_update_opts).pack(side="left")
        self.beta_var = tk.BooleanVar(value=self.settings.beta_updates)
        ttk.Checkbutton(opts, text="Get beta versions (for testing)", variable=self.beta_var,
                        command=self._save_update_opts).pack(side="left", padx=(12, 0))
        ttk.Label(opts, text="     GitHub token (only while the repository is private):", style="Muted.TLabel").pack(side="left")
        self.token_var = tk.StringVar(value=self.settings.github_token)
        e = ttk.Entry(opts, textvariable=self.token_var, width=34, show="•")
        e.pack(side="left", padx=6)
        e.bind("<FocusOut>", lambda _e: self._save_update_opts())
        ttk.Button(opts, text="Save", command=self._save_update_opts).pack(side="left")
        panes = ttk.Frame(f)
        panes.pack(fill="both", expand=True, pady=(12, 0))
        panes.columnconfigure(0, weight=1)
        panes.columnconfigure(1, weight=1)
        panes.rowconfigure(1, weight=1)
        ttk.Label(panes, text="Update news", style="H.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(panes, text="Changelog", style="H.TLabel").grid(row=0, column=1, sticky="w", padx=(12, 0))
        self.news_text = tk.Text(panes, bg=PANEL, fg=FG, relief="flat", wrap="word", font=("Segoe UI", 10), padx=12, pady=10)
        self.news_text.grid(row=1, column=0, sticky="nsew")
        self.log_text = tk.Text(panes, bg=PANEL, fg=FG, relief="flat", wrap="word", font=("Segoe UI", 10), padx=12, pady=10)
        self.log_text.grid(row=1, column=1, sticky="nsew", padx=(12, 0))
        for t in (self.news_text, self.log_text):
            t.tag_configure("h1", font=("Segoe UI Semibold", 13), foreground=ACCENT, spacing3=4)
            t.tag_configure("h2", font=("Segoe UI Semibold", 11), foreground=GOLD, spacing1=8)
            t.tag_configure("h3", font=FONT_B, foreground=FG, spacing1=4)
        self._show_markdown(self.news_text, _read_doc("NEWS.md"))
        self._show_markdown(self.log_text, _read_doc("CHANGELOG.md"))
        self._release = None

    # development overview: the weekly board + roadmap the improvement cycles keep up to date
    def _build_dev(self):
        f = self.tab_dev
        top = ttk.Frame(f)
        top.pack(fill="x")
        ttk.Label(top, text="Development overview", style="Title.TLabel", foreground=ACCENT).pack(side="left")
        self.dev_info = tk.StringVar()
        ttk.Label(top, textvariable=self.dev_info, style="Muted.TLabel").pack(side="left", padx=12)
        ttk.Button(top, text="Releases on GitHub",
                   command=lambda: webbrowser.open(f"https://github.com/{GITHUB_REPO}/releases")).pack(side="right")
        ttk.Button(top, text="Refresh", command=self._fill_dev).pack(side="right", padx=8)
        panes = ttk.Frame(f)
        panes.pack(fill="both", expand=True, pady=(10, 0))
        panes.columnconfigure(0, weight=3)
        panes.columnconfigure(1, weight=2)
        panes.rowconfigure(1, weight=1)
        ttk.Label(panes, text="This week's board", style="H.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(panes, text="Test it in game  ·  Roadmap", style="H.TLabel").grid(row=0, column=1, sticky="w", padx=(12, 0))
        self.board_text = tk.Text(panes, bg=PANEL, fg=FG, relief="flat", wrap="word", font=("Segoe UI", 10), padx=12, pady=10)
        self.board_text.grid(row=1, column=0, sticky="nsew")
        self.road_text = tk.Text(panes, bg=PANEL, fg=FG, relief="flat", wrap="word", font=("Segoe UI", 10), padx=12, pady=10)
        self.road_text.grid(row=1, column=1, sticky="nsew", padx=(12, 0))
        for t in (self.board_text, self.road_text):
            t.tag_configure("h1", font=("Segoe UI Semibold", 13), foreground=ACCENT, spacing3=4)
            t.tag_configure("h2", font=("Segoe UI Semibold", 11), foreground=GOLD, spacing1=10, spacing3=2)
            t.tag_configure("h3", font=FONT_B, foreground=FG, spacing1=4)
            t.tag_configure("row", lmargin1=8, lmargin2=24)
            t.tag_configure("head", font=FONT_B, foreground=MUTED, lmargin1=8)
        self._fill_dev()

    def _fill_dev(self):
        board = _read_doc("docs/WEEKLY_BOARD.md")
        road = _read_doc("docs/IN_GAME_TEST.md") + "\n\n" + _read_doc("docs/ROADMAP.md")
        self._show_markdown(self.board_text, board)
        self._show_markdown(self.road_text, road)
        problems = sum(1 for l in board.splitlines() if l.startswith("| P"))
        open_high = sum(1 for l in board.splitlines() if l.startswith("| P") and "| High |" in l)
        self.dev_info.set(f"version {VERSION}  ·  {problems} open issues ({open_high} high priority)  ·  "
                          f"updated with every release")

    def _show_markdown(self, widget, md):
        widget.configure(state="normal")
        widget.delete("1.0", "end")
        for line in md.splitlines():
            line = line.replace("**", "").replace("*", "")
            if line.startswith("|"):
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                if all(set(c) <= set("-: ") for c in cells):
                    continue  # table divider
                is_head = widget.index("end-1c").endswith(".0") and getattr(widget, "_in_table", False) is False
                widget._in_table = True
                widget.insert("end", "   ·   ".join(cells) + "\n", "head" if is_head else "row")
                continue
            widget._in_table = False
            if line.startswith("### "):
                widget.insert("end", line[4:] + "\n", "h3")
            elif line.startswith("## "):
                widget.insert("end", line[3:] + "\n", "h2")
            elif line.startswith("# "):
                widget.insert("end", line[2:] + "\n", "h1")
            else:
                widget.insert("end", line + "\n")
        widget.configure(state="disabled")

    def _save_update_opts(self):
        self.settings.auto_check_updates = bool(self.auto_upd_var.get())
        self.settings.beta_updates = bool(self.beta_var.get())
        self.settings.github_token = self.token_var.get().strip()
        self.settings.save()

    def check_updates(self, quiet=False):
        self.upd_status.set("Checking GitHub...")
        self.upd_check_btn.configure(state="disabled")
        token = self.settings.github_token
        beta = self.settings.beta_updates

        def work():
            try:
                rel = updater.latest(token, beta=beta)
                self.after(0, lambda: self._update_result(rel, None, quiet))
            except updater.UpdateError as e:
                self.after(0, lambda: self._update_result(None, str(e), quiet))
        threading.Thread(target=work, daemon=True).start()

    def _update_result(self, rel, error, quiet):
        self.upd_check_btn.configure(state="normal")
        if error:
            self.upd_status.set(error)
            return
        self._release = rel
        if updater.is_newer(rel.version):
            kind = "Beta version" if updater.is_beta(rel.version) else "Version"
            self.upd_status.set(f"{kind} {rel.version} is available (released {rel.published}). You have {VERSION}.")
            self.upd_install_btn.configure(state="normal")
            self._show_markdown(self.news_text, rel.notes or "(no release notes)")
            if quiet and messagebox.askyesno("FlipForever update", f"FlipForever {rel.version} is available "
                                             f"(you have {VERSION}).\n\nInstall it now? The app restarts; your data stays."):
                self.install_update()
        else:
            self.upd_status.set(f"You're up to date ({VERSION}).")
            self.upd_install_btn.configure(state="disabled")

    def install_update(self):
        rel = self._release
        if not rel:
            return
        self.upd_install_btn.configure(state="disabled")
        self.upd_check_btn.configure(state="disabled")
        token = self.settings.github_token

        def progress(frac):
            self.after(0, lambda: self.upd_status.set(f"Downloading {rel.version}... {frac:.0%}"))

        def work():
            try:
                new_dir = updater.install(rel, token, progress)
                self.after(0, lambda: self._apply_update(new_dir, rel))
            except updater.UpdateError as e:
                self.after(0, lambda: (self.upd_status.set(str(e)), self.upd_check_btn.configure(state="normal")))
        threading.Thread(target=work, daemon=True).start()

    def _apply_update(self, new_dir, rel):
        try:
            updater.apply_and_restart(new_dir)
        except updater.UpdateError as e:
            self.upd_status.set(str(e))
            self.upd_check_btn.configure(state="normal")
            return
        self.upd_status.set(f"Installing {rel.version} - the app restarts in a moment...")
        self.after(600, self.destroy)

    def _startup_updates(self):
        """After an app update: bring the WoW addon up to the bundled version. Then (optionally) check GitHub."""
        try:
            addon = self.settings.addon_path()
            bundled = updater.bundled_addon_version()
            installed = updater.installed_addon_version(addon)
            if installed and bundled and updater.is_newer(bundled, installed):
                engine.install_addon(self.settings)
                self.status(f"WoW addon updated {installed} -> {bundled}. Restart WoW (or /reload) to load it.")
        except Exception:  # noqa: BLE001
            traceback.print_exc()
        # first start of the program: offer a desktop and Start menu shortcut (once)
        if getattr(sys, "frozen", False) and not self.settings.shortcut_asked:
            self.settings.shortcut_asked = True
            self.settings.save()
            if messagebox.askyesno("FlipForever", "Add FlipForever to your desktop and Start menu?\n\n"
                                   "Keep this FlipForever folder where it is: the app updates itself there."):
                self.add_shortcuts(quiet=True)
        if "--updated" in sys.argv:
            self.nb.select(self.tab_about)
            messagebox.showinfo("FlipForever", f"Updated to FlipForever {VERSION}!\n\nSee 'About & updates' for what's new.")
        elif self.settings.auto_check_updates:
            self.check_updates(quiet=True)

    # advisor (what the in-game advisor recommends, per character)
    def _build_advisor(self):
        self.adv_info = tk.StringVar(value="")
        ttk.Label(self.tab_adv, textvariable=self.adv_info, style="Muted.TLabel", wraplength=1100,
                  justify="left").pack(anchor="w", pady=(0, 8))
        self.adv_text = tk.Text(self.tab_adv, bg=PANEL, fg=FG, relief="flat", wrap="word", font=("Segoe UI", 11),
                                padx=16, pady=12)
        self.adv_text.pack(fill="both", expand=True)
        self.adv_text.tag_configure("h", font=("Segoe UI Semibold", 13), foreground=ACCENT, spacing1=8, spacing3=4)
        self.adv_text.tag_configure("muted", foreground=MUTED)
        self.adv_text.tag_configure("sub", font=FONT_B, foreground=GOLD)

    def _fill_advisor(self):
        t = self.adv_text
        t.configure(state="normal")
        t.delete("1.0", "end")
        chars = self.chars or {}
        names = [self.char] if self.char else sorted(chars)
        self.adv_info.set("In game: /ff guide opens the advisor. It detects your race and class, lets you pick the build "
                          "to follow (< > buttons), and re-checks after every level-up, quest, gear change and talent point. "
                          "This page shows what it said the last time the game saved (/reload or log out).")
        shown = 0
        for name in names:
            adv = (chars.get(name) or {}).get("advisor")
            if not isinstance(adv, dict):
                continue
            shown += 1
            t.insert("end", f"{name} - level {adv.get('level', '?')} {adv.get('race', '')} {adv.get('className', '')}\n", "h")
            t.insert("end", f"Following: {adv.get('build') or '-'}   ·   {adv.get('source') or ''}   ·   "
                            f"checked {ago(adv.get('t'))}\n", "muted")
            steps = adv.get("steps") or []
            steps = steps if isinstance(steps, list) else list(steps.values())
            for i, s in enumerate(steps[:12], 1):
                t.insert("end", f"  {i}. {s}\n")
            gear = engine._as_list(adv.get("gear"))
            if gear:
                t.insert("end", "\n  Auction house upgrades (Gear tab in game)\n", "sub")
                for g in gear:
                    better = f"+{g['pct']}%" if g.get("pct") is not None else "new slot"
                    t.insert("end", f"    {g.get('slot', '')}: {g.get('name', '?')}  {money(g.get('price'), True)}  ({better})\n")
            auc = adv.get("auctions")
            if isinstance(auc, dict):
                n = auc.get("n") or 0
                head = (f"{auc.get('up', 0)} up, {n} undercut" if n else f"{auc.get('up', 0)} up, all still the cheapest")
                t.insert("end", f"\n  Your auctions ({head}, checked {ago(auc.get('t'))})\n", "sub")
                for u in engine._as_list(auc.get("undercut")):
                    t.insert("end", f"    {u.get('name', '?')} x{u.get('qty', 1)}: yours {money(u.get('mine'), True)}, "
                                    f"now {money(u.get('now'), True)}\n")
            crafts = engine._as_list(adv.get("crafts"))
            if crafts:
                t.insert("end", "\n  Profitable crafts (profession planner)\n", "sub")
                for c in crafts:
                    t.insert("end", f"    {c.get('crafts', 1)}x {c.get('name', '?')} ({c.get('prof', '')}): "
                                    f"+{money(c.get('profit'), True)} each, ~{c.get('perDay', '?')}/day\n")
            t.insert("end", "\n")
        if not shown:
            t.insert("end", "Nothing yet - log in with the character, let the addon check it once, then /reload.", "muted")
        t.configure(state="disabled")

    # gathering (the merged Ore Farmer module)
    def _build_gather(self):
        ttk.Label(self.tab_gather, text="Your gathering runs (in game: /ore or /ff gather). Gold per hour appears once a "
                  "zone has 10+ nodes and 10+ minutes of farming. Resource values use FlipForever's own price scans.",
                  style="Muted.TLabel", wraplength=1100, justify="left").pack(anchor="w", pady=(0, 8))
        cols = ("Zone", "Spots known", "Nodes gathered", "Minutes farmed", "Loot value", "Gold / hour")
        frame, self.gather_tree = self._tree(self.tab_gather, cols, (260, 100, 120, 120, 120, 120), height=8)
        frame.pack(fill="x")
        ttk.Label(self.tab_gather, text="Value per node (from what you actually looted)", style="H.TLabel").pack(anchor="w", pady=(12, 4))
        cols2 = ("Resource", "Nodes", "Items looted", "Value per node")
        frame2, self.res_tree = self._tree(self.tab_gather, cols2, (260, 100, 120, 160), height=10)
        frame2.pack(fill="both", expand=True)

    def _fill_gather(self):
        g = engine.gathering(self.con, self.model)
        rows = []
        for z in g["zones"]:
            rows.append(((z["zone"], z["spots"], z["nodes"], f"{z['minutes']:.0f}", money(z["value"], True),
                          money(z["rate"], True) if z["rate"] else "need more data"),
                         (z["zone"].lower(), z["spots"], z["nodes"], z["minutes"], z["value"], z["rate"] or 0),
                         "deal" if z["rate"] else None))
        self._fill(self.gather_tree, rows)
        rows2 = []
        for r in g["resources"]:
            rows2.append(((r["resource"], r["visits"], r["items"],
                           money(r["per_visit"], True) + ("" if r["priced"] else " (some items unpriced)")),
                          (r["resource"].lower(), r["visits"], r["items"], r["per_visit"]), None))
        self._fill(self.res_tree, rows2)

    def _tree(self, parent, cols, widths, height=18):
        frame = ttk.Frame(parent)
        tree = ttk.Treeview(frame, columns=[c for c in cols], show="headings", height=height)
        for c, w in zip(cols, widths):
            tree.heading(c, text=c, command=lambda c=c, t=tree: self._sort(t, c))
            tree.column(c, width=w, anchor="w" if w >= 160 else "e", stretch=w >= 160)
        sb = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
        tree.configure(yscrollcommand=sb.set)
        tree.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")
        tree.tag_configure("deal", foreground=ACCENT)
        tree.tag_configure("bad", foreground=RED)
        tree.tag_configure("muted", foreground=MUTED)
        tree.tag_configure("starter", foreground=GOLD)
        tree.tag_configure("odd", background=STRIPE)
        tree._sortkeys = {}
        return frame, tree

    @staticmethod
    def _stripe(tree):
        """Alternate row shading (kept correct after sorting)."""
        for i, iid in enumerate(tree.get_children("")):
            tags = [t for t in tree.item(iid, "tags") if t != "odd"]
            if i % 2:
                tags.append("odd")
            tree.item(iid, tags=tags)

    def _sort(self, tree, col):
        rev = getattr(tree, "_rev", {}).get(col, False)
        keys = tree._sortkeys

        def key(iid):
            k = keys.get((iid, col))
            if k is not None:
                return (0, k)
            v = tree.set(iid, col)
            return (1, v.lower())
        items = sorted(tree.get_children(""), key=key, reverse=rev)
        for i, iid in enumerate(items):
            tree.move(iid, "", i)
        tree._rev = {col: not rev}
        self._stripe(tree)

    def _fill(self, tree, rows):
        tree.delete(*tree.get_children())
        tree._sortkeys = {}
        cols = tree["columns"]
        for row in rows:
            values, sortvals, tag = row
            iid = tree.insert("", "end", values=values, tags=(tag,) if tag else ())
            for c, s in zip(cols, sortvals):
                if s is not None:
                    tree._sortkeys[(iid, c)] = s
        self._stripe(tree)

    # dashboard
    def _build_dash(self):
        cards = ttk.Frame(self.tab_dash)
        cards.pack(fill="x")
        self.cards = {}
        self.card_values = {}
        for i, (key, label, accent) in enumerate((("realized", "Realized profit", ACCENT), ("week", "Last 7 days", ACCENT),
                                                  ("held", "Stock: cost / value", GOLD), ("st", "Sell-through", BLUE),
                                                  ("scan", "Last scan", BLUE), ("tracked", "Items tracked", MUTED))):
            outer = tk.Frame(cards, bg=CARD)
            outer.grid(row=0, column=i, sticky="nsew", padx=(0 if i == 0 else 8, 0))
            cards.columnconfigure(i, weight=1)
            tk.Frame(outer, bg=accent, height=3).pack(fill="x")      # colour strip: what kind of number this is
            f = ttk.Frame(outer, style="Card.TFrame", padding=(14, 8, 14, 10))
            f.pack(fill="both", expand=True)
            ttk.Label(f, text=label, style="Card.TLabel").pack(anchor="w")
            v = tk.StringVar(value="-")
            lbl = ttk.Label(f, textvariable=v, style="CardValue.TLabel")
            lbl.pack(anchor="w", pady=(4, 0))
            self.cards[key] = v
            self.card_values[key] = lbl
        mid = ttk.Frame(self.tab_dash)
        mid.pack(fill="both", expand=True, pady=(14, 0))
        left = ttk.Frame(mid)
        left.pack(side="left", fill="both", expand=True)
        ttk.Label(left, text="Profit over time", style="H.TLabel").pack(anchor="w")
        self.chart = tk.Canvas(left, bg=PANEL, highlightthickness=0, height=300)
        self.chart.pack(fill="both", expand=True, pady=(6, 0))
        self.chart.bind("<Configure>", lambda e: self._draw_chart())
        # profit per character (shown when more than one character trades)
        self.char_frame = ttk.Frame(left)
        ttk.Label(self.char_frame, text="Profit per character", style="H.TLabel").pack(anchor="w", pady=(12, 4))
        frame, self.char_tree = self._tree(self.char_frame, ("Character", "Realized profit", "Last 7 days", "Stock (cost)", "Sales", "Bought"),
                                           (180, 120, 110, 110, 70, 80), height=4)
        frame.pack(fill="x")
        right = ttk.Frame(mid, width=360)
        right.pack(side="left", fill="y", padx=(14, 0))
        right.pack_propagate(False)
        ttk.Label(right, text="Next steps", style="H.TLabel").pack(anchor="w")
        self.steps = tk.Text(right, bg=PANEL, fg=FG, relief="flat", wrap="word", font=FONT, padx=12, pady=10, height=14)
        self.steps.pack(fill="both", expand=True, pady=(6, 0))
        self.steps.tag_configure("done", foreground=MUTED, overstrike=True)
        self.steps.tag_configure("todo", foreground=FG)
        self.steps.tag_configure("now", foreground=GOLD, font=FONT_B)
        ttk.Label(right, text="Best deals right now", style="H.TLabel").pack(anchor="w", pady=(12, 0))
        self.top_deals = tk.Text(right, bg=PANEL, fg=FG, relief="flat", wrap="none", font=FONT, padx=12, pady=8, height=7)
        self.top_deals.pack(fill="x", pady=(6, 0))

    def _fill_char_profit(self, realm):
        """Profit per character on the Dashboard; only shown when more than one character trades."""
        rows = engine.profit_by_char(self.con, realm) if realm else []
        if len(rows) < 2:
            self.char_frame.pack_forget()
            return
        self.char_frame.pack(fill="x")
        self._fill(self.char_tree, [
            ((r["char"], money(r["realized"], True), money(r["week"], True), money(r["held_cost"], True), r["sold"], r["bought"]),
             (r["char"].lower(), r["realized"], r["week"], r["held_cost"], r["sold"], r["bought"]),
             "deal" if r["realized"] > 0 else "bad" if r["realized"] < 0 else None)
            for r in rows])

    def _draw_chart(self):
        c = self.chart
        c.delete("all")
        w, h = c.winfo_width(), c.winfo_height()
        if not self.ledger or not self.ledger.timeline:
            c.create_text(w / 2, h / 2, text="Your profit appears here once you've sold something.", fill=MUTED, font=FONT)
            return
        pts, total = [], 0
        for t, p, _ in sorted(self.ledger.timeline):
            total += p
            pts.append((t, total))
        t0, t1 = pts[0][0], max(pts[-1][0], pts[0][0] + 1)
        lo, hi = min(0, min(v for _, v in pts)), max(1, max(v for _, v in pts))
        pad_l, pad_r, pad_t, pad_b = 70, 16, 16, 28

        def xy(t, v):
            return (pad_l + (t - t0) / (t1 - t0) * (w - pad_l - pad_r),
                    pad_t + (1 - (v - lo) / (hi - lo)) * (h - pad_t - pad_b))
        for k in range(5):
            v = lo + (hi - lo) * k / 4
            _, y = xy(t0, v)
            c.create_line(pad_l, y, w - pad_r, y, fill="#262c36")
            c.create_text(pad_l - 8, y, text=money(v, short=True), fill=MUTED, anchor="e", font=("Segoe UI", 8))
        for k in range(4):
            t = t0 + (t1 - t0) * k / 3
            x, _ = xy(t, lo)
            c.create_text(x, h - 12, text=dt.datetime.fromtimestamp(t).strftime("%b %d"), fill=MUTED, font=("Segoe UI", 8))
        _, y0 = xy(t0, 0)
        c.create_line(pad_l, y0, w - pad_r, y0, fill="#3a4250")
        line = []
        prev = None
        for t, v in pts:
            x, y = xy(t, v)
            if prev:
                line += [x, prev[1]]
            line += [x, y]
            prev = (x, y)
        poly = [pad_l, y0] + line + [line[-2], y0]
        c.create_polygon(poly, fill="#1f3b31", outline="")
        if len(line) >= 4:
            c.create_line(line, fill=ACCENT, width=2)
        x, y = line[-2], line[-1]
        c.create_oval(x - 4, y - 4, x + 4, y + 4, fill=ACCENT, outline="")

    # deals
    def _build_deals(self):
        top = ttk.Frame(self.tab_deals)
        top.pack(fill="x", pady=(0, 8))
        self.only_deals = tk.BooleanVar(value=True)
        ttk.Checkbutton(top, text="Only show buy-now deals", variable=self.only_deals, command=self._fill_deals).pack(side="left")
        self.fast_only = tk.BooleanVar(value=False)
        ttk.Checkbutton(top, text="Fast sellers only", variable=self.fast_only,
                        command=self._fill_deals).pack(side="left", padx=(12, 0))
        ttk.Label(top, text="   min. profit/unit (silver):", style="Muted.TLabel").pack(side="left")
        self.min_profit = tk.StringVar()
        ttk.Entry(top, textvariable=self.min_profit, width=6).pack(side="left", padx=4)
        self.min_profit.trace_add("write", lambda *a: self._fill_deals())
        ttk.Label(top, text="   search:", style="Muted.TLabel").pack(side="left")
        self.deal_filter = tk.StringVar()
        e = ttk.Entry(top, textvariable=self.deal_filter, width=24)
        e.pack(side="left", padx=4)
        self.deal_filter.trace_add("write", lambda *a: self._fill_deals())
        ttk.Button(top, text="Never buy selected", command=self._blacklist_selected).pack(side="right")
        self.deal_info = tk.StringVar()
        ttk.Label(self.tab_deals, textvariable=self.deal_info, style="Muted.TLabel", wraplength=1100,
                  justify="left").pack(anchor="w", pady=(0, 6))
        cols = ("Item", "Now", "7-day trend", "Fair value", "Max buy", "Profit/unit", "ROI", "Sells/day", "Sells in",
                "Sell chance", "Buy qty", "Confidence", "Note")
        widths = (190, 85, 80, 85, 85, 85, 55, 70, 70, 80, 60, 80, 200)
        frame, self.deal_tree = self._tree(self.tab_deals, cols, widths)
        frame.pack(fill="both", expand=True)
        self.deal_tree.bind("<Double-1>", lambda e: self._show_item(self.deal_tree))

    def _fill_deals(self):
        rows = []
        n_deals = sum(1 for d in self.deals if d.is_deal)
        try:
            min_profit = max(0, round(float(self.min_profit.get().replace(",", ".") or 0) * 100))
        except ValueError:
            min_profit = 0
        shown = engine.filter_deals(self.deals, self.only_deals.get(), self.fast_only.get(), min_profit,
                                    self.deal_filter.get())
        for d in shown:
            tr = self.trends.get(d.id)
            trend = engine.trend_text(tr)
            if d.starter:
                rows.append(((d.name, money(d.cur), trend, money(d.market), "live", "live", "", "-", "?",
                              f"{d.p_sell:.0%}", "auto", "new", d.reason),
                             (d.name.lower(), d.cur, tr or 0, d.market, 0, 0, 0, 0, 999, d.p_sell, 0, 0, None), "starter"))
                continue
            vol = "-" if d.vol_day is None else f"{d.vol_day:.1f}"
            if d.est_days is None:
                speed = "?"
            elif d.est_days < 1:
                speed = f"~{max(1, round(d.est_days * 24))} h"
            else:
                speed = f"~{d.est_days:.1f} d"
            rows.append(((d.name, money(d.cur), trend, money(d.market), money(d.max_buy), money(d.profit_unit),
                          f"{d.roi:.0%}", vol, speed, f"{d.p_sell:.0%}", d.qty_cap if d.fast else "-",
                          f"{d.confidence:.0%}", d.reason),
                         (d.name.lower(), d.cur, tr or 0, d.market, d.max_buy, d.profit_unit, d.roi, d.vol_day or 0,
                          d.est_days if d.est_days is not None else 999, d.p_sell, d.qty_cap, d.confidence, None),
                         "deal" if d.is_deal else ("bad" if not d.fast else "muted")))
        self._fill(self.deal_tree, rows)
        self._deal_ids = dict(zip(self.deal_tree.get_children(), shown))
        margin = self.settings.min_margin * (self.learned.margin_factor if self.learned else 1)
        n_fast = sum(1 for d in self.deals if d.fast and not d.starter)
        n_start = sum(1 for d in self.deals if d.starter)
        starter_txt = (f"{n_start} first-scan picks (gold): deep markets where the addon reads all listings live and "
                       f"only buys stacks far below the normal price. ") if n_start else ""
        self.deal_info.set(f"{starter_txt}{n_deals} items with price history are under their max buy price. {n_fast} of "
                           f"{len(self.deals)} items pass the speed rules (at least {self.settings.min_sales_per_day:g} "
                           f"sales/day, sold within ~{self.settings.hold_days:g} days); red items are never bought. "
                           f"Required margin: {margin:.0%}. Double-click an item for its price history.")

    def _blacklist_selected(self):
        sel = self.deal_tree.selection()
        if not sel:
            return
        for iid in sel:
            d = self._deal_ids.get(iid)
            if d and str(d.id) not in self.settings.blacklist:
                self.settings.blacklist.append(str(d.id))
        self.settings.save()
        self.refresh()

    def _show_item(self, tree):
        sel = tree.selection()
        if not sel:
            return
        d = self._deal_ids.get(sel[0])
        if not d:
            return
        trend = engine.trend_text(self.trends.get(d.id))
        self._show_chart(d.id, d.name,
                         f"{d.name}  ·  fair value {money(d.market)}  ·  max buy {money(d.max_buy)}"
                         + (f"  ·  7 days: {trend}" if trend else ""),
                         ((d.max_buy, GOLD, "max buy"), (d.market, MUTED, "fair")))

    def _show_held(self):
        """Inventory & selling: double-click an item for its price history with your cost and floor."""
        sel = self.sell_tree.selection()
        if not sel:
            return
        e = getattr(self, "_sell_ids", {}).get(sel[0])
        if not e:
            return
        iid, name, cost, floor, fair = e
        trend = engine.trend_text(self.trends.get(iid))
        self._show_chart(iid, name,
                         f"{name}  ·  your cost {money(cost)}  ·  floor {money(floor)}"
                         + (f"  ·  7 days: {trend}" if trend else ""),
                         tuple(x for x in ((floor, GOLD, "floor"), (cost, "#ff8a65", "your cost"),
                                           (fair, MUTED, "fair")) if x[0]))

    def _show_chart(self, iid, title, header, marks):
        """Price history window: cheapest listing and typical price per scan, with marker lines."""
        hist = engine.price_history(self.con, self.realm, iid)
        win = tk.Toplevel(self, bg=BG)
        win.title(title)
        win.geometry("720x380")
        ttk.Label(win, text=header, style="H.TLabel", padding=10).pack(anchor="w")
        c = tk.Canvas(win, bg=PANEL, highlightthickness=0)
        c.pack(fill="both", expand=True, padx=10, pady=(0, 10))

        def draw(_e=None):
            c.delete("all")
            w, h = c.winfo_width(), c.winfo_height()
            if len(hist) < 2:
                c.create_text(w / 2, h / 2, text="Not enough history yet.", fill=MUTED)
                return
            t0, t1 = hist[0][0], hist[-1][0]
            vals = [p for row in hist for p in row[1:3] if p] + [m[0] for m in marks]
            lo, hi = min(vals) * 0.9, max(vals) * 1.05
            if hi <= lo:
                hi = lo + 1

            def xy(t, v):
                return 60 + (t - t0) / max(1, t1 - t0) * (w - 80), 10 + (1 - (v - lo) / (hi - lo)) * (h - 40)
            for v, col, label in marks:
                _, y = xy(t0, v)
                c.create_line(60, y, w - 20, y, fill=col, dash=(4, 3))
                c.create_text(w - 22, y - 8, text=label, fill=col, anchor="e", font=("Segoe UI", 8))
            for idx, col in ((2, "#6c8cff"), (1, ACCENT)):
                line = []
                for row in hist:
                    line += xy(row[0], row[idx])
                c.create_line(line, fill=col, width=2)
            for k in range(5):
                v = lo + (hi - lo) * k / 4
                _, y = xy(t0, v)
                c.create_text(54, y, text=money(v, short=True), fill=MUTED, anchor="e", font=("Segoe UI", 8))
            c.create_text(70, h - 14, text="green = cheapest listing   blue = typical (25th percentile)", fill=MUTED,
                          anchor="w", font=("Segoe UI", 8))
        c.bind("<Configure>", draw)

    # selling
    def _build_sell(self):
        ttk.Label(self.tab_sell, text="Items you bought with FlipForever and still hold. The addon never posts below "
                  "the floor; the floor slowly drops if an item keeps expiring.", style="Muted.TLabel",
                  wraplength=1000).pack(anchor="w", pady=(0, 2))
        ttk.Label(self.tab_sell, text="Double-click an item for its price history, with your cost and floor.",
                  style="Muted.TLabel").pack(anchor="w", pady=(0, 8))
        cols = ("Item", "Holding", "Days held", "Avg cost", "Fair value", "Floor", "Target price", "Unrealized", "Expired in a row")
        widths = (230, 70, 80, 95, 95, 95, 100, 105, 115)
        frame, self.sell_tree = self._tree(self.tab_sell, cols, widths)
        frame.pack(fill="both", expand=True)
        self.sell_tree.bind("<Double-1>", lambda e: self._show_held())

    # history
    def _build_hist(self):
        cols = ("When", "What", "Item", "Qty", "Unit price", "Profit", "Character")
        widths = (140, 80, 260, 60, 110, 110, 120)
        frame, self.hist_tree = self._tree(self.tab_hist, cols, widths, height=22)
        frame.pack(fill="both", expand=True)

    # learning
    def _build_learn(self):
        self.learn_info = tk.StringVar()
        ttk.Label(self.tab_learn, textvariable=self.learn_info, style="Muted.TLabel", wraplength=1100,
                  justify="left").pack(anchor="w", pady=(0, 8))
        cols = ("Item", "Sold", "Expired", "Sell chance", "Price accuracy", "Margin tweak", "Profit", "Avg days to sell", "Status")
        widths = (220, 60, 70, 90, 110, 100, 100, 120, 220)
        frame, self.learn_tree = self._tree(self.tab_learn, cols, widths, height=14)
        frame.pack(fill="both", expand=True)
        ttk.Label(self.tab_learn, text="Margin auto-tuning log", style="H.TLabel").pack(anchor="w", pady=(10, 4))
        cols2 = ("When", "Required margin", "Losing flips", "Sell-through", "ROI", "Decision")
        frame2, self.tune_tree = self._tree(self.tab_learn, cols2, (140, 120, 100, 100, 80, 360), height=5)
        frame2.pack(fill="x")

    # settings
    def _build_settings(self):
        f = self.tab_set
        self.vars = {}
        row = 0

        def add(label, key, kind="entry", width=50, values=None, hint=""):
            nonlocal row
            ttk.Label(f, text=tr_padded(label)).grid(row=row, column=0, sticky="w", pady=5, padx=(0, 14))
            val = getattr(self.settings, key)
            if kind == "bool":
                v = tk.BooleanVar(value=val)
                w = ttk.Checkbutton(f, variable=v)
            elif kind == "combo":
                v = tk.StringVar(value=val)
                w = ttk.Combobox(f, textvariable=v, values=values or [], width=width)
            else:
                v = tk.StringVar(value=str(val))
                w = ttk.Entry(f, textvariable=v, width=width)
            w.grid(row=row, column=1, sticky="w")
            if hint:
                ttk.Label(f, text=tr(hint), style="Muted.TLabel").grid(row=row, column=2, sticky="w", padx=12)
            self.vars[key] = (v, kind)
            row += 1
            return w

        # language (all languages the game supports); saved right away, applied on restart
        ttk.Label(f, text=tr("Language")).grid(row=row, column=0, sticky="w", pady=5, padx=(0, 14))
        names = list(i18n.LANGUAGES.values())
        self.lang_var = tk.StringVar(value=i18n.LANGUAGES.get(self.settings.language or "enUS", "English"))
        lang_box = ttk.Combobox(f, textvariable=self.lang_var, values=names, state="readonly", width=24)
        lang_box.grid(row=row, column=1, sticky="w")
        ttk.Label(f, text=tr("Language changes apply after restarting the app."), style="Muted.TLabel").grid(
            row=row, column=2, sticky="w", padx=12)
        lang_box.bind("<<ComboboxSelected>>", lambda e: self._language_changed())
        row += 1
        self.path_box = add("WoW Forever folder", "wow_path", "combo", 60, store.find_wow_installs(), "the _forever_ folder")
        ttk.Button(f, text="Browse...", command=self._browse).grid(row=row - 1, column=2, sticky="w", padx=12)
        self.acct_box = add("Account folder", "account", "combo", 30, store.find_accounts(self.settings.wow_path),
                            "under WTF\\Account (picked automatically)")
        self.path_box.bind("<<ComboboxSelected>>", lambda e: self._path_changed())
        add("Gold budget per shopping list", "budget_gold", width=12, hint="gold")
        add("Minimum profit margin", "min_margin", width=12, hint="0.20 = 20% after the AH cut; the learner tunes around this")
        add("Must sell within (days)", "hold_days", width=12, hint="only buy as much as sells in this many days; slower items are skipped")
        add("Minimum market sales per day", "min_sales_per_day", width=12, hint="items the market buys fewer of are never bought")
        add("Minimum sell chance", "min_sell_chance", width=12, hint="0.55 = at least 55% of auctions must sell (learned from your sales)")
        add("First-scan mode", "starter_mode", "bool", hint="buy right after one scan: deep markets, price judged live in game")
        add("  deep market = units listed", "starter_min_listed", width=12, hint="only items with at least this many listed")
        add("Max units per item", "max_units_per_item", width=12)
        add("Max items on a shopping list", "max_plan_items", width=12)
        add("Ignore items worth less than", "min_value_copper", width=12, hint="copper (100 = 1 silver)")
        add("Auction duration", "duration", "combo", 10, ["1", "2", "3"], "1 = 12h, 2 = 24h, 3 = 48h")
        add("Also post my farmed loot", "sell_farmed", "bool", hint="items you didn't flip get posted at fair value (floor 75%)")
        add("Let it tune the margin itself", "autotune", "bool", hint="the self-improving part: tightens after losses, loosens when winning")
        add("Auto-import when the game saves", "auto_import", "bool", hint="watches for /reload or logout")
        add("Auto-build the shopping list after a new scan", "auto_build", "bool",
            hint="then plays a sound and pops up: click Reload in game to load it")
        add("Switch to the character I play", "auto_character", "bool",
            hint="after each import, picks the character the game saved last")
        btns = ttk.Frame(f)
        btns.grid(row=row, column=0, columnspan=3, sticky="w", pady=(18, 0))
        ttk.Button(btns, text="Save settings", style="Accent.TButton", command=self.save_settings).pack(side="left")
        ttk.Button(btns, text="Install / update the addon", command=self.install_addon).pack(side="left", padx=8)
        ttk.Button(btns, text="Load demo data", command=self.load_demo).pack(side="left")
        ttk.Button(btns, text="Remove demo data", command=self.remove_demo).pack(side="left", padx=8)
        ttk.Button(btns, text="Clear blacklist", command=self.clear_blacklist).pack(side="left")
        row += 1
        self.addon_state = tk.StringVar()
        ttk.Label(f, textvariable=self.addon_state, style="Muted.TLabel").grid(row=row, column=0, columnspan=3, sticky="w", pady=(12, 0))

    def _browse(self):
        d = filedialog.askdirectory(title="Pick your World of Warcraft\\_forever_ folder")
        if d:
            self.vars["wow_path"][0].set(os.path.normpath(d))
            self._path_changed()

    def _path_changed(self):
        accts = store.find_accounts(self.vars["wow_path"][0].get())
        self.acct_box["values"] = accts
        if accts and self.vars["account"][0].get() not in accts:
            self.vars["account"][0].set(accts[0])

    def save_settings(self, quiet=False):
        old_default = self.settings.budget_gold
        for key, (v, kind) in self.vars.items():
            cur = getattr(self.settings, key)
            raw = v.get()
            try:
                if kind == "bool":
                    val = bool(raw)
                elif isinstance(cur, bool):
                    val = bool(raw)
                elif isinstance(cur, int):
                    val = int(float(raw))
                elif isinstance(cur, float):
                    val = float(raw)
                else:
                    val = str(raw).strip()
            except ValueError:
                messagebox.showerror("FlipForever", f"'{raw}' is not a valid number for {key}.")
                return False
            setattr(self.settings, key, val)
        # a new budget in Settings also applies to the selected character (and the box at the top)
        new_default = self.settings.budget_gold
        char_key = self._char_key()
        if new_default != old_default and char_key:
            self.settings.budgets[char_key] = new_default
            self.budget_var.set(f"{new_default:g}")
        self.settings.save()
        if not quiet:
            if new_default != old_default:
                self.status(f"Settings saved. Budget is now {new_default:g} gold: click Build shopping list, "
                            "then Reload in game, so the addon uses it.")
            else:
                self.status("Settings saved.")
        self.refresh()
        return True

    def clear_blacklist(self):
        self.settings.blacklist = []
        self.settings.save()
        self.refresh()

    def _build_help(self):
        t = tk.Text(self.tab_help, bg=PANEL, fg=FG, relief="flat", wrap="word", font=("Segoe UI", 11), padx=18, pady=14)
        t.pack(fill="both", expand=True)
        t.tag_configure("h", font=("Segoe UI Semibold", 13), foreground=ACCENT, spacing1=10, spacing3=4)
        from . import i18n_help
        for i, (kind, text) in enumerate(HELP):
            text = i18n_help.translate(i, text, i18n.language())
            t.insert("end", text + "\n", ("h",) if kind == "h" else ())
        t.configure(state="disabled")

    # ------------------------------------------------------------- actions
    def status(self, text):
        self.status_var.set(text)

    def _first_run(self):
        s = self.settings
        if not s.wow_path:
            found = store.find_wow_installs()
            if found:
                s.wow_path = found[0]
                self.vars["wow_path"][0].set(found[0])
        if s.wow_path and not s.account:
            accts = store.find_accounts(s.wow_path)
            if accts:
                s.account = accts[0]
                self.vars["account"][0].set(accts[0])
        s.save()

    def install_addon(self):
        if not self.save_settings(quiet=True):
            return
        try:
            path = engine.install_addon(self.settings)
        except Exception as e:  # noqa: BLE001
            messagebox.showerror("FlipForever", f"Couldn't install the addon:\n{e}\n\nIf it's a permissions error, run this app as administrator once.")
            return
        self.status(f"Addon installed to {path}")
        messagebox.showinfo("FlipForever", "Addon installed. If WoW is running, type /reload (or restart the game) "
                            "and make sure 'FlipForever' is ticked in the AddOns list on the character screen.")
        self.refresh()

    def import_now(self, quiet=False):
        path = self.settings.savedvars_path()
        if not path or not path.exists():
            if not quiet:
                messagebox.showinfo("FlipForever", "No FlipForever data from the game yet.\n\n1. Install the addon (Settings).\n"
                                    "2. In game, open the auction house and click 'Full scan'.\n3. Type /reload - the game saves "
                                    "the data, then click Import (or wait, it auto-imports).")
            return
        try:
            res = engine.import_savedvars(self.con, path)
        except Exception as e:  # noqa: BLE001
            traceback.print_exc()
            if not quiet:
                messagebox.showerror("FlipForever", f"Couldn't read the game data:\n{e}")
            return
        self.last_mtime = path.stat().st_mtime
        self.status(f"Imported {res['scans']} new scans and {res['events']} new trade events "
                    f"({dt.datetime.now():%H:%M}).")
        if res["realms"] and (not self.settings.realm or self.settings.realm == demo.DEMO_REALM):
            self.settings.realm = res["realms"][0]
            self.settings.save()
        switched = self._follow_played_character()
        self.refresh(commit_tuning=True)
        if switched:
            self.status(f"Switched to {switched}, the character you played last.")
        # a new scan arrived: build the shopping list straight away and tell the player
        if res["scans"] > 0 and self.settings.auto_build:
            self._auto_build()

    def _follow_played_character(self):
        """Switch realm and character to the one the game saved last, once per new character:
        a character you pick yourself stays until you play another one. Returns its name or None."""
        if not self.settings.auto_character:
            return None
        found = engine.last_played(self.con)
        if not found or found[0] == demo.DEMO_REALM:
            return None
        realm, name, _ = found
        key = engine.char_key(name, realm)
        if key == self.settings.auto_char_seen:
            return None
        self.settings.auto_char_seen = key
        changed = (self.settings.realm, self.settings.character) != (realm, name)
        self.settings.realm, self.settings.character = realm, name
        self.settings.save()
        return name if changed else None

    def _auto_build(self):
        key = self._char_key()
        if not key or not self.realm or self.realm == demo.DEMO_REALM:
            return
        try:
            budget = self.settings.budget_for(key)
            plan, spent = engine.build_plan(self.settings, self.deals, self.model, self.learned, self.ledger,
                                            engine.item_names(self.con, self.realm), self.realm, budget)
            plan["ctx"] = engine.planner_context(self.settings, self.learned, self.ledger_all, self.ledger, budget)
            engine.write_plan(self.settings, key, plan)
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            return
        self._notify(f"New shopping list for {self.char} ready: {len(plan['buy'])} items to check. "
                     "Click Reload in game to load it.")

    def _notify(self, text):
        """Sound + bring the window to the front + status line."""
        self.status(text)
        try:
            import winsound
            winsound.MessageBeep(winsound.MB_ICONASTERISK)
        except Exception:  # noqa: BLE001
            self.bell()
        try:
            self.deiconify()
            self.lift()
            self.attributes("-topmost", True)
            self.after(2500, lambda: self.attributes("-topmost", False))
        except tk.TclError:
            pass

    def _watch(self):
        try:
            if self.settings.auto_import:
                path = self.settings.savedvars_path()
                if path and path.exists() and path.stat().st_mtime != self.last_mtime:
                    if self.last_mtime == 0 or time.time() - path.stat().st_mtime > 2:
                        self.import_now(quiet=True)
        finally:
            self.after(5000, self._watch)

    def build_plan(self):
        if not self.realm:
            messagebox.showinfo("FlipForever", "No market data yet - do a Full scan in game first (or load demo data).")
            return
        if self.realm == demo.DEMO_REALM:
            messagebox.showinfo("FlipForever", "That's the demo realm - pick your real realm at the top to build a real list.")
            return
        key = self._char_key()
        if not key:
            messagebox.showinfo("FlipForever", "Pick the character this list is for (top bar, 'character').\n\n"
                                "Each character has its own gold, bags and shopping list. If your character isn't "
                                "listed yet, log in with it once (or /reload) so the addon can record it.")
            return
        self._budget_changed()
        budget = self.settings.budget_for(key)
        plan, spent = engine.build_plan(self.settings, self.deals, self.model, self.learned, self.ledger,
                                        engine.item_names(self.con, self.realm), self.realm, budget)
        plan["ctx"] = engine.planner_context(self.settings, self.learned, self.ledger_all, self.ledger, budget)
        try:
            out = engine.write_plan(self.settings, key, plan)
        except Exception as e:  # noqa: BLE001
            messagebox.showerror("FlipForever", str(e))
            return
        deals = sum(1 for b in plan["buy"] if any(d.id == b["id"] and d.is_deal for d in self.deals))
        live = sum(1 for b in plan["buy"] if b.get("gap"))
        self.status(f"Shopping list written: {len(plan['buy'])} items ({deals} deals now, {live} checked live), "
                    f"{len(plan['sell'])} sell rules.")
        why = ""
        if not plan["buy"]:
            why = "\n\nWhy nothing to buy yet: " + self._readiness()
        elif live:
            why = (f"\n\n{live} are first-scan picks: busy markets where the addon looks at every listing in game and "
                   "only buys stacks far below the normal price. Budget limit applies.")
        messagebox.showinfo("FlipForever", f"Shopping list for {self.char} ready (budget {budget:g}g)!\n\n"
                            f"{len(plan['buy'])} items to check "
                            f"({deals} known deals right now, about {money(spent, True)}).\n"
                            f"{len(plan['sell'])} items have sell prices (for posting your loot)."
                            f"{why}\n\nIn game: click 'Reload' on the FlipForever auction house panel (or in the "
                            "FlipForever window), then press the big button to work through the list.")

    def _readiness(self) -> str:
        """Plain-language reason the buy list is empty."""
        rows = self.con.execute("SELECT t FROM scans WHERE realm=? AND t>=? ORDER BY t",
                                (self.realm, int(time.time()) - 14 * 86400)).fetchall()
        times = [r[0] for r in rows]
        need = self.settings.min_scans
        if len(times) < need or (times[-1] - times[0]) < 6 * 3600:
            have_h = (times[-1] - times[0]) / 3600 if times else 0
            ready_at = dt.datetime.fromtimestamp(times[0] + 6 * 3600) if times else None
            msg = (f"you have {len(times)} scan(s) covering {have_h:.1f} hours. Buying needs at least {need} scans "
                   f"spread over 6+ hours, so the app knows normal prices and how fast items sell.")
            if ready_at:
                msg += f" Do a Full scan every couple of hours; after about {ready_at:%H:%M} it can start buying."
            return msg
        fast = sum(1 for d in self.deals if d.fast)
        if not fast:
            return "no item passes the speed rules yet (Settings: sales per day / sell chance). More scans help."
        return (f"{fast} items sell fast enough, but none is listed below its max buy price right now. "
                "Scan again later - cheap listings show up all the time.")

    def load_demo(self):
        demo.create_demo(self.con)
        self.settings.realm = demo.DEMO_REALM
        self.settings.save()
        self.refresh()
        self.status("Demo data loaded - this is a made-up market so you can look around.")

    def remove_demo(self):
        demo.clear_demo(self.con)
        if self.settings.realm == demo.DEMO_REALM:
            self.settings.realm = ""
            self.settings.save()
        self.refresh()

    def _realm_changed(self):
        self.settings.realm = self.realm_var.get()
        self.settings.character = ""
        self.settings.save()
        self.refresh()

    ALL_CHARS = "All characters"

    def _char_changed(self):
        v = self.char_var.get()
        self.settings.character = "*" if v == self.ALL_CHARS else v
        self.settings.save()
        self.refresh()

    def _char_key(self):
        return engine.char_key(self.char, self.realm) if (self.char and self.realm) else None

    def _budget_changed(self):
        key = self._char_key()
        if not key:
            return
        try:
            gold = float(self.budget_var.get().replace(",", ".").rstrip("g").strip())
        except ValueError:
            self.budget_var.set(f"{self.settings.budget_for(key):g}")
            return
        if gold != self.settings.budget_for(key):
            self.settings.budgets[key] = gold
            self.settings.save()
            self.status(f"Budget for {self.char}: {gold:g} gold. Click Build shopping list, then Reload in game, "
                        "so the addon uses it.")
            self.refresh()

    # ------------------------------------------------------------- refresh everything
    def refresh(self, commit_tuning=False):
        try:
            self._refresh(commit_tuning)
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            self.status("Something went wrong while refreshing - see the console.")

    def _refresh(self, commit_tuning):
        all_realms = engine.realms(self.con)
        self.realm_box["values"] = all_realms
        realm = self.settings.realm if self.settings.realm in all_realms else (all_realms[0] if all_realms else None)
        self.realm = realm
        self.realm_var.set(realm or "")
        addon = self.settings.addon_path()
        installed = bool(addon and (addon / "FlipForever.toc").exists())
        self.addon_state.set(("Addon: installed at " + str(addon)) if installed else "Addon: not installed yet")
        # characters on this realm: each has its own gold, bags, budget and shopping list
        self.chars = engine.characters(self.con, realm) if realm else {}
        names_sorted = sorted(self.chars)
        self.char_box["values"] = [self.ALL_CHARS] + names_sorted
        if self.settings.character in self.chars:
            char = self.settings.character
        elif self.settings.character != "*" and len(names_sorted) == 1:
            char = names_sorted[0]          # only one character: pick it automatically
        else:
            char = ""
        self.char = char
        self.char_var.set(char or self.ALL_CHARS)
        key = self._char_key()
        if key:
            self.budget_entry.configure(state="normal")
            self.budget_var.set(f"{self.settings.budget_for(key):g}")
            info = self.chars.get(char) or {}
            self.char_gold.set(f"g  (has {money(info['money'], True)})" if info.get("money") is not None else "g")
        else:
            self.budget_var.set("")
            self.budget_entry.configure(state="disabled")
            self.char_gold.set("pick a character")
        if not realm:
            self.model, self.ledger, self.learned, self.deals = {}, engine.Ledger({}, [], []), None, []
            self.ledger_all = self.ledger
            for v in self.cards.values():
                v.set("-")
            self._draw_chart()
            self._fill_steps(installed)
            self._fill(self.deal_tree, [])
            self._deal_ids = {}
            return
        names = engine.item_names(self.con, realm)
        self.model = engine.market_model(self.con, realm)
        # learning uses every character's trades; stock/profit/lists are per character
        self.ledger_all = engine.build_ledger(self.con, realm)
        self.ledger = engine.build_ledger(self.con, realm, char) if char else self.ledger_all
        self.learned = engine.learn(self.con, realm, self.settings, self.ledger_all, self.model, commit_tuning=commit_tuning)
        self.deals = engine.recommend(self.settings, self.model, self.learned, self.ledger_all, names, holder=self.ledger)
        self.trends = engine.price_trends(self.con, realm)
        s = engine.summary(self.con, realm, self.ledger, self.model)
        self.cards["realized"].set(money(s["realized"], True))
        self.cards["week"].set(money(s["week"], True))
        for key in ("realized", "week"):        # green when you're up, red when you're down
            val = s[key] or 0
            self.card_values[key].configure(foreground=ACCENT if val > 0 else RED if val < 0 else FG)
        self.cards["held"].set(f"{money(s['held_cost'], True)} / {money(s['held_value'], True)}")
        self.cards["st"].set("-" if s["sell_through"] is None else f"{s['sell_through']:.0%}")
        self.cards["scan"].set(ago(s["last_scan"]["t"]) if s["last_scan"] else "never")
        self.cards["tracked"].set(f"{s['tracked']:,}")
        self._draw_chart()
        self._fill_char_profit(realm)
        self._fill_steps(installed, s)
        self._fill_deals()
        self._fill_top_deals()
        self._fill_sell()
        self._fill_hist()
        self._fill_learn()
        self._fill_advisor()
        self._fill_gather()

    def _fill_steps(self, installed, s=None):
        t = self.steps
        t.configure(state="normal")
        t.delete("1.0", "end")
        scanned = bool(s and s["last_scan"])
        fresh = bool(s and s["last_scan"] and time.time() - s["last_scan"]["t"] < 6 * 3600)
        key = self._char_key()
        has_plan = bool(key and engine.plan_for(key))
        steps = [
            (installed, "Install the addon (Settings tab)"),
            (scanned, "In game: open the auction house and click Full scan (the list builds itself in game)"),
            (fresh, "Keep data fresh: scan every few hours (more scans = smarter prices)"),
            (bool(self.char), "Pick your character at the top and set its budget"),
            (has_plan, "Once: click 'Build shopping list' and Reload in game, so the addon learns your budget"),
            (False, "At the AH: press the big button (or your key) to buy deals; autopilot keeps checking"),
            (False, "Click 'Post my items' to sell; profits get learned automatically"),
        ]
        first_todo = next((i for i, (done, _) in enumerate(steps) if not done), None)
        for i, (done, text) in enumerate(steps):
            tag = "done" if done else ("now" if i == first_todo else "todo")
            t.insert("end", ("✓ " if done else "→ " if i == first_todo else "• ") + text + "\n\n", tag)
        t.configure(state="disabled")

    def _fill_top_deals(self):
        t = self.top_deals
        t.configure(state="normal")
        t.delete("1.0", "end")
        deals = [d for d in self.deals if d.is_deal][:6]
        if not deals:
            t.insert("end", "No deals right now. Scan again later -\nmarkets move all the time.")
        for d in deals:
            t.insert("end", f"{d.name[:24]:<24}  +{money(d.profit_unit, True)}/unit  ({d.roi:.0%})\n")
        t.configure(state="disabled")

    def _fill_sell(self):
        rows, held = [], []
        for iid, led in self.ledger.items.items():
            if led.held <= 0:
                continue
            m = self.model.get(iid)
            cost = led.held_cost / led.held
            fair = m.market if m else 0
            overdue = max(0.0, (time.time() - led.inventory[0][3]) / 86400 - self.settings.hold_days * 2) if led.inventory else 0
            floor = cost * 1.02 / (1 - self.settings.ah_cut) * (0.95 ** led.last_expired_streak) * (0.95 ** overdue)
            floor = max(floor, cost * 0.85) if (led.last_expired_streak or overdue) else floor
            target = max(fair, floor * 1.05)
            unreal = (fair * (1 - self.settings.ah_cut) - cost) * led.held if fair else 0
            age = (time.time() - led.inventory[0][3]) / 86400 if led.inventory else 0
            slow = age > self.settings.hold_days * 2
            rows.append(((led.name, led.held, f"{age:.1f}" + (" (slow!)" if slow else ""), money(cost), money(fair),
                          money(floor), money(target), money(unreal, True), led.last_expired_streak),
                         (led.name.lower(), led.held, age, cost, fair, floor, target, unreal, led.last_expired_streak),
                         "bad" if unreal < 0 or slow else None))
            held.append((iid, led.name, cost, floor, fair))
        self._fill(self.sell_tree, rows)
        self._sell_ids = dict(zip(self.sell_tree.get_children(), held))

    def _fill_hist(self):
        rows = []
        for t, what, name, q, p, profit, char in self.ledger.trades[:2000]:
            rows.append(((dt.datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M"), what, name, q if q is not None else "",
                          money(p) if p is not None else "", money(profit) if profit is not None else "", char or ""),
                         (t, what, name.lower(), q or 0, p or 0, profit or 0, char or ""),
                         "deal" if (profit or 0) > 0 and what == "Sold" else ("bad" if (profit or 0) < 0 else None)))
        self._fill(self.hist_tree, rows)

    def _fill_learn(self):
        L = self.learned
        margin = self.settings.min_margin * L.margin_factor
        info = (f"Current required margin: {margin:.0%} (your base {self.settings.min_margin:.0%} x learned factor "
                f"{L.margin_factor:.2f}).  Sale price accuracy across all flips: {L.global_calib:.0%} of predicted.  ")
        if L.paused:
            info += f"{len(L.paused)} items are auto-paused because they kept expiring."
        if L.notes:
            info += "\nLatest: " + "; ".join(L.notes)
        info += ("\nHow it learns: each sale teaches it how close its price predictions were (price accuracy), every sale "
                 "or expiry updates that item's sell chance, items that lose money need a bigger margin, and the overall "
                 "margin is tightened or loosened from your recent win/loss record.")
        self.learn_info.set(info)
        rows = []
        for iid, led in self.ledger_all.items.items():   # learning is shared by all characters
            if not isinstance(iid, int) or (led.sold_lots + led.expired_lots + led.bought_units) == 0:
                continue
            p, _ = L.item_sell.get(iid, (None, 0))
            calib = L.item_calib.get(iid)
            adj = L.item_margin_adj.get(iid, 0)
            dts = sum(led.days_to_sell) / len(led.days_to_sell) if led.days_to_sell else None
            status = L.paused.get(iid, "")
            if not status:
                status = "favourite" if adj < 0 else ("needs bigger margin" if adj > 0 else "")
            rows.append(((led.name, led.sold_lots, led.expired_lots, "-" if p is None else f"{p:.0%}",
                          "-" if calib is None else f"{calib:.0%}", f"{adj:+.0%}" if adj else "", money(led.profit, True),
                          "-" if dts is None else f"{dts:.1f}", status),
                         (led.name.lower(), led.sold_lots, led.expired_lots, p or 0, calib or 0, adj, led.profit, dts or 0, status),
                         "bad" if led.profit < 0 else ("deal" if adj < 0 else None)))
        self._fill(self.learn_tree, rows)
        rows2 = []
        for t, m, lr, st, roi, note in engine.tuning_history(self.con, self.realm):
            rows2.append(((dt.datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M"), f"{m:.0%}", f"{lr:.0%}", f"{st:.0%}",
                           f"{roi:.0%}", note), (t, m, lr, st, roi, note), None))
        self._fill(self.tune_tree, rows2)


HELP = [
    ("h", "What this is"),
    ("p", "FlipForever finds items on the WoW Forever auction house that are listed below what they normally sell for, "
          "tells the in-game addon exactly what to buy and the most it may pay, and then posts them back at a sensible price. "
          "It learns from every sale and expiry, so it gets better the more you use it."),
    ("h", "Why you still press a button"),
    ("p", "Blizzard only allows an addon to buy or post an auction during a real key press or click - fully automatic "
          "bots are against the rules and get accounts banned. FlipForever does all the thinking and searching; you press "
          "one key per purchase/post. Tip: in game type  /ff key SPACE  (or any key) so that key drives the big button "
          "while the auction house is open."),
    ("h", "The loop"),
    ("p", "1. Settings -> Install / update the addon.\n"
          "2. In game: open the auction house, click 'Full scan' on the FlipForever panel (allowed once every 15 min).\n"
          "3. When the scan finishes, the addon rebuilds your shopping list in game - no reload needed.\n"
          "4. Now and then click Reload in game: the app imports your scans and trades, learns from them and passes that back with the next list.\n"
          "5. At the auction house, press the big button: it searches each item and stops on deals - press again to buy "
          "(commodities ask once more to confirm the final price).\n"
          "6. Click 'Post my items' to list what you bought (and your farmed loot, if enabled). It undercuts the cheapest "
          "competitor by 1 copper but never goes below your floor.\n"
          "7. Open your mailbox now and then - sale invoices tell the app what really sold and for how much.\n"
          "Repeat a few times a day. More scans = better price knowledge."),
    ("h", "Reading the Deals tab"),
    ("p", "Now = cheapest listing at the last scan. Fair value = recency-weighted typical price over 14 days. Max buy = the most "
          "you can pay and still hit your margin after the 5% AH cut, deposits and the chance it doesn't sell. Sell chance "
          "starts as a guess from market activity and becomes your own track record. Confidence drops for jumpy prices and "
          "thin data."),
    ("h", "Staying safe"),
    ("p", "Start with a small gold budget while the app learns your server. Thin markets (few sales per day) can be "
          "manipulated - the app prefers items that actually sell. Use 'Never buy selected' on anything you don't trust."),
]


def main():
    app = App()
    app.mainloop()
