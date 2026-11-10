--- Custom `$Odoo/*` notifications of odoo-ls, normalised into the state the API and health read.
local M = {}

local levels = vim.log.levels

---@class odoo_ls.ServerDiagnostic
---@field level integer 0=info, 1=warning, 2=error
---@field message string

---@class odoo_ls.State
---@field client_id integer|nil    client of the server that sent `$Odoo/setPid`
---@field pid integer|nil          server process id (from `$Odoo/setPid`)
---@field loading string|nil       last loading status ('start'|'stop'|other)
---@field js boolean|nil           whether the server's tsserver runs (from `$Odoo/jsLsStatus`)
---@field configuration table|nil  last `$Odoo/setConfiguration` payload, as the server sent it
---@field server_diagnostics odoo_ls.ServerDiagnostic[]
---@field crashed boolean
---@field crash_info string|nil    full crash text (from panic hook)

--- Normalised server state, written only by the handlers below and read by the API and health.
---@type odoo_ls.State
local state = {
  server_diagnostics = {},
  crashed = false,
}

local function notify(msg, level)
  vim.notify(msg, level, { title = 'odoo_ls' })
end

--- `lsp-handler`s keyed by method, registered on the client by `lsp/odoo_ls.lua`.
---@type table<string, fun(err:any, result:any, ctx:any, config:any)>
local handlers = {}

-- The first notification of a new server, so state left by a previous one is cleared here
handlers['$Odoo/setPid'] = function(_, result, ctx)
  state.client_id = ctx.client_id
  state.pid = type(result) == 'table' and result.server_pid or nil
  state.crashed, state.crash_info = false, nil
  state.configuration, state.server_diagnostics = nil, {}
end

-- Loading status, sent as a bare string ('start'|'stop'|other)
handlers['$Odoo/loadingStatusUpdate'] = function(_, result)
  if type(result) ~= 'string' then
    return
  end
  state.loading = result
  if result == 'start' or result == 'stop' then
    return
  end
  if result == 'git_locked' then
    notify('indexing paused: git index locked', levels.WARN)
  else
    notify('status: ' .. result, levels.INFO)
  end
end

handlers['$Odoo/invalid_python_path'] = function()
  notify(
    'invalid python_path: the server could not spawn Python. Check python_path in odools.toml.',
    levels.ERROR
  )
end

handlers['$Odoo/restartNeeded'] = function()
  notify('server requested a restart', levels.INFO)
  require('odoo_ls.api').restart()
end

-- Full configuration snapshot, read by the API and health
handlers['$Odoo/setConfiguration'] = function(_, result)
  if type(result) ~= 'table' then
    return
  end
  state.configuration = result
  for _, d in ipairs(result.diagnostics or {}) do
    local lvl = d.level == 2 and levels.ERROR or levels.WARN
    local where = d.profile and d.profile ~= '' and (' [' .. d.profile .. ']') or ''
    notify('config' .. where .. ': ' .. tostring(d.message), lvl)
  end
end

-- tsserver status, a bare boolean that is true while the server's tsserver runs
handlers['$Odoo/jsLsStatus'] = function(_, result)
  state.js = result
end

local function server_level(n)
  if n == 2 then
    return levels.ERROR
  elseif n == 1 then
    return levels.WARN
  end
  return levels.INFO
end

-- Runtime server diagnostics, such as a tsserver startup failure
handlers['$Odoo/diagnostic_config'] = function(_, result)
  if type(result) ~= 'table' then
    return
  end
  if result.action == 'replace' then
    state.server_diagnostics = {}
  end
  for _, m in ipairs(result.messages or {}) do
    table.insert(state.server_diagnostics, m)
    notify('server: ' .. tostring(m.message), server_level(m.level))
  end
end

-- Panic-hook crash notification, the one method without a `$` prefix
handlers['Odoo/displayCrashNotification'] = function(_, result)
  state.crashed = true
  local info = type(result) == 'table' and result.crashInfo or nil
  state.crash_info = info
  local short = info and info:sub(1, 400) or 'server crashed'
  if info and #info > 400 then
    short = short .. '…'
  end
  notify('server crashed: ' .. short .. '\n(run :OdooLs for details)', levels.ERROR)
end

M.handlers = handlers
M.state = state

--- Reset volatile state when its client exits, called from the spec `on_exit`.
---@param client_id integer
function M._on_exit(client_id)
  -- After a restart the new server may have written the state before the old client exits
  if client_id ~= state.client_id then
    return
  end
  state.pid = nil
  state.js = nil
  state.loading = 'stop'
end

return M
