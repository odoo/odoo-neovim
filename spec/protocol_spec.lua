local protocol = require('odoo_ls.protocol')
local handlers = protocol.handlers

local function leaf(value, ...)
  return { value = value, sources = { ... }, info = '' }
end

-- Shaped like the server's `ConfigView` serialization: profiles arrive resolved, keys as leaves.
local payload = {
  html = { __all__ = '<div></div>' },
  configFile = {
    config = {
      {
        name = 'base',
        extends = '',
        abstract = true,
        odoo_path = leaf('/w/odoo', '/w/odools.toml'),
      },
      {
        name = 'src',
        extends = 'base',
        abstract = false,
        odoo_path = leaf('/w/odoo', '/w/odools.toml'),
        addons_paths = {
          leaf('/w/enterprise', '/w/src/odools.toml'),
          leaf('/w/odoo/addons', '$workspaceFolder:odoo', '/w/src/odools.toml'),
        },
        tsserver_command = leaf('tsserver', '$default'),
        file_cache = leaf(false, '/w/src/odools.toml'),
        diagnostic_settings = { OLS01000 = leaf('error', '/w/src/odools.toml') },
      },
      {
        name = 'other',
        extends = '',
        abstract = false,
        odoo_path = leaf('/x/odoo', '/x/odools.toml'),
      },
    },
  },
  diagnostics = {
    { level = 2, message = "Config profile 'other': odoo_path rejected", profile = 'other' },
    { level = 1, message = "Config profile 'src': unknown key", profile = 'src' },
  },
}

describe('protocol', function()
  local notify = vim.notify

  before_each(function()
    vim.notify = function() end
    vim.lsp.config('odoo_ls', { settings = { Odoo = { selectedProfile = 'src' } } })
    handlers['$Odoo/setConfiguration'](nil, payload, { client_id = 7 })
    handlers['$Odoo/diagnostic_config'](nil, {
      action = 'replace',
      messages = { { level = 1, message = 'tsserver slow' }, { level = 0, message = 'indexing' } },
    })
    handlers['$Odoo/jsLsStatus'](nil, true)
  end)

  after_each(function()
    vim.notify = notify
  end)

  it('stores the configuration as the server sent it', function()
    assert.equal(payload, protocol.state.configuration)
    assert.same({ 'src', 'other' }, require('odoo_ls.api').profiles())
    assert.is_true(protocol.state.js)
  end)

  it('forgets the previous server crash and diagnostics when a new server starts', function()
    handlers['Odoo/displayCrashNotification'](nil, { crashInfo = 'panicked' })
    handlers['$Odoo/diagnostic_config'](nil, { action = 'extend', messages = { { level = 2, message = 'late' } } })
    handlers['$Odoo/setPid'](nil, { server_pid = 42 }, { client_id = 7 })
    local st = protocol.state
    assert.same({ 42, false }, { st.pid, st.crashed })
    assert.is_nil(st.configuration)
    assert.same({}, st.server_diagnostics)
  end)

  it('keeps the state of a new server when the client it replaced exits', function()
    handlers['$Odoo/setPid'](nil, { server_pid = 1 }, { client_id = 1 })
    handlers['$Odoo/setPid'](nil, { server_pid = 2 }, { client_id = 2 })
    protocol._on_exit(1)
    assert.equal(2, protocol.state.pid)
    protocol._on_exit(2)
    assert.is_nil(protocol.state.pid)
  end)

  it('says the server is not running when a profile is picked without a client', function()
    local notices = {}
    vim.notify = function(msg)
      table.insert(notices, msg)
    end
    require('odoo_ls.api').select_profile()
    assert.same({ 'odoo_ls is not running' }, notices)
  end)
end)
