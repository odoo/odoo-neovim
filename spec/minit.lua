#!/usr/bin/env -S nvim -l
-- Bootstraps lazy.nvim into .tests/ and runs busted over spec/*_spec.lua
vim.env.LAZY_STDPATH = '.tests'
load(vim.fn.system('curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua'))()
require('lazy.minit').busted({ spec = {} })
