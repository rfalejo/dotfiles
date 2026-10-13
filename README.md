# dotfiles

Dark shell setup for **Linux, WSL, and native Windows PowerShell**, with Claude Code integration. Linux/WSL uses Solarized Dark (with near-black blue backgrounds) and includes tmux, plus an optional matching XFCE desktop theme; native Windows uses Minimal Mocha. Windows Terminal theming is available for WSL and PowerShell.

```
╭─ user@host  ~/src/project  main *%  (venv)  1m15s  ✘ 1
╰─❯
```

## Install

### Windows (PowerShell 7)

```powershell
git clone git@github.com:rfalejo/dotfiles.git "$HOME/dotfiles"
pwsh -NoProfile -File "$HOME/dotfiles/install.ps1" -WindowsTerminal
```

The installer requires PowerShell 7; the installed profile supports both PowerShell 7 and Windows PowerShell 5.1. It adds a managed block to each edition's current-user, all-hosts `Profile.ps1`, dot-sourcing `powershell/rice.ps1` directly from the checkout. Keep the checkout at the installed path. Existing profile content is preserved; changed files get timestamped `*.pre-dotfiles.*` backups. Rerunning updates the same block.

| Switch | Does |
| --- | --- |
| *(none)* | Hooks both PowerShell profiles and configures the native Claude Code status line |
| `-Packages` | Installs Git, fzf, bat, eza, and zoxide via winget |
| `-WindowsTerminal` | Applies *Minimal Mocha (PowerShell)* to local PowerShell profiles in installed Windows Terminal editions |
| `-All` | Includes packages and Windows Terminal |
| `-SkipClaude` | Leaves Claude Code settings alone |
| `-WhatIf` | Previews changes |

Open a new PowerShell tab after installing, or run `. $PROFILE.CurrentUserAllHosts`. If local scripts are blocked, set `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` in your own shell. The installer does not change execution policy. Windows Terminal's unrelated settings and default profile are preserved; rewriting JSON removes comments and formatting, with the original retained in the backup.

PowerShell includes the two-line Minimal Mocha prompt with Git branch/dirty state, virtualenv, command duration and failure status; Windows Terminal directory reporting; shared PSReadLine history, prefix search on ↑/↓, and menu completion on Tab. Helpers include `g`, `gs`, `gd`, `gl`, `ga`, `gcommit`, `gp`, `ll`, `la`, `..`, `...`, `e`, `open`, `winhome`, `pbcopy`, `pbpaste`, and `reload`. Native PowerShell aliases such as `gc`, `ls`, `cat`, and `copy` keep their standard meanings. When installed, eza enhances `ll`/`la` and adds `lt`, zoxide provides `z`/`zi`, and fzf powers Ctrl+R history selection. `bat` uses OneHalfDark. tmux remains a Linux/WSL tool.

The Windows theme uses a near-black blue background (`#070D15`), pale text, and soft blue, purple, and green accents. Prompt and fzf colors match the Terminal palette. Windows profiles are fully opaque, with acrylic and bell indicators disabled.

### Linux / WSL

```bash
git clone https://github.com/rfalejo/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh --all
```

| Flag | Does |
| --- | --- |
| *(none)* | Symlinks configs, hooks `rice.sh` into `~/.bashrc`, sets the Claude Code `statusLine` |
| `--packages` | Installs shell tools with apt; on standalone Linux, also installs `wl-clipboard`, `xclip`, and `xdg-utils`; on XFCE, also the theme dependencies (`greybird-gtk-theme`, `papirus-icon-theme`, `fonts-cascadia-code`, `python3-pil`) |
| `--windows-terminal` | On WSL, adds the *Solarized Dark (WSL)* scheme and applies it to the current distro's profile |
| `--xfce` | On XFCE, builds the *Greybird-Solarized-Dark* theme and applies it with matching icons, notifications, and xfce4-terminal colors |
| `--all` | All applicable steps for the current host |

Anything already at a target path is moved to `*.pre-dotfiles.<timestamp>`; Windows Terminal's `settings.json` is backed up to `settings.json.bak-<timestamp>`; `--xfce` copies `~/.config/xfce4/xfconf/xfce-perchannel-xml` to `*.pre-dotfiles.<timestamp>` before changing settings. Configs are symlinked, so edits in place land in the repo.

The package step needs sudo. If you already ran the installer without `--packages` on Ubuntu or Debian, run:

