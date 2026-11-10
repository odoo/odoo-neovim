--- `:checkhealth odoo_ls`
local M = {}

local NAME = 'odoo_ls'
--- Server release this plugin version is built for, bumped with every odoo-ls release.
local VERSION = '1.6.1'
local RELEASES = 'https://github.com/odoo/odoo-ls/releases'
local PROFILE_ATTRS = { name = true, extends = true, abstract = true }

local uv = vim.uv

local api = require('odoo_ls.api')
local st = require('odoo_ls.protocol').state

--- `vim.health`, looked up on each check.
local h

-- Unwrap the `{value, sources, info}` leaves of a config key, collecting their sources.
local function unwrap(v, sources)
  if type(v) ~= 'table' then
    return v
  end
  if v.sources then
    for _, src in ipairs(v.sources) do
      sources[src] = true
    end
    return v.value
  end
  local out = {}
  for k, e in pairs(v) do
    out[k] = unwrap(e, sources)
  end
  return out
end

--- Plain values and sorted sources of each key of a profile of the configuration snapshot.
---@return table<string, any> values, table<string, string[]> sources
local function flatten(profile)
  local values, sources = {}, {}
  for key, v in pairs(profile) do
    if not PROFILE_ATTRS[key] then
      local set = {}
      values[key] = unwrap(v, set)
      sources[key] = vim.tbl_keys(set)
      table.sort(sources[key])
    end
  end
  return values, sources
end

---@return table[]
local function snapshot_profiles()
  return vim.tbl_get(st, 'configuration', 'configFile', 'config') or {}
end

--- Values and sources of `name` in the snapshot, nil when the server sent no such profile.
---@return table<string, any>?, table<string, string[]>?
local function active_config(name)
  for _, p in ipairs(snapshot_profiles()) do
    if p.name == name then
      return flatten(p)
    end
  end
end

local function check_neovim()
  if vim.fn.has('nvim-0.12') == 1 then
    local v = vim.version()
    h.ok(('Neovim %d.%d.%d'):format(v.major, v.minor, v.patch))
  else
    h.error('Neovim 0.12+ is required')
  end
end

--- Report the server binary, its version and its typeshed, and return the launch command.
---@param config table<string, any>?
---@return string[]
local function check_binary(config)
  local cmd = vim.lsp.config[NAME].cmd
  cmd = type(cmd) == 'table' and cmd or {}
  local exe = cmd[1] or ''
  local path = vim.fn.exepath(exe)
  if path == '' then
    h.error('server binary not found: ' .. tostring(exe), {
      'Download it from ' .. RELEASES .. ' and put odoo_ls_server on PATH, or',
      "point at it: require('odoo_ls').setup({ cmd = { '/abs/path/odoo_ls_server' } })",
    })
    return cmd
  end
  local version = 'version unknown'
  local ok, res = pcall(function()
    return vim.system({ exe, '--version' }, { text = true }):wait(5000)
  end)
  if ok and res and res.stdout and vim.trim(res.stdout) ~= '' then
    version = vim.trim(res.stdout)
  end
  h.ok(('server binary: %s (%s)'):format(path, version))
  local found = version:match('(%d+%.%d+%.%d+)')
  if found and found ~= VERSION then
    h.warn(('server %s does not match the plugin version %s'):format(found, VERSION), {
      'Download odoo_ls_server ' .. VERSION .. ' from ' .. RELEASES,
    })
  end

  -- The server loads typeshed from next to its own executable (odoo-ls server/src/core/odoo.rs).
  local typeshed = vim.fs.joinpath(vim.fs.dirname(uv.fs_realpath(path) or path), 'typeshed')
  if uv.fs_stat(typeshed .. '/stdlib') then
    h.ok('bundled typeshed: ' .. typeshed)
  elseif config and config.stdlib and config.stdlib ~= '' then
    h.ok('stdlib (odools.toml): ' .. config.stdlib)
  else
    h.info('no typeshed next to the binary - supply the standard library via odools.toml (stdlib / additional_stubs)')
  end
  return cmd
end

