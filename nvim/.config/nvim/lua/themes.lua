-- Colorschemes pinned to palette.lua's background. astroui.lua gives these the
-- chrome overrides and snacks.lua limits the <Leader>ft picker to them.
-- `mono` adds the monochrome tweaks; `hl` is g:colors_name when it differs
-- (every Monokai Pro filter calls itself "monokai-pro").
return {
  { name = "zenwritten", mono = true },

  { name = "github_dark_dimmed" },
  { name = "github_dark" },
  { name = "github_dark_default" },

  { name = "tokyonight-night" },
  { name = "tokyonight-storm" },
  { name = "tokyonight-moon" },

  { name = "monokai-pro", hl = "monokai-pro" },
  { name = "monokai-pro-classic", hl = "monokai-pro" },
  { name = "monokai-pro-octagon", hl = "monokai-pro" },
  { name = "monokai-pro-machine", hl = "monokai-pro" },
  { name = "monokai-pro-ristretto", hl = "monokai-pro" },
  { name = "monokai-pro-spectrum", hl = "monokai-pro" },
}
