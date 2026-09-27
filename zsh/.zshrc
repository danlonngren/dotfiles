if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# ------------------------------------------------------------
# Alias
# ------------------------------------------------------------
alias refresh="exec zsh"
alias vrc="nvim ~/.zshrc"
alias v="nvim"

# ------------------------------------------------------------
# ZINIT Setup
# ------------------------------------------------------------
# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ -r "${ZINIT_HOME}/zinit.zsh" ]]; then
  source "${ZINIT_HOME}/zinit.zsh"

  # Plugins. Syntax highlighting must load last.
  zinit light zsh-users/zsh-completions
  zinit light zsh-users/zsh-autosuggestions
  zinit light Aloxaf/fzf-tab

  zinit snippet OMZL::git.zsh
  zinit snippet OMZP::git
  zinit snippet OMZP::sudo
  zinit snippet OMZP::aws
  zinit snippet OMZP::kubectl
  zinit snippet OMZP::kubectx
  zinit snippet OMZP::command-not-found

  autoload -Uz compinit && compinit
  zinit cdreplay -q

  zinit light zsh-users/zsh-syntax-highlighting
fi

# ------------------------------------------------------------
# Shell behaviour
# ------------------------------------------------------------

export VISUAL="nvim"
export EDITOR="nvim"
export BROWSER="firefox"

# Final keybindings
bindkey -e

autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search

zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Some terminals (and tmux) send application-cursor sequences for arrow keys.
# Bind those variants too so prefix history search works consistently.
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

bindkey '^[[C' forward-char
bindkey '^[[D' backward-char

# Bind delete key
bindkey -M emacs '^[[3~' delete-char
bindkey -M viins '^[[3~' delete-char

# Home/End vary between terminal emulators and tmux. Support the common ANSI,
# application-cursor, and xterm-style sequences.
bindkey '^[[H' beginning-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[7~' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OF' end-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[8~' end-of-line

# History
HISTSIZE=5000
HISTFILE="$HOME/.zsh_history"
SAVEHIST=$HISTSIZE
setopt appendhistory
setopt sharehistory
setopt hist_expire_dups_first
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'command ls -la $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'command ls -la $realpath'

# Shell integrations
if command -v fzf >/dev/null 2>&1 && fzf --zsh >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd zsh)"
fi

# ------------------------------------------------------------
# Sources
# ------------------------------------------------------------
[[ -r "$HOME/.shellrc_common" ]] && source "$HOME/.shellrc_common"
[[ -r "$HOME/.zshrc_local" ]] && source "$HOME/.zshrc_local"

# Keep prompt initialization last so it can wrap the final shell configuration.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
