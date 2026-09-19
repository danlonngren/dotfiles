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
		"$repo_dir/scripts/install-ubuntu-dependencies"
		;;
	*)
		printf 'Unsupported operating system: %s\n' "$(uname -s)" >&2
		return 1
		;;
	esac
}

install_zinit() {
	local zinit_home="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

	if ! command -v git >/dev/null 2>&1; then
		printf 'Cannot install Zinit: git is required but was not found on PATH.\n' >&2
		return 1
	fi

	if [[ -r "$zinit_home/zinit.zsh" ]]; then
		printf 'Zinit is already installed at %s\n' "$zinit_home"
		return
	fi

	if [[ -e "$zinit_home" ]]; then
		printf 'Cannot install Zinit: %s exists but is not a valid Zinit checkout. Move it aside, then run this script again.\n' "$zinit_home" >&2
		return 1
	fi

	mkdir -p "$(dirname "$zinit_home")"
	git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$zinit_home"
}

install_nerd_font() {
	case "$(uname -s)" in
	Darwin)
		# Homebrew installs this cask from the Brewfile.
		return
		;;
	Linux)
		local font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMonoNerdFont"
		local archive

		if [[ -d "$font_dir" ]] && find "$font_dir" -maxdepth 1 -name '*.ttf' -print -quit | grep -q .; then
			printf 'JetBrains Mono Nerd Font is already installed at %s\n' "$font_dir"
			return
		fi

		archive="$(mktemp)"
		curl --fail --location --retry 3 \
			--output "$archive" \
			https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
		mkdir -p "$font_dir"
		tar -xJf "$archive" -C "$font_dir"
		rm -f "$archive"
		fc-cache --force "$font_dir"
		printf 'Installed JetBrains Mono Nerd Font at %s\n' "$font_dir"
		;;
	esac
}

set_default_shell() {
	local zsh_path
	local current_shell

	if ((EUID == 0)); then
		printf 'Skipping default-shell setup when running as root.\n' >&2
		return
	fi

	zsh_path="$(command -v zsh || true)"
	if [[ -z "$zsh_path" ]]; then
		printf 'Cannot set the default shell: zsh was not found on PATH.\n' >&2
		return 1
	fi

	# chsh only accepts shells registered by the operating system. Prefer the
	# discovered Zsh, but fall back to the system Zsh when Homebrew's is absent.
	if [[ -r /etc/shells ]] && ! grep -Fxq "$zsh_path" /etc/shells; then
		if [[ -x /bin/zsh ]] && grep -Fxq /bin/zsh /etc/shells; then
			zsh_path=/bin/zsh
		else
			printf 'Cannot set the default shell: %s is not listed in /etc/shells.\n' "$zsh_path" >&2
			return 1
		fi
	fi

	case "$(uname -s)" in
	Darwin)
		current_shell="$(dscl . -read "/Users/${USER}" UserShell 2>/dev/null | awk '{print $2}' || true)"
		;;
	Linux)
		current_shell="$(getent passwd "${USER}" 2>/dev/null | awk -F: '{print $7}' || true)"
		;;
	esac

	if [[ "$current_shell" == "$zsh_path" ]]; then
		printf 'Zsh is already the default shell (%s).\n' "$zsh_path"
		return
	fi

	chsh -s "$zsh_path"
	printf 'Set Zsh as the default shell. Open a new terminal session to use it.\n'
}

mkdir -p "$HOME/.config/tmux"

# zshrc
link_path "$repo_dir/zsh/.zshrc" "$HOME/.zshrc"
link_path "$repo_dir/shell/.shellrc_common" "$HOME/.shellrc_common"
link_path "$repo_dir/starship/starship.toml" "$HOME/.config/starship.toml"

# Bashrc
link_path "$repo_dir/bash/.bashrc" "$HOME/.bashrc"

link_path "$repo_dir/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
link_path "$repo_dir/nvim" "$HOME/.config/nvim"

link_path "$repo_dir/scripts" "$HOME/scripts"

# Load the repository-managed Git aliases without replacing any existing
# global Git configuration.
if command -v git >/dev/null 2>&1 \
	&& ! git config --global --get-all include.path 2>/dev/null | grep -Fxq '~/.git_aliases'; then
	git config --global --add include.path '~/.git_aliases'
fi

mkdir -p "$HOME/.config/tmuxinator"
for project_file in "$repo_dir"/tmuxinator/*.yml; do
	link_path "$project_file" "$HOME/.config/tmuxinator/$(basename "$project_file")"
done

install_dependencies
install_nerd_font
set_default_shell
install_zinit

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
