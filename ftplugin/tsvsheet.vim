" Buffer-local settings for tsvsheet .tsvt spreadsheets.
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Cells are TAB-separated; expanding tabs to spaces corrupts the grid.
setlocal noexpandtab
setlocal softtabstop=0

let b:undo_ftplugin = 'setlocal expandtab< softtabstop<'
