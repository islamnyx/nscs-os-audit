#!/usr/bin/env python3
"""
NSCS OS Project — Rebuilt GUI v3
Rebuilt from zero: same hacker style as the old GUI,
but wired exactly like main_menu.sh — runs real scripts,
no bugs, clean threading, fast matrix rain.
"""

import tkinter as tk
import subprocess
import threading
import random
import time
import os
import sys
import math
from datetime import datetime
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR  = Path(__file__).parent.resolve()
MODULES_DIR = SCRIPT_DIR / "modules"
LOG_DIR     = Path.home() / "nscs-os-audit"
REPORT_DIR  = LOG_DIR / "reports"

# ── Palette ────────────────────────────────────────────────────────────────────
C_BG      = "#000000"
C_BG2     = "#030a03"
C_PANEL   = "#050d05"
C_BORDER  = "#0a280a"
C_GREEN   = "#00ff41"
C_GREEN2  = "#00cc33"
C_GREEN3  = "#005512"
C_DIM     = "#002a08"
C_DIM2    = "#001505"
C_YELLOW  = "#ffcc00"
C_RED     = "#ff3333"
C_WHITE   = "#d0ffd0"
C_CYAN    = "#00ffcc"
C_PURPLE  = "#bb88ff"

FONT      = ("Courier New", 10)
FONT_SM   = ("Courier New", 9)
FONT_XS   = ("Courier New", 8)
FONT_LG   = ("Courier New", 11, "bold")
FONT_BOLD = ("Courier New", 10, "bold")

# Matrix chars
_MC = "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789ABCDEF"

# Modules — (key, label, subtitle, script_name, color, danger)
MODULES = [
    ("1",  "HARDWARE AUDIT",   "Phase 1  ·  DMI / CPU / GPU / RAM",         "audit_hardware_v2.sh", C_GREEN,  False),
    ("2",  "SOFTWARE AUDIT",   "Phase 1  ·  OS / Packages / Services",       "audit_software.sh",    C_CYAN,   False),
    ("3",  "GENERATE REPORTS", "Phase 2  ·  TXT / JSON / HTML / PDF",        "generate_reports.sh",  C_YELLOW, False),
    ("4",  "SEND REPORTS",     "Phase 3  ·  SMTP / TLS / Gmail",             "send_reports.sh",      C_WHITE,  False),
    ("5",  "CRON AUTOMATION",  "Phase 4  ·  Scheduling / Logging",           "setup_cron.sh",        C_PURPLE, False),
    ("6",  "REMOTE MONITOR",   "Phase 5  ·  SSH / SCP / Centralized",        "remote_monitor.sh",    C_RED,    True),
]


