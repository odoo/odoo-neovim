local M = {}

local uv = vim.uv or vim.loop

function M.get_platform()
    local sysinfo = uv.os_uname()

    local sysname = sysinfo.sysname:lower()
    local machine = sysinfo.machine

    local os_name
    if sysname == 'darwin' then
        os_name = 'darwin'
    elseif sysname == 'linux' then
        os_name = 'linux'
    elseif sysname:find('windows') or sysname:find('mingw') then
        os_name = 'win32'
    else
       vim.notify('[odoo-ls] Unsupported platform: ' .. sysinfo.sysname .. ' ' .. sysinfo.machine, vim.log.levels.ERROR)
    end

    local arch
    if machine == 'aarch64' or machine == 'arm64' then
        arch = 'aarch64'
    elseif machine == 'x86_64' or machine == 'x86-64' or machine == 'AMD64' then
        arch = 'x86_64'
    else
       vim.notify('[odoo-ls] Unsupported platform: ' .. sysinfo.sysname .. ' ' .. sysinfo.machine, vim.log.levels.ERROR)
    end

    return os_name, arch
end

function M.create_symlink(origin, target)
    if uv.fs_stat(target) then
        vim.fn.delete(target)
    end
    uv.fs_symlink(origin, target)
end

return M
