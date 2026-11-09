-- Minimal Neovim config for competitive programming.
-- No plugins. Everything else is Neovim's default.

vim.g.mapleader = " "

-- Options ---------------------------------------------------------------
local o = vim.opt
o.number = true            -- absolute line numbers (no relativenumber)
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4
o.expandtab = true
o.ignorecase = true
o.smartcase = true
o.undofile = true
o.signcolumn = "yes"       -- keep text from shifting when diagnostics appear
o.clipboard = "unnamedplus" -- yank/paste via the system clipboard
if vim.fn.has("wsl") == 1 and vim.fn.executable("win32yank.exe") == 1 then
  -- WSL: share the clipboard with Windows.
  vim.g.clipboard = {
    name = "win32yank",
    copy = { ["+"] = "win32yank.exe -i --crlf", ["*"] = "win32yank.exe -i --crlf" },
    paste = { ["+"] = "win32yank.exe -o --lf", ["*"] = "win32yank.exe -o --lf" },
    cache_enabled = 0,
  }
end
o.completeopt = { "menu", "menuone", "noselect" } -- Enter never auto-accepts
o.pumheight = 10

-- Colors ------------------------------------------------------------------
-- The default colorscheme with a bluish palette (Tokyo Night colors) on top,
-- so code is not mostly white. Colors for variables, functions, types, macros
-- etc. come from clangd's semantic highlighting.
local c = {
  fg = "#c0caf5", dim = "#a9b1d6", comment = "#565f89",
  blue = "#7aa2f7", cyan = "#7dcfff", sky = "#2ac3de", teal = "#73daca",
  green = "#9ece6a", yellow = "#e0af68", orange = "#ff9e64", magenta = "#bb9af7", red = "#f7768e",
}
local palette = {
  Normal = { fg = c.fg },
  Comment = { fg = c.comment, italic = true },
  Constant = { fg = c.orange },       -- numbers, true/false
  String = { fg = c.green },
  Character = { fg = c.green },
  Identifier = { fg = c.fg },
  Function = { fg = c.blue },
  Statement = { fg = c.magenta },     -- if, for, return, ...
  Operator = { fg = c.sky },
  PreProc = { fg = c.cyan },          -- #include, #define
  Type = { fg = c.sky },              -- int, vector, ll, ...
  Special = { fg = c.sky },
  Delimiter = { fg = c.dim },
  ["@lsp.type.macro"] = { fg = c.cyan },                    -- rep, all
  ["@lsp.type.namespace"] = { fg = c.cyan },                -- std, atcoder
  ["@lsp.type.function"] = { fg = c.blue },
  ["@lsp.type.method"] = { fg = c.blue },
  ["@lsp.type.class"] = { fg = c.sky },
  ["@lsp.type.type"] = { fg = c.sky },
  ["@lsp.type.typeParameter"] = { fg = c.sky },
  ["@lsp.type.parameter"] = { fg = c.yellow, italic = true },
  ["@lsp.type.property"] = { fg = c.teal },                 -- struct members
  ["@lsp.type.enumMember"] = { fg = c.orange },
  ["@lsp.type.variable"] = { fg = c.fg },                   -- local variables
  ["@lsp.typemod.variable.globalScope"] = { fg = c.yellow }, -- global arrays (dx, dy)
  ["@lsp.typemod.variable.fileScope"] = { fg = c.yellow },
}

-- Transparent background (the terminal's background shows through).
local function apply_colors()
  if vim.g.colors_name == nil or vim.g.colors_name == "default" then
    for group, spec in pairs(palette) do
      vim.api.nvim_set_hl(0, group, spec)
    end
  end
  for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "FloatBorder",
                           "SignColumn", "LineNr", "EndOfBuffer" }) do
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    hl.bg = nil
    vim.api.nvim_set_hl(0, group, hl)
  end
end
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_colors })
apply_colors()

-- Diagnostics: show the message at the end of the line.
vim.diagnostic.config({ virtual_text = true, severity_sort = true })

-- LSP (clangd, built-in client) -------------------------------------------
vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--header-insertion=never",       -- never add #include lines on completion
    "--function-arg-placeholders=0",  -- complete "push_back(" only, no arg snippets
  },
  filetypes = { "c", "cpp" },
  root_markers = { "compile_flags.txt", ".clangd", ".git" },
})
vim.lsp.enable("clangd")

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or not client:supports_method("textDocument/completion") then
      return
    end
    -- Pop up completion only after ".", "->" and "::" (e.g. v.push_back).
    local cp = client.server_capabilities.completionProvider
    if cp then
      cp.triggerCharacters = { ".", ">", ":" }
    end
    vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
  end,
})