```bash
sudo apt-get update && sudo apt-get install -y tmux fzf bat eza zoxide tree jq git vim wl-clipboard xclip xdg-utils
```

On a headless Linux host, the shell and tmux setup still work; tmux keeps copied text in its own buffer when no system clipboard is available.

## Layout

| Path | Linked to | What |
| --- | --- | --- |
| `bash/rice.sh` | `~/.config/bash/rice.sh` | Prompt, history, aliases, WSL helpers, tool integrations |
| `powershell/rice.ps1` | sourced by both Windows `Profile.ps1` files | Native PowerShell prompt, history, helpers, optional tools |
| `bash/dircolors` | `~/.dircolors` | Solarized `LS_COLORS` |
| `tmux/tmux.conf` | `~/.tmux.conf` | Solarized tmux tuned for Claude Code |
| `tmux/copy.sh` | `~/.config/tmux/copy.sh` | Clipboard helper for WSL, Wayland, or X11 |
| `claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | Claude Code status line |
| `claude/statusline-command.ps1` | invoked directly from checkout | Native Windows Claude Code status line |
| `windows-terminal/solarized-dark-wsl.json` | merged into WT `settings.json` | Color scheme + profile look |
| `windows-terminal/minimal-mocha-powershell.json` | merged into WT `settings.json` | Native Windows color scheme + profile look |
| `xfce/solarize-theme.py` | generates `~/.local/share/themes/Greybird-Solarized-Dark` | Recolors Greybird-dark to Solarized Dark |

## Highlights

**Bash**
- Two-line prompt: git status (dirty checks skipped on slow `/mnt/*`), virtualenv, command duration ≥ 3s, exit code, jobs.
- Emits OSC 9;9 so Windows Terminal *Duplicate Tab/Pane* (`Alt+Shift+D`) opens in the same directory — also through tmux.
- 100k shared history, ↑/↓ prefix search, `fzf` (`Ctrl+R`, `Ctrl+T`), `zoxide` (`z`), `eza`, `bat`.
- WSL: `open`/`e` (Explorer), `pbcopy`/`pbpaste`/`copy` (Windows clipboard), `winhome`. Linux desktops: `open`/`e` use `xdg-open`.
- Interactive `cp`/`mv`/`rm -i` and `cat → bat` are skipped inside Claude Code's shell (`$CLAUDECODE`).

**tmux** — prefix `C-b` (also `C-a`)
| Key | Action |
| --- | --- |
| `\|` / `-` | Split horizontally / vertically in the current dir |
| `h j k l` / `H J K L` | Move between / resize panes |
| `Tab` | Last window |
| `g` | Popup shell |
| `s` | Session picker |
| `Enter`, `v`, `y` | Copy mode, select, yank to the available clipboard |
| `r` | Reload config |

Also: mouse, 1-based numbering, `escape-time 10`, extended keys (Shift+Enter), truecolor, OSC passthrough. Copy mode sends text to the Windows, Wayland, or X11 clipboard when available. `t` in bash attaches to (or creates) session `main`.

**Windows Terminal** — *Solarized Dark (WSL)*: Solarized accents and text on near-black blue backgrounds (`#070D15`, with `#0F1B29` for selection and ANSI black in place of base03/base02), bright black as base01 (readable dim text), bright red/magenta as orange/violet, and `intenseTextStyle: bold` so bold text keeps its color. Cascadia Mono 11, bar cursor, full opacity, no bell indicators.

**XFCE** — *Greybird-Solarized-Dark* is generated from the installed Greybird-dark rather than vendored: its greys map onto the Solarized base ramp (views base03, windows and panel base02, text base1) and its accents onto Solarized blue, red, green, and orange. CSS, gtkrc, SVG, XPM, and PNG assets all go through the same mapping, so GTK 2/3 widgets, the panel, xfwm4 window decorations, and notifications match tmux. Also sets the flat, minimal Papirus-Dark icons, `prefer-dark` for GTK 4/libadwaita apps, and gives xfce4-terminal the Windows Terminal scheme (read from `windows-terminal/solarized-dark-wsl.json`), Cascadia Mono 11, and a bar cursor. Rerun `--xfce` after Greybird updates to rebuild. To revert, pick another theme in *Appearance* and *Window Manager*.

**Claude Code status line** — `user@host:~/dir (branch)  Model`; drops `user@host` inside tmux since the tmux bar already shows it.