# ══════════════════════════════════════════════════════════════════════════════
#  Matrix Rain Canvas
# ══════════════════════════════════════════════════════════════════════════════
class MatrixRain(tk.Canvas):
    COL_W  = 13
    ROW_H  = 13
    DELAY  = 55  # ms between frames

    def __init__(self, master, **kw):
        super().__init__(master, bg=C_BG, highlightthickness=0, **kw)
        self._drops  = []
        self._items  = []
        self._ncols  = 0
        self._nrows  = 0
        self._job    = None
        self._alive  = False
        self.bind("<Configure>", self._on_resize)

    def start(self):
        self._alive = True
        self._init_columns()
        self._tick()

    def stop(self):
        self._alive = False
        if self._job:
            try: self.after_cancel(self._job)
            except Exception: pass

    def _on_resize(self, _e):
        if self._alive:
            self._init_columns()

    def _init_columns(self):
        self.delete("all")
        self._items = []
        self._drops = []
        w = self.winfo_width()  or 300
        h = self.winfo_height() or 110
        self._ncols = max(1, w // self.COL_W)
        self._nrows = max(1, h // self.ROW_H) + 2
        for c in range(self._ncols):
            x = c * self.COL_W + 6
            col_items = []
            for r in range(self._nrows):
                ch = random.choice(_MC)
                y  = r * self.ROW_H
                tid = self.create_text(x, y, text=ch,
                                       font=("Courier New", 9),
                                       fill=C_DIM2, anchor="center")
                col_items.append(tid)
            self._items.append(col_items)
            self._drops.append(random.randint(0, self._nrows))

    def _tick(self):
        if not self._alive:
            return
        for ci, (drop, col) in enumerate(zip(self._drops, self._items)):
            for ri, tid in enumerate(col):
                dist = ri - drop
                if   dist == 0:      fill, ch = C_GREEN,  random.choice(_MC)
                elif dist == -1:     fill, ch = C_GREEN2, random.choice(_MC)
                elif -4 < dist < 0:  fill, ch = C_GREEN3, random.choice(_MC)
                elif dist < 0:       fill, ch = C_DIM,    None
                else:                fill, ch = C_DIM2,   None
                if ch:
                    self.itemconfigure(tid, fill=fill, text=ch)
                else:
                    self.itemconfigure(tid, fill=fill)
            limit = self._nrows + random.randint(4, 18)
            self._drops[ci] = (drop + 1) % limit
        self._job = self.after(self.DELAY, self._tick)


# ══════════════════════════════════════════════════════════════════════════════
#  Glow Progress Bar
# ══════════════════════════════════════════════════════════════════════════════
class ProgressBar(tk.Canvas):
    def __init__(self, master, **kw):
        super().__init__(master, bg=C_BG2, highlightthickness=0, height=5, **kw)
        self._pct = 0.0
        self._pulse_t = 0.0
        self._pulsing = False
        self._job = None
        self.bind("<Configure>", lambda _e: self._redraw())

    def set_pct(self, pct):
        self._pct = max(0.0, min(1.0, pct))
        self._redraw()

    def start_pulse(self):
        self._pulsing = True
        self._pulse_loop()

    def stop_pulse(self):
        self._pulsing = False
        if self._job:
            try: self.after_cancel(self._job)
            except Exception: pass
        self._redraw()

    def _pulse_loop(self):
        if not self._pulsing:
            return
        self._pulse_t += 0.12
        self._pct = (math.sin(self._pulse_t) + 1) / 2
        self._redraw()
        self._job = self.after(50, self._pulse_loop)

    def _redraw(self):
        self.delete("all")
        w = self.winfo_width() or 400
        h = self.winfo_height() or 5
        # track
        self.create_rectangle(0, 0, w, h, fill=C_DIM2, outline="")
        # fill
        fw = int(w * self._pct)
        if fw > 2:
            self.create_rectangle(0, 0, fw, h, fill=C_GREEN3, outline="")
            tip = min(fw, 8)
            self.create_rectangle(fw - tip, 0, fw, h, fill=C_GREEN2, outline="")
            self.create_rectangle(fw - 2, 0, fw, h, fill=C_GREEN, outline="")


# ══════════════════════════════════════════════════════════════════════════════
#  Terminal Text Widget
# ══════════════════════════════════════════════════════════════════════════════
class Terminal(tk.Text):
    TAGS = {
        "ok":     {"foreground": C_GREEN},
        "warn":   {"foreground": C_YELLOW},
        "err":    {"foreground": C_RED},
        "head":   {"foreground": C_CYAN,   "font": ("Courier New", 10, "bold")},
        "dim":    {"foreground": C_GREEN3},
        "prompt": {"foreground": C_GREEN2},
        "white":  {"foreground": C_WHITE},
        "info":   {"foreground": C_PURPLE},
    }

    def __init__(self, master, **kw):
        super().__init__(
            master,
            bg=C_BG2, fg=C_GREEN2,
            insertbackground=C_GREEN,
            font=FONT_SM,
            relief="flat", borderwidth=0,
            wrap="word",
            state="disabled",
            cursor="arrow",
            **kw
        )
        for name, cfg in self.TAGS.items():
            self.tag_configure(name, **cfg)

    def clear(self):
        self.configure(state="normal")
        self.delete("1.0", "end")
        self.configure(state="disabled")

    def write(self, text, tag="", newline=True):
        self.configure(state="normal")
        suffix = "\n" if newline else ""
        self.insert("end", text + suffix, tag or ())
        self.see("end")
        self.configure(state="disabled")

    def typewrite(self, text, tag="", char_delay=0.008):
        """Character-by-character typewriter effect. Call from a worker thread."""
        self.configure(state="normal")
        for ch in text:
            self.insert("end", ch, tag or ())
            self.see("end")
            self.update_idletasks()
            if char_delay > 0:
                time.sleep(char_delay)
        self.insert("end", "\n", tag or ())
        self.see("end")
        self.configure(state="disabled")


# ══════════════════════════════════════════════════════════════════════════════
#  Module Button
# ══════════════════════════════════════════════════════════════════════════════
class ModuleButton(tk.Frame):
    def __init__(self, master, key, label, subtitle, command, color=C_GREEN, danger=False, **kw):
        super().__init__(master, bg=C_PANEL, **kw)
        self._cmd     = command
        self._color   = color
        self._danger  = danger
        self._active  = False
        self._hovered = False
        self._dim_border  = "#440000" if danger else C_DIM
        self._bright_border = C_RED if danger else color

        self.configure(
            highlightbackground=self._dim_border,
            highlightthickness=1,
            padx=0, pady=0
        )

        inner = tk.Frame(self, bg=C_PANEL, padx=10, pady=7)
        inner.pack(fill="both", expand=True)

        # Key label
        key_lbl = tk.Label(inner, text=f"[{key}]",
                           font=FONT_BOLD,
                           fg=self._bright_border, bg=C_PANEL,
                           width=4, anchor="w")
        key_lbl.pack(side="left")

        # Info block
        info = tk.Frame(inner, bg=C_PANEL)
        info.pack(side="left", fill="both", expand=True)

        tk.Label(info, text=label, font=FONT_BOLD,
                 fg=C_WHITE, bg=C_PANEL, anchor="w").pack(fill="x")
        tk.Label(info, text=subtitle, font=FONT_XS,
                 fg=C_GREEN3, bg=C_PANEL, anchor="w").pack(fill="x")

        # Status badge
        self._status_lbl = tk.Label(inner, text="READY", font=FONT_XS,
                                    fg=C_GREEN3, bg=C_PANEL, padx=4)
        self._status_lbl.pack(side="right")

        # Collect all widgets for bg propagation
        self._inner = inner
        self._all   = [self, inner, key_lbl, info, self._status_lbl] + \
                      list(info.winfo_children())

        for w in self._all:
            w.bind("<Button-1>", self._on_click)
            w.bind("<Enter>",    self._on_enter)
            w.bind("<Leave>",    self._on_leave)

    # ── hover / active state ───────────────────────────────────────────────
    def _on_enter(self, _e): self._hovered = True;  self._refresh()
    def _on_leave(self, _e): self._hovered = False; self._refresh()
    def _on_click(self, _e):
        if self._cmd: self._cmd()

    def set_active(self, state):
        self._active = state
        self._refresh()

    def set_status(self, text, color=None):
        self._status_lbl.configure(text=text, fg=color or C_GREEN3)

    def _refresh(self):
        lit = self._active or self._hovered
        bg  = ("#0d1a0d" if not self._danger else "#1a0000") if lit else C_PANEL
        hl  = self._bright_border if lit else self._dim_border
        self.configure(highlightbackground=hl)
        def set_bg(w):
            try: w.configure(bg=bg)
            except Exception: pass
            for c in w.winfo_children():
                set_bg(c)
        set_bg(self._inner)


# ══════════════════════════════════════════════════════════════════════════════
#  Main Application Window
# ══════════════════════════════════════════════════════════════════════════════
class NSCSApp(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("NSCS OS PROJECT — Command Center v2.0")
        self.geometry("1140x720")
        self.minsize(920, 580)
        self.configure(bg=C_BG)

        # Ensure dirs exist
        MODULES_DIR.mkdir(parents=True, exist_ok=True)
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        REPORT_DIR.mkdir(parents=True, exist_ok=True)

        self._running   = False        # True while a module thread is active
        self._active_id = None         # Currently lit button key
        self._btns      = {}           # key -> ModuleButton
        self._clock_job = None

        self._build_ui()
        self._start_clock()
        self._run_boot_sequence()
        self._bind_keys()

        self.protocol("WM_DELETE_WINDOW", self._on_close)

    # ══════════════════════════════════════════════════════════════════════
    #  UI Construction
    # ══════════════════════════════════════════════════════════════════════
    def _build_ui(self):
        # Root grid: sidebar | main
        self.grid_columnconfigure(0, weight=0, minsize=310)
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        self._build_sidebar()
        self._build_main()

        # Start matrix after layout settles
        self.after(200, self._matrix.start)

    # ── SIDEBAR ───────────────────────────────────────────────────────────
    def _build_sidebar(self):
        sb = tk.Frame(self, bg=C_BG2,
                      highlightbackground=C_BORDER, highlightthickness=1)
        sb.grid(row=0, column=0, sticky="nsew")
        sb.grid_rowconfigure(4, weight=1)

        # Matrix rain header
        self._matrix = MatrixRain(sb, width=310, height=108)
        self._matrix.grid(row=0, column=0, sticky="ew")

        # ASCII banner
        banner = tk.Frame(sb, bg=C_BG2)
        banner.grid(row=1, column=0, sticky="ew", padx=8, pady=(4, 0))
        ascii_art = (
            " ███╗   ██╗███████╗ ██████╗███████╗\n"
            " ████╗  ██║██╔════╝██╔════╝██╔════╝\n"
            " ██╔██╗ ██║███████╗██║     ███████╗\n"
            " ██║╚██╗██║╚════██║██║     ╚════██║\n"
            " ██║ ╚████║███████║╚██████╗███████║\n"
            " ╚═╝  ╚═══╝╚══════╝ ╚═════╝╚══════╝"
        )
        tk.Label(banner, text=ascii_art,
                 font=("Courier New", 7, "bold"),
                 fg=C_GREEN, bg=C_BG2,
                 justify="left").pack(anchor="w")
        tk.Label(banner, text="OS PROJECT — COMMAND CENTER  v2.0",
                 font=FONT_XS, fg=C_GREEN3, bg=C_BG2).pack(anchor="w", pady=(2, 0))

        # Clock + host
        info_frame = tk.Frame(sb, bg=C_BG2)
        info_frame.grid(row=2, column=0, sticky="ew", padx=10, pady=(6, 0))
        tk.Frame(sb, bg=C_DIM, height=1).grid(row=2, column=0, sticky="ew")
        clock_host = tk.Frame(sb, bg=C_BG2)
        clock_host.grid(row=3, column=0, sticky="ew")
        self._clock_lbl = tk.Label(clock_host, text="",
                                   font=("Courier New", 9, "bold"),
                                   fg=C_GREEN2, bg=C_BG2, anchor="w")
        self._clock_lbl.pack(fill="x", padx=10, pady=(4, 1))
        self._host_lbl = tk.Label(clock_host,
                                  text=f"HOST: {os.uname().nodename}   USER: {os.getenv('USER', 'root')}",
                                  font=FONT_XS, fg=C_GREEN3, bg=C_BG2, anchor="w")
        self._host_lbl.pack(fill="x", padx=10, pady=(0, 4))
        tk.Frame(sb, bg=C_DIM, height=1).grid(row=3, column=0, sticky="ew", pady=(0, 0))

        # Module buttons
        tk.Label(sb, text="█  SYSTEM MENU", font=FONT_XS,
                 fg=C_GREEN3, bg=C_BG2, anchor="w").grid(
                     row=3, column=0, sticky="ew", padx=10, pady=(28, 2))

        btn_outer = tk.Frame(sb, bg=C_BG2)
        btn_outer.grid(row=4, column=0, sticky="nsew", padx=6)

        for key, label, subtitle, script, color, danger in MODULES:
            btn = ModuleButton(
                btn_outer, key, label, subtitle,
                command=lambda k=key, sc=script, lb=label: self._launch(k, lb, sc),
                color=color, danger=danger
            )
            btn.pack(fill="x", pady=2)
            self._btns[key] = btn

        # Divider + utils
        tk.Frame(sb, bg=C_DIM, height=1).grid(row=5, column=0, sticky="ew", pady=4)

        util = tk.Frame(sb, bg=C_BG2)
        util.grid(row=6, column=0, sticky="ew", padx=6, pady=(0, 4))

        self._mk_util_btn(util, "[L]  LIST REPORTS", self._list_reports).pack(fill="x", pady=1)
        self._mk_util_btn(util, "[C]  CLEAR TERMINAL", lambda: self.terminal.clear()).pack(fill="x", pady=1)
        self._mk_util_btn(util, "[Q]  QUIT / EXIT", self._on_close,
                          fg=C_RED, border="#440000").pack(fill="x", pady=1)

        # Report count badge
        self._report_lbl = tk.Label(sb, text="REPORTS: 0 saved",
                                    font=FONT_XS, fg=C_DIM, bg=C_BG2)
        self._report_lbl.grid(row=7, column=0, sticky="ew", padx=10, pady=(2, 6))

    def _mk_util_btn(self, parent, text, cmd, fg=None, border=None):
        f = tk.Frame(parent, bg=C_DIM2,
                     highlightbackground=border or C_DIM,
                     highlightthickness=1)
        lbl = tk.Label(f, text=text, font=FONT_XS,
                       fg=fg or C_GREEN3, bg=C_DIM2, anchor="w", padx=8, pady=5)
        lbl.pack(fill="x")
        for w in (f, lbl):
            w.bind("<Button-1>", lambda _e, c=cmd: c())
            w.bind("<Enter>",    lambda _e, w=f, l=lbl, fg=fg: (
                w.configure(highlightbackground=C_GREEN3),
                l.configure(bg=C_DIM, fg=fg or C_GREEN2)
            ))
            w.bind("<Leave>",    lambda _e, w=f, l=lbl, fg=fg, b=border: (
                w.configure(highlightbackground=b or C_DIM),
                l.configure(bg=C_DIM2, fg=fg or C_GREEN3)
            ))
        return f

    # ── MAIN PANEL ────────────────────────────────────────────────────────
    def _build_main(self):
        main = tk.Frame(self, bg=C_BG)
        main.grid(row=0, column=1, sticky="nsew")
        main.grid_rowconfigure(1, weight=1)
        main.grid_columnconfigure(0, weight=1)

        # Title bar
        top = tk.Frame(main, bg=C_BG2,
                       highlightbackground=C_BORDER, highlightthickness=1)
        top.grid(row=0, column=0, sticky="ew")
        self._title_lbl = tk.Label(top,
                                   text="[ NSCS OS PROJECT — COMMAND CENTER ]",
                                   font=FONT_BOLD, fg=C_GREEN, bg=C_BG2, anchor="w")
        self._title_lbl.pack(side="left", padx=12, pady=6)
        self._status_lbl = tk.Label(top, text="●  READY",
                                    font=FONT_SM, fg=C_GREEN2, bg=C_BG2)
        self._status_lbl.pack(side="right", padx=12)

        # Terminal frame
        term_frame = tk.Frame(main, bg=C_BG,
                              highlightbackground=C_BORDER, highlightthickness=1)
        term_frame.grid(row=1, column=0, sticky="nsew", padx=4, pady=4)
        term_frame.grid_rowconfigure(0, weight=1)
        term_frame.grid_columnconfigure(0, weight=1)

        self.terminal = Terminal(term_frame)
        self.terminal.grid(row=0, column=0, sticky="nsew")

        sb = tk.Scrollbar(term_frame, command=self.terminal.yview,
                          bg=C_BG2, troughcolor=C_BG,
                          width=8, relief="flat", borderwidth=0)
        sb.grid(row=0, column=1, sticky="ns")
        self.terminal.configure(yscrollcommand=sb.set)

        # Progress bar
        self._progress = ProgressBar(main)
        self._progress.grid(row=2, column=0, sticky="ew", padx=4, pady=(0, 2))

        # Prompt bar
        prompt_bar = tk.Frame(main, bg=C_BG2,
                              highlightbackground=C_BORDER, highlightthickness=1)
        prompt_bar.grid(row=3, column=0, sticky="ew")

        tk.Label(prompt_bar, text="root@nscs-audit:~$",
                 font=FONT_BOLD, fg=C_GREEN, bg=C_BG2).pack(side="left", padx=(10, 6), pady=6)

        self._cmd_var = tk.StringVar()
        self._cmd_entry = tk.Entry(prompt_bar,
                                   textvariable=self._cmd_var,
                                   font=FONT,
                                   fg=C_GREEN, bg=C_BG,
                                   insertbackground=C_GREEN,
                                   relief="flat", borderwidth=0)
        self._cmd_entry.pack(side="left", fill="x", expand=True)
        self._cmd_entry.bind("<Return>", self._on_cmd)

        tk.Label(prompt_bar, text="[ENTER] to run",
                 font=FONT_XS, fg=C_GREEN3, bg=C_BG2).pack(side="right", padx=10)

    # ══════════════════════════════════════════════════════════════════════
    #  Clock
    # ══════════════════════════════════════════════════════════════════════
    def _start_clock(self):
        def tick():
            try:
                now = datetime.now().strftime("[ %a  %d %b %Y   %H:%M:%S ]")
                self._clock_lbl.configure(text=now)
                self._clock_job = self.after(1000, tick)
            except Exception:
                pass
        tick()

    # ══════════════════════════════════════════════════════════════════════
    #  Key bindings  (matches main_menu.sh: 1-6, L, C, Q)
    # ══════════════════════════════════════════════════════════════════════
    def _bind_keys(self):
        for key, label, subtitle, script, color, danger in MODULES:
            self.bind(key, lambda _e, k=key, s=script, l=label:
                      self._launch(k, l, s))
        self.bind("l", lambda _e: self._list_reports())
        self.bind("L", lambda _e: self._list_reports())
        self.bind("c", lambda _e: self.terminal.clear())
        self.bind("C", lambda _e: self.terminal.clear())
        self.bind("q", lambda _e: self._on_close())
        self.bind("Q", lambda _e: self._on_close())

    # ══════════════════════════════════════════════════════════════════════
    #  Boot Sequence
    # ══════════════════════════════════════════════════════════════════════
    def _run_boot_sequence(self):
        def run():
            lines = [
                ("head", "▶ NSCS OS PROJECT — BOOT SEQUENCE v2.0"),
                ("dim",  "─" * 56),
                ("dim",  f"[0.000000] Initializing kernel audit subsystem..."),
                ("",     f"[0.041233] Loading modules from: {MODULES_DIR}"),
            ]
            for key, label, subtitle, script, color, danger in MODULES:
                status = "[ OK ]" if (MODULES_DIR / script).exists() else "[MISSING]"
                tag = "ok" if status == "[ OK ]" else "warn"
                lines.append((tag, f"[0.{random.randint(100000,300000)}] {script:<30s} {status}"))

            lines += [
                ("warn", f"[0.290340] Checking log directory..."),
                ("ok",   f"[0.312500] {LOG_DIR} — [ OK ]"),
                ("ok",   "[0.340000] All systems nominal."),
                ("dim",  "─" * 56),
                ("head", ">>> SYSTEM READY — SELECT A MODULE  [1-6 / L / Q] <<<"),
            ]

            time.sleep(0.2)
            for tag, text in lines:
                if tag:
                    self.terminal.typewrite(text, tag, char_delay=0.0)
                else:
                    self.terminal.write(text)
                time.sleep(0.06)

        threading.Thread(target=run, daemon=True).start()

    # ══════════════════════════════════════════════════════════════════════
    #  Module Launch  — mirrors main_menu.sh's launch_module()
    # ══════════════════════════════════════════════════════════════════════
    def _launch(self, key, label, script_name):
        if self._running:
            self.terminal.write("\n[!!] A module is already running — please wait.", "warn")
            return

        script_path = MODULES_DIR / script_name

        def job():
            self._running = True
            self._set_active(key)
            self._set_status("● RUNNING", C_YELLOW)
            self._set_title(f"[ LAUNCHING  MODULE  0{key}  —  {label} ]")
            self._btns[key].set_status("RUNNING", C_YELLOW)
            self._progress.start_pulse()

            # Header
            self.terminal.clear()
            self.terminal.write(f"▶ LAUNCHING: {label}", "head")
            self.terminal.write("─" * 56, "dim")
            self.terminal.write(f"$ {script_path}", "dim")
            self.terminal.write(f"  Time   : {datetime.now().strftime('%H:%M:%S')}", "dim")
            self.terminal.write("")

            if not script_path.exists():
                # ── DEMO MODE (no real script) ─────────────────────────
                self.terminal.write(f"[!!] Script not found: {script_path}", "warn")
                self.terminal.write("     Running in DEMO mode...", "warn")
                self.terminal.write("")
                self._run_demo(label)
            else:
                # ── REAL MODE — execute the shell script ───────────────
                self._run_script(script_path, label)

            # Finish
            self._progress.stop_pulse()
            self._progress.set_pct(1.0)
            time.sleep(0.4)
            self._progress.set_pct(0.0)

            self._set_status("● READY", C_GREEN2)
            self._set_title("[ NSCS OS PROJECT — COMMAND CENTER ]")
            self._btns[key].set_status("READY")
            self._set_active(None)
            self._running = False

            # Update report count
            try:
                n = len(list(REPORT_DIR.glob("*")))
                self._report_lbl.configure(text=f"REPORTS: {n} saved",
                                           fg=C_GREEN3 if n else C_DIM)
            except Exception:
                pass

        threading.Thread(target=job, daemon=True).start()

    # ── Real script execution ──────────────────────────────────────────────
    def _run_script(self, script_path, label):
        import re
        ANSI = re.compile(r'\x1b\[[0-9;]*[mABCDEFGHJKSTfisu]'
                          r'|\x1b\(B|\x1b=|\r')
        SECTION_KW = [
            "motherboard","bios","cpu","gpu","memory","disk","partition",
            "network","usb","operating system","kernel","user account",
            "processes","services","firewall","security","package",
        ]
        DELAY = {"head":0.022,"ok":0.010,"err":0.016,"warn":0.016,
                 "white":0.008,"dim":0.005,"":0.005}

        try:
            script_path.chmod(script_path.stat().st_mode | 0o111)
            proc = subprocess.Popen(
                ["bash", str(script_path), "--gui"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env={**os.environ, "TERM": "dumb", "NO_COLOR": "1"},
            )
            buf = b""
            lc  = 0
            while True:
                ch = proc.stdout.read(1)
                if not ch:
                    break
                buf += ch
                if ch == b"\n":
                    raw  = buf.decode("utf-8", errors="replace").rstrip()
                    buf  = b""
                    line = ANSI.sub("", raw)
                    if not line.strip():
                        continue
                    garbled = sum(1 for c in line if ord(c) == 0xFFFD)
                    if garbled / max(len(line), 1) > 0.4:
                        continue

                    lo  = line.lower()
                    is_section = any(k in lo for k in SECTION_KW)
                    tag = ""
                    if any(w in lo for w in ["error","fail","[x]"]):
                        tag = "err"
                    elif any(w in lo for w in ["[ ok ]","[ok]","success","saved","complete"]):
                        tag = "ok"
                    elif any(w in lo for w in ["warn","[!!]","caution","inactive"]):
                        tag = "warn"
                    elif any(w in lo for w in [">>>","initializing","launching"]):
                        tag = "head"
                    elif "▶" in line or "▸" in line:
                        tag = "white"
                    else:
                        tag = "dim"

                    if is_section and lc > 0:
                        self.terminal.write("")
                        self.terminal.write("  " + "─" * 52, "dim")
                        self.terminal.write("")
                        time.sleep(0.15)

                    self.terminal.typewrite(line, tag, char_delay=DELAY.get(tag, 0.006))
                    lc += 1
                    time.sleep(0.04)

            proc.wait()
            code = proc.returncode
            self.terminal.write("")
            if code == 0:
                self.terminal.write(f"[✓] {label} completed successfully.", "ok")
            else:
                self.terminal.write(f"[✗] Process exited with code {code}.", "err")

        except Exception as exc:
            self.terminal.write(f"[✗] Failed to launch module: {exc}", "err")

    # ── Demo mode (same as original but cleaner) ───────────────────────────
    DEMO_DATA = {
        "HARDWARE AUDIT": [
            ("",    "Scanning CPU information..."),
            ("ok",  "[OK] CPU: Intel Core i7-12700K @ 3.60GHz (12 cores / 20 threads)"),
            ("ok",  "[OK] CPU Cache: L1=480KB  L2=12MB  L3=25MB"),
            ("",    "Scanning memory..."),
            ("ok",  "[OK] RAM: 32768 MB DDR5 @ 4800 MHz — 2 DIMMs installed"),
            ("",    "Scanning storage devices..."),
            ("ok",  "[OK] /dev/nvme0n1: 512 GB NVMe SSD — SAMSUNG 980 PRO"),
            ("ok",  "[OK] /dev/sda:      2.0 TB HDD — Seagate Barracuda"),
            ("",    "Scanning GPU..."),
            ("ok",  "[OK] GPU: NVIDIA GeForce RTX 3070 Ti (8192 MB VRAM)"),
            ("ok",  "[OK] Driver: 535.171.04  |  CUDA: 12.3"),
            ("",    "Scanning network interfaces..."),
            ("ok",  "[OK] eth0:  1 Gbps Ethernet — UP — 192.168.1.42/24"),
            ("ok",  "[OK] wlan0: 802.11ax Wi-Fi — UP"),
            ("ok",  f"[✓] Report saved → {REPORT_DIR}/hardware_report.json"),
        ],
        "SOFTWARE AUDIT": [
            ("",    "Checking kernel version..."),
            ("ok",  "[OK] Kernel: Linux 6.5.0-35-generic #35-Ubuntu SMP x86_64"),
            ("",    "Enumerating installed packages..."),
            ("ok",  "[OK] dpkg: 1,847 packages installed"),
            ("ok",  "[OK] snap:     12 snaps active"),
            ("",    "Scanning running services..."),
            ("ok",  "[OK] Active: 43  |  Enabled: 12  |  Failed: 0"),
            ("",    "Checking user accounts..."),
            ("ok",  "[OK] Users: root / nscs / audit"),
            ("",    "Checking firewall status..."),
            ("ok",  "[OK] UFW: active — 3 rules"),
            ("ok",  f"[✓] Report saved → {REPORT_DIR}/software_audit.json"),
        ],
        "GENERATE REPORTS": [
            ("",    "Loading audit data..."),
            ("ok",  "[OK] hardware_report.json   loaded (48 KB)"),
            ("ok",  "[OK] software_audit.json    loaded (32 KB)"),
            ("",    "Generating TXT summary..."),
            ("ok",  "[OK] audit_summary.txt      created (18 KB)"),
            ("",    "Generating HTML dashboard..."),
            ("ok",  "[OK] report.html            created (94 KB)"),
            ("",    "Generating PDF summary..."),
            ("ok",  "[OK] audit_summary.pdf      created (2.1 MB)"),
            ("ok",  f"[✓] All reports saved → {REPORT_DIR}/"),
        ],
        "SEND REPORTS": [
            ("",    "Configuring SMTP relay..."),
            ("ok",  "[OK] SMTP: smtp.gmail.com:587 — STARTTLS"),
            ("",    "Authenticating..."),
            ("ok",  "[OK] OAuth2 credentials loaded"),
            ("",    "Attaching reports..."),
            ("ok",  "[OK] audit_summary.pdf   2.1 MB  attached"),
            ("ok",  "[OK] report.html          94 KB   attached"),
            ("ok",  "[OK] Delivered → admin@nscs.edu"),
            ("ok",  "[✓] Email transmission complete"),
        ],
        "CRON AUTOMATION": [
            ("",    "Loading cron configuration..."),
            ("ok",  "[OK] Daily audit:    0 2 * * *   (02:00 AM every day)"),
            ("ok",  "[OK] Weekly report:  0 8 * * 1   (Monday 08:00)"),
            ("ok",  "[OK] Email dispatch: 30 8 * * 1  (Monday 08:30)"),
            ("ok",  "[OK] Log rotation:   0 0 * * 0   (weekly)"),
            ("ok",  "[✓] Cron entries written — automation active"),
        ],
        "REMOTE MONITOR": [
            ("",    "Initializing SSH connections..."),
            ("ok",  "[OK] 192.168.1.10   ONLINE   latency: 12ms"),
            ("ok",  "[OK] 192.168.1.11   ONLINE   latency:  8ms"),
            ("ok",  "[OK] 192.168.1.12   ONLINE   latency: 15ms"),
            ("warn","[!!] 192.168.1.13   TIMEOUT  latency: ---ms"),
            ("",    "Collecting remote metrics..."),
            ("ok",  "[OK] CPU usage avg: 14%  across 3 nodes"),
            ("ok",  "[OK] RAM usage avg: 61%  across 3 nodes"),
            ("",    "Starting monitoring daemon..."),
            ("ok",  "[OK] Daemon started — PID 4821"),
            ("ok",  "[✓] Remote telemetry stream LIVE"),
        ],
    }

    def _run_demo(self, label):
        lines = self.DEMO_DATA.get(label.upper(),
                [("warn", "[DEMO] No demo data for this module.")])
        total = len(lines)
        for i, (tag, text) in enumerate(lines):
            if not text:
                self.terminal.write("")
            else:
                delay = {"ok":0.010, "warn":0.014, "err":0.016}.get(tag, 0.006)
                self.terminal.typewrite(text, tag, char_delay=delay)
            self._progress.set_pct((i + 1) / total * 0.9)
            time.sleep(0.15)

    # ══════════════════════════════════════════════════════════════════════
    #  List Reports  — mirrors main_menu.sh's list_reports()
    # ══════════════════════════════════════════════════════════════════════
    def _list_reports(self):
        if self._running:
            return
        def run():
            self.terminal.clear()
            self.terminal.write("▶ SAVED REPORTS", "head")
            self.terminal.write("─" * 56, "dim")
            self.terminal.write(f"  Directory: {REPORT_DIR}", "dim")
            self.terminal.write("")

            if not REPORT_DIR.exists():
                self.terminal.write(f"[!!] Directory not found: {REPORT_DIR}", "warn")
                return

            EXT_COLOR = {"json":"ok", "txt":"white", "html":"info", "pdf":"warn"}
            found = False
            for f in sorted(REPORT_DIR.iterdir()):
                if not f.is_file():
                    continue
                found = True
                ext   = f.suffix.lstrip(".")
                color = EXT_COLOR.get(ext, "dim")
                try:
                    size = f"{f.stat().st_size / 1024:.1f} KB"
                except Exception:
                    size = "?"
                self.terminal.typewrite(
                    f"  [{ext.upper():4s}]  {f.name:<40s}  {size}",
                    color, char_delay=0.004
                )
                time.sleep(0.04)

            if not found:
                self.terminal.write("[!!] No reports found.", "warn")
                self.terminal.write("     Run modules 1→2 first, then module 3.", "dim")

            self.terminal.write("")
            self.terminal.write("─" * 56, "dim")

        threading.Thread(target=run, daemon=True).start()

    # ══════════════════════════════════════════════════════════════════════
    #  Command Entry  — mirrors bash main_menu.sh prompt
    # ══════════════════════════════════════════════════════════════════════
    def _on_cmd(self, _event):
        cmd = self._cmd_var.get().strip()
        self._cmd_var.set("")
        if not cmd:
            return
        self.terminal.write(f"\nroot@nscs-audit:~$ {cmd}", "prompt")

        # Module shortcuts
        for key, label, subtitle, script, color, danger in MODULES:
            if cmd == key or cmd.upper() == f"F{key}":
                self._launch(key, label, script)
                return

        # Other commands
        cmd_l = cmd.lower()
        if cmd_l in ("l", "list"):
            self._list_reports()
        elif cmd_l in ("q", "quit", "exit", "0"):
            self._on_close()
        elif cmd_l in ("c", "clear"):
            self.terminal.clear()
        elif cmd_l == "whoami":
            self.terminal.write("root", "ok")
        elif cmd_l in ("uname", "uname -a"):
            self.terminal.write(
                f"Linux {os.uname().nodename} {os.uname().release} "
                f"#1 SMP {os.uname().machine} GNU/Linux", "ok"
            )
        elif cmd_l == "ls modules/":
            if MODULES_DIR.exists():
                for f in sorted(MODULES_DIR.glob("*.sh")):
                    self.terminal.write(f"  -rwxr-xr-x  {f.name}", "ok")
            else:
                self.terminal.write(f"  ls: {MODULES_DIR}: No such directory", "warn")
        elif cmd_l == "pwd":
            self.terminal.write(str(SCRIPT_DIR), "ok")
        elif cmd_l == "date":
            self.terminal.write(datetime.now().strftime("%A %d %B %Y %H:%M:%S"), "ok")
        elif cmd_l in ("help", "?"):
            self.terminal.write("  Commands: 1-6  L  C  Q  whoami  uname  pwd  date  ls modules/", "dim")
        else:
            self.terminal.write(f"  bash: {cmd}: command not found", "err")
            self.terminal.write("  Type 'help' for available commands.", "dim")

    # ══════════════════════════════════════════════════════════════════════
    #  Helpers
    # ══════════════════════════════════════════════════════════════════════
    def _set_title(self, text):
        try: self._title_lbl.configure(text=text)
        except Exception: pass

    def _set_status(self, text, color=None):
        try: self._status_lbl.configure(text=text, fg=color or C_GREEN2)
        except Exception: pass

    def _set_active(self, key):
        if self._active_id and self._active_id in self._btns:
            self._btns[self._active_id].set_active(False)
        self._active_id = key
        if key and key in self._btns:
            self._btns[key].set_active(True)

    # ══════════════════════════════════════════════════════════════════════
    #  Shutdown  — mirrors main_menu.sh quit block
    # ══════════════════════════════════════════════════════════════════════
    def _on_close(self):
        self._matrix.stop()
        if self._clock_job:
            try: self.after_cancel(self._clock_job)
            except Exception: pass

        self.terminal.clear()
        self.terminal.write("▶ SHUTDOWN SEQUENCE", "head")
        self.terminal.write("─" * 40, "dim")
        msgs = [
            "Flushing log buffers...",
            "Closing module handles...",
            "Stopping background services...",
            "Saving session state...",
            "Goodbye.",
        ]
        for m in msgs:
            self.terminal.write(f"  {m}", "dim")
            self.update()
            time.sleep(0.22)
        self.after(500, self.destroy)


# ══════════════════════════════════════════════════════════════════════════════
#  Entry Point
# ══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    app = NSCSApp()
    app.mainloop()
