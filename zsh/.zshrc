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

  # Prompt and plugins. Syntax highlighting must load last.
  zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
  zinit light sindresorhus/pure

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

# Pure normally separates its context and input lines. Keep the same dynamic
# components, including the built-in virtualenv indicator, on one line.
if (( $+functions[prompt_pure_setup] )); then
  # Let Pure render virtualenv names while preventing activation scripts from
  # prepending a second, unmanaged prompt prefix.
  export VIRTUAL_ENV_DISABLE_PROMPT=20
  zstyle ':prompt:pure:environment:virtualenv' show yes
  PROMPT=${PROMPT//\$\{prompt_newline\}/ }

  # Pure unconditionally prints a blank line before each prompt. It does not
  # expose this as an option, so retain its preprompt logic without that print.
  function prompt_pure_preprompt_render() {
    setopt localoptions noshwordsplit
    unset prompt_pure_async_render_requested
    typeset -g prompt_pure_git_branch_color=$prompt_pure_colors[git:branch]
    [[ -n ${prompt_pure_git_last_dirty_check_timestamp+x} ]] && prompt_pure_git_branch_color=$prompt_pure_colors[git:branch:cached]
    psvar[12]=
    ((${(M)#jobstates:#suspended:*} != 0)) && psvar[12]=${PURE_SUSPENDED_JOBS_SYMBOL-✦}
    psvar[14]=${prompt_pure_vcs_info[branch]}
    psvar[15]=${prompt_pure_git_dirty}
    psvar[16]=${prompt_pure_vcs_info[action]}
    psvar[17]=${prompt_pure_git_arrows}
    psvar[18]=
    [[ -n $prompt_pure_git_stash ]] && psvar[18]=${PURE_GIT_STASH_SYMBOL-≡}
    psvar[19]=${prompt_pure_cmd_exec_time}
    psvar[21]=
    if [[ -n $prompt_pure_node_version ]]; then
      local node_symbol
      zstyle -s ':prompt:pure:environment:node_version' symbol node_symbol || node_symbol='⬢'
      psvar[21]="${node_symbol}${prompt_pure_node_version}"
    fi
    psvar[22]=
    psvar[23]=
    if (( $+functions[prompt_pure_precustom] )); then
      prompt_pure_precustom
    fi
    local -a prompt_fingerprint_parts=(
      "${psvar[12]}" "${psvar[13]}" "${psvar[14]}" "${psvar[15]}"
      "${psvar[16]}" "${psvar[17]}" "${psvar[18]}" "${psvar[19]}"
      "${psvar[20]}" "${psvar[21]}" "${psvar[22]}" "${psvar[23]}"
      "${prompt_pure_state[prompt]}" "${prompt_pure_git_branch_color}" "${PWD}"
    )
    local prompt_fingerprint="${(pj:|:)${(@qqq)prompt_fingerprint_parts}}"

    if [[ $1 != precmd && $prompt_pure_last_prompt != $prompt_fingerprint ]]; then
      prompt_pure_reset_prompt
    fi

    typeset -g prompt_pure_last_prompt=$prompt_fingerprint
  }

  typeset -g _pure_docker_image=''
  typeset -gi _pure_docker_image_checked=0

  function prompt_pure_precustom() {
    if (( ! _pure_docker_image_checked )); then
      _pure_docker_image_checked=1
      _pure_docker_image=${DOCKER_IMAGE:-${DOCKER_IMAGE_NAME:-}}

      # Docker has no global "current image" on the host. Inside a container,
      # the image can be resolved when the Docker socket and CLI are available.
      if [[ -z $_pure_docker_image && -r /.dockerenv && -S /var/run/docker.sock ]] \
        && (( $+commands[docker] )); then
        _pure_docker_image=$(docker inspect --format '{{.Config.Image}}' "$(hostname)" 2>/dev/null)
      fi
    fi

    [[ -n $_pure_docker_image ]] && psvar[23]="🐳 ${_pure_docker_image}"
  }
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
# bindkey '^[OA' up-line-or-beginning-search
# bindkey '^[OB' down-line-or-beginning-search

# bindkey '^[[C' forward-char
# bindkey '^[[D' backward-char

# Bind delete key
bindkey -M emacs '^[[3~' delete-char
bindkey -M viins '^[[3~' delete-char

# Home/End vary between terminal emulators and tmux. Support the common ANSI,
# application-cursor, and xterm-style sequences.
# bindkey '^[[H' beginning-of-line
# bindkey '^[OH' beginning-of-line
# bindkey '^[[1~' beginning-of-line
# bindkey '^[[7~' beginning-of-line
# bindkey '^[[F' end-of-line
# bindkey '^[OF' end-of-line
# bindkey '^[[4~' end-of-line
# bindkey '^[[8~' end-of-line

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
