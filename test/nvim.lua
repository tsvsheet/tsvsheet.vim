-- Neovim test harness, run headless via `nvim -l test/nvim.lua`.
-- Asserts the plugin's whole contract: filetype detection, TAB-preserving
-- buffer settings and their undo, the native LSP config, inertness when the
-- server binary is absent, and (when a binary is available, or required via
-- TSVSHEET_VIM_E2E=required) a live attach + hover round trip.

local failures = {}

local function check(name, ok, detail)
  if ok then
    print(('ok - %s'):format(name))
  else
    failures[#failures + 1] = name
    print(('FAIL - %s%s'):format(name, detail and (': ' .. detail) or ''))
  end
end

local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(arg[0], ':p'))))
vim.opt.runtimepath:prepend(root)
vim.cmd('filetype plugin on')
vim.cmd('runtime! plugin/tsvsheet.vim')

local sheet = vim.fn.tempname() .. '.tsvt'
vim.fn.writefile({ '1\t2\t=A1+B1' }, sheet)

-- Globals the ftplugin must locally override, and undo back to.
vim.o.expandtab = true
vim.o.softtabstop = 4

-- Detection + ftplugin: the grid survives editing only with real tabs.
vim.cmd.edit(sheet)
check('filetype detected as tsvsheet', vim.bo.filetype == 'tsvsheet', 'got ' .. vim.bo.filetype)
check('ftplugin disables expandtab', vim.bo.expandtab == false)
check('ftplugin zeroes softtabstop', vim.bo.softtabstop == 0)

-- undo_ftplugin: leaving the filetype must restore the global values.
vim.bo.filetype = 'text'
check('undo_ftplugin restores expandtab', vim.bo.expandtab == true)
check('undo_ftplugin restores softtabstop', vim.bo.softtabstop == 4)
vim.cmd.bwipeout({ bang = true })

-- Native LSP config: name, command, and filetype are the published contract.
local config = vim.lsp.config['tsvsheet']
check('lsp config exists', config ~= nil)
check('lsp config launches tsvsheet-lsp', config ~= nil and config.cmd[1] == 'tsvsheet-lsp')
check(
  'lsp config binds the tsvsheet filetype',
  config ~= nil and #config.filetypes == 1 and config.filetypes[1] == 'tsvsheet'
)
check('lsp enabled for auto-attach', vim.lsp.is_enabled == nil or vim.lsp.is_enabled('tsvsheet'))

-- Inertness: no binary on PATH must mean no client and no error.
local real_path = vim.env.PATH
vim.env.PATH = ''
local opened = pcall(vim.cmd.edit, sheet)
vim.wait(500)
check('opening without a binary raises no error', opened)
check('no client attaches without a binary', #vim.lsp.get_clients({ bufnr = 0 }) == 0)
vim.cmd.bwipeout({ bang = true })
vim.env.PATH = real_path

-- Live attach + hover, the load-bearing property, when a server is available.
local e2e_required = vim.env.TSVSHEET_VIM_E2E == 'required'
if vim.fn.executable('tsvsheet-lsp') == 1 then
  vim.cmd.edit(sheet)
  local attached = vim.wait(10000, function()
    return #vim.lsp.get_clients({ bufnr = 0, name = 'tsvsheet' }) == 1
  end)
  check('client tsvsheet attaches', attached)
  if attached then
    local client = vim.lsp.get_clients({ bufnr = 0, name = 'tsvsheet' })[1]
    local hover
    client:request(
      'textDocument/hover',
      vim.lsp.util.make_position_params(0, client.offset_encoding),
      function(err, result)
        hover = err == nil and result ~= nil and result.contents ~= nil
      end
    )
    vim.wait(10000, function()
      return hover ~= nil
    end)
    check('hover answers on a cell', hover == true)
  end
elseif e2e_required then
  check('live attach (TSVSHEET_VIM_E2E=required)', false, 'tsvsheet-lsp not on PATH')
else
  print('skip - live attach (tsvsheet-lsp not on PATH; set TSVSHEET_VIM_E2E=required to enforce)')
end

if #failures > 0 then
  print(('%d failure(s): %s'):format(#failures, table.concat(failures, ', ')))
  os.exit(1)
end
print('all nvim tests passed')
