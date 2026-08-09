" tsvsheet.vim - .tsvt spreadsheet support: filetype plus tsvsheet-lsp wiring.
if exists('g:loaded_tsvsheet')
  finish
endif
let g:loaded_tsvsheet = 1

let s:save_cpo = &cpo
set cpo&vim

if has('nvim-0.11')
  " Native client; the server config lives in lsp/tsvsheet.lua on the runtimepath.
  lua vim.lsp.enable('tsvsheet')
else
  " Classic vim (or any editor without the native lsp/ config) via vim-lsp.
  " The User lsp_setup autocmd fires only when vim-lsp initializes, so this
  " stays inert when vim-lsp is absent; the executable() guard keeps it inert
  " when the server binary is absent too.
  function! s:register() abort
    " executable() can answer -1 (indeterminate); only a definite yes may
    " register, so an unlaunchable server never reaches the user as an error.
    if executable('tsvsheet-lsp') != 1
      return
    endif
    call lsp#register_server({
        \ 'name': 'tsvsheet-lsp',
        \ 'cmd': {server_info->['tsvsheet-lsp']},
        \ 'allowlist': ['tsvsheet'],
        \ })
  endfunction
  augroup tsvsheet_lsp
    autocmd!
    autocmd User lsp_setup call s:register()
  augroup END
endif

let &cpo = s:save_cpo
unlet s:save_cpo
