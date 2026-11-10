if vim.g.loaded_odoo_ls then
  return
end
vim.g.loaded_odoo_ls = true

-- 0.12 is where :lsp restart exists
if vim.fn.has('nvim-0.12') == 0 then
  vim.notify('odoo-ls requires Neovim 0.12+', vim.log.levels.ERROR, { title = 'odoo_ls' })
  return
end

local subcommands = {
  restart = function()
    require('odoo_ls.api').restart()
  end,
  profile = function()
    require('odoo_ls.api').select_profile()
  end,
  logs = function()
    require('odoo_ls.api').open_logs()
  end,
  health = function()
    vim.cmd.checkhealth('odoo_ls')
  end,
}

vim.api.nvim_create_user_command('OdooLs', function(cmd)
  local sub = cmd.fargs[1] or 'health'
  local fn = subcommands[sub]
  if fn then
    fn(unpack(cmd.fargs, 2))
  else
    vim.notify('odoo_ls: unknown subcommand ' .. sub, vim.log.levels.ERROR, { title = 'odoo_ls' })
  end
end, {
  nargs = '*',
  desc = 'odoo-ls language server controls',
  complete = function(arglead, cmdline)
    local parts = vim.split(vim.trim(cmdline), '%s+')
    if #parts > 2 or (#parts == 2 and arglead == '') then
      return {}
    end
    return vim.tbl_filter(function(name)
      return name:find(arglead, 1, true) == 1
    end, vim.fn.sort(vim.tbl_keys(subcommands)))
  end,
})
