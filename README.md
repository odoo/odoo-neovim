# Neovim

Neovim client for the [odoo-ls](https://github.com/odoo/odoo-ls) language server

![screenshot](https://i.imgur.com/wuqsF9q.png)

## Important

This plugin is still in its early development stage. Don't hesitate to submit bugs, issues and/or
feedbacks to improve the user experience.

## Requirements

- Neovim `>= 0.11.0`
- `curl` (for downloading the server and typeshed)
- `tar` / `unzip` (for extracting release assets)

## Installation

### lazy.nvim
```lua
{
    'odoo/odoo-neovim',
    config = function()
        require('odoo_ls').setup()
    end
}
```

The plugin will automatically download the latest `odoo_ls_server` binary and
typeshed from [GitHub releases](https://github.com/odoo/odoo-ls/releases) on
launch. Both are installed into `vim.fn.stdpath('data') .. '/odoo'`
(typically `~/.local/share/nvim/odoo/`).

If the plugin can detect a server is already on installed either in `PATH`
or `vim.fn.stdpath('data') .. '/odoo'`, the plugin will use that existing
installation instead of downloading a new one.

On launch the plugin will check whether a new version of the server was
released. The latest version can be downloaded through the plugin using 
the `OdooLsInstall` command. This will remove the odoo_ls_server installed
under `vim.fn.stdpath('data') .. '/odoo_ls_server'` and create a new symlink
for the newest version to that path. The next time neovim is launched it will
pick up and use the newly installed version.

### Commands

| Command                      | Description                                                                                |
|------------------------------|--------------------------------------------------------------------------------------------|
| `:OdooLsInstall`             | Download and install the server + typeshed using the configured `version` channel          |
| `:OdooLsInstall stable`      | Install the latest stable release                                                          |
| `:OdooLsInstall latest`      | Install the latest release of any kind (including prereleases)                             |
| `:OdooLsInstall <tag>`       | Install a specific release tag (e.g. `:OdooLsInstall 1.2.1`)                               |

## Plugin options

Options are passed to `setup()`:

```lua
require('odoo_ls').setup({
    checkVersion = true,   -- check for updates on startup (default: true)
    checkFrequency = 24,   -- hours between update checks (default: 24)
    profile = 'main',      -- the profile defined in odoo.toml (default: 'main')
    version = 'stable',    -- release channel to install/check (default: 'stable')
})
```

| Option           | Type    | Default    | Description                                                                                                             |
|------------------|---------|------------|-------------------------------------------------------------------------------------------------------------------------|
| `checkVersion`   | boolean | `true`     | Check for a newer release on startup                                                                                    |
| `checkFrequency` | number  | `24`       | Minimum hours between version checks                                                                                    |
| `profile`        | string  | `'main'`   | The odoo.toml profile to be used by the server                                                                          |
| `version`        | string  | `'stable'` | Release channel (`'stable'` — latest stable, `'latest'` — incl. prereleases) or a specific release tag (e.g. `'1.2.1'`) |

Update checks only run when `version` is `'stable'` or `'latest'`. A pinned tag
(e.g. `version = '1.2.1'`) disables periodic update notifications.

## Configs

The odools.toml file should be included in the root of your working directory and define the
addons, stubs and python path (if you need to use a different python executable such as
the one from a virtual environment).

### odools.toml
```toml
name = "main"
odoo_path = "odoo"
addons_paths = ["/home/user/src/enterprise"]
python_path = "/home/user/.pyenv/shims/python"
additional_stubs = ["/home/user/.local/share/nvim/odoo/typeshed/stubs"]
```

### Server CLI arguments

The server supports additional CLI arguments documented in
[args.rs](https://github.com/odoo/odoo-ls/blob/release/server/src/args.rs).
Notable ones:

- `--config-path` — path to an `odools.toml` file
- `--stdlib` — alternative path to stdlib stubs from typeshed (automatically set by the plugin to the stdlib
in the typeshed bundled in the release)
