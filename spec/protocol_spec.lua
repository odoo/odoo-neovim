local eq = MiniTest.expect.equality
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
    eq(protocol.state.configuration, payload)
    eq(require('odoo_ls.api').profiles(), { 'src', 'other' })
    eq(protocol.state.js, true)
  end)

  it('forgets the previous server crash and diagnostics when a new server starts', function()
    handlers['Odoo/displayCrashNotification'](nil, { crashInfo = 'panicked' })
    handlers['$Odoo/diagnostic_config'](nil, { action = 'extend', messages = { { level = 2, message = 'late' } } })
    handlers['$Odoo/setPid'](nil, { server_pid = 42 }, { client_id = 7 })
    local st = protocol.state
    eq({ st.pid, st.crashed }, { 42, false })
    eq(st.configuration, nil)
    eq(st.server_diagnostics, {})
  end)

  it('keeps the state of a new server when the client it replaced exits', function()
    handlers['$Odoo/setPid'](nil, { server_pid = 1 }, { client_id = 1 })
    handlers['$Odoo/setPid'](nil, { server_pid = 2 }, { client_id = 2 })
    protocol._on_exit(1)
    eq(protocol.state.pid, 2)
    protocol._on_exit(2)
    eq(protocol.state.pid, nil)
  end)

  it('says the server is not running when a profile is picked without a client', function()
    local notices = {}
    vim.notify = function(msg)
      table.insert(notices, msg)
    end
    require('odoo_ls.api').select_profile()
    eq(notices, { 'odoo_ls is not running' })
  end)

  describe('health', function()
    local health = vim.health

    -- Runs the check and returns the calls made from `from` on.
    local function section(from)
      local calls = {}
      vim.health = setmetatable({}, {
        __index = function(_, kind)
          return function(msg)
            table.insert(calls, { kind, msg })
          end
        end,
      })
      require('odoo_ls.health').check()
      for i, call in ipairs(calls) do
        if call[2] == from then
          return vim.list_slice(calls, i + 1)
        end
      end
    end

    after_each(function()
      vim.health = health
      protocol.state.crashed = false
    end)

    it('lists every key of the profile, marks the defaults and reports every diagnostic', function()
      eq(section('odoo_ls: profile src'), {
        { 'info', 'addons_paths = ["/w/enterprise", "/w/odoo/addons"]  $workspaceFolder:odoo `/w/src/odools.toml`' },
        { 'info', 'diagnostic_settings = { OLS01000 = "error" }        `/w/src/odools.toml`' },
        { 'info', 'file_cache = false                                  `/w/src/odools.toml`' },
        { 'info', 'odoo_path = "/w/odoo"                               `/w/odools.toml`' },
        { 'info', 'tsserver_command = "tsserver"                       default' },
        { 'info', 'other profiles: other' },
        { 'error', "config [other]: Config profile 'other': odoo_path rejected" },
        { 'warn', "config [src]: Config profile 'src': unknown key" },
        { 'warn', 'server: tsserver slow' },
        { 'info', 'server: indexing' },
      })
    end)

    it('lists the config files of every profile', function()
      local lines = vim.tbl_filter(function(call)
        return call[1] == 'ok' and call[2]:find('odools.toml in effect', 1, true)
      end, section('odoo-ls.nvim'))
      eq(lines, { { 'ok', 'odools.toml in effect (3):\n  /w/odools.toml\n  /w/src/odools.toml\n  /x/odools.toml' } })
    end)

    it('says only that the client is not running before the server sends its configuration', function()
      handlers['$Odoo/setPid'](nil, { server_pid = 1 }, { client_id = 1 })
      local calls = section('odoo-ls.nvim')
      eq(vim.list_slice(calls, #calls - 1), {
        { 'info', 'client not running (it attaches to python/xml/csv/js/ts files under an odools.toml)' },
        { 'info', 'no configuration received from the server yet' },
      })
    end)

    it('cuts a crash to its first 20 lines', function()
      local lines = {}
      for i = 1, 30 do
        table.insert(lines, 'frame ' .. i)
      end
      handlers['Odoo/displayCrashNotification'](nil, { crashInfo = table.concat(lines, '\n') })
      local crash = section('odoo_ls: profile src')[11]
      eq(crash, { 'error', table.concat(vim.list_slice(lines, 1, 20), '\n') })
    end)
  end)
end)
