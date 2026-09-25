# dotfiles

Solarized Dark shell setup for **Linux or WSL**, with tmux and Claude Code integration. Windows Terminal theming is available on WSL.

```
╭─ user@host  ~/src/project  main *%  (venv)  1m15s  ✘ 1
╰─❯
```

## Install

```bash
git clone https://github.com/rfalejo/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh --all
```

| Flag | Does |
| --- | --- |
| *(none)* | Symlinks configs, hooks `rice.sh` into `~/.bashrc`, sets the Claude Code `statusLine` |
| `--packages` | Installs shell tools with apt; on standalone Linux, also installs `wl-clipboard`, `xclip`, and `xdg-utils` |
| `--windows-terminal` | On WSL, adds the *Solarized Dark (WSL)* scheme and applies it to the current distro's profile |
| `--all` | All applicable steps for the current host |

Anything already at a target path is moved to `*.pre-dotfiles.<timestamp>`; Windows Terminal's `settings.json` is backed up to `settings.json.bak-<timestamp>`. Configs are symlinked, so edits in place land in the repo.

The package step needs sudo. If you already ran the installer without `--packages` on Ubuntu or Debian, run:

```bash
sudo apt-get update && sudo apt-get install -y tmux fzf bat eza zoxide tree jq git vim wl-clipboard xclip xdg-utils
```

On a headless Linux host, the shell and tmux setup still work; tmux keeps copied text in its own buffer when no system clipboard is available.

## Layout

| Path | Linked to | What |
| --- | --- | --- |
| `bash/rice.sh` | `~/.config/bash/rice.sh` | Prompt, history, aliases, WSL helpers, tool integrations |
| `bash/dircolors` | `~/.dircolors` | Solarized `LS_COLORS` |
| `tmux/tmux.conf` | `~/.tmux.conf` | Solarized tmux tuned for Claude Code |
| `tmux/copy.sh` | `~/.config/tmux/copy.sh` | Clipboard helper for WSL, Wayland, or X11 |
| `claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | Claude Code status line |
| `windows-terminal/solarized-dark-wsl.json` | merged into WT `settings.json` | Color scheme + profile look |

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

**Windows Terminal** — *Solarized Dark (WSL)*: canonical Solarized with bright black as base01 (readable dim text), bright red/magenta as orange/violet, and `intenseTextStyle: bold` so bold text keeps its color. Cascadia Mono 11, bar cursor, 95% opacity.

**Claude Code status line** — `user@host:~/dir (branch)  Model`; drops `user@host` inside tmux since the tmux bar already shows it.
