-- Auto-discovered by vim.lsp.enable('odoo_ls'), override any field with vim.lsp.config('odoo_ls')

---@type vim.lsp.Config
return {
  cmd = { 'odoo_ls_server' },
  filetypes = { 'python', 'xml', 'csv', 'javascript', 'typescript' },
  -- Attach only under an odools.toml, whose directory becomes the workspace folder
  root_markers = { 'odools.toml' },
  workspace_required = true,
  -- One server per Neovim, whatever the root of the buffer
  reuse_client = function(client, config)
    return client.name == config.name and not client:is_stopped()
  end,
  -- utf-16 only because lemminx shares the xml buffers and all clients on a buffer must agree
  capabilities = { general = { positionEncodings = { 'utf-16' } } },
  settings = { Odoo = { selectedProfile = 'default' } },
}
