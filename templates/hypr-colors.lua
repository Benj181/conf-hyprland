-- GENERATED from palettes/{{palette}}.env by scripts/theme.sh -- do not edit.
-- Edit the palette and re-run the script.
--
-- Colours are stored bare (no leading '#') because every field that consumes
-- them here wants them that way: hyprlang spells a colour rgba(rrggbbaa), and
-- the Lua config's integer colour fields want 0xAARRGGBB. The two helpers at
-- the bottom build both forms, so callers never concatenate hex by hand.

local C = {
    bg         = "{{bg_raw}}",
    bg_alt     = "{{bg_alt_raw}}",
    surface    = "{{surface_raw}}",
    surface_hi = "{{surface_hi_raw}}",
    border     = "{{border_raw}}",
    muted      = "{{muted_raw}}",
    dim        = "{{dim_raw}}",
    text       = "{{text_raw}}",
    accent     = "{{accent_raw}}",

    urgent = "{{urgent_raw}}",
    warn   = "{{warn_raw}}",
    good   = "{{good_raw}}",
}

--- hyprlang colour string, e.g. C.rgba(C.accent, "cc") -> "rgba(ffffffcc)".
--- @param hex string bare rrggbb
--- @param alpha string|nil two hex digits, default "ff"
function C.rgba(hex, alpha)
    return "rgba(" .. hex .. (alpha or "ff") .. ")"
end

--- Integer colour for the Lua config's numeric fields (shadow.color and
--- friends), which take 0xAARRGGBB rather than a string.
--- @param hex string bare rrggbb
--- @param alpha string|nil two hex digits, default "ff"
function C.argb(hex, alpha)
    return tonumber((alpha or "ff") .. hex, 16)
end

return C
