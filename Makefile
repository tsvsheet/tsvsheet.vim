.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

here := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

NVIM ?= nvim
VIM ?= vim
STYLUA ?= npx --yes @johnnymorganz/stylua-bin@2.3.0

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "\033[36m%-12s\033[0m %s\n",$$1,$$2}'

.PHONY: check
check: fmt-check test-nvim test-vim ## Run formatting and every editor test

.PHONY: test-nvim
test-nvim: ## Run the Neovim tests headless
	$(NVIM) -l $(here)test/nvim.lua

.PHONY: test-vim
test-vim: ## Run the classic-vim tests headless
	$(VIM) -es -N -u NONE -S $(here)test/vim.vim

.PHONY: fmt-check
fmt-check: ## Verify Lua formatting
	$(STYLUA) --check $(here)

.PHONY: fmt
fmt: ## Format the Lua sources
	$(STYLUA) $(here)
