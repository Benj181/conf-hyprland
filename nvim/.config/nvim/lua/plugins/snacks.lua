-- Hide the picker's multi-select marker glyphs, which looked like a second
-- cursor. Multi-select itself still works. Both blanks must have the same
-- width to keep the columns aligned.
---@type LazySpec
return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    picker = {
      -- <Leader>ft only lists the themes in lua/themes.lua.
      sources = {
        colorschemes = {
          transform = function(item)
            for _, theme in ipairs(require "themes") do
              if theme.name == item.text then return true end
            end
            return false
          end,
        },
      },
      icons = {
        ui = {
          selected = " ",
          unselected = " ",
        },
      },
    },
  },
}
