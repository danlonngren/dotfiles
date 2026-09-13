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
# Directories
# ---------------------------------------------------
# export DOTFILES=""
export GITUSER="$USER"
export REPOS="$HOME/git"
export GHREPOS="$REPOS/github.com/$GITUSER"
export ICLOUD="$HOME/icloud"
export DOTSCRIPTS="$HOME/scripts"

# PATH and platform tools
export PATH="$HOME/bin:$HOME/.local/bin:$HOME/dotnet:$DOTSCRIPTS:$PATH"

if command -v brew >/dev/null 2>&1; then
	llvm_bin="$(brew --prefix llvm 2>/dev/null)/bin"
	[[ -d "$llvm_bin" ]] && export PATH="$llvm_bin:$PATH"
	unset llvm_bin
fi

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
[[ -r "$HOME/.shellrc-common" ]] && source "$HOME/.shellrc-common"
# shellcheck source=/dev/null
[[ -r "$HOME/.bashrc-aliases" ]] && source "$HOME/.bashrc-aliases"

# Keep machine-specific aliases and credentials outside this repository.
# shellcheck source=/dev/null
[[ -r "$HOME/.bashrc-local" ]] && source "$HOME/.bashrc-local"
