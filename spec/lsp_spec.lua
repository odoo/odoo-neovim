local spec = dofile('lsp/odoo_ls.lua')

describe('lsp spec', function()
  it('attaches only under an odools.toml', function()
    assert.same({ 'odools.toml' }, spec.root_markers)
    assert.is_true(spec.workspace_required)
  end)

  it('reuses the running client for every buffer, but not one that is stopping', function()
    local stopped = false
    local client = {
      name = 'odoo_ls',
      is_stopped = function()
        return stopped
      end,
    }
    assert.is_true(spec.reuse_client(client, { name = 'odoo_ls', root_dir = '/elsewhere' }))
    assert.is_false(spec.reuse_client(client, { name = 'pyright' }))
    stopped = true
    assert.is_false(spec.reuse_client(client, { name = 'odoo_ls' }))
  end)
end)
