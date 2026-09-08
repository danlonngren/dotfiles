# Dotfiles

Portable Zsh and tmux configuration, including an automatically saved terminal
workspace.

## Install

Clone this repository anywhere, then run:

```sh
./install.sh
```

The installer derives the repository location from itself and creates symlinks
for `.zshrc`, `.tmux.conf`, `~/scripts`, and the `work` tmuxinator project. It
will not replace an existing non-symlink path; move or back it up first.

Your shell derives `DOTFILES` and `SCRIPTS` from the installed `.zshrc`
symlink, so the repository may be cloned anywhere. The scripts are both added
to `PATH` and available at `$SCRIPTS`.

## Application configuration

The repository tracks Neovim's portable configuration in `config/nvim/`,
including `init.vim` and LSP settings. Installed plugins, state, logs, and
caches are intentionally excluded.

If `~/.config/nvim` already exists as a directory, preserve it before running
the installer so it can create the symlink:

```sh
mv ~/.config/nvim ~/.config/nvim.backup
./install.sh
```

Review the backup before deleting it. Add other application configurations only
when they are authored settings, not generated state or credentials.

## Requirements

- Zsh and [Oh My Zsh](https://ohmyz.sh/)
- tmux
- [TPM](https://github.com/tmux-plugins/tpm), installed with:

  ```sh
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  ```

Start tmux and press `prefix` then `I` (normally `Ctrl-b`, then `I`) to install
the configured plugins. `tmux-resurrect` saves sessions, panes, layouts, and
working directories; `tmux-continuum` saves every 15 minutes and restores the
latest workspace when tmux starts. You can also save with `prefix` + `Ctrl-s`
and restore with `prefix` + `Ctrl-r`.

Install `tmuxinator` if you want a repeatable starter layout, then run:

```sh
tmuxinator start work
```

## Dependencies and checks

`./install.sh` installs the core command-line dependencies for its platform:
Homebrew and the `Brewfile` on macOS, or APT on Ubuntu. Other Linux
distributions use the `Brewfile` when Homebrew is installed.

To install the dependencies separately on macOS or another Homebrew-supported
platform, run:

```sh
brew bundle --file Brewfile
```

To install the Ubuntu dependencies separately, run:

```sh
./scripts/install-ubuntu-dependencies
```

The installer enables the `universe` repository when needed and installs the
full package set, including Zsh and its plugins. Ubuntu names the `bat` command
`batcat`; this configuration detects it automatically. Install `wl-clipboard`
(Wayland) or `xclip` (X11) if you want `logview`'s Enter-to-copy binding.

## Local settings

Put machine-specific values, tokens, and private aliases in `~/.zshrc.local`.
It is sourced after this configuration and is deliberately not tracked here.
Use `zsh/.zshrc.local.example` as a starting point.
