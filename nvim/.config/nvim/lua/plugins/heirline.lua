-- Show the file path (relative to cwd) and modified/read-only markers in the
-- statusline, since the tabline is off (astrocore.lua).

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
