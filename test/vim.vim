" Classic-vim test harness, run headless via `vim -es -N -u NONE -S test/vim.vim`.
" Asserts the portable core on vim: filetype detection, TAB-preserving buffer
" settings, and that the vim-lsp registration hook exists yet stays inert when
" vim-lsp is absent. Exits 1 (cquit) on any failure.

let s:root = fnamemodify(expand('<sfile>'), ':h:h')
let s:failures = []

function! s:check(name, ok) abort
  if a:ok
    verbose echo 'ok - ' .. a:name
  else
    call add(s:failures, a:name)
    verbose echo 'FAIL - ' .. a:name
  endif
endfunction

execute 'set runtimepath+=' .. s:root
filetype plugin on
runtime! plugin/tsvsheet.vim

let s:sheet = tempname() .. '.tsvt'
call writefile(["1\t2\t=A1+B1"], s:sheet)

set expandtab softtabstop=4
execute 'edit' fnameescape(s:sheet)

call s:check('plugin loaded', get(g:, 'loaded_tsvsheet', 0) == 1)
call s:check('filetype detected as tsvsheet', &filetype ==# 'tsvsheet')
call s:check('ftplugin disables expandtab', &l:expandtab == 0)
call s:check('ftplugin zeroes softtabstop', &l:softtabstop == 0)

" The vim-lsp hook is registered but inert: the autocmd exists, and nothing
" errored while loading without vim-lsp installed.
call s:check('vim-lsp registration hook exists', exists('#tsvsheet_lsp#User#lsp_setup') == 1)

" Execute the registration body against a stub vim-lsp, both ways: without the
" server binary the guard must keep it inert; with one on PATH the server must
" register with the contract's name, command, and filetype allowlist. The stub
" must live in a real autoload/lsp.vim on the runtimepath — vim refuses
" autoload-named functions defined anywhere else (E746).
let g:tsvsheet_test_registered = {}
let s:stub = tempname()
call mkdir(s:stub .. '/autoload', 'p')
call writefile([
    \ 'function! lsp#register_server(info) abort',
    \ '  let g:tsvsheet_test_registered = a:info',
    \ 'endfunction',
    \ ], s:stub .. '/autoload/lsp.vim')
execute 'set runtimepath+=' .. s:stub

let s:saved_path = $PATH
let s:emptydir = tempname()
call mkdir(s:emptydir, 'p')
let $PATH = s:emptydir
doautocmd User lsp_setup
call s:check('no registration without a binary', empty(g:tsvsheet_test_registered))

let s:bindir = tempname()
call mkdir(s:bindir, 'p')
call writefile(['#!/bin/sh'], s:bindir .. '/tsvsheet-lsp')
call setfperm(s:bindir .. '/tsvsheet-lsp', 'rwxr-xr-x')
let $PATH = s:bindir
doautocmd User lsp_setup
call s:check('registers as tsvsheet-lsp', get(g:tsvsheet_test_registered, 'name', '') ==# 'tsvsheet-lsp')
call s:check('registration launches tsvsheet-lsp',
    \ has_key(g:tsvsheet_test_registered, 'cmd') && g:tsvsheet_test_registered.cmd({}) ==# ['tsvsheet-lsp'])
call s:check('registration allowlists the tsvsheet filetype',
    \ get(g:tsvsheet_test_registered, 'allowlist', []) ==# ['tsvsheet'])
let $PATH = s:saved_path

" undo_ftplugin restores the global values on filetype change.
set filetype=text
call s:check('undo_ftplugin restores expandtab', &l:expandtab == 1)
call s:check('undo_ftplugin restores softtabstop', &l:softtabstop == 4)

if len(s:failures) > 0
  verbose echo len(s:failures) .. ' failure(s)'
  cquit
endif
verbose echo 'all vim tests passed'
qall!
