local eq = MiniTest.expect.equality

describe('odoo_ls', function()
  it('exposes only setup, restart and set_profile', function()
    local odoo_ls = require('odoo_ls')
    local keys = vim.tbl_keys(odoo_ls)
    table.sort(keys)
    eq(keys, { 'restart', 'set_profile', 'setup' })
    for _, key in ipairs(keys) do
      eq(type(odoo_ls[key]), 'function')
    end
  end)

  describe('setup', function()
    local orig_enable = vim.lsp.enable
    local enabled

    before_each(function()
      enabled = 0
      vim.lsp.enable = function()
        enabled = enabled + 1
      end
    end)

    after_each(function()
      vim.lsp.enable = orig_enable
    end)

    it('launches odoo_ls_server from PATH by default, or the cmd it is given', function()
      require('odoo_ls').setup()
      eq(vim.lsp.config.odoo_ls.cmd, { 'odoo_ls_server' })
      require('odoo_ls').setup({ cmd = { '/opt/odoo_ls_server', '--log-level', 'info' } })
      eq(vim.lsp.config.odoo_ls.cmd, { '/opt/odoo_ls_server', '--log-level', 'info' })
      eq(enabled, 2)
    end)
  end)
end)
