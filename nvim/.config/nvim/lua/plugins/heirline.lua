-- The buffer names normally live in the tabline, which astrocore.lua turns off
-- (showtabline = 0). AstroNvim's default statusline file_info only shows the
-- filetype, so with the tabline gone nothing said which file was open. Swap
-- that component for one showing the path (relative to cwd, ~ for home) plus
-- the modified / read-only markers.

---@type LazySpec
return {
  "rebelot/heirline.nvim",
  opts = function(_, opts)
    local status = require "astroui.status"
    opts.statusline[4] = status.component.file_info {
      filename = { modify = ":~:." },
      filetype = false,
      file_modified = {},
      file_read_only = {},
      update = { "BufEnter", "BufFilePost", "BufModifiedSet", "DirChanged" },
    }
  end,
}
