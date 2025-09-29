-- This file provides the default configuration for the 'odoo_ls' server.

local odoo_ls_locations = {
    vim.fn.expand('$HOME/.local/share/nvim/odoo/odoo_ls_server'),
    "odoo_ls_server"
}

local executable = ''

for _, location in ipairs(odoo_ls_locations) do
    if vim.fn.executable(location) then
        executable = location
    end
end

return {
    cmd = {
        executable,
    },
    filetypes = { 'python', 'xml' },
    workspace_folders = { {
        uri = vim.uri_from_fname(vim.fn.getcwd()),
        name = 'main_folder'
    } },
    settings = {
        Odoo = {
            selectedProfile = 'main',
        }
    },
}
