--- Client controls: restart, profile switching, status and logs.
local M = {}

local protocol = require('odoo_ls.protocol')

local NAME = 'odoo_ls'

local function notify(msg, level)
  vim.notify(msg, level, { title = 'odoo_ls' })
end

--- The running client, skipping the old one that `:lsp restart` is still stopping.
---@return vim.lsp.Client?
local function get_client()
  return vim.iter(vim.lsp.get_clients({ name = NAME })):find(function(client)
    return not client:is_stopped()
  end)
end

M.get_client = get_client

---@return string
local function active_profile()
  local client = get_client()
  if client and client.config and client.config.settings then
    return vim.tbl_get(client.config.settings, 'Odoo', 'selectedProfile') or 'default'
  end
  local cfg = vim.lsp.config[NAME]
  return cfg and vim.tbl_get(cfg, 'settings', 'Odoo', 'selectedProfile') or 'default'
end

M.active_profile = active_profile

--- Non-abstract profile names of the last configuration snapshot, nil before the first one.
---@return string[]?
function M.profiles()
  local configuration = protocol.state.configuration
  if not configuration then
    return nil
  end
  local names = {}
  for _, p in ipairs(vim.tbl_get(configuration, 'configFile', 'config') or {}) do
    if not p.abstract then
      table.insert(names, p.name)
    end
  end
  return names
end

--- Restart the server on the same buffers, or enable it when no client runs.
function M.restart()
  if not get_client() then
    vim.lsp.enable(NAME)
    return
  end
  vim.cmd.lsp({ 'restart', NAME })
end

--- Select `profile` in the stored spec and the running client's settings, then restart.
---@param profile string
function M.set_profile(profile)
  vim.lsp.config(NAME, { settings = { Odoo = { selectedProfile = profile } } })
  local client = get_client()
  if client then
    client.config.settings = client.config.settings or {}
    client.config.settings.Odoo = client.config.settings.Odoo or {}
    client.config.settings.Odoo.selectedProfile = profile
  end
  M.restart()
end

--- Pick a profile from the last snapshot, or `"Disabled"` to idle the server, and apply it.
function M.select_profile()
  if not get_client() then
    notify('odoo_ls is not running', vim.log.levels.WARN)
    return
  end
  local profiles = M.profiles()
  if not profiles then
    notify('no configuration received from the server yet', vim.log.levels.WARN)
    return
  end
  table.insert(profiles, 'Disabled')
  local current = active_profile()
  vim.ui.select(profiles, {
    prompt = 'odoo_ls profile:',
    format_item = function(item)
      return item == current and (item .. '  (current)') or item
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice == current then
      notify('profile "' .. choice .. '" is already active', vim.log.levels.INFO)
      return
    end
    M.set_profile(choice)
  end)
end

--- Open the newest server log file (`<exe_dir>/logs/`).
function M.open_logs()
  local cmd = vim.lsp.config[NAME].cmd
  local exe = type(cmd) == 'table' and cmd[1] or ''
  local path = vim.fn.exepath(exe)
  if path == '' then
    notify('server binary not found: ' .. tostring(exe), vim.log.levels.ERROR)
    return
  end
  local dir = vim.fs.joinpath(vim.fs.dirname(vim.uv.fs_realpath(path) or path), 'logs')
  if vim.fn.isdirectory(dir) == 0 then
    notify('no logs directory: ' .. dir, vim.log.levels.WARN)
    return
  end
  local newest, newest_mtime
  for name, t in vim.fs.dir(dir) do
    if t == 'file' then
      local full = vim.fs.joinpath(dir, name)
      local stat = vim.uv.fs_stat(full)
      if stat and (not newest_mtime or stat.mtime.sec > newest_mtime) then
        newest_mtime = stat.mtime.sec
        newest = full
      end
    end
  end
  vim.cmd.edit(vim.fn.fnameescape(newest or dir))
end

return M
