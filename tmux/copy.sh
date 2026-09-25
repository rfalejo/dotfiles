#!/bin/bash
# Copy tmux selections to the host clipboard when one is available.
# tmux keeps its own copy buffer even when this script has no clipboard target.

if [ -n "${WSL_DISTRO_NAME:-}" ] && command -v clip.exe >/dev/null 2>&1; then
    exec clip.exe
fi

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    exec wl-copy
fi

if [ -n "${DISPLAY:-}" ]; then
    if command -v xclip >/dev/null 2>&1; then
        exec xclip -selection clipboard -in
    fi
    if command -v xsel >/dev/null 2>&1; then
        exec xsel --clipboard --input
    fi
fi

# Consume piped text so tmux doesn't leave a blocked writer on headless hosts.
cat >/dev/null
