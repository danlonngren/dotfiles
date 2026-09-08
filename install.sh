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

install_dependencies() {
	case "$(uname -s)" in
	Darwin)
		if ! command -v brew >/dev/null 2>&1; then
			printf 'Homebrew is required on macOS: https://brew.sh\n' >&2
			return 1
		fi
		brew bundle --file "$repo_dir/Brewfile"
		;;
	Linux)
		if [[ -r /etc/os-release ]] && grep -qx 'ID=ubuntu' /etc/os-release; then
			"$repo_dir/scripts/install-ubuntu-dependencies"
		elif command -v brew >/dev/null 2>&1; then
			brew bundle --file "$repo_dir/Brewfile"
		else
			printf 'Unsupported Linux distribution. Use Ubuntu or install Homebrew first.\n' >&2
			return 1
		fi
		;;
	*)
		printf 'Unsupported operating system: %s\n' "$(uname -s)" >&2
		return 1
		;;
	esac
}

mkdir -p "$HOME/.config/tmux"

link_path "$repo_dir/zsh/.zshrc" "$HOME/.zshrc"
link_path "$repo_dir/zsh/.zshrc-paths" "$HOME/.zshrc-paths"
link_path "$repo_dir/zsh/.zshrc-aliases" "$HOME/.zshrc-aliases"

link_path "$repo_dir/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
link_path "$repo_dir/nvim" "$HOME/.config/nvim"

link_path "$repo_dir/scripts" "$HOME/scripts"

mkdir -p "$HOME/.config/tmuxinator"
for project_file in "$repo_dir"/tmuxinator/*.yml; do
	link_path "$project_file" "$HOME/.config/tmuxinator/$(basename "$project_file")"
done

install_dependencies

printf '\nInstall tmux plugins with prefix + I after starting tmux.\n'

missing_commands=()
for command_name in zsh tmux fzf rg nvim; do
	command -v "$command_name" >/dev/null 2>&1 || missing_commands+=("$command_name")
done

if ! command -v bat >/dev/null 2>&1 && ! command -v batcat >/dev/null 2>&1; then
	missing_commands+=(bat)
fi

if ((${#missing_commands[@]})); then
	printf 'Missing optional commands: %s\n' "${missing_commands[*]}" >&2
fi
