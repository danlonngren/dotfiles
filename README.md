# Dotfiles

Zsh, tmux, Neovim, tmuxinator, and small terminal utilities for a personal development environment.

## Install

Clone the repository, then run:

```sh
./install.sh
```

The installer creates symlinks for `~/.zshrc`, `~/.zshrc-paths`, `~/.zshrc-aliases`, `~/.bashrc`, `~/.shellrc-common`, `~/.config/tmux/tmux.conf`, `~/.config/nvim`, `~/scripts`, and every tmuxinator project in `tmuxinator/`. It does not overwrite an existing non-symlink path; move or back up a conflicting path first. It also installs the platform's command-line dependencies.

### Dependencies

On macOS, Homebrew is required and the installer runs:

```sh
brew bundle --file Brewfile
```

On Ubuntu, it enables `universe` and runs `scripts/install-ubuntu-dependencies`. Other Linux distributions require Homebrew. Run either dependency setup separately with:

```sh
brew bundle --file Brewfile
# or, on Ubuntu
./scripts/install-ubuntu-dependencies
```

Zsh initializes `fzf` and `zoxide` only when they are available. The Brewfile installs both; install `zoxide` separately when using the Ubuntu installer. `git` is installed by both platform installers and is required for the Zinit checkout.

## Zsh

The installer checks out Zinit to `$XDG_DATA_HOME/zinit/zinit.git` (or `~/.local/share/zinit/zinit.git`). The main configuration loads it for Powerlevel10k, completions, syntax highlighting, autosuggestions, and fzf-tab; shell startup never performs a network checkout.

`~/.zshrc-paths` sets the repository locations and adds `~/scripts` to `PATH`. `~/.shellrc-common` contains shared aliases and fzf helpers for both shells; the shell-specific alias files retain only shell-specific behavior. The `ff`, `fdc`, `gf`, `gv`, `gb`, `gt`, and `gl` helpers use fzf; previews use `bat` when available and fall back to `sed` (`batcat` is supported on Ubuntu). `~/scripts/fzf-git` remains as a compatibility loader for older configurations.

## Bash

`bash/.bashrc` is a dependency-light alternative for machines without Zsh. It provides the same directory variables, `PATH` entries, common aliases, Git prompt, fzf helpers, Git pickers, and fzf/zoxide shell integrations. It is active only in interactive shells and optionally sources `~/.bashrc-local` for machine-specific settings.

Optional integrations are guarded: a missing tool never prevents shell startup, and an fzf helper reports the missing command when invoked.

## tmux and tmuxinator

tmux uses `Ctrl-Space` as its prefix, Vim-style pane navigation, mouse support, and pane splits that inherit the current working directory. It uses TPM for `tmux-sensible`, `vim-tmux-navigator`, `catppuccin-tmux`, and `tmux-yank`.

Install TPM, start tmux, then press `prefix` followed by `I` to install the configured plugins:

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Two tmuxinator layouts are included:

```sh
tmuxinator start dotfiles
tmuxinator start work
```

`dotfiles` defaults to `~/dotfiles` unless `DOTFILES` is set; `work` defaults to `~/git` unless `REPOS` is set.

## Neovim

The Neovim configuration uses vim-plug. Install vim-plug before opening Neovim with this configuration, then run `:PlugInstall`. It configures UI settings, NERDTree, Fugitive, nvim-cmp, LuaSnip, and `nvim-lspconfig`.

LSP support requires Neovim 0.11 or later and language servers on `PATH`:

- `clangd` for C and C++
- `basedpyright-langserver` for Python

The Python LSP definition is in `nvim/lsp/basedpyright.lua`.

## Scripts

The installed `~/scripts` directory contains `fzf-git` (Git pickers), `logview` (browse, regex-search, or follow a log), `newscript`, `newpyscript`, and `path`. `logview` copies the selected line with Enter when `pbcopy`, `wl-copy`, or `xclip` is available.
