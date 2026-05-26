local M = {}

function M.enable()
  vim.lsp.enable('odoo_ls')
end

function M.attach_open_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if ft == 'python' or ft == 'xml' then
        vim.api.nvim_exec_autocmds('FileType', { buffer = buf, modeline = false })
      end
    end
  end
end

return M
