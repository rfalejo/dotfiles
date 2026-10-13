#!/bin/bash

# Dotfiles installer
# Symlinks configs into place, hooks the bash setup into ~/.bashrc and wires up
# the Claude Code status line. Optional flags install packages and theme Windows Terminal or XFCE.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
PACKAGES=(tmux fzf bat eza zoxide tree jq git vim)
LINUX_DESKTOP_PACKAGES=(wl-clipboard xclip xdg-utils)
XFCE_PACKAGES=(greybird-gtk-theme papirus-icon-theme fonts-cascadia-code python3-pil rofi)
XFCE_THEME=Greybird-Solarized-Dark

print_usage() {
    cat <<EOF
Usage: $0 [options]

With no options, links configs and updates ~/.bashrc and Claude Code settings.

Options:
  --packages          Also apt-install: ${PACKAGES[*]} (plus Linux desktop clipboard tools,
                      and the XFCE theme dependencies on XFCE)
  --windows-terminal  Also add the Solarized scheme to Windows Terminal and apply it to this distro
  --xfce              Also build and apply the Solarized Dark XFCE theme and terminal colors
  --login-screen      Also theme the LightDM GTK greeter to match (uses sudo)
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
    if command -v xfconf-query >/dev/null; then
        packages+=("${XFCE_PACKAGES[@]}")
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

# xfset <channel> <property> <type> <value>: create or update an xfconf property
xfset() {
    xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4"
}

configure_xfce() {
    if ! command -v xfconf-query >/dev/null; then
        log_warn "xfconf-query not found (not an XFCE desktop?); skipping XFCE"
        return
    fi

    local xfconf_dir="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
    if [ -d "$xfconf_dir" ]; then
        cp -a "$xfconf_dir" "$xfconf_dir.pre-dotfiles.$STAMP"
        log_info "Backed up $xfconf_dir -> $xfconf_dir.pre-dotfiles.$STAMP"
    fi

    python3 "$DOTFILES_DIR/xfce/solarize-theme.py" "$HOME/.local/share/themes/$XFCE_THEME"

    xfset xsettings /Net/ThemeName string "$XFCE_THEME"
    xfset xfwm4 /general/theme string "$XFCE_THEME"
    xfset xfce4-notifyd /theme string "$XFCE_THEME"
    if [ -d /usr/share/icons/Papirus-Dark ]; then
        xfset xsettings /Net/IconThemeName string Papirus-Dark
    fi
    if command -v gsettings >/dev/null; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    fi

    # Wallpaper on every monitor and workspace, existing or not yet configured
    local wallpaper="$HOME/.local/share/backgrounds/solarized-dusk.png"
    python3 "$DOTFILES_DIR/xfce/wallpaper.py" "$wallpaper"
    local workspaces monitor ws backdrop
    workspaces="$(xfconf-query -c xfwm4 -p /general/workspace_count 2>/dev/null || echo 1)"
    while read -r backdrop; do
        xfset xfce4-desktop "$backdrop/last-image" string "$wallpaper"
        xfset xfce4-desktop "$backdrop/image-style" int 5   # zoomed
    done < <({
        xfconf-query -c xfce4-desktop -l 2>/dev/null | sed -n 's#/last-image$##p'
        for monitor in $(xrandr --listmonitors 2>/dev/null | awk 'NR > 1 { print $NF }'); do
            for ((ws = 0; ws < workspaces; ws++)); do
                echo "/backdrop/screen0/monitor$monitor/workspace$ws"
            done
        done
    } | sort -u)

    # xfce4-terminal gets the same scheme and look as the Windows Terminal WSL profile
    local key value
    while read -r key value; do
        xfset xfce4-terminal "/$key" string "$value"
    done < <(python3 - "$DOTFILES_DIR/windows-terminal/solarized-dark-wsl.json" <<'EOF'
import json, sys

with open(sys.argv[1]) as f:
    scheme = json.load(f)["scheme"]

names = ["black", "red", "green", "yellow", "blue", "purple", "cyan", "white"]
palette = [scheme[n] for n in names] + [scheme["bright" + n.capitalize()] for n in names]
print("color-background", scheme["background"].lower())
print("color-foreground", scheme["foreground"].lower())
print("color-cursor", scheme["cursorColor"].lower())
print("color-selection", scheme["selectionBackground"].lower())
print("color-palette", ";".join(palette).lower())
EOF
)
    xfset xfce4-terminal /color-cursor-use-default bool false
    xfset xfce4-terminal /color-selection-use-default bool false
    xfset xfce4-terminal /color-bold-use-default bool true
    xfset xfce4-terminal /color-bold-is-bright bool false
    xfset xfce4-terminal /tab-activity-color string "#cb4b16"
    xfset xfce4-terminal /misc-cursor-shape string TERMINAL_CURSOR_SHAPE_IBEAM
    if [ -n "$(fc-list "Cascadia Mono" family)" ]; then
        xfset xfce4-terminal /font-use-system bool false
        xfset xfce4-terminal /font-name string "Cascadia Mono 11"
        xfset xsettings /Gtk/MonospaceFontName string "Cascadia Mono 10"
    else
        log_warn "Cascadia Mono not installed (see --packages); keeping the current terminal font"
    fi
    xfset xfce4-terminal /misc-menubar-default bool false          # right-click still opens the menu
    xfset xfce4-terminal /scrolling-bar string TERMINAL_SCROLLBAR_NONE

    # Clean desktop, and a panel clock formatted like the tmux one
    xfset xfce4-desktop /desktop-icons/style int 0
    local clock
    for clock in $(xfconf-query -c xfce4-panel -lv | awk '$2 == "clock" { print $1 }'); do
        xfset xfce4-panel "$clock/digital-layout" int 3
        xfset xfce4-panel "$clock/digital-time-format" string "%a %d %b  %H:%M"
    done

    link gtk/gtk-4.0.css "$HOME/.config/gtk-4.0/gtk.css"
    link rofi/config.rasi "$HOME/.config/rofi/config.rasi"
    if command -v rofi >/dev/null; then
        xfset xfce4-keyboard-shortcuts "/commands/custom/<Super>r" string "rofi -show drun"
        xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>r/startup-notify" -r 2>/dev/null || true
    else
        log_warn "rofi not installed (see --packages); keeping the Super+R run dialog"
    fi

    log_info "Applied $XFCE_THEME to XFCE and xfce4-terminal"
}

# Login screen: the greeter runs as the lightdm user, so the theme and wallpaper are
# copied system-wide and set in /etc/lightdm/lightdm-gtk-greeter.conf (needs sudo)
configure_login_screen() {
    local conf=/etc/lightdm/lightdm-gtk-greeter.conf
    local theme="$HOME/.local/share/themes/$XFCE_THEME"
    local wallpaper="$HOME/.local/share/backgrounds/solarized-dusk.png"

    if [ ! -f "$conf" ]; then
        log_warn "$conf not found (not using lightdm-gtk-greeter?); skipping login screen"
        return
    fi
    [ -d "$theme" ] || python3 "$DOTFILES_DIR/xfce/solarize-theme.py" "$theme"
    [ -f "$wallpaper" ] || python3 "$DOTFILES_DIR/xfce/wallpaper.py" "$wallpaper"

    sudo rm -rf "/usr/share/themes/$XFCE_THEME"
    sudo cp -r "$theme" "/usr/share/themes/$XFCE_THEME"
    sudo install -D -m 644 "$wallpaper" /usr/share/backgrounds/solarized-dusk.png
    sudo cp "$conf" "$conf.bak-$STAMP"
    log_info "Backed up $conf"

    sudo python3 - "$conf" "$XFCE_THEME" <<'EOF'
import sys

path, theme = sys.argv[1:]
settings = {
    "theme-name": theme,
    "icon-theme-name": "Papirus-Dark",
    "background": "/usr/share/backgrounds/solarized-dusk.png",
    "user-background": "false",
    "font-name": "Noto Sans 10",
    "clock-format": "%a %d %b  %H:%M",
}

lines = open(path).read().splitlines()
if not any(line.strip() == "[greeter]" for line in lines):
    lines.append("[greeter]")
section = None
for i, line in enumerate(lines):
    if line.startswith("["):
        section = line.strip()
        continue
    key = line.split("=", 1)[0].strip()
    if section == "[greeter]" and "=" in line and key in settings:
        lines[i] = f"{key}={settings.pop(key)}"
start = next(i for i, line in enumerate(lines) if line.strip() == "[greeter]")
end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("[")), len(lines))
lines[end:end] = [f"{key}={value}" for key, value in settings.items()]

with open(path, "w") as f:
    f.write("\n".join(lines) + "\n")
EOF
    log_info "Applied $XFCE_THEME and the dusk wallpaper to the login screen"
}

main() {
    local packages=false windows_terminal=false xfce=false login_screen=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --packages) packages=true ;;
            --windows-terminal) windows_terminal=true ;;
            --xfce) xfce=true ;;
            --login-screen) login_screen=true ;;
            --all) packages=true; windows_terminal=true; xfce=true; login_screen=true ;;
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
    $xfce && configure_xfce
    $login_screen && configure_login_screen

    log_info "Done. Open a new shell (or run: exec bash -l)."
}

main "$@"
