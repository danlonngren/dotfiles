# Load this file only for interactive shells.
case $- in
*i*) ;;
*) return ;;
esac

# Homebrew is installed in different locations on Apple Silicon and Intel Macs.
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# Directories
export GITUSER="danlonngren"
export REPOS="$HOME/git"
export GHREPOS="$REPOS/github.com/$GITUSER"
export ICLOUD="$HOME/icloud"
export SCRIPTS="$HOME/scripts"

# PATH and platform tools
export PATH="$HOME/bin:$HOME/.local/bin:$HOME/dotnet:$SCRIPTS:$PATH"

if command -v brew >/dev/null 2>&1; then
  llvm_bin="$(brew --prefix llvm 2>/dev/null)/bin"
  [[ -d "$llvm_bin" ]] && export PATH="$llvm_bin:$PATH"
  unset llvm_bin
fi

# Shell behaviour
HISTSIZE=5000
HISTFILE="$HOME/.bash_history"
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend cmdhist

# Aliases
alias v='nvim'
alias c='clear'
alias e='exit'
alias tm='tmux'
alias refresh='exec bash'
alias vrc='nvim ~/.bashrc'
alias home='cd "$HOME"'
alias scripts='cd "$SCRIPTS"'
alias icloud='cd "$ICLOUD"'
alias repos='cd "$REPOS"'
alias ghrepos='cd "$GHREPOS"'
alias gr='cd "$GHREPOS"'
alias cdgo='cd "$GHREPOS/go"'
alias gp='git pull'
alias gs='git status'
alias lg='lazygit'
alias pstatus='echo "${PIPESTATUS[*]}"'

if [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi
alias la='ls -lathr'
alias lastmod='find . -type f -not -path "*/.*" -exec ls -lrt {} +'

# Prompt
git_branch() {
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

# fzf helpers
if command -v bat >/dev/null 2>&1; then
  export FZF_PREVIEW_COMMAND='bat --color=always --style=numbers'
elif command -v batcat >/dev/null 2>&1; then
  export FZF_PREVIEW_COMMAND='batcat --color=always --style=numbers'
else
  export FZF_PREVIEW_COMMAND='sed -n "1,160p"'
fi

ff() {
  local file

  file=$(rg --files | fzf --prompt='File > ' --preview="$FZF_PREVIEW_COMMAND {} 2>/dev/null") || return
  nvim "$file"
}

fdc() {
  local dir

  dir=$(find . -type d -not -path '*/.git/*' 2>/dev/null | fzf --prompt='Directory > ') || return
  cd "$dir" || return
}

gb() {
  local branch

  branch=$(git branch --all --format='%(refname:short)' | sed 's#^origin/##' | grep -v 'HEAD' | sort -u | fzf --prompt='Branch > ' --preview='git log --oneline --graph --color=always -20 {}') || return
  git switch "$branch" 2>/dev/null || git switch --track "origin/$branch"
}

gt() {
  local tag

  tag=$(git tag --sort=-creatordate | fzf --prompt='Tag > ' --preview='git show --color=always {}') || return
  git checkout "$tag"
}

gf() {
  local file

  file=$(git ls-files | fzf --prompt='File > ' --preview="${FZF_PREVIEW_COMMAND} {} 2>/dev/null") || return
  printf '%s\n' "$file"
}

gv() {
  local file

  file=$(git ls-files | fzf --prompt='Edit > ' --preview="${FZF_PREVIEW_COMMAND} {} 2>/dev/null") || return
  nvim "$file"
}

gl() {
  local commit

  commit=$(git log --oneline | fzf --prompt='Commit > ' --preview='git show --color=always {1}') || return
  git show "${commit%% *}"
}

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd bash)"
fi

# Keep machine-specific aliases and credentials outside this repository.
# shellcheck source=/dev/null
[[ -r "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"
