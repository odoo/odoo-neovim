# Neovim

Neovim client for the Odools language server

![screenshot](https://i.imgur.com/wuqsF9q.png)

## Important ⚠️
This plugin is still in its early development stage. Don't hesitate to submit bugs, issues and/or
feedbacks to improve the user experience.

This repository give some snippet example to make the [odoo-ls](https://github.com/odoo/odoo-ls)
working inside Neovim.

This will later become a true plugin managing the download of the server executable and dependencies

## Requirements
We recommend using nvim version `0.11.0` or later to benefit from the builtin lsp config helpers.
Working with `< 0.11` will require installing [lspconfig](https://github.com/neovim/nvim-lspconfig)

## Instalation
For now the language server is not included in the plugin. The plugin defines the config for neovim.
First download the [language server releases](https://github.com/odoo/odoo-ls/releases). 
The plugin will search for the server either directly on the path or inside the 
"$HOME/.local/share/nvim/odoo/odoo_ls_server" folder. For custom locations, the 
config will need to be update as in the [config section](#lspconfiglua-custom-config)

Additionally, the server requires the [python typeshed](https://github.com/python/typeshed).
The server will look for the stdlib either in the same folder as the server binary
or in the current working directory. Otherwise the stdlib can be configured both in the
[odools.toml](#odoolstoml) or [config](#lspconfiglua-custom-config)

## Configs

There are 2 configuration parts needed. One for the server directly, and one for neovim. 

The odools.toml file should be included in the root of you working directory and define the
addons, stubs and python path (if you need to use a different python executable such as a 
the one from a virtual environment). 

### odools.toml
 ```toml
name = "main"
odoo_path = "odoo"
addons_path = ["/home/user/src/enterprise"]
python_path = "/home/user/.pyenv/shims/python"
additional_stubs = ["/home/user/.local/nvim/odoo/typeshed/stubs"]
```

You can import the odoo-nvim plugin to provide a default setting for the odoo_ls.

### lazy.lua
```lua
    {'odoo/odoo-neovim'}
```

### lspconfig.lua (in nvim >0.11)
```lua
vim.lsp.config("odoo_ls", {
    -- custom config if needed
    })

vim.lsp.enable({"odoo_ls"})
```

The config can be customised depending on the needs. Multiple commands exist and can
be found on the [cli page of the server](https://github.com/odoo/odoo-ls/blob/release/server/src/args.rs).
But for setup reasons some notable ones are:
- --config-path - a specific path where to find the odools.toml
- --stdlib - give an alternative path to stdlib stubs from typeshed

### lspconfig.lua custom config
```lua
vim.lsp.config("odoo_ls", {
    cmd = {
        -- Path to the odoo_ls_server binary
        vim.fn.expand('$HOME/.local/share/nvim/odoo/odoo_ls_server'),
        '--config-path',
        'Path_to_toml/odools.toml',
        '--stdlib',
        'path_to_typeshed/stdlib',
    })
```
