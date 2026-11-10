# odoo-neovim

A Neovim client for the [odoo-ls](https://github.com/odoo/odoo-ls) language
server. It launches the binary, answers the server's configuration request and
handles its `$Odoo/*` notifications. The real configuration lives in
`odools.toml`, read by the server, and the client adds no keymaps or UI of its
own.

Inside Neovim, the full reference is `:help odoo_ls`.

![Field completion with types and documentation while typing in an Odoo model](doc/assets/completion.png)

## Requirements

- Neovim **0.12+**.
- `odoo_ls_server` and its typeshed stubs from the
  [odoo-ls releases](https://github.com/odoo/odoo-ls/releases).

## Install

Download the release archive for your platform and `typeshed.zip` from the
[odoo-ls releases](https://github.com/odoo/odoo-ls/releases). Extract the
archive, then extract `typeshed.zip` into a `typeshed/` directory next to the
`odoo_ls_server` binary, where the server looks for it. Put the binary on your
`PATH`, or pass its path as the `cmd` option.

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'odoo/odoo-neovim',
  ft = { 'python', 'xml', 'csv', 'javascript', 'typescript' },
  cmd = 'OdooLs',  -- lazy-loads on this command, unrelated to the server's cmd
  opts = {},  -- must be set, even empty, for lazy.nvim to call setup()
}
```

With the binary outside `PATH`:

```lua
opts = { cmd = { '/abs/path/to/odoo_ls_server' } },
```

Options (all optional):

```lua
require('odoo_ls').setup({
  profile = 'default',  -- odools.toml profile to select
  cmd = { '/abs/path/to/odoo_ls_server' },  -- not needed when odoo_ls_server is on PATH
})
```

`setup()` is optional: a plain `vim.lsp.enable('odoo_ls')` uses the
`lsp/odoo_ls.lua` spec as is.

## Configuration

The client attaches only to files under an `odools.toml`, and that file's
directory becomes the workspace folder. Neovim runs a single server, which
buffers under another `odools.toml` join. Put it in the directory that holds both
odoo and enterprise. Each profile is a `[[config]]` table:

```toml
#:schema https://github.com/odoo/odoo-ls/releases/download/1.6.1/config_schema.json

[[config]]
name = "default"
odoo_path = "/home/user/src/odoo"
addons_paths = ["/home/user/src/enterprise"]
python_path = "/home/user/.pyenv/shims/python"
```

See the [odoo-ls repository](https://github.com/odoo/odoo-ls) for every key.
The client only chooses the profile (`"default"` unless set, `"Disabled"` makes
the server idle) and the launch command, also settable the standard way:

```lua
vim.lsp.config('odoo_ls', {
  cmd = { '/abs/path/to/odoo_ls_server' },
  settings = { Odoo = { selectedProfile = 'My Setup' } },
})
```

## Commands

| Command           | Action                                                     |
| ----------------- | ---------------------------------------------------------- |
| `:OdooLs health`  | Run `:checkhealth odoo_ls` (default when run bare).        |
| `:OdooLs profile` | Pick a profile via `vim.ui.select` and restart the server. |
| `:OdooLs restart` | Restart the server, re-attaching current buffers.          |
| `:OdooLs logs`    | Open the newest server log file.                           |

![:OdooLs profile - vim.ui.select with the active profile marked](doc/assets/profile-picker.png)

## Health

`:checkhealth odoo_ls` is the first stop when something looks wrong. It reports
which binary runs and whether its version matches the plugin, which
`odools.toml` files the server uses and every key of the active profile,
buffers outside the workspace, typeshed, file watching, overlapping Python and
TypeScript servers, and every config and server diagnostic.

![:checkhealth odoo_ls with the active profile section](doc/assets/health.png)

## Known limitations

- **File watching is off on Linux.** Neovim disables it there by default, so a
  `git pull` or branch switch is not seen by the server. Run `:OdooLs restart`,
  or see `:help odoo_ls-limitations` to opt in.
- **`odools.toml` is not watched.** Edits made outside Neovim need a restart.
- **Position encoding is utf-16 only**, so the client can share buffers with
  lemminx and other utf-16 servers.

## Versioning

Versions follow the odoo-ls server: each server release gets a plugin release
with the same number, even when the client is unchanged. Changes are listed in
[CHANGELOG.md](CHANGELOG.md).

### Upgrading from the old snippet config

1.6.1 changes defaults the snippet relied on: the selected profile is now
`default` (was `main`), the client attaches only under an `odools.toml`, and
that file must hold its keys in a `[[config]]` table. See the Breaking section
of the [CHANGELOG](CHANGELOG.md).

## License

LGPL-3.0, the same as the language server.
