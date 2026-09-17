-- GENERATED from palettes/{{palette}}.env by scripts/theme.sh -- do not edit.
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
  bg         = "{{bg}}",
  bg_alt     = "{{bg_alt}}",
  surface    = "{{surface}}",
  surface_hi = "{{surface_hi}}",
  border     = "{{border}}",
  muted      = "{{muted}}",
  dim        = "{{dim}}",
  text       = "{{text}}",
  accent     = "{{accent}}",

  urgent = "{{urgent}}",
  warn   = "{{warn}}",
  good   = "{{good}}",

  red     = "{{red}}",
  green   = "{{green}}",
  yellow  = "{{yellow}}",
  blue    = "{{blue}}",
  magenta = "{{magenta}}",
  cyan    = "{{cyan}}",
}
