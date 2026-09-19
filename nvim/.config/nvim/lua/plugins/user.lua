-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

-- zenbones compat flag (see the zenbones spec below). Set while the spec is
-- read rather than in the plugin's `init`: AstroNvim applies the colorscheme
-- from inside another plugin's init (mason-tool-installer requires astrocore),
-- and lazy gives no ordering between init functions, so adding an unrelated
-- plugin can make the colorscheme run first and fail on a missing lush.
vim.g.bones_compat = 1

---@type LazySpec
return {

  -- == Examples of Adding Plugins ==

  -- zenwritten, from the zenbones collection. Picked over writing a
  -- colorscheme out of palettes/*.env because a hand-rolled one has to cover
  -- every treesitter and LSP-semantic-token group to not look broken, and the
  -- interesting part of a monochrome editor theme is not the colour list --
  -- it is deciding what carries meaning once colour cannot. zenbones answers
  -- that with contrast and font variation, which is exactly the brief.
  --
  -- zenwritten specifically: it is the achromatic member of the family, and it
  -- keeps colour only for diagnostics, diffs and search matches -- the same
  -- line this repo's palette draws for the bar and the terminal.
  {
    "zenbones-theme/zenbones.nvim",
    -- lush.nvim is only needed to *generate* a customised variant. compat mode
    -- uses the pre-built colorschemes that ship in the plugin's colors/ dir,
    -- which is all that is wanted here -- the chrome overrides in astroui.lua
    -- do the palette matching instead. Without this flag `colorscheme
    -- zenwritten` fails outright on a missing lush.
    --
    -- g:bones_compat, not g:zenbones_compat. autoload/bones.vim checks
    -- `g:<colors_name>_compat` first and falls back to `g:bones_compat`, so
    -- the name in the plugin's own README only covers the scheme literally
    -- called "zenbones" -- it does nothing for zenwritten. The generic flag
    -- also means trying another variant while experimenting does not need a
    -- second edit here.
    --
    -- The flag itself is set at the top of this file, not in `init`.
    lazy = false,
    priority = 1000,
  },


  -- == Examples of Overriding Plugins ==

  -- customize dashboard options
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            " █████  ███████ ████████ ██████   ██████ ",
            "██   ██ ██         ██    ██   ██ ██    ██",
            "███████ ███████    ██    ██████  ██    ██",
            "██   ██      ██    ██    ██   ██ ██    ██",
            "██   ██ ███████    ██    ██   ██  ██████ ",
            "",
            "███    ██ ██    ██ ██ ███    ███",
            "████   ██ ██    ██ ██ ████  ████",
            "██ ██  ██ ██    ██ ██ ██ ████ ██",
            "██  ██ ██  ██  ██  ██ ██  ██  ██",
            "██   ████   ████   ██ ██      ██",
          }, "\n"),
        },
      },
    },
  },

  -- You can disable default plugins as follows:
  -- { "max397574/better-escape.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  -- {
  --   "L3MON4D3/LuaSnip",
  --   config = function(plugin, opts)
  --     -- add more custom luasnip configuration such as filetype extend or custom snippets
  --     local luasnip = require "luasnip"
  --     luasnip.filetype_extend("javascript", { "javascriptreact" })

  --     -- include the default astronvim config that calls the setup call
  --     require "astronvim.plugins.configs.luasnip"(plugin, opts)
  --   end,
  -- },

  -- {
  --   "windwp/nvim-autopairs",
  --   config = function(plugin, opts)
  --     require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
  --     -- add more custom autopairs configuration such as custom rules
  --     local npairs = require "nvim-autopairs"
  --     local Rule = require "nvim-autopairs.rule"
  --     local cond = require "nvim-autopairs.conds"
  --     npairs.add_rules(
  --       {
  --         Rule("$", "$", { "tex", "latex" })
  --           -- don't add a pair if the next character is %
  --           :with_pair(cond.not_after_regex "%%")
  --           -- don't add a pair if  the previous character is xxx
  --           :with_pair(
  --             cond.not_before_regex("xxx", 3)
  --           )
  --           -- don't move right when repeat character
  --           :with_move(cond.none())
  --           -- don't delete if the next character is xx
  --           :with_del(cond.not_after_regex "xx")
  --           -- disable adding a newline when you press <cr>
  --           :with_cr(cond.none()),
  --       },
  --       -- disable for .vim files, but it work for another filetypes
  --       Rule("a", "a", "-vim")
  --     )
  --   end,
  -- },
}
