-- GENERATED from palettes/mono-warm.env by scripts/theme.sh -- do not edit.
-- Edit the palette and re-run the script.
--
-- Named palette.lua rather than colors.lua: `colors/` is a reserved runtime
-- directory in Neovim (it is where colorschemes live and what `:colorscheme`
-- searches), and giving a plain Lua module the same stem invites confusion
-- with it even though require() resolves the two separately.
--
-- Syntax highlighting is zenwritten's job (see lua/plugins/user.lua); this
-- table exists so the *chrome* -- float borders, statusline, split lines,
-- the dashboard -- can be pinned to the exact same greys as waybar and the
-- window borders. Getting an editor to within one shade of the desktop is
-- worse than not matching at all, because the near-miss is what the eye
-- catches.

return {
  bg         = "#121110",
  bg_alt     = "#191614",
  surface    = "#1d1b19",
  surface_hi = "#2a2724",
  border     = "#322f2c",
  muted      = "#5e574f",
  dim        = "#8c837a",
  text       = "#ddd6ce",
  accent     = "#f2ece4",

  urgent = "#c05a50",
  warn   = "#b08a4a",
  good   = "#7d8f6a",

  red     = "#b06a66",
  green   = "#8a9b76",
  yellow  = "#b09a68",
  blue    = "#7f8d9b",
  magenta = "#a3849a",
  cyan    = "#82a0a0",
}
