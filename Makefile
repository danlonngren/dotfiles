BASH_FILES := install.sh scripts/bulk-file-replace scripts/bulkreplace scripts/newpyscript scripts/newscript scripts/path
ZSH_FILES := zsh/.zshrc scripts/fzf-git scripts/logview

.PHONY: check syntax

syntax:
	bash -n $(BASH_FILES)
	zsh -n $(ZSH_FILES)
	python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("scripts/ssh-helper").read_text())'

check: syntax
	shellcheck --shell=bash $(BASH_FILES)
	shfmt -d $(BASH_FILES)
