-- render-markdown: styles Markdown in the buffer (headings, code blocks,
-- tables, checkboxes). The line under the cursor stays raw for editing.
-- Code and heading backgrounds come from the palette; the theme's own
-- colours are re-applied on top after each :colorscheme, so set them then.

local function palette_highlights()
  local p = require "palette"
  vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = p.bg_alt })
  vim.api.nvim_set_hl(0, "RenderMarkdownCodeInline", { bg = p.surface })
  for i = 1, 6 do
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i .. "Bg", { bg = p.surface })
  end
end

---@type LazySpec
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
  opts = {
    completions = { blink = { enabled = true } },
  },
  config = function(_, opts)
    require("render-markdown").setup(opts)
    palette_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("render_markdown_palette", { clear = true }),
      callback = palette_highlights,
    })
  end,
  keys = {
    { "<Leader>um", "<Cmd>RenderMarkdown toggle<CR>", ft = "markdown", desc = "Toggle Markdown rendering" },
  },
}
