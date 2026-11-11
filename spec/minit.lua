#!/usr/bin/env -S nvim -l
-- Runs the specs with mini.test: nvim -l spec/minit.lua [spec/x_spec.lua ...]
-- Every spec file runs in its own clean Neovim (see spec/minimal_init.lua),
-- so no state leaks from one file to the next.
local MINI_TEST_VERSION = 'v0.18.0'

vim.fn.chdir(vim.fs.dirname(vim.fs.dirname(vim.fs.abspath(arg[0]))))

local mini_test = '.tests/mini.test-' .. MINI_TEST_VERSION
if not vim.uv.fs_stat(mini_test) then
  local url = 'https://github.com/nvim-mini/mini.test'
  local clone = vim.system({ 'git', 'clone', '--quiet', '--depth=1', '--branch=' .. MINI_TEST_VERSION, url, mini_test }):wait()
  if clone.code ~= 0 then
    io.stderr:write(clone.stderr)
    os.exit(1)
  end
end

local files = #arg > 0 and arg or vim.fn.glob('spec/*_spec.lua', false, true)
local failed = {}
for _, file in ipairs(files) do
  local run = vim.system({
    vim.v.progpath,
    '--headless',
    '--clean',
    '-u',
    'spec/minimal_init.lua',
    '-c',
    ('lua run_spec(%q)'):format(file),
  }, { text = true, env = { MINI_TEST = mini_test }, timeout = 60000 }):wait()
  io.write(run.stdout, run.stderr)
  if run.code ~= 0 then
    table.insert(failed, file)
  end
end

if #failed > 0 then
  io.write('\nFailed: ', table.concat(failed, ', '), '\n')
  os.exit(1)
end
