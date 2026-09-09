COMMON_FILES := shell/.shellrc-common
BASH_FILES := $(COMMON_FILES) bash/.bashrc bash/.bashrc-aliases install.sh scripts/fzf-git scripts/install-ubuntu-dependencies scripts/newpyscript scripts/newscript scripts/path
ZSH_FILES := $(COMMON_FILES) zsh/.zshrc zsh/.zshrc-aliases zsh/.zshrc-paths scripts/logview

.PHONY: check syntax

syntax:
	bash -n $(BASH_FILES)
	zsh -n $(ZSH_FILES)

check: syntax
	shellcheck --shell=bash $(BASH_FILES)
	shfmt -d $(BASH_FILES)
