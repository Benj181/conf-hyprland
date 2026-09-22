-- Snacks provides AstroNvim's default picker (find_files, buffers, grep, and
-- leetcode.nvim's question list all go through it).
--
-- Tab-multiselect (<Tab>/<S-Tab>, Snacks' defaults) stays enabled -- it's
-- genuinely useful for e.g. sending several grep/file results to the
-- quickfix list. What's blanked out is only the "●"/"○" marker glyph Snacks
-- draws in front of each row once anything is selected: it rendered next to
-- the *cursor* row too, so it read as a second, conflicting "current item"
-- indicator once SnacksPickerListCursorLine (see astroui.lua) actually made
-- the real cursor row visible. The marker column's width is computed from
-- these two icon strings, so blanking both to the same width keeps alignment
-- stable and leaves the underlying selection state/actions untouched.
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
