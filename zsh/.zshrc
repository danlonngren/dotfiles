# ============================================================
# ZSH Configuration
# ============================================================

# Resolve this repository from the .zshrc symlink, so it can be cloned anywhere.
typeset _dotfiles_zshrc="${${(%):-%N}:A}"
export DOTFILES="${DOTFILES:-${_dotfiles_zshrc:h:h}}"
export SCRIPTS="${SCRIPTS:-$DOTFILES/scripts}"
unset _dotfiles_zshrc

# ------------------------------------------------------------
# Homebrew / PATH
# ------------------------------------------------------------

export PATH="/opt/homebrew/bin:$PATH"

path=(
  /opt/homebrew/opt/llvm/bin
  "$HOME/bin"
  "$HOME/.local/bin"
  "$HOME/dotnet"
  "$SCRIPTS"
  $path
)

[[ -d /home/vscode/.local/bin ]] && path+=(/home/vscode/.local/bin)
[[ -d /root/.local/bin ]] && path+=(/root/.local/bin)

typeset -U path
export PATH


# ------------------------------------------------------------
# Oh My Zsh
# ------------------------------------------------------------

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

ZSH_THEME="robbyrussell"

plugins=(
  git
  docker
  extract
)

# Disable async Git prompt if branch info fails to render
zstyle ':omz:alpha:lib:git' async-prompt false

[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"


# ------------------------------------------------------------
# Shell behaviour
# ------------------------------------------------------------

bindkey -v

export VISUAL="nvim"
export EDITOR="nvim"
export BROWSER="firefox"


# ------------------------------------------------------------
# Directories
# ------------------------------------------------------------

export REPOS="$HOME/git"
export GITUSER="danlonngren"
export GHREPOS="$REPOS/github.com/$GITUSER"
export ICLOUD="$HOME/icloud"


# ------------------------------------------------------------
# Go
# ------------------------------------------------------------

export GOPATH="$HOME/go"
export GOBIN="$HOME/.local/bin"
export GOPRIVATE="github.com/$GITUSER/*,gitlab.com/$GITUSER/*"


# ------------------------------------------------------------
# Build flags
# ------------------------------------------------------------

export LDFLAGS="-L/opt/homebrew/opt/expat/lib"
export CPPFLAGS="-I/opt/homebrew/opt/expat/include"
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/expat/lib"


# ------------------------------------------------------------
# History
# ------------------------------------------------------------

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY


# ------------------------------------------------------------
# General aliases
# ------------------------------------------------------------

alias v="nvim"
alias c="clear"
alias e="exit"
alias tm="tmux"

alias refresh="exec zsh"
alias vrc="nvim ~/.zshrc"

alias home='cd "$HOME"'

alias scripts='cd "$SCRIPTS"'
alias icloud='cd "$ICLOUD"'

alias repos='cd "$REPOS"'
alias ghrepos='cd "$GHREPOS"'
alias gr='cd "$GHREPOS"'
alias cdgo='cd "$GHREPOS/go"'


# ------------------------------------------------------------
# Personal shortcuts
# ------------------------------------------------------------

alias 0='cd "$HOME/0"'
alias zo='eval "$("$SCRIPTS/0-cd")"'


# ------------------------------------------------------------
# ls
# ------------------------------------------------------------

alias ls="ls -G"
alias la="ls -lathr"

alias lastmod='find . -type f -not -path "*/.*" -exec ls -lrt {} +'


# ------------------------------------------------------------
# Git aliases
# ------------------------------------------------------------

alias gp="git pull"
alias gs="git status"
alias lg="lazygit"


# ------------------------------------------------------------
# Pipeline status
# ------------------------------------------------------------

alias pstatus='echo "${pipestatus[*]}"'


# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------

autoload -Uz compinit
compinit


# ------------------------------------------------------------
# History navigation
# ------------------------------------------------------------

autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search

zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search


# ------------------------------------------------------------
# fzf
# ------------------------------------------------------------

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)

  alias fzf-preview="rg --files | fzf --preview 'bat --color=always --style=numbers {}'"
fi


# ------------------------------------------------------------
# External plugins
# ------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
  ZSH_AUTOSUGGESTIONS="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_SYNTAX_HIGHLIGHTING="$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

  [[ -f "$ZSH_AUTOSUGGESTIONS" ]] && source "$ZSH_AUTOSUGGESTIONS"
  [[ -f "$ZSH_SYNTAX_HIGHLIGHTING" ]] && source "$ZSH_SYNTAX_HIGHLIGHTING"
fi


# ------------------------------------------------------------
# Custom scripts
# ------------------------------------------------------------

[[ -r "$SCRIPTS/fzf-git" ]] && source "$SCRIPTS/fzf-git"

# ------------------------------------------------------------
# General fzf helpers
# ------------------------------------------------------------

ff() {
  local file

  file=$(
    rg --files |
      fzf \
        --prompt="File > " \
        --preview='bat --color=always --style=numbers {} 2>/dev/null'
  ) || return

  nvim "$file"
}


fdc() {
  local dir

  dir=$(
    find . -type d -not -path '*/.git/*' 2>/dev/null |
      fzf --prompt="Directory > "
  ) || return

  cd "$dir"
}



# ------------------------------------------------------------
# Show current git branch in shell
# ------------------------------------------------------------
git_branch() {
  git symbolic-ref --short HEAD 2>/dev/null
}

setopt PROMPT_SUBST
PROMPT='%F{green}➜%f  %F{cyan}%1~%f $(b=$(git_branch); [[ -n "$b" ]] && echo "%F{blue}git:($b)%f ")'

# ------------------------------------------------------------
# NVM
# ------------------------------------------------------------

export NVM_DIR="$HOME/.nvm"

# Keep machine-specific settings and secrets out of version control.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

[[ -s "$NVM_DIR/nvm.sh" ]] &&
  source "$NVM_DIR/nvm.sh"

[[ -s "$NVM_DIR/bash_completion" ]] &&
  source "$NVM_DIR/bash_completion"
