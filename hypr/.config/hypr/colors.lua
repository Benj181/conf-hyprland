-- GENERATED from palettes/mono-warm.env by scripts/theme.sh -- do not edit.
-- Edit the palette and re-run the script.
--
-- Colours are bare rrggbb; use the helpers below to build config values.

local C = {
    bg         = "121110",
    bg_alt     = "191614",
    surface    = "1d1b19",
    surface_hi = "2a2724",
    border     = "322f2c",
    muted      = "5e574f",
    dim        = "8c837a",
    text       = "ddd6ce",
    accent     = "f2ece4",

    urgent = "c05a50",
    warn   = "b08a4a",
    good   = "7d8f6a",
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