-- Ctrl-Space: open completion manually.
vim.keymap.set("i", "<C-Space>", function() vim.lsp.completion.get() end)
-- Tab / Shift-Tab: move in the completion menu.
vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true })

-- Auto-close brackets -------------------------------------------------------
--   ( [ {    insert the pair with the cursor inside
--   ) ] }    step over the same closing bracket
--   Enter    between {} opens an indented block
--   BS       between an empty pair deletes both
local pairs_map = { ["("] = ")", ["["] = "]", ["{"] = "}" }
local function around_cursor()
  local col, line = vim.fn.col("."), vim.fn.getline(".")
  return line:sub(col - 1, col - 1), line:sub(col, col)
end
for open, close in pairs(pairs_map) do
  vim.keymap.set("i", open, open .. close .. "<C-g>U<Left>")
  vim.keymap.set("i", close, function()
    local _, next = around_cursor()
    return next == close and "<C-g>U<Right>" or close
  end, { expr = true })
end
vim.keymap.set("i", "<CR>", function()
  local prev, next = around_cursor()
  if vim.fn.pumvisible() == 0 and prev == "{" and next == "}" then
    return "<CR><Esc>O"
  end
  return "<CR>"
end, { expr = true })
vim.keymap.set("i", "<BS>", function()
  local prev, next = around_cursor()
  return (pairs_map[prev] and pairs_map[prev] == next) and "<BS><Del>" or "<BS>"
end, { expr = true })

-- Competitive programming -------------------------------------------------
-- Run a command in a terminal split, in the directory of the current file.
-- When it finishes: back to Normal mode, cursor on the last output line
-- (the result summary). Scroll with k / Ctrl-u, close with q.
local function run_in_term(cmd, interactive)
  vim.cmd("silent! write")
  local dir = vim.fn.expand("%:p:h")
  vim.cmd("botright 15split | enew")
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = dir,
    on_exit = function()
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(win) then return end
        if vim.api.nvim_get_current_win() == win then vim.cmd("stopinsert") end
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local last = #lines
        while last > 1 and lines[last] == "" do last = last - 1 end
        vim.api.nvim_win_set_cursor(win, { last, 0 })
      end)
    end,
  })
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, nowait = true })
  if interactive then vim.cmd("startinsert") end
end

-- Space t: build + test samples   Space r: build + run with stdin
-- Space s: test + submit (cps)     (F5 / F6 / F8 do the same, for keyboards
-- where the F keys are not media keys)
local function test() run_in_term({ "cpt" }) end
local function run() run_in_term({ "sh", "-c", "cp-build main.cpp a.out && ./a.out" }, true) end
local function submit() run_in_term({ "cps" }, true) end
vim.keymap.set("n", "<leader>t", test, { desc = "Build + oj test" })
vim.keymap.set("n", "<leader>r", run, { desc = "Build + run" })
vim.keymap.set("n", "<leader>s", submit, { desc = "Test + submit" })
vim.keymap.set("n", "<F5>", test, { desc = "Build + oj test" })
vim.keymap.set("n", "<F6>", run, { desc = "Build + run" })
vim.keymap.set("n", "<F8>", submit, { desc = "Test + submit" })

-- Switch problems inside contests/<contest>/<task>/main.cpp.
--   :P b         open problem b
--   <Space>n/p   next / previous problem
local function problems()
  local contest = vim.fn.expand("%:p:h:h")
  local names = {}
  for name, kind in vim.fs.dir(contest) do
    if kind == "directory" and vim.uv.fs_stat(contest .. "/" .. name .. "/main.cpp") then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return contest, names
end

local function open_problem(name)
  local contest = problems()
  local file = contest .. "/" .. name .. "/main.cpp"
  if not vim.uv.fs_stat(file) then
    vim.notify("no problem: " .. name, vim.log.levels.WARN)
    return
  end
  vim.cmd("silent! update")
  vim.cmd.edit(vim.fn.fnameescape(file))
  vim.cmd.cd(vim.fn.fnameescape(contest .. "/" .. name)) -- so :!cps uses this problem
end

local function step_problem(delta)
  local _, names = problems()
  local current = vim.fn.expand("%:p:h:t")
  for i, name in ipairs(names) do
    if name == current and names[i + delta] then
      return open_problem(names[i + delta])
    end
  end
end

