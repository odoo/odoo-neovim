-- Init of the Neovim that runs one spec file. spec/minit.lua starts it as:
--   MINI_TEST=<mini.test clone> nvim --headless --clean -u spec/minimal_init.lua -c "lua run_spec('spec/x_spec.lua')"
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:prepend(assert(vim.env.MINI_TEST, 'run the specs with: nvim -l spec/minit.lua'))
require('mini.test').setup()

-- Runs one spec file (busted style, mini.test emulates it), then quits.
-- mini.test exits with code 1 if a test fails; this does the same if the file cannot be loaded.
function _G.run_spec(file)
  local ok, err = pcall(MiniTest.run_file, file)
  if not ok then
    io.stderr:write(err, '\n')
    vim.cmd('1cquit')
  end
end
