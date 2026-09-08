# Dotfiles

Zsh, tmux, Neovim, tmuxinator, and small terminal utilities for a personal development environment.

## Install

Clone the repository, then run:

```sh
./install.sh
```

The installer creates symlinks for `~/.zshrc`, `~/.zshrc-paths`, `~/.zshrc-aliases`, `~/.bashrc`, `~/.config/tmux/tmux.conf`, `~/.config/nvim`, `~/scripts`, and every tmuxinator project in `tmuxinator/`. It does not overwrite an existing non-symlink path; move or back up a conflicting path first. It also installs the platform's command-line dependencies.

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

Zsh initializes both `fzf` and `zoxide`. The Brewfile installs them; install `zoxide` separately when using the Ubuntu installer. `git` is also required for Zinit and TPM checkouts.

## Zsh

The main configuration loads Zinit from `$XDG_DATA_HOME/zinit/zinit.git` (or `~/.local/share/zinit/zinit.git`) and uses it for Powerlevel10k, completions, syntax highlighting, autosuggestions, and fzf-tab. The first shell startup checks out Zinit if it is absent.

`~/.zshrc-paths` sets the repository locations and adds `~/scripts` to `PATH`. `~/.zshrc-aliases` contains aliases, the prompt, and fzf helpers. The `ff`, `fdc`, `gf`, `gv`, `gb`, `gt`, and `gl` helpers use fzf; previews use `bat` when available and fall back to `sed` (`batcat` is supported on Ubuntu).

## Bash

`bash/.bashrc` is a dependency-light alternative for machines without Zsh. It provides the same directory variables, `PATH` entries, common aliases, Git prompt, fzf helpers, Git pickers, and fzf/zoxide shell integrations. It is active only in interactive shells and optionally sources `~/.bashrc.local` for machine-specific settings.

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
