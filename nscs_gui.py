#!/usr/bin/env python3
"""
NSCS OS Project — Hacker GUI (CustomTkinter Edition)
A standalone desktop GUI that orchestrates all audit modules
with matrix rain, animated terminal output, and full hacker aesthetic.
"""

import customtkinter as ctk
import tkinter as tk
import subprocess
import threading
import random
import time
import os
import sys
from datetime import datetime
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR  = Path(__file__).parent.resolve()
MODULES_DIR = SCRIPT_DIR / "modules"
LOG_DIR     = Path.home() / "nscs_os_project"
REPORT_DIR  = LOG_DIR / "reports"

# ── Theme ──────────────────────────────────────────────────────────────────
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("green")

# Palette
C_BG       = "#000000"
C_BG2      = "#050d05"
C_PANEL    = "#060f06"
C_BORDER   = "#0a2a0a"
C_GREEN    = "#00ff41"
C_GREEN2   = "#00cc33"
C_GREEN3   = "#005512"
C_DIM      = "#003a0a"
C_YELLOW   = "#ffcc00"
C_RED      = "#ff3333"
C_WHITE    = "#e8ffe8"
C_CYAN     = "#00ffcc"

MONO_FONT  = ("Courier New", 11)
MONO_SM    = ("Courier New", 9)
MONO_LG    = ("Courier New", 13, "bold")
MONO_XL    = ("Courier New", 18, "bold")
MONO_TITLE = ("Courier New", 10)

# Matrix characters
MATRIX_CHARS = "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789ABCDEF"


# ══════════════════════════════════════════════════════════════════════════════
#  Matrix Rain Canvas
# ══════════════════════════════════════════════════════════════════════════════

