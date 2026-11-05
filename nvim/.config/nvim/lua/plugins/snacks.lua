-- Hide the picker's multi-select marker glyphs, which looked like a second
-- cursor. Multi-select itself still works. Both blanks must have the same
-- width to keep the columns aligned.
---@type LazySpec
return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    picker = {
      icons = {
        ui = {
          selected = " ",
          unselected = " ",
        },
      },
    },
  },
}
