# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ -r "${ZINIT_HOME}/zinit.zsh" ]]; then
  source "${ZINIT_HOME}/zinit.zsh"

  # Theme and plugins. Syntax highlighting must load last.
  zinit ice depth=1
  zinit light romkatv/powerlevel10k

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if (( $+functions[p10k] )) && [[ -r "$HOME/.p10k.zsh" ]]; then
  source "$HOME/.p10k.zsh"
fi

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

# Source files
[[ -r "$HOME/.zshrc-paths" ]] && source "$HOME/.zshrc-paths"
[[ -r "$HOME/.shellrc-common" ]] && source "$HOME/.shellrc-common"
[[ -r "$HOME/.zshrc-aliases" ]] && source "$HOME/.zshrc-aliases"

[[ -r "$HOME/.zshrc-local" ]] && source "$HOME/.zshrc-local"
