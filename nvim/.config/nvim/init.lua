-- Minimal NVIM mit Completion + Autopairs + Statusline + Tim-Theme

-- ---------- Palette (aus deiner Liste) ----------
local C = {
  red   = "#a14040",  -- auch "orange" bei dir
  green = "#6aaa64",
  orange ="#df970d",
  pink  = "#b16286",
  fg    = "#bec1bf",
  bg    = "#2a2a2a",  -- "dark background" (etwas heller als #222222)
  bg2   = "#333333",  -- leicht heller für CursorLine/Status
  dim   = "#222222",  -- border/darker
}

vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.cursorline = true

-- ---------- sehr kleines Colorscheme ----------
local function apply_colors()
  local hl = vim.api.nvim_set_hl
  hl(0, "Normal",         { fg=C.fg, bg=C.bg })
  hl(0, "NormalFloat",    { fg=C.fg, bg=C.bg2 })
  hl(0, "FloatBorder",    { fg=C.dim, bg=C.bg2 })
  hl(0, "SignColumn",     { bg=C.bg })
  hl(0, "LineNr",         { fg="#8a8a8a", bg=C.bg })
  hl(0, "CursorLine",     { bg=C.bg2 })
  hl(0, "CursorLineNr",   { fg=C.fg, bg=C.bg2, bold=true })
  hl(0, "Visual",         { bg=C.pink, fg="#000000" })
  hl(0, "Search",         { bg=C.green, fg="#000000" })
  hl(0, "IncSearch",      { bg=C.red,   fg="#000000" })
  hl(0, "Pmenu",          { fg=C.fg, bg=C.bg2 })
  hl(0, "PmenuSel",       { fg="#000000", bg=C.green })
  hl(0, "StatusLine",     { fg=C.fg, bg=C.bg2 })
  hl(0, "StatusLineNC",   { fg="#9e9e9e", bg=C.dim })
  hl(0, "WinSeparator",   { fg=C.dim, bg=C.bg })
end
apply_colors()

-- ---------- lazy.nvim bootstrap ----------
local lazypath = vim.fn.stdpath("data").."/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Completion
  { "hrsh7th/nvim-cmp",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = {
          { name = "path" },
          { name = "buffer" },
          { name = "luasnip" },
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end
  },

  -- Autopairs
  { "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({})
      -- glue mit cmp
      local cmp_ok, cmp = pcall(require, "cmp")
      if cmp_ok then
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end
    end
  },

  -- Statusline mit Mode-Farben nach Palette
  { "nvim-lualine/lualine.nvim",
    config = function()
      local theme = {
        normal  = { a = { fg="#000000", bg=C.orange   , gui="bold" }, c = { fg=C.fg, bg=C.bg2 } },
        insert  = { a = { fg="#000000", bg=C.green , gui="bold" } },
        visual  = { a = { fg="#000000", bg=C.pink  , gui="bold" } },
        replace = { a = { fg="#000000", bg=C.red   , gui="bold" } },
        command = { a = { fg="#000000", bg=C.red   , gui="bold" } },
        inactive= { a = { fg=C.fg,      bg=C.dim }, c = { fg="#9e9e9e", bg=C.dim } },
      }
      require("lualine").setup({
        options = {
          theme = theme,
          globalstatus = true,
          section_separators = "",
          component_separators = "",
        },
        sections = {
          lualine_a = {"mode"},
          lualine_b = {"branch"},
          lualine_c = {{ "filename", path = 1 }},
          lualine_x = {"encoding","fileformat","filetype"},
          lualine_y = {"progress"},
          lualine_z = {"location"},
        },
      })
    end
  },
}, {
  ui = { border = "rounded" }
})

-- Re-apply Farben, falls ein Plugin sie überschreibt
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_colors })

-- In ~/.config/nvim/init.lua ans Ende packen
-- :w!!  -> speichert die aktuelle Datei per sudo
vim.api.nvim_create_user_command('SudoWrite', function()
  vim.cmd('write !sudo tee % > /dev/null')
  vim.cmd('edit!')
end, { desc = 'Write using sudo' })

vim.keymap.set('n', '<leader>W', ':SudoWrite<CR>', { silent = true, desc = 'sudo write' })

-- wer den klassischen Alias mag:
vim.cmd([[cnoreabbrev w!! SudoWrite]])

