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

Install the core command-line dependencies listed in `Brewfile` with:

```sh
brew bundle --file Brewfile
```

Run the same local checks used by GitHub Actions with:

```sh
make check
```

The checks validate Bash and Zsh syntax, validate the Python helper, run
ShellCheck, and verify Bash formatting with shfmt.

`scripts/ssh-helper` needs its Python dependency when you use it:

```sh
python3 -m pip install -r requirements.txt
```

## Local settings

Put machine-specific values, tokens, and private aliases in `~/.zshrc.local`.
It is sourced after this configuration and is deliberately not tracked here.
Use `zsh/.zshrc.local.example` as a starting point.