--- List the config files that set a value in any profile of the server's snapshot.
---@param cmd string[]
local function check_config_files(cmd)
  -- The snapshot is authoritative because --config-path pins only one of several merged sources.
  local pinned
  for i, arg in ipairs(cmd) do
    if arg == '--config-path' then
      pinned = cmd[i + 1]
    end
  end
  if pinned and not uv.fs_stat(vim.fs.normalize(pinned)) then
    h.error('--config-path points at a missing file: ' .. pinned)
  end
  if not st.configuration then
    return
  end
  local files = {}
  for _, p in ipairs(snapshot_profiles()) do
    local _, sources = flatten(p)
    for _, list in pairs(sources) do
      for _, src in ipairs(list) do
        if vim.fn.isabsolutepath(src) == 1 then
          files[src] = true
        end
      end
    end
  end
  local sorted = vim.tbl_keys(files)
  table.sort(sorted)
  if #sorted > 0 then
    local lines = { ('odools.toml in effect (%d):'):format(#sorted) }
    for _, src in ipairs(sorted) do
      table.insert(lines, ('  %s%s'):format(src, src == pinned and '  (pinned via --config-path)' or ''))
    end
    h.ok(table.concat(lines, '\n'))
  else
    h.info('no odools.toml contributed a value - the server is running on built-in defaults')
  end
end

--- Report the running client, the scope of its buffers and its file watching.
---@param c vim.lsp.Client?
---@param profile string
---@param config table<string, any>?
local function check_client(c, profile, config)
  if not c then
    h.info('client not running (it attaches to python/xml/csv/js/ts files under an odools.toml)')
    return
  end
  h.ok(('client running (id=%d, server pid=%s, profile=%s)'):format(c.id, tostring(st.pid or '?'), profile))
  if st.loading then
    h.info('loading status: ' .. st.loading)
  end
  if st.js ~= nil then
    h.info('tsserver running in the server: ' .. (st.js and 'yes' or 'no'))
  end

  -- Files outside odoo_path/addons_paths are analyzed as isolated custom entry points
  local function realpath(p)
    return vim.fs.normalize(uv.fs_realpath(p) or p)
  end
  local cfg = config or {}
  local roots = vim.tbl_map(realpath, vim.list_extend({ cfg.odoo_path }, cfg.addons_paths or {}))
  if #roots == 0 then
    h.info('buffer scope not checked (no odoo_path/addons_paths received from the server yet)')
  end
  local in_scope = 0
  for buf in pairs(c.attached_buffers or {}) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= '' and #roots > 0 then
      local real = realpath(name)
      local inside = vim.iter(roots):any(function(d)
        return real == d or real:sub(1, #d + 1) == d .. '/'
      end)
      if inside then
        in_scope = in_scope + 1
      else
        h.warn(vim.fn.fnamemodify(name, ':~') .. ' is OUTSIDE odoo_path/addons_paths - analyzed as an isolated custom entry point (model completions/hover degraded)', {
          'Add its addons directory to addons_paths in odools.toml, or',
          'switch to a profile whose odoo_path covers this checkout (:OdooLs profile)',
        })
      end
    end
  end
  if in_scope > 0 then
    h.ok(('%d attached buffer(s) inside the configured project'):format(in_scope))
  end

  -- Watching needs both the server registration and the client capability (neovim#27807)
  local advertised = vim.tbl_get(c.capabilities, 'workspace', 'didChangeWatchedFiles', 'dynamicRegistration') == true
  local registered = c.dynamic_capabilities:get('workspace/didChangeWatchedFiles') ~= nil
  if advertised and registered then
    h.ok('file watching active (registered + advertised)')
    h.info('watching can be heavy over very large trees')
  elseif not advertised then
    h.warn('file watching is OFF: Neovim disables it by default on this OS, so external changes (git pull, branch switches, generated files) will NOT refresh the server index', {
      'Opt in (mind the CPU cost on huge trees):',
      "vim.lsp.config('odoo_ls', { capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } } })",
      'Without it, use :OdooLs restart after external changes.',
    })
  else
    h.info('watcher registration not received yet - it arrives shortly after the server initializes')
  end
  h.info('no odools.toml is covered by the watcher: edit them inside Neovim or the changes are missed')
end

local function check_companions()
  for _, name in ipairs({ 'pyright', 'basedpyright', 'ts_ls', 'vtsls' }) do
    if #vim.lsp.get_clients({ name = name }) > 0 then
      h.warn(name .. ' is also attached - it overlaps with odoo-ls features and may conflict')
    end
  end
end

--- Show every key of the active profile as the server resolved it, and the other profiles.
---@param profile string
---@param config table<string, any>?
---@param sources table<string, string[]>?
local function check_profile(profile, config, sources)
  if not st.configuration then
    h.info('no configuration received from the server yet')
    return
  end
  h.start('odoo_ls: profile ' .. profile)
  if not config or not sources then
    h.info('the server sent no profile named ' .. profile)
  else
    local function toml(v)
      if type(v) == 'string' then
        return ('"%s"'):format(v)
      elseif vim.islist(v) then
        return '[' .. table.concat(vim.tbl_map(toml, v), ', ') .. ']'
      end
      return type(v) == 'table' and (vim.inspect(v):gsub('%s+', ' ')) or tostring(v)
    end
    -- The health buffer is vimdoc, where a `code span` is colored and defaults stay plain text
    local function source(src)
      if src == '$default' then
        return 'default'
      end
      return vim.fn.isabsolutepath(src) == 1 and ('`%s`'):format(src) or src
    end
    local keys = vim.tbl_keys(config)
    table.sort(keys)
    local rows, width = {}, 0
    for _, k in ipairs(keys) do
      local left = ('%s = %s'):format(k, toml(config[k]))
      table.insert(rows, { left, table.concat(vim.tbl_map(source, sources[k]), ' ') })
      width = math.max(width, math.min(#left, 80))
    end
    for _, row in ipairs(rows) do
      h.info(('%-' .. width .. 's  %s'):format(row[1], row[2]))
    end
  end
  local others = vim.tbl_filter(function(name)
    return name ~= profile
  end, api.profiles())
  if #others > 0 then
    h.info('other profiles: ' .. table.concat(others, ', '))
  end
end

local function check_diagnostics()
  for _, d in ipairs(vim.tbl_get(st, 'configuration', 'diagnostics') or {}) do
    local where = d.profile and d.profile ~= '' and (' [' .. d.profile .. ']') or ''
    local report = d.level == 2 and h.error or h.warn
    report('config' .. where .. ': ' .. tostring(d.message))
  end
  for _, d in ipairs(st.server_diagnostics) do
    local report = ({ [1] = h.warn, [2] = h.error })[d.level] or h.info
    report('server: ' .. tostring(d.message))
  end
  if st.crashed then
    local lines = vim.split(st.crash_info or 'server crashed', '\n', { plain = true })
    h.error(table.concat(vim.list_slice(lines, 1, 20), '\n'), { 'full text in :OdooLs logs' })
  end
end

function M.check()
  h = vim.health
  local profile = api.active_profile()
  local config, sources = active_config(profile)
  h.start('odoo-ls.nvim')
  check_neovim()
  local cmd = check_binary(config)
  check_config_files(cmd)
  check_client(api.get_client(), profile, config)
  check_companions()
  check_profile(profile, config, sources)
  check_diagnostics()
end

return M