class MatrixRain(tk.Canvas):
    def __init__(self, master, **kwargs):
        super().__init__(master, bg=C_BG, highlightthickness=0, **kwargs)
        self.cols   = []
        self.drops  = []
        self.texts  = []
        self._after = None
        self.bind("<Configure>", self._on_resize)
        self._running = False

    def start(self):
        self._running = True
        self._init_columns()
        self._tick()

    def stop(self):
        self._running = False
        if self._after:
            try:
                self.after_cancel(self._after)
            except Exception:
                pass

    def _init_columns(self):
        self.delete("all")
        self.texts = []
        self.drops = []
        w = self.winfo_width()  or 200
        h = self.winfo_height() or 400
        col_w = 14
        n = max(1, w // col_w)
        for i in range(n):
            x = i * col_w + 7
            drop = random.randint(0, h // 14)
            self.drops.append(drop)
            items = []
            rows = h // 14 + 2
            for j in range(rows):
                ch = random.choice(MATRIX_CHARS)
                y  = j * 14
                txt = self.create_text(x, y, text=ch, font=("Courier New", 9),
                                       fill=C_DIM, anchor="center")
                items.append(txt)
            self.texts.append(items)

    def _on_resize(self, _event):
        self._init_columns()

    def _tick(self):
        if not self._running:
            return
        h = self.winfo_height() or 400
        rows = h // 14 + 2
        for col_idx, (drop, items) in enumerate(zip(self.drops, self.texts)):
            for row_idx, txt in enumerate(items):
                dist = row_idx - drop
                if dist == 0:
                    self.itemconfigure(txt, fill=C_GREEN,
                                       text=random.choice(MATRIX_CHARS))
                elif dist == -1:
                    self.itemconfigure(txt, fill=C_GREEN2,
                                       text=random.choice(MATRIX_CHARS))
                elif -4 < dist < 0:
                    self.itemconfigure(txt, fill=C_GREEN3,
                                       text=random.choice(MATRIX_CHARS))
                elif dist < 0:
                    self.itemconfigure(txt, fill=C_DIM)
                else:
                    self.itemconfigure(txt, fill=C_BG)

            self.drops[col_idx] = (drop + 1) % (rows + random.randint(5, 20))

        self._after = self.after(60, self._tick)


# ══════════════════════════════════════════════════════════════════════════════
#  Animated Terminal Output Widget
# ══════════════════════════════════════════════════════════════════════════════

class TerminalOutput(tk.Text):
    def __init__(self, master, **kwargs):
        super().__init__(
            master,
            bg=C_BG2, fg=C_GREEN2,
            insertbackground=C_GREEN,
            font=MONO_SM,
            relief="flat",
            borderwidth=0,
            wrap="word",
            state="disabled",
            cursor="arrow",
            **kwargs
        )
        self.tag_configure("ok",      foreground=C_GREEN)
        self.tag_configure("warn",    foreground=C_YELLOW)
        self.tag_configure("err",     foreground=C_RED)
        self.tag_configure("head",    foreground=C_CYAN, font=("Courier New", 10, "bold"))
        self.tag_configure("dim",     foreground=C_DIM)
        self.tag_configure("prompt",  foreground=C_GREEN2)
        self.tag_configure("white",   foreground=C_WHITE)

    def clear(self):
        self.configure(state="normal")
        self.delete("1.0", "end")
        self.configure(state="disabled")

    def append(self, text, tag="", newline=True):
        self.configure(state="normal")
        self.insert("end", text + ("\n" if newline else ""), tag or ())
        self.see("end")
        self.configure(state="disabled")

    def stream_line(self, text, tag="", delay=0.0):
        """Write character by character for typewriter effect."""
        self.configure(state="normal")
        for ch in text:
            self.insert("end", ch, tag or ())
            self.see("end")
            self.update_idletasks()
            if delay:
                time.sleep(delay)
        self.insert("end", "\n", tag or ())
        self.see("end")
        self.configure(state="disabled")


# ══════════════════════════════════════════════════════════════════════════════
#  Progress Bar (custom, glowing)
# ══════════════════════════════════════════════════════════════════════════════

class GlowProgressBar(tk.Canvas):
    def __init__(self, master, **kwargs):
        super().__init__(master, bg=C_BG2, highlightthickness=0,
                         height=6, **kwargs)
        self._pct = 0.0
        self.bind("<Configure>", lambda _e: self._draw())

    def set(self, pct):
        self._pct = max(0.0, min(1.0, pct))
        self._draw()

    def _draw(self):
        self.delete("all")
        w = self.winfo_width()
        h = self.winfo_height() or 6
        # Track
        self.create_rectangle(0, 0, w, h, fill=C_DIM, outline="")
        # Fill
        fw = int(w * self._pct)
        if fw > 0:
            self.create_rectangle(0, 0, fw, h, fill=C_GREEN2, outline="")
            # Bright tip
            tip = min(fw, 6)
            self.create_rectangle(fw - tip, 0, fw, h, fill=C_GREEN, outline="")


# ══════════════════════════════════════════════════════════════════════════════
#  Module Button
# ══════════════════════════════════════════════════════════════════════════════

class ModuleButton(tk.Frame):
    def __init__(self, master, number, label, phase, command, danger=False, **kwargs):
        super().__init__(master, bg=C_PANEL, **kwargs)
        self._cmd     = command
        self._danger  = danger
        self._active  = False
        self._hovered = False

        acc = C_RED if danger else C_GREEN
        acc2 = "#440000" if danger else C_DIM

        # Outer border frame (simulates clip-path corner effect)
        self.configure(
            highlightbackground=acc2,
            highlightthickness=1,
            padx=0, pady=0
        )

        inner = tk.Frame(self, bg=C_PANEL, padx=12, pady=8)
        inner.pack(fill="both", expand=True)

        num_lbl = tk.Label(inner, text=f"[{number}]",
                           font=("Courier New", 11, "bold"),
                           fg=acc, bg=C_PANEL)
        num_lbl.pack(side="left", padx=(0, 10))

        txt_frame = tk.Frame(inner, bg=C_PANEL)
        txt_frame.pack(side="left", fill="both", expand=True)

        tk.Label(txt_frame, text=label,
                 font=("Courier New", 10, "bold"),
                 fg=C_WHITE, bg=C_PANEL,
                 anchor="w").pack(fill="x")

        tk.Label(txt_frame, text=phase,
                 font=("Courier New", 8),
                 fg=C_GREEN3, bg=C_PANEL,
                 anchor="w").pack(fill="x")

        # Bind clicks & hover to all children recursively
        for widget in [self, inner, num_lbl, txt_frame] + list(txt_frame.winfo_children()) + list(inner.winfo_children()):
            widget.bind("<Button-1>",   self._on_click)
            widget.bind("<Enter>",      self._on_enter)
            widget.bind("<Leave>",      self._on_leave)

        self._inner    = inner
        self._num_lbl  = num_lbl
        self._acc      = acc
        self._acc2     = acc2
        self._all_widgets = [self, inner, num_lbl, txt_frame] + list(txt_frame.winfo_children())

    def _on_enter(self, _e):
        self._hovered = True
        self._refresh()

    def _on_leave(self, _e):
        self._hovered = False
        self._refresh()

    def _on_click(self, _e):
        if self._cmd:
            self._cmd()

    def set_active(self, state: bool):
        self._active = state
        self._refresh()

    def _refresh(self):
        if self._active or self._hovered:
            bg = "#0a1a0a" if not self._danger else "#1a0000"
            hl = self._acc
        else:
            bg = C_PANEL
            hl = self._acc2
        self.configure(highlightbackground=hl)
        self._inner.configure(bg=bg)
        self._num_lbl.configure(bg=bg)
        for w in self.winfo_children():
            try:
                w.configure(bg=bg)
                for ww in w.winfo_children():
                    try:
                        ww.configure(bg=bg)
                        for www in ww.winfo_children():
                            try: www.configure(bg=bg)
                            except Exception: pass
                    except Exception: pass
            except Exception:
                pass


# ══════════════════════════════════════════════════════════════════════════════
#  Main Application
# ══════════════════════════════════════════════════════════════════════════════

class NSCSApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("NSCS — Linux Audit & Monitoring System v2.0.26")
        self.geometry("1100x720")
        self.minsize(900, 600)
        self.configure(fg_color=C_BG)

        # Make dirs
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        REPORT_DIR.mkdir(parents=True, exist_ok=True)

        self._running_job  = None
        self._active_btn   = None
        self._clock_after  = None

        self._build_ui()
        self._start_clock()
        self._boot_sequence()

        self.protocol("WM_DELETE_WINDOW", self._on_close)

    # ── UI Construction ────────────────────────────────────────────────────

    def _build_ui(self):
        # ── Root grid: left sidebar | right content
        self.grid_columnconfigure(0, weight=0, minsize=320)
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # ── LEFT SIDEBAR ──────────────────────────────────────────────────
        sidebar = tk.Frame(self, bg=C_BG2,
                           highlightbackground=C_DIM,
                           highlightthickness=1)
        sidebar.grid(row=0, column=0, sticky="nsew")
        sidebar.grid_rowconfigure(3, weight=1)

        # Matrix rain header
        self.matrix = MatrixRain(sidebar, width=320, height=120)
        self.matrix.pack(fill="x")

        # ASCII banner over matrix (overlay label)
        banner_frame = tk.Frame(sidebar, bg=C_BG2)
        banner_frame.pack(fill="x", padx=8, pady=(4, 0))

        ascii_art = (
            " ███╗   ██╗███████╗ ██████╗███████╗\n"
            " ████╗  ██║██╔════╝██╔════╝██╔════╝\n"
            " ██╔██╗ ██║███████╗██║     ███████╗\n"
            " ██║╚██╗██║╚════██║██║     ╚════██║\n"
            " ██║ ╚████║███████║╚██████╗███████║\n"
            " ╚═╝  ╚═══╝╚══════╝ ╚═════╝╚══════╝"
        )
        tk.Label(banner_frame, text=ascii_art,
                 font=("Courier New", 7, "bold"),
                 fg=C_GREEN, bg=C_BG2,
                 justify="left").pack(anchor="w")

        tk.Label(banner_frame,
                 text="Linux Audit & Monitoring System  v2.0.26",
                 font=("Courier New", 8),
                 fg=C_GREEN3, bg=C_BG2).pack(anchor="w", pady=(2, 0))

        # Divider
        tk.Frame(sidebar, bg=C_DIM, height=1).pack(fill="x", pady=6)

        # Clock
        self.clock_lbl = tk.Label(sidebar,
                                  text="",
                                  font=("Courier New", 10, "bold"),
                                  fg=C_GREEN2, bg=C_BG2)
        self.clock_lbl.pack(fill="x", padx=12, pady=(0, 4))

        # System info row
        info = tk.Label(sidebar,
                        text=f"HOST: {os.uname().nodename}   USER: {os.getenv('USER','root')}",
                        font=("Courier New", 8),
                        fg=C_GREEN3, bg=C_BG2)
        info.pack(fill="x", padx=12)

        tk.Frame(sidebar, bg=C_DIM, height=1).pack(fill="x", pady=6)

        # ── MENU BUTTONS ──────────────────────────────────────────────────
        menu_label = tk.Label(sidebar, text="█ SYSTEM MENU",
                              font=("Courier New", 9, "bold"),
                              fg=C_GREEN3, bg=C_BG2, anchor="w")
        menu_label.pack(fill="x", padx=12, pady=(0, 6))

        modules = [
            ("1",  "Hardware Audit",        "Phase 1 — audit_hardware_v2.sh",  self._run_hardware),
            ("2",  "Software Audit",         "Phase 1 — audit_software.sh",     self._run_software),
            ("3",  "Generate Reports",       "Phase 2 — generate_reports.sh",   self._run_reports),
            ("4",  "Send Email Reports",     "Phase 3 — send_reports.sh",       self._run_email),
            ("5",  "Setup Cron Jobs",        "Phase 4 — setup_cron.sh",         self._run_cron),
            ("6",  "Remote Monitoring",      "Phase 5 — remote_monitor.sh",     self._run_remote),
            ("10", "Help & Documentation",   "View docs",                       self._run_help),
        ]

        self._btns = {}
        btn_frame = tk.Frame(sidebar, bg=C_BG2)
        btn_frame.pack(fill="x", padx=8)

        for num, label, phase, cmd in modules:
            btn = ModuleButton(btn_frame, num, label, phase, cmd)
            btn.pack(fill="x", pady=2)
            self._btns[num] = btn

        tk.Frame(sidebar, bg=C_DIM, height=1).pack(fill="x", pady=6)

        exit_btn = ModuleButton(sidebar, "0", "Exit System", "Terminate session",
                                self._on_close, danger=True)
        exit_btn.pack(fill="x", padx=8, pady=(0, 8))

        # Deadline label
        tk.Label(sidebar,
                 text="DEADLINE: MAR 30, 2026 @ 08:00",
                 font=("Courier New", 8, "bold"),
                 fg="#444400", bg=C_BG2).pack(pady=(0, 8))

        # ── RIGHT PANEL ───────────────────────────────────────────────────
        right = tk.Frame(self, bg=C_BG)
        right.grid(row=0, column=1, sticky="nsew")
        right.grid_rowconfigure(1, weight=1)
        right.grid_columnconfigure(0, weight=1)

        # Top bar
        top_bar = tk.Frame(right, bg=C_BG2, height=36,
                           highlightbackground=C_DIM, highlightthickness=1)
        top_bar.grid(row=0, column=0, sticky="ew")
        top_bar.grid_propagate(False)

        self.module_title = tk.Label(top_bar,
                                     text="[ NSCS AUDIT SYSTEM — SELECT A MODULE ]",
                                     font=("Courier New", 10, "bold"),
                                     fg=C_GREEN, bg=C_BG2, anchor="w")
        self.module_title.pack(side="left", padx=12, pady=6)

        self.status_dot = tk.Label(top_bar, text="●  READY",
                                   font=("Courier New", 9),
                                   fg=C_GREEN2, bg=C_BG2)
        self.status_dot.pack(side="right", padx=12)

        # Terminal output area
        term_frame = tk.Frame(right, bg=C_BG,
                              highlightbackground=C_DIM, highlightthickness=1)
        term_frame.grid(row=1, column=0, sticky="nsew", padx=4, pady=4)
        term_frame.grid_rowconfigure(0, weight=1)
        term_frame.grid_columnconfigure(0, weight=1)

        self.terminal = TerminalOutput(term_frame)
        self.terminal.grid(row=0, column=0, sticky="nsew")

        scroll = tk.Scrollbar(term_frame, command=self.terminal.yview,
                              bg=C_BG2, troughcolor=C_BG, width=8,
                              relief="flat", borderwidth=0)
        scroll.grid(row=0, column=1, sticky="ns")
        self.terminal.configure(yscrollcommand=scroll.set)

        # Progress bar
        self.progress = GlowProgressBar(right)
        self.progress.grid(row=2, column=0, sticky="ew", padx=4, pady=(0, 2))

        # Bottom prompt bar
        bottom = tk.Frame(right, bg=C_BG2,
                          highlightbackground=C_DIM, highlightthickness=1)
        bottom.grid(row=3, column=0, sticky="ew")

        tk.Label(bottom, text="root@nscs-audit:~$",
                 font=("Courier New", 10, "bold"),
                 fg=C_GREEN, bg=C_BG2).pack(side="left", padx=(10, 6), pady=6)

        self.cmd_var = tk.StringVar()
        self.cmd_entry = tk.Entry(bottom,
                                  textvariable=self.cmd_var,
                                  font=("Courier New", 10),
                                  fg=C_GREEN, bg=C_BG, insertbackground=C_GREEN,
                                  relief="flat", borderwidth=0)
        self.cmd_entry.pack(side="left", fill="x", expand=True, padx=(0, 10))
        self.cmd_entry.bind("<Return>", self._on_cmd_enter)

        tk.Label(bottom, text="[ENTER] to run",
                 font=("Courier New", 8),
                 fg=C_GREEN3, bg=C_BG2).pack(side="right", padx=10)

        # Start matrix
        self.after(200, self.matrix.start)

    # ── Clock ──────────────────────────────────────────────────────────────

    def _start_clock(self):
        def tick():
            now = datetime.now().strftime("%A %d %b %Y   %H:%M:%S")
            try:
                self.clock_lbl.configure(text=f"[ {now} ]")
            except Exception:
                return
            self._clock_after = self.after(1000, tick)
        tick()

    # ── Boot sequence ──────────────────────────────────────────────────────

    def _boot_sequence(self):
        def run():
            lines = [
                ("head", "▶ NSCS AUDIT SYSTEM — BOOT SEQUENCE", 0.0),
                ("dim",  "─" * 54, 0.0),
                ("dim",  "[0.000000] Initializing kernel audit subsystem...", 0.04),
                ("",     "[0.041233] Loading modules from: " + str(MODULES_DIR), 0.04),
                ("ok",   "[0.088712] audit_hardware_v2.sh ............ [ OK ]", 0.04),
                ("ok",   "[0.120441] audit_software.sh ............... [ OK ]", 0.04),
                ("ok",   "[0.155890] generate_reports.sh ............. [ OK ]", 0.04),
                ("ok",   "[0.189003] send_reports.sh ................. [ OK ]", 0.04),
                ("ok",   "[0.221567] setup_cron.sh ................... [ OK ]", 0.04),
                ("ok",   "[0.255100] remote_monitor.sh ............... [ OK ]", 0.04),
                ("warn", "[0.290340] Checking log directory...", 0.04),
                ("ok",   f"[0.312500] {LOG_DIR} ........... [ OK ]", 0.04),
                ("ok",   "[0.340000] All systems nominal — interface ready.", 0.04),
                ("dim",  "─" * 54, 0.0),
                ("head", ">>> SYSTEM READY — SELECT A MODULE <<<", 0.0),
            ]
            time.sleep(0.3)
            for tag, text, delay in lines:
                self.terminal.stream_line(text, tag, delay=delay)
                time.sleep(0.07)

        threading.Thread(target=run, daemon=True).start()

    # ── Module execution ───────────────────────────────────────────────────

    def _set_active_btn(self, key):
        if self._active_btn:
            try:
                self._btns[self._active_btn].set_active(False)
            except Exception:
                pass
        self._active_btn = key
        if key and key in self._btns:
            self._btns[key].set_active(True)

    def _set_status(self, text, color=None):
        self.status_dot.configure(text=text, fg=color or C_GREEN2)

    def _run_module(self, btn_key, title, script_name):
        if self._running_job and self._running_job.is_alive():
            self.terminal.append("\n[!!] A module is already running — please wait.", "warn")
            return

        def job():
            self._set_active_btn(btn_key)
            self._set_status("● RUNNING", C_YELLOW)
            self.module_title.configure(text=f"[ EXECUTING: {title.upper()} ]")

            self.terminal.clear()
            self.terminal.append(f"▶ LAUNCHING: {title}", "head")
            self.terminal.append("─" * 54, "dim")
            self.terminal.append(f"$ {MODULES_DIR / script_name}", "dim")
            self.terminal.append("")

            script_path = MODULES_DIR / script_name

            if not script_path.exists():
                # Simulate if module not present
                self.terminal.append(f"[!!] Module not found: {script_path}", "warn")
                self.terminal.append("     Running in DEMO mode...", "warn")
                self.terminal.append("")
                self._demo_run(title)
            else:
                # Make executable
                script_path.chmod(script_path.stat().st_mode | 0o111)
                # Run real script — read raw bytes, strip ANSI, decode safely
                try:
                    import re
                    ansi_escape = re.compile(
                        r'\x1b\[[0-9;]*[mABCDEFGHJKSTfisu]'
                        r'|\x1b\(B|\x1b=|\r'
                    )
                    proc = subprocess.Popen(
                        ["bash", str(script_path), "--gui"],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        env={**os.environ, "TERM": "dumb", "NO_COLOR": "1"},
                    )
                    buf = b""
                    line_count = 0
                    section_keywords = [
                        "motherboard", "bios", "cpu information", "gpu", "memory",
                        "disk", "partition", "network interface", "usb",
                        "operating system", "kernel", "user account",
                        "processes", "services", "network exposure",
                        "package", "firewall", "security",
                    ]

                    while True:
                        ch = proc.stdout.read(1)
                        if not ch:
                            break
                        buf += ch
                        if ch == b"\n":
                            line = buf.decode("utf-8", errors="replace").rstrip()
                            buf = b""
                            line = ansi_escape.sub("", line)
                            if not line.strip():
                                continue
                            clean = line.strip()
                            if clean:
                                garbled = sum(1 for c in clean if ord(c) == 0xfffd)
                                if garbled / len(clean) > 0.4:
                                    continue

                            lo = line.lower()

                            # detect section header lines
                            is_section = any(kw in lo for kw in section_keywords)

                            # classify tag
                            tag = ""
                            if any(w in lo for w in ["error", "fail", "[x]"]):
                                tag = "err"
                            elif any(w in lo for w in ["[ ok ]", "ok ]", "success", "[ok]", "saved", "complete", "[auto]"]):
                                tag = "ok"
                            elif any(w in lo for w in ["warn", "[!!]", "caution", "inactive", "risk"]):
                                tag = "warn"
                            elif any(w in lo for w in [">>>", "initializing", "launching"]):
                                tag = "head"
                            elif "\u25b6" in line or "\u25b8" in line:
                                tag = "white"
                            else:
                                tag = "dim"

                            # insert visual section break
                            if is_section and line_count > 0:
                                self.terminal.append("", "")
                                self.terminal.append("  " + "\u2500" * 52, "dim")
                                self.terminal.append("", "")
                                time.sleep(0.18)

                            # typewriter delays per tag
                            delay_map = {"head": 0.025, "ok": 0.012, "err": 0.018,
                                         "warn": 0.018, "white": 0.010, "dim": 0.006, "": 0.006}
                            self.terminal.stream_line(line, tag, delay=delay_map.get(tag, 0.008))

                            # animate progress bar slowly when script prints a bar line
                            if "[" in line and "\u2588" in line:
                                for step in range(11):
                                    self.progress.set(step / 10)
                                    time.sleep(0.10)
                            else:
                                self._progress_pulse()

                            line_count += 1
                            # small pause between data lines
                            if tag in ("white", "dim") and not is_section:
                                time.sleep(0.055)
                    proc.wait()
                    code = proc.returncode
                    self.terminal.append("")
                    if code == 0:
                        self.terminal.append(f"[✓] {title} completed successfully.", "ok")
                    else:
                        self.terminal.append(f"[✗] Process exited with code {code}.", "err")
                except Exception as exc:
                    self.terminal.append(f"[✗] Failed to run module: {exc}", "err")

            self.progress.set(1.0)
            time.sleep(0.4)
            self.progress.set(0.0)
            self._set_status("● READY", C_GREEN2)
            self.module_title.configure(text="[ NSCS AUDIT SYSTEM — SELECT A MODULE ]")
            self._set_active_btn(None)

        self._running_job = threading.Thread(target=job, daemon=True)
        self._running_job.start()

    def _progress_pulse(self):
        """Indeterminate progress animation — call from worker thread."""
        import math
        t = time.time()
        val = (math.sin(t * 3) + 1) / 2
        try:
            self.progress.set(val)
        except Exception:
            pass

    def _demo_run(self, title):
        """Fake animated output when module script is missing."""
        demo_lines = {
            "Hardware Audit": [
                ("", "Scanning CPU information..."),
                ("ok", "[OK] CPU: Intel Core i7-12700K @ 3.60GHz (12 cores)"),
                ("", "Scanning memory..."),
                ("ok", "[OK] RAM: 32768 MB DDR5 @ 4800 MHz"),
                ("", "Scanning storage devices..."),
                ("ok", "[OK] /dev/nvme0n1: 512 GB NVMe SSD"),
                ("ok", "[OK] /dev/sda: 2.0 TB HDD"),
                ("", "Scanning GPU..."),
                ("ok", "[OK] GPU: NVIDIA GeForce RTX 3070 Ti (8192 MB)"),
                ("", "Scanning network interfaces..."),
                ("ok", "[OK] eth0: 1Gbps Ethernet (connected)"),
                ("ok", "[OK] wlan0: 802.11ax Wi-Fi"),
                ("ok", f"[✓] Report saved → {REPORT_DIR}/hardware_report_full.json"),
            ],
            "Software Audit": [
                ("", "Checking kernel version..."),
                ("ok", "[OK] Kernel: Linux 6.5.0-35-generic #35-Ubuntu SMP x86_64"),
                ("", "Enumerating installed packages..."),
                ("ok", "[OK] dpkg: 1,847 packages installed"),
                ("", "Scanning running services..."),
                ("ok", "[OK] Active services: 43  |  Enabled: 12"),
                ("", "Checking user accounts..."),
                ("ok", "[OK] Users found: 3 (root, nscs, audit)"),
                ("ok", f"[✓] Report saved → {REPORT_DIR}/software_audit.json"),
            ],
            "Generate Reports": [
                ("", "Loading audit data..."),
                ("ok", "[OK] hardware_report_full.json loaded"),
                ("ok", "[OK] software_audit.json loaded"),
                ("", "Generating HTML dashboard..."),
                ("ok", "[OK] report.html (48 KB) created"),
                ("", "Generating PDF summary..."),
                ("ok", "[OK] audit_summary.pdf (2.1 MB) created"),
                ("ok", f"[✓] All reports saved → {REPORT_DIR}"),
            ],
            "Send Email Reports": [
                ("", "Configuring SMTP relay..."),
                ("ok", "[OK] SMTP: smtp.gmail.com:587 (STARTTLS)"),
                ("", "Authenticating..."),
                ("ok", "[OK] OAuth2 credentials loaded"),
                ("", "Attaching reports..."),
                ("ok", "[OK] Attached: audit_summary.pdf (2.1 MB)"),
                ("ok", "[OK] Delivered to: admin@nscs.edu"),
                ("ok", "[✓] Email transmission complete"),
            ],
            "Setup Cron Jobs": [
                ("", "Loading cron configuration..."),
                ("ok", "[OK] Daily audit:   0 2 * * *  (02:00 AM)"),
                ("ok", "[OK] Weekly report: 0 8 * * 1  (Mon 08:00)"),
                ("ok", "[OK] Email dispatch:30 8 * * 1  (Mon 08:30)"),
                ("ok", "[OK] Log rotation:  0 0 * * 0  (weekly)"),
                ("ok", "[✓] Cron entries written — automation active"),
            ],
            "Remote Monitoring": [
                ("", "Initializing SSH connections..."),
                ("ok", "[OK] 192.168.1.10  ONLINE  (latency: 12ms)"),
                ("ok", "[OK] 192.168.1.11  ONLINE  (latency:  8ms)"),
                ("ok", "[OK] 192.168.1.12  ONLINE  (latency: 15ms)"),
                ("", "Starting monitoring daemon..."),
                ("ok", "[OK] Daemon started — PID 4821"),
                ("ok", "[✓] Remote telemetry stream LIVE"),
            ],
        }
        lines = demo_lines.get(title, [("warn", "[DEMO] No demo data for this module.")])
        total = len(lines)
        for i, (tag, text) in enumerate(lines):
            self.terminal.append(text, tag)
            self.progress.set((i + 1) / total)
            time.sleep(0.18)

    # ── Button callbacks ───────────────────────────────────────────────────

    def _run_hardware(self): self._run_module("1",  "Hardware Audit",        "audit_hardware_v2.sh")
    def _run_software(self): self._run_module("2",  "Software Audit",        "audit_software.sh")
    def _run_reports(self):  self._run_module("3",  "Generate Reports",      "generate_reports.sh")
    def _run_email(self):    self._run_module("4",  "Send Email Reports",    "send_reports.sh")
    def _run_cron(self):     self._run_module("5",  "Setup Cron Jobs",       "setup_cron.sh")
    def _run_remote(self):   self._run_module("6",  "Remote Monitoring",     "remote_monitor.sh")

    def _run_help(self):
        self._set_active_btn("10")
        self.terminal.clear()
        self.terminal.append("▶ HELP & DOCUMENTATION", "head")
        self.terminal.append("─" * 54, "dim")
        docs = [
            "00_START_HERE.txt",
            "QUICK_START.md",
            "README_HARDWARE.md",
            "IMPLEMENTATION_SUMMARY.md",
            "PROJECT_ARCHITECTURE.md",
        ]
        docs_dir = SCRIPT_DIR / "docs"
        for doc in docs:
            path = docs_dir / doc
            tag = "ok" if path.exists() else "warn"
            status = "FOUND" if path.exists() else "NOT FOUND"
            self.terminal.append(f"  [{status}]  {doc}", tag)
            time.sleep(0.05)
        self.terminal.append("")
        self.terminal.append(f"  Docs directory: {docs_dir}", "dim")
        self.terminal.append("")
        self.terminal.append("  Modules available:", "white")
        for m in MODULES_DIR.glob("*.sh") if MODULES_DIR.exists() else []:
            self.terminal.append(f"    ✓  {m.name}", "ok")
        self._set_active_btn(None)

    # ── Command entry ──────────────────────────────────────────────────────

    def _on_cmd_enter(self, _event):
        cmd = self.cmd_var.get().strip()
        self.cmd_var.set("")
        if not cmd:
            return
        self.terminal.append(f"\nroot@nscs-audit:~$ {cmd}", "prompt")
        dispatch = {
            "1": self._run_hardware, "2": self._run_software,
            "3": self._run_reports,  "4": self._run_email,
            "5": self._run_cron,     "6": self._run_remote,
            "10": self._run_help,    "help": self._run_help,
            "0": self._on_close,     "exit": self._on_close,
            "clear": self.terminal.clear,
        }
        if cmd.lower() == "whoami":
            self.terminal.append("root", "ok")
        elif cmd.lower() in ("uname -a", "uname"):
            self.terminal.append(f"Linux {os.uname().nodename} {os.uname().release} #1 SMP x86_64 GNU/Linux", "ok")
        elif cmd.lower() == "ls modules/":
            if MODULES_DIR.exists():
                for f in sorted(MODULES_DIR.glob("*.sh")):
                    self.terminal.append(f"  -rwxr-xr-x  {f.name}", "ok")
            else:
                self.terminal.append(f"  ls: {MODULES_DIR}: No such directory", "warn")
        elif cmd in dispatch:
            dispatch[cmd]()
        else:
            self.terminal.append(f"  bash: {cmd}: command not found", "err")
            self.terminal.append("  Hint: try 1-6, 10, help, clear, exit, whoami, uname -a, ls modules/", "dim")

    # ── Close ──────────────────────────────────────────────────────────────

    def _on_close(self):
        self.matrix.stop()
        if self._clock_after:
            try: self.after_cancel(self._clock_after)
            except Exception: pass
        self.terminal.clear()
        self.terminal.append("▶ SHUTDOWN SEQUENCE", "head")
        self.terminal.append("─" * 40, "dim")
        msgs = ["Flushing log buffers...", "Closing module handles...",
                "Stopping background services...", "Saving session state...",
                "Goodbye."]
        for m in msgs:
            self.terminal.append(f"  {m}", "dim")
            self.update()
            time.sleep(0.2)
        self.after(400, self.destroy)


# ══════════════════════════════════════════════════════════════════════════════
#  Entry point
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    app = NSCSApp()
    app.mainloop()