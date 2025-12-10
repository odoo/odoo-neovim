local M = {}

local installer = require('odoo_ls.installer')
local github = require('odoo_ls.github')
local lsp = require('odoo_ls.lsp')

local odoo_share = vim.fn.stdpath('data') .. '/odoo'
local last_check_file = odoo_share .. '/.last_version_check'
local uv = vim.uv or vim.loop

local defaults = {
    checkVersion = true,
    checkFrequency = 24,
    profile = 'main',
    version = 'stable',
}

local function build_cmd(executable, stdlib)
    local cmd = { executable }
    table.insert(cmd, '--stdlib')
    table.insert(cmd, stdlib)
    return cmd
end

local function configure_and_enable(executable, stdlib)
    vim.lsp.config('odoo_ls', {
        cmd = build_cmd(executable, stdlib),
        filetypes = { 'python', 'xml' },
        settings = {
            Odoo = {
                selectedProfile = M.config.profile,
            }
        },
        root_dir = function(bufnr, cb)
            local root = vim.fs.root(bufnr, '.git')
            if root then cb(root) end
        end,
    })
    lsp.enable()
    lsp.attach_open_buffers()
end

local function should_check_version()
    local stat = uv.fs_stat(last_check_file)
    if not stat then
        return true
    end
    local lines = vim.fn.readfile(last_check_file)
    local last_check = tonumber(lines[1]) or 0
    return (os.time() - last_check) >= M.config.checkFrequency * 3600
end

local function record_version_check()
    vim.fn.mkdir(odoo_share, 'p')
    vim.fn.writefile({ tostring(os.time()) }, last_check_file)
end

local function check_version(release, executable)
    if (release ~= "latest" and release ~= "stable") or not should_check_version() then
        return
    end
    vim.system({ executable, '--version' }, { text = true }, function(out)
        if out.code ~= 0 or not out.stdout then
            return
        end
        local version = vim.trim(out.stdout):match('%S+$')
        if release == "stable" then
            github.get_stable_release(function(tag, err)
                if err then return end
                record_version_check()
                if version ~= tag then
                    vim.notify(
                        '[odoo-ls] Update available: ' .. tag .. ' (current: ' .. version .. ')',
                        vim.log.levels.INFO
                    )
                end
            end)
        else
            github.get_latest_release(function(tag, err)
                if err then return end
                record_version_check()
                if version ~= tag then
                    vim.notify(
                        '[odoo-ls] Update available: ' .. tag .. ' (current: ' .. version .. ')',
                        vim.log.levels.INFO
                    )
                end
            end)
        end
    end)
end

function M.installOdooLs(release)
    release = release or M.config.version
    vim.notify('[odoo-ls] Installing...', vim.log.levels.INFO)
    local executable = odoo_share .. '/odoo_ls_server'
    installer.download(release, function()
        vim.notify('[odoo-ls] Installation complete', vim.log.levels.INFO)
        configure_and_enable(executable, odoo_share .. '/stdlib')
    end)
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend('force', defaults, opts or {})

    vim.api.nvim_create_user_command('OdooLsInstall', function(cmd_opts)
        M.installOdooLs(cmd_opts.args ~= '' and cmd_opts.args or nil)
    end, {
        nargs = '?',
        complete = function(arg_lead)
            local options = { 'stable', 'latest' }
            return vim.tbl_filter(function(opt)
                return opt:find(arg_lead, 1, true) == 1
            end, options)
        end
    })

    local executable = installer.get_executable()

    if executable == '' then
        M.installOdooLs()
        return
    end

    configure_and_enable(executable, odoo_share .. '/stdlib')

    if M.config.checkVersion then
        check_version(M.config.version, executable)
    end
end

return M
