-- Neovim 0.11+ native LSP config, discovered from this runtimepath lsp/ directory.
-- The server binary comes from PATH; mason.nvim's install location is on nvim's PATH.
return {
  cmd = { 'tsvsheet-lsp' },
  filetypes = { 'tsvsheet' },
}
