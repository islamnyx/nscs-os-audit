# NSCS OS Project — README

> **v2.0 · 2026** | Read this fully before running anything.

---

## Table of Contents

1. [What Is This Project](#1-what-is-this-project)
2. [File Structure](#2-file-structure)
3. [System Requirements](#3-system-requirements)
4. [Modules Overview](#4-modules-overview)
5. [Setup — Step by Step](#5-setup--step-by-step)
6. [How to Run](#6-how-to-run)
7. [Reports & Output](#7-reports--output)
8. [Troubleshooting](#8-troubleshooting)
9. [Quick Reference](#9-quick-reference)

---

## 1. What Is This Project

The **NSCS OS Project** is a modular Linux auditing and monitoring toolkit. It collects hardware and software information from a machine, generates reports in multiple formats, and can send them automatically via email or gather them from remote hosts over SSH.

**Three ways to run it:**

| Interface | Script | Notes |
|-----------|--------|-------|
| Terminal Menu | `nscs_menu.sh` | Simple, no dependencies, works anywhere |
| Tkinter GUI | `nscs_launcher.py` | Built-in Python GUI, no extra install |
| CustomTkinter GUI | `nscs_gui.py` | Modern GUI, requires one pip install |

---

## 2. File Structure

```
nscs-os-audit/
│
├── nscs_menu.sh          ← Terminal main menu (no dependencies)
├── nscs_launcher.py      ← Tkinter GUI launcher
├── nscs_gui.py           ← CustomTkinter GUI (modern version)
├── install.sh            ← Installs CustomTkinter dependency
├── README.md             ← This file
│
└── modules/              ← All audit scripts go here
    ├── audit_hardware_v2.sh
    ├── audit_software.sh
    ├── generate_reports.sh
    ├── send_reports.sh
    ├── setup_cron.sh
    └── remote_monitor.sh
```

> ⚠️ **The `modules/` folder must exist and contain all `.sh` scripts.** The GUIs and menu will show `[MISSING]` or an error if any script is not in that exact location.

---

## 3. System Requirements

The project runs on any **Debian-based Linux distribution** (Ubuntu, Kali, Parrot, etc.).

### 3.1 Always Required *(built-in on most systems)*

- `bash` (version 4+)
- `python3`
- `python3-tk` — for the Tkinter GUI
- Standard tools: `dmidecode`, `lscpu`, `lsblk`, `ss`, `systemctl`, `ufw`

### 3.2 CustomTkinter GUI only (`nscs_gui.py`)

- `customtkinter` Python package — installed by running `install.sh` (see [Step 4](#step-4--install-customtkinter-only-for-nscs_guipy))

### 3.3 Certain Modules only

| Module | Dependency |
|--------|-----------|
| Module 3 — Generate Reports | `wkhtmltopdf` or `weasyprint` for PDF output |
| Module 4 — Send Reports | Gmail account with App Password enabled |
| Module 5 — Cron | `cron` daemon running (standard on most systems) |
| Module 6 — Remote Monitor | SSH key-based access configured to target hosts |

---

## 4. Modules Overview

Each module is a standalone bash script. They can be run from any of the three interfaces or directly from the terminal.

| Key | Module | Description | Script |
|-----|--------|-------------|--------|
| `[1]` | Hardware Audit | Phase 1 · DMI / SMBIOS / CPU / GPU / RAM | `audit_hardware_v2.sh` |
| `[2]` | Software Audit | Phase 1 · OS / Packages / Services / Security | `audit_software.sh` |
| `[3]` | Generate Reports | Phase 2 · TXT / JSON / HTML / PDF | `generate_reports.sh` |
| `[4]` | Send Reports | Phase 3 · SMTP / TLS / Gmail | `send_reports.sh` |
| `[5]` | Cron Automation | Phase 4 · Scheduling / Logging / Failure Handling | `setup_cron.sh` |
| `[6]` | Remote Monitor | Phase 5 · SSH / SCP / Centralized Reports | `remote_monitor.sh` |

> **`--gui` flag:** All scripts accept `--gui`. When launched from the GUI, this flag is added automatically to skip interactive prompts (auto-saves JSON, etc.).

---

## 5. Setup — Step by Step

Follow these steps **in order** the first time you set up the project.

### Step 1 — Get the files into one folder

```bash
mkdir -p ~/nscs-os-audit/modules
cd ~/nscs-os-audit
```

- Copy all `.sh` module scripts into `modules/`
- Copy `nscs_menu.sh`, `nscs_launcher.py`, `nscs_gui.py`, and `install.sh` into the root folder

### Step 2 — Make scripts executable

```bash
cd ~/nscs-os-audit
chmod +x nscs_menu.sh install.sh
chmod +x modules/*.sh
```

### Step 3 — Install `python3-tk` *(if not already installed)*

Needed for `nscs_launcher.py`. Skip if already installed.

```bash
sudo apt update
sudo apt install python3-tk -y
```

### Step 4 — Install CustomTkinter *(only for `nscs_gui.py`)*

Run the provided installer:

```bash
bash install.sh
```

Or install manually:

```bash
pip install customtkinter --break-system-packages
```

### Step 5 — `dmidecode` sudo access *(for Hardware Audit)*

Module 1 uses `dmidecode` which requires `sudo`. Either run the menu/GUI as sudo, or add a passwordless rule:

```bash
sudo visudo
# Add this line at the bottom:
yourusername ALL=(ALL) NOPASSWD: /usr/sbin/dmidecode
```

> ⚠️ Replace `yourusername` with the output of `whoami`

---

## 6. How to Run

### Option A — Terminal Menu *(recommended, no dependencies)*

```bash
cd ~/nscs-os-audit
bash nscs_menu.sh
```

- Type `1`–`6` + Enter to launch a module
- Type `L` to list saved reports
- Type `Q` to quit

### Option B — Tkinter GUI *(built-in Python, no extra install)*

```bash
cd ~/nscs-os-audit
python3 nscs_launcher.py
```

A graphical window opens with module cards. Click **LAUNCH** or press `F1`–`F6` to run modules. Output appears in the terminal panel on the right.

### Option C — CustomTkinter GUI *(modern look, requires `install.sh` first)*

```bash
cd ~/nscs-os-audit
python3 nscs_gui.py
```

Same as the Tkinter GUI but with a modern appearance and matrix rain animation.

### Running a module directly from the terminal

```bash
bash modules/audit_hardware_v2.sh
bash modules/audit_software.sh
```

---

## 7. Reports & Output

Reports are saved automatically to:

```
~/nscs-os-audit/reports/
```

- **Module 1 & 2** — save a JSON file each run
- **Module 3** — reads those JSON files and generates TXT, HTML, and PDF formats
- **Terminal menu** — press `L` to list all saved report files with their sizes

---

## 8. Troubleshooting

| Problem | Solution |
|---------|----------|
| `python3-tk` not found | `sudo apt install python3-tk -y` |
| `ModuleNotFoundError: customtkinter` | `bash install.sh` |
| Script not found / `[MISSING]` | Make sure all `.sh` files are inside `modules/` |
| Permission denied on `.sh` file | `chmod +x modules/*.sh` |
| `dmidecode: command not found` | `sudo apt install dmidecode -y` |
| Hardware audit shows `Unknown` | Run with sudo: `sudo bash modules/audit_hardware_v2.sh` |
| GUI window doesn't open | Requires a desktop session (X11). Won't work over SSH without X forwarding |
| No reports after running modules | Check `~/nscs-os-audit/reports/` exists; also check disk space |

---

## 9. Quick Reference

Minimal commands to get everything running from scratch on a fresh Kali/Ubuntu machine:

```bash
# 1. Go to the project folder
cd ~/nscs-os-audit

# 2. Make everything executable
chmod +x nscs_menu.sh install.sh modules/*.sh

# 3. Install dependencies
sudo apt install python3-tk dmidecode -y
bash install.sh

# 4. Run (choose one)
bash nscs_menu.sh          # Terminal menu
python3 nscs_launcher.py   # Tkinter GUI
python3 nscs_gui.py        # CustomTkinter GUI
```

---

*NSCS OS Project · v2.0 · 2026*
