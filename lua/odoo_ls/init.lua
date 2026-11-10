--- Public entry point: setup, restart and profile switching.
local M = {}

local api = require('odoo_ls.api')

M.restart = api.restart
M.set_profile = api.set_profile

--- Forward `profile`/`cmd` to the client config and enable it.
---@param opts? { profile?: string, cmd?: string[] }
function M.setup(opts)
  opts = opts or {}
  local cfg = { cmd = opts.cmd }
  if opts.profile then
    cfg.settings = { Odoo = { selectedProfile = opts.profile } }
  end
  vim.lsp.config('odoo_ls', cfg)
  vim.lsp.enable('odoo_ls')
end

return M
