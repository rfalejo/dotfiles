#!/bin/bash

# Dotfiles installer
# Symlinks configs into place, hooks the bash setup into ~/.bashrc and wires up
# the Claude Code status line. Optional flags install packages and theme Windows Terminal.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
PACKAGES=(tmux fzf bat eza zoxide tree jq git vim)
LINUX_DESKTOP_PACKAGES=(wl-clipboard xclip xdg-utils)

print_usage() {
    cat <<EOF
Usage: $0 [options]

With no options, links configs and updates ~/.bashrc and Claude Code settings.

Options:
  --packages          Also apt-install: ${PACKAGES[*]} (plus Linux desktop clipboard tools)
  --windows-terminal  Also add the Solarized scheme to Windows Terminal and apply it to this distro
  --all               Everything above
  -h, --help          Show this message
EOF
}

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1" >&2
}

# link <repo path> <target path>: back up anything already there, then symlink
link() {
    local source="$DOTFILES_DIR/$1"
    local target="$2"

    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        log_info "Already linked $target"
        return
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        mv "$target" "$target.pre-dotfiles.$STAMP"
        log_info "Backed up $target -> $target.pre-dotfiles.$STAMP"
    fi

    ln -s "$source" "$target"
    log_info "Linked $target"
}

link_configs() {
    link bash/rice.sh                 "$HOME/.config/bash/rice.sh"
    link bash/dircolors               "$HOME/.dircolors"
    link tmux/tmux.conf               "$HOME/.tmux.conf"
    link tmux/copy.sh                  "$HOME/.config/tmux/copy.sh"
    link claude/statusline-command.sh "$HOME/.claude/statusline-command.sh"
}

hook_bashrc() {
    local bashrc="$HOME/.bashrc"

    if grep -qs 'config/bash/rice.sh' "$bashrc"; then
        log_info "~/.bashrc already sources rice.sh"
        return
    fi

    cat >> "$bashrc" <<'EOF'

# >>> rice: Solarized Dark prompt, aliases, WSL/Windows Terminal integration >>>
[ -r ~/.config/bash/rice.sh ] && . ~/.config/bash/rice.sh
# <<< rice <<<
EOF
    log_info "Hooked rice.sh into ~/.bashrc"
}

configure_claude() {
    local settings="$HOME/.claude/settings.json"

    python3 - "$settings" <<'EOF'
import json, os, sys

path = sys.argv[1]
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)

data["statusLine"] = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF
    log_info "Set Claude Code statusLine in $settings"
}

install_packages() {
    local packages=("${PACKAGES[@]}")
    if [ -z "${WSL_DISTRO_NAME:-}" ]; then
        packages+=("${LINUX_DESKTOP_PACKAGES[@]}")
    fi
    log_info "Installing packages: ${packages[*]}"
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}"
}

configure_windows_terminal() {
    if [ -z "${WSL_DISTRO_NAME:-}" ]; then
        log_warn "Not running under WSL; skipping Windows Terminal"
        return
    fi

    local localappdata settings=""
    localappdata="$(wslpath "$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")"
    for candidate in \
        "$localappdata"/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json \
        "$localappdata"/Packages/Microsoft.WindowsTerminalPreview_*/LocalState/settings.json \
        "$localappdata/Microsoft/Windows Terminal/settings.json"; do
        if [ -f "$candidate" ]; then
            settings="$candidate"
            break
        fi
    done

    if [ -z "$settings" ]; then
        log_warn "Windows Terminal settings.json not found; skipping"
        return
    fi

    cp "$settings" "$settings.bak-$STAMP"
    log_info "Backed up $settings"

    python3 - "$settings" "$DOTFILES_DIR/windows-terminal/solarized-dark-wsl.json" "$WSL_DISTRO_NAME" "$HOME" <<'EOF'
import json, sys

settings_path, theme_path, distro, home = sys.argv[1:]
with open(settings_path, encoding="utf-8") as f:
    settings = json.load(f)
with open(theme_path) as f:
    theme = json.load(f)

scheme = theme["scheme"]
settings["schemes"] = [s for s in settings.get("schemes", []) if s.get("name") != scheme["name"]] + [scheme]

look = dict(theme["wslProfile"], startingDirectory=f"//wsl.localhost/{distro}{home}")
matched = False
for profile in settings.get("profiles", {}).get("list", []):
    if profile.get("name") != distro:
        continue
    profile.update(look)
    matched = True
    if profile.get("source") == "Microsoft.WSL":
        settings["defaultProfile"] = profile["guid"]
    elif profile.get("source") == "Windows.Terminal.Wsl":
        profile["hidden"] = True  # legacy duplicate of the Microsoft.WSL profile

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
    f.write("\n")

print(f"[INFO] Windows Terminal: {'themed profile ' + distro if matched else 'added scheme (no profile named ' + distro + ')'}")
EOF
}

main() {
    local packages=false windows_terminal=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --packages) packages=true ;;
            --windows-terminal) windows_terminal=true ;;
            --all) packages=true; windows_terminal=true ;;
            -h|--help) print_usage; exit 0 ;;
            *) print_usage; exit 1 ;;
        esac
        shift
    done

    $packages && install_packages
    link_configs
    hook_bashrc
    configure_claude
    $windows_terminal && configure_windows_terminal

    log_info "Done. Open a new shell (or run: exec bash -l)."
}

main "$@"
