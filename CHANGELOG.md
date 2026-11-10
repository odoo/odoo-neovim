# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow the
odoo-ls server: each server release gets a plugin release with the same number,
even when the client is unchanged.

## [1.6.1] - Unreleased

First versioned release, turning the configuration snippet into a full client.

### Breaking

- Neovim 0.12 or later is required.
- The default selected profile is `default` (was `main`). The server always has
  a built-in `default` profile. To keep `main`, pass `profile = 'main'` to
  `setup()`, set `settings.Odoo.selectedProfile`, or rename the profile.
- The client attaches only to files under an `odools.toml`, and that file's
  directory is the workspace folder. It used to attach to any buffer with the
  current working directory as the workspace folder.
- Filetypes are now `python`, `xml`, `csv`, `javascript` and `typescript` (was
  `python` and `xml`).
- `odools.toml` must hold its keys in `[[config]]` tables. The top-level keys of
  the old README example were never read by the server.
- The server binary is no longer looked up in `~/.local/share/nvim/odoo/`. The
  plugin does not install it: download it from the odoo-ls releases, put it on
  `PATH` or pass it as `cmd`.

### Added

- `:OdooLs` command: `health` (the default), `profile`, `restart` and `logs`
  subcommands.
- `require('odoo_ls')` with `setup()`, `restart()` and `set_profile()`.
- Handling of the server's `$Odoo/*` notifications: configuration snapshot,
  diagnostics, loading status, crashes.
- `:checkhealth odoo_ls`, with every key of the active profile and every
  config and server diagnostic.

### Changed

- The default launch command is `odoo_ls_server`, found on `PATH`.
- A single client and server run per Neovim, shared by every buffer.
- Only `utf-16` is advertised as position encoding, so the client can share
  buffers with lemminx.
