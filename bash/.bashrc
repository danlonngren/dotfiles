# Load this file only for interactive shells.
case $- in
*i*) ;;
*) return ;;
esac

# ---------------------------------------------------
# Homebrew is installed in different locations on Apple Silicon and Intel Macs.
# ---------------------------------------------------
if command -v brew >/dev/null 2>&1; then
	eval "$(brew shellenv)"
fi

# ---------------------------------------------------
# Aliases
# ---------------------------------------------------
alias refresh='exec bash'
alias vrc='nvim ~/.bashrc'
alias pstatus='echo "${PIPESTATUS[*]}"'

# ---------------------------------------------------
# Prompt
# ---------------------------------------------------
git_branch() {
	command -v git >/dev/null 2>&1 || return
	git symbolic-ref --short HEAD 2>/dev/null
}

__dotfiles_prompt_command() {
	local branch
	branch="$(git_branch)"
	PS1='\[\e[32m\]➜\[\e[0m\] \[\e[36m\]\W\[\e[0m\] '
	[[ -n "$branch" ]] && PS1+="\\[\\e[34m\\]git:($branch)\\[\\e[0m\\] "
	PS1+='\$ '
}

PROMPT_COMMAND=__dotfiles_prompt_command

# ---------------------------------------------------
# Shell behaviour
# ---------------------------------------------------
HISTSIZE=5000
HISTFILESIZE=10000
HISTFILE="$HOME/.bash_history"
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend cmdhist

# ---------------------------------------------------
# Readline keybindings (Bash)
# ---------------------------------------------------
# Up/Down search history entries beginning with the text already entered.
set -o emacs
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Some terminals (and tmux) send application-cursor sequences for arrow keys.
bind '"\eOA": history-search-backward'
bind '"\eOB": history-search-forward'

bind '"\e[C": forward-char'
bind '"\e[D": backward-char'
bind '"\eOC": forward-char'
bind '"\eOD": backward-char'

# Home/End vary between terminal emulators and tmux. Support the common ANSI,
# application-cursor, and xterm-style sequences.
bind '"\e[H": beginning-of-line'
bind '"\eOH": beginning-of-line'
bind '"\e[1~": beginning-of-line'
bind '"\e[7~": beginning-of-line'
bind '"\e[F": end-of-line'
bind '"\eOF": end-of-line'
bind '"\e[4~": end-of-line'
bind '"\e[8~": end-of-line'

# ---------------------------------------------------
# Shell integrations
# ---------------------------------------------------
if command -v fzf >/dev/null 2>&1 && fzf --bash >/dev/null 2>&1; then
	eval "$(fzf --bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
	eval "$(zoxide init --cmd cd bash)"
fi

# ---------------------------------------------------
# Sources
# ---------------------------------------------------
# shellcheck source=/dev/null
[[ -r "$HOME/.shellrc_common" ]] && source "$HOME/.shellrc_common"
[[ -r "$HOME/.bashrc_local" ]] && source "$HOME/.bashrc_local"
