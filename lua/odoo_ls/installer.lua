local M = {}

local github = require('odoo_ls.github')
local sys = require('odoo_ls.sys')

local odoo_share = vim.fn.stdpath('data') .. '/odoo'

local function download_callback(tag_name, error, on_complete)
    if error then
        vim.notify('[odoo-ls] Could not fetch latest release: ' .. error, vim.log.levels.ERROR)
        return
    end

    local os_name, arch = sys.get_platform()

    local ext = os_name == 'win32' and 'zip' or 'tar.gz'
    local asset = string.format('odoo-%s-%s-%s.%s', os_name, arch, tag_name, ext)
    local download_base = string.format(github.download_url .. '/%s', tag_name)

    local install_dir = string.format(odoo_share .. '/%s', tag_name)
    local server_location = install_dir .. '/odoo_ls_server'
    local typeshed_location = install_dir .. '/typeshed'
    local uv = vim.uv or vim.loop

    if uv.fs_stat(server_location) and uv.fs_stat(typeshed_location) then
        sys.create_symlink(server_location, odoo_share .. '/odoo_ls_server')
        sys.create_symlink(typeshed_location .. '/stdlib', odoo_share .. '/stdlib')
        sys.create_symlink(typeshed_location, odoo_share .. '/typeshed')
        if on_complete then
            on_complete()
        end
        return
    end

    vim.fn.mkdir(install_dir, 'p')

    local remaining = 2
    local function check_done()
        remaining = remaining - 1
        if remaining == 0 and on_complete then
            vim.schedule(function() on_complete() end)
        end
    end

    -- Download odoo_ls_server
    local server_download_location = string.format(install_dir .. '/%s', asset)
    github.download_asset(string.format(download_base .. '/%s', asset), server_download_location, function(ok)
        if not ok then
            vim.notify('[odoo-ls] Could not download the server', vim.log.levels.ERROR)
            return
        end

        local extract_cmd
        if ext == 'zip' then
            extract_cmd = { 'unzip', '-o', server_download_location, '-d', install_dir }
        else
            extract_cmd = { 'tar', '-xzf', server_download_location, '-C', install_dir }
        end

        vim.system(extract_cmd, {}, function(extract_out)
            vim.schedule(function()
                if extract_out.code ~= 0 then
                    vim.notify('[odoo-ls] Server extraction failed', vim.log.levels.ERROR)
                    return
                end

                vim.fn.delete(server_download_location)
                vim.fn.setfperm(server_location, 'rwxr-xr-x')

                sys.create_symlink(server_location, odoo_share .. '/odoo_ls_server')
                check_done()
            end)
        end)
    end)

    -- Download typeshed
    local typeshed_download_location = string.format(install_dir .. '/typeshed.zip')
    github.download_asset(string.format(download_base .. '/%s', 'typeshed.zip'), typeshed_download_location, function(ok)
        if not ok then
            vim.notify('[odoo-ls] Could not download the typeshed', vim.log.levels.ERROR)
            return
        end

        local extract_cmd = { 'unzip', '-o', typeshed_download_location, '-d', typeshed_location }

        vim.system(extract_cmd, {}, function(extract_out)
            vim.schedule(function()
                if extract_out.code ~= 0 then
                    vim.notify('[odoo-ls] Typeshed extraction failed', vim.log.levels.ERROR)
                    return
                end

                vim.fn.delete(typeshed_download_location)
                sys.create_symlink(typeshed_location .. '/stdlib', odoo_share .. '/stdlib')
                sys.create_symlink(typeshed_location, odoo_share .. '/typeshed')
                check_done()
            end)
        end)
    end)
end

function M.get_executable()
    local odoo_ls_locations = {
        string.format(odoo_share .. '/%s', 'odoo_ls_server'),
        "odoo_ls_server"
    }
    local executable = ''
    for _, location in ipairs(odoo_ls_locations) do
        if vim.fn.executable(location) == 1 then
            executable = location
        end
    end
    return executable
end

function M.download(release, on_complete)
    if release == "latest" then
        github.get_latest_release(function(tag_name, error)
            download_callback(tag_name, error, on_complete)
        end)
    elseif release == "stable" then
        github.get_stable_release(function(tag_name, error)
            download_callback(tag_name, error, on_complete)
        end)
    else
        download_callback(release, nil, on_complete)
    end
end

return M
