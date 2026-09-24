#!/bin/bash
# Claude Code status line, styled after ~/.bashrc PS1:
#   PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#
# Outside tmux:  user@host:~/dir  branch  Model
# Inside tmux:   ~/dir  branch  Model   (tmux's own status bar already shows session/host)

input=$(cat)

# jq isn't installed; parse the JSON with python3 instead.
IFS=$'\t' read -r cwd model < <(
  printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
cwd = (d.get("workspace") or {}).get("current_dir") or d.get("cwd") or ""
model = (d.get("model") or {}).get("display_name") or ""
print(f"{cwd}\t{model}")
' 2>/dev/null
)
[ -z "$cwd" ] && cwd="$PWD"

# Abbreviate $HOME as ~ (quoted so bash doesn't expand the tilde back)
case "$cwd" in
  "$HOME") dir_display="~" ;;
  "$HOME"/*) dir_display="~${cwd#"$HOME"}" ;;
  *) dir_display="$cwd" ;;
esac

branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
  || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

green=$'\033[01;32m'; blue=$'\033[01;34m'; magenta=$'\033[35m'; dim=$'\033[2m'; reset=$'\033[00m'

out=""
[ -n "$debian_chroot" ] && out+="(${debian_chroot})"
if [ -z "$TMUX" ]; then
  out+="${green}$(whoami)@$(hostname -s)${reset}:"
fi
out+="${blue}${dir_display}${reset}"
[ -n "$branch" ] && out+=" ${magenta}(${branch})${reset}"
[ -n "$model" ] && out+="  ${dim}${model}${reset}"

printf '%s' "$out"
