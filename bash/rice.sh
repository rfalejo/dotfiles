# ~/.config/bash/rice.sh — Solarized Dark bash setup for WSL + Windows Terminal + tmux
# Sourced from ~/.bashrc. Optional tools (fzf, bat, eza, zoxide) are used when installed.

# ── Solarized palette (24-bit) ────────────────────────────────────
__rgb() { printf '\033[38;2;%d;%d;%dm' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
SOL_BASE01=$(__rgb 586e75)  SOL_BASE0=$(__rgb 839496)   SOL_BASE1=$(__rgb 93a1a1)
SOL_YELLOW=$(__rgb b58900)  SOL_ORANGE=$(__rgb cb4b16)  SOL_RED=$(__rgb dc322f)
SOL_MAGENTA=$(__rgb d33682) SOL_VIOLET=$(__rgb 6c71c4)  SOL_BLUE=$(__rgb 268bd2)
SOL_CYAN=$(__rgb 2aa198)    SOL_GREEN=$(__rgb 859900)
SOL_BOLD=$'\033[1m'         SOL_RESET=$'\033[0m'
unset -f __rgb
export COLORTERM=truecolor

# ── History & shell options ───────────────────────────────────────
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE='ls:ll:la:cd:pwd:exit:clear:history'
HISTTIMEFORMAT='%F %T  '
shopt -s histappend cmdhist globstar autocd cdspell dirspell checkjobs no_empty_cmd_completion

# Readline niceties (only when interactive with a line editor)
if [[ $- == *i* && -t 0 ]]; then
  bind 'set completion-ignore-case on'
  bind 'set show-all-if-ambiguous on'
  bind 'set colored-stats on'
  bind 'set colored-completion-prefix on'
  bind 'set mark-symlinked-directories on'
  bind '"\e[A": history-search-backward'      # ↑/↓ search history by typed prefix
  bind '"\e[B": history-search-forward'
fi

export EDITOR=vim VISUAL=vim PAGER=less
export LESS='-R -F -i -M --mouse --wheel-lines=3'

# Solarized man pages
export GROFF_NO_SGR=1
export LESS_TERMCAP_md="${SOL_BOLD}${SOL_BLUE}"      # bold → headings
export LESS_TERMCAP_me="$SOL_RESET"
export LESS_TERMCAP_us="${SOL_GREEN}"                 # underline → args
export LESS_TERMCAP_ue="$SOL_RESET"
export LESS_TERMCAP_so=$'\033[48;2;7;54;66m'"$SOL_YELLOW"  # standout → status/search
export LESS_TERMCAP_se="$SOL_RESET"

# ── Prompt ────────────────────────────────────────────────────────
#   ╭─ user@host  ~/src/project  main *+  (venv)  3s  ✘ 1
#   ╰─❯
if [[ -r /usr/lib/git-core/git-sh-prompt ]]; then
  . /usr/lib/git-core/git-sh-prompt
  GIT_PS1_SHOWUNTRACKEDFILES=1
  GIT_PS1_SHOWSTASHSTATE=1
  GIT_PS1_SHOWUPSTREAM=auto
fi
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Record command start time from PS0 without forking (arithmetic assignment trick)
PS0='${PS1:$((__rice_t0=SECONDS, 0)):0}'

# Windows path for the current dir, used by Windows Terminal's "duplicate tab/pane"
__rice_winpath() {
  local p=$PWD
  if [[ $p =~ ^/mnt/([a-z])(/.*)?$ ]]; then
    p="${BASH_REMATCH[1]^}:${BASH_REMATCH[2]:-/}"
  else
    p="//wsl.localhost/${WSL_DISTRO_NAME}${p}"
  fi
  printf '%s' "${p//\//\\}"
}

__rice_prompt() {
  local status=$?
  history -a

  local c=$SOL_RESET line1="" branch=""
  local w="\[" e="\]"   # non-printing wrappers

  # user@host: quiet grey locally, yellow over SSH
  if [[ -n $SSH_CONNECTION ]]; then
    line1+="${w}${SOL_YELLOW}${e}\u@\h${w}${c}${e}  "
  else
    line1+="${w}${SOL_BASE01}${e}\u@\h${w}${c}${e}  "
  fi
  line1+="${w}${SOL_BOLD}${SOL_BLUE}${e}\w${w}${c}${e}"

  # Git: skip dirty-state checks on /mnt/* (Windows filesystem is slow over 9P)
  if declare -F __git_ps1 >/dev/null; then
    if [[ $PWD == /mnt/* ]]; then GIT_PS1_SHOWDIRTYSTATE=; else GIT_PS1_SHOWDIRTYSTATE=1; fi
    branch=$(__git_ps1 '%s')
    [[ -n $branch ]] && line1+="  ${w}${SOL_VIOLET}${e}${branch}${w}${c}${e}"
  fi

  [[ -n $VIRTUAL_ENV ]] && line1+="  ${w}${SOL_CYAN}${e}(${VIRTUAL_ENV##*/})${w}${c}${e}"
  [[ -n $CONDA_DEFAULT_ENV && $CONDA_DEFAULT_ENV != base ]] && line1+="  ${w}${SOL_CYAN}${e}(${CONDA_DEFAULT_ENV})${w}${c}${e}"

  if [[ -n $__rice_t0 ]]; then
    local dt=$((SECONDS - __rice_t0))
    if (( dt >= 3 )); then
      local fmt="${dt}s"
      (( dt >= 60 )) && fmt="$((dt / 60))m$((dt % 60))s"
      line1+="  ${w}${SOL_YELLOW}${e}${fmt}${w}${c}${e}"
    fi
    unset __rice_t0
  fi

  (( status != 0 )) && line1+="  ${w}${SOL_RED}${e}✘ ${status}${w}${c}${e}"
  (( ${#DIRSTACK[@]} > 1 )) && line1+="  ${w}${SOL_BASE01}${e}+$(( ${#DIRSTACK[@]} - 1 ))${w}${c}${e}"
  (( $(jobs -p | wc -l) > 0 )) && line1+="  ${w}${SOL_ORANGE}${e}⚙ \j${w}${c}${e}"

  local arrow_color=$SOL_GREEN
  (( status != 0 )) && arrow_color=$SOL_RED

  # Terminal title + Windows Terminal cwd (OSC 9;9), wrapped for tmux passthrough
  local title="\[\e]0;\W\a\]"
  __rice_osc=""
  if [[ -n $WT_SESSION ]]; then
    local wp; wp=$(__rice_winpath)
    if [[ -n $TMUX ]]; then
      __rice_osc=$'\ePtmux;\e\e]9;9;'"${wp}"$'\a\e\\'
    else
      __rice_osc=$'\e]9;9;'"${wp}"$'\a'
    fi
  fi
  # Referenced as a variable so bash doesn't decode the backslashes in the Windows path
  local osc='\[${__rice_osc}\]'

  PS1="${title}${osc}\n${w}${SOL_BASE01}${e}╭─${w}${c}${e} ${line1}\n${w}${SOL_BASE01}${e}╰─${w}${arrow_color}${e}❯${w}${c}${e} "
  PS2="${w}${SOL_BASE01}${e}  ┆${w}${c}${e} "
}
PROMPT_COMMAND=(__rice_prompt)

# ── Colors for ls/grep/gcc ────────────────────────────────────────
[[ -r ~/.dircolors ]] && eval "$(dircolors -b ~/.dircolors)"
export GREP_COLORS='ms=01;33:mc=01;33:sl=:cx=:fn=34:ln=32:bn=32:se=90'
export GCC_COLORS='error=01;31:warning=01;33:note=01;36:caret=01;32:locus=01:quote=01'

# ── Aliases ───────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias tree='tree -C --dirsfirst'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias mkdir='mkdir -pv'
# Interactive safety aliases — skipped inside Claude Code's shell, where prompts would hang/no-op
if [[ -z $CLAUDECODE ]]; then
  alias cp='cp -iv'
  alias mv='mv -iv'
  alias rm='rm -Iv'
fi
alias diff='diff --color=auto'
alias ip='ip -color=auto'
alias path='tr ":" "\n" <<< "$PATH"'
alias reload='exec bash -l'

# git
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --graph --pretty=format:"%C(yellow)%h%Creset %C(blue)%ad%Creset %s%C(magenta)%d%Creset %C(dim)%an%Creset" --date=short'
alias ga='git add'
alias gc='git commit'
alias gp='git push'

# tmux: attach to "main" or create it
alias t='tmux new-session -A -s main'
alias ta='tmux attach -t'
alias tl='tmux ls'

# ── WSL / Windows integration ─────────────────────────────────────
if [[ -n $WSL_DISTRO_NAME ]]; then
  alias open='explorer.exe'
  alias pbcopy='clip.exe'
  alias pbpaste='powershell.exe -NoProfile -Command Get-Clipboard | tr -d "\r"'
  # cd to the Windows user profile (resolved on first use, then cached)
  winhome() {
    [[ -z $__rice_winhome ]] && __rice_winhome=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
    cd "$__rice_winhome"
  }
  # open the current dir (or a path) in Windows Explorer
  e() { explorer.exe "$(wslpath -w "${1:-.}")"; true; }
  # copy file contents to the Windows clipboard
  copy() { if [[ -n $1 ]]; then clip.exe < "$1"; else clip.exe; fi; }
fi

# ── Optional modern tools (installed via apt) ─────────────────────
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first --icons=never'
  alias ll='eza -alh --git --group-directories-first --time-style=relative'
  alias la='eza -a --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
fi

if command -v batcat >/dev/null && ! command -v bat >/dev/null; then
  alias bat='batcat'
fi
if command -v bat >/dev/null || command -v batcat >/dev/null; then
  export BAT_THEME='Solarized (dark)'
  [[ -z $CLAUDECODE ]] && alias cat='bat --paging=never --style=plain'
  export MANPAGER="sh -c 'col -bx | $(command -v bat || command -v batcat) -l man -p'"
  export MANROFFOPT='-c'
fi

if command -v fzf >/dev/null; then
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border=rounded --info=inline
    --color=bg+:#073642,bg:-1,spinner:#2aa198,hl:#268bd2
    --color=fg:#839496,header:#268bd2,info:#b58900,pointer:#2aa198
    --color=marker:#2aa198,fg+:#eee8d5,prompt:#b58900,hl+:#268bd2,border:#586e75"
  if fzf --bash >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  else
    [[ -r /usr/share/doc/fzf/examples/key-bindings.bash ]] && . /usr/share/doc/fzf/examples/key-bindings.bash
    [[ -r /usr/share/bash-completion/completions/fzf ]] && . /usr/share/bash-completion/completions/fzf
  fi
fi

if command -v zoxide >/dev/null; then
  eval "$(zoxide init bash)"      # z <dir>, zi for interactive
fi