vim.api.nvim_create_user_command("P", function(opts) open_problem(opts.args:lower()) end, {
  nargs = 1,
  complete = function(arglead)
    local _, names = problems()
    return vim.tbl_filter(function(n) return vim.startswith(n, arglead) end, names)
  end,
})
vim.keymap.set("n", "<leader>n", function() step_problem(1) end, { desc = "Next problem" })
vim.keymap.set("n", "<leader>p", function() step_problem(-1) end, { desc = "Previous problem" })

-- Libraries -----------------------------------------------------------------
-- Libraries live in ~/CP/CP_Library (one file each, no main()).
-- :NAME            inserts that library just before int main() (e.g. :tree_diameter)
-- Space l          opens the list (type to narrow, Tab / Enter to choose)
-- :Lib A B ...     inserts several at once
local my_lib = vim.fn.expand("~/CP/CP_Library")

-- name -> file. The name is the file name in lowercase with "-" turned into
-- "_" (tree-diameter.hpp -> tree_diameter); DIR_NAME if two files share it.
local function libraries()
  local found = {}
  local function add(name, path)
    name = name:lower():gsub("[^%w_]", "_")
    if found[name] == nil then
      found[name] = path
      return true
    end
    return found[name] == path
  end
  for _, path in ipairs(vim.fn.globpath(my_lib, "**/*.[ch]pp", false, true)) do
    local rel = path:sub(#my_lib + 2)
    local text = table.concat(vim.fn.readfile(path), "\n")
    -- skip files with their own main() and the archive folder
    if not text:find("\nint%s+main%s*%(") and not rel:find("^archive/") then
      local base = vim.fn.fnamemodify(rel, ":t:r")
      if not add(base, path) then
        add(vim.fn.fnamemodify(rel, ":h") .. "_" .. base, path)
      end
    end
  end
  return found
end

-- Insert a file before int main(). Leading #include / #define / using lines
-- that the buffer already has are dropped.
local function insert_file(name, path)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local have = {}
  for _, l in ipairs(lines) do have[vim.trim(l):gsub("atcoder::", "")] = true end

  local body, prologue = {}, true
  for _, l in ipairs(vim.fn.readfile(path)) do
    local t = vim.trim(l)
    local is_prologue = t == "" or t:match("^#include") or t:match("^#define") or t:match("^#pragma once")
      or t:match("^using ")
    if prologue and is_prologue then
      if t ~= "" and not t:match("^#pragma once") and not have[t:gsub("atcoder::", "")] then
        table.insert(body, l)
      end
    else
      prologue = false
      table.insert(body, l)
    end
  end

  local first_code
  for _, l in ipairs(body) do
    if not vim.trim(l):match("^#") and not vim.trim(l):match("^using ") then first_code = l break end
  end
  if first_code and vim.tbl_contains(lines, first_code) then
    return "already inserted: " .. name
  end
  for i, l in ipairs(lines) do
    if l:match("^int%s+main%s*%(") then
      table.insert(body, "")
      vim.api.nvim_buf_set_lines(0, i - 1, i - 1, false, body)
      return "inserted: " .. name
    end
  end
  return "int main() not found"
end

vim.api.nvim_create_user_command("Lib", function(opts)
  local libs, msgs = libraries(), {}
  for _, name in ipairs(opts.fargs) do
    name = name:lower()
    table.insert(msgs, libs[name] and insert_file(name, libs[name]) or ("unknown library: " .. name))
  end
  vim.cmd("silent! write")
  vim.notify(table.concat(msgs, "\n"))
end, {
  nargs = "+",
  complete = function(arglead)
    local names = vim.tbl_keys(libraries())
    table.sort(names)
    return vim.tbl_filter(function(n) return n:find(arglead:lower(), 1, true) end, names)
  end,
})
-- :NAME also works (e.g. :rerooting, :seg): pressing Enter on a command line
-- that is exactly a library name runs "Lib NAME" instead.
vim.keymap.set("c", "<CR>", function()
  if vim.fn.getcmdtype() == ":" then
    local line = vim.trim(vim.fn.getcmdline()):lower()
    -- only a single word that is not a full built-in command name (e.g. :w)
    if line:match("^[%w_]+$") and vim.fn.exists(":" .. line) ~= 2 and libraries()[line] then
      return "<C-u>Lib " .. line .. "<CR>"
    end
  end
  return "<CR>"
end, { expr = true })
o.wildcharm = 9 -- lets the mapping below open the completion list with <Tab>
vim.keymap.set("n", "<leader>l", ":Lib <Tab>", { desc = "Insert library" })

-- Terminal: Esc leaves terminal mode.
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])
