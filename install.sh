#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

link_path() {
  local source_path="$1"
  local target_path="$2"

  if [[ -e "$target_path" && ! -L "$target_path" ]]; then
    printf 'Skipping %s: it is an existing non-symlink path. Move it aside, then run this script again.\n' "$target_path" >&2
    return 1
  fi

  ln -sfn "$source_path" "$target_path"
  printf 'Linked %s -> %s\n' "$target_path" "$source_path"
}

link_path "$repo_dir/zsh/.zshrc" "$HOME/.zshrc"
link_path "$repo_dir/zsh/.zshrc.pre-oh-my-zsh" "$HOME/.zshrc.pre-oh-my-zsh"
link_path "$repo_dir/tmux/.tmux.conf" "$HOME/.tmux.conf"
link_path "$repo_dir/scripts" "$HOME/scripts"

mkdir -p "$HOME/.config/tmuxinator"
for project_file in "$repo_dir"/tmuxinator/*.yml; do
  link_path "$project_file" "$HOME/.config/tmuxinator/$(basename "$project_file")"
done

printf '\nInstall tmux plugins with prefix + I after starting tmux.\n'
printf 'Install command-line dependencies with: brew bundle --file "%s/Brewfile"\n' "$repo_dir"

missing_commands=()
for command_name in zsh tmux fzf rg bat nvim; do
  command -v "$command_name" >/dev/null 2>&1 || missing_commands+=("$command_name")
done

if ((${#missing_commands[@]})); then
  printf 'Missing optional commands: %s\n' "${missing_commands[*]}" >&2
fi
