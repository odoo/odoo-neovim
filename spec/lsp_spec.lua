local eq = MiniTest.expect.equality
local spec = dofile('lsp/odoo_ls.lua')

describe('lsp spec', function()
  it('attaches only under an odools.toml', function()
    eq(spec.root_markers, { 'odools.toml' })
    eq(spec.workspace_required, true)
  end)

  it('reuses the running client for every buffer, but not one that is stopping', function()
    local stopped = false
    local client = {
      name = 'odoo_ls',
      is_stopped = function()
        return stopped
      end,
    }
    eq(spec.reuse_client(client, { name = 'odoo_ls', root_dir = '/elsewhere' }), true)
    eq(spec.reuse_client(client, { name = 'pyright' }), false)
    stopped = true
    eq(spec.reuse_client(client, { name = 'odoo_ls' }), false)
  end)
end)
