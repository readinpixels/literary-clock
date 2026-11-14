--[[
The one call both home screens make: pick the quote for the current minute
and lay it out in the box they give.
]]

local Core = ...   -- passed by core/init.lua
local Layout, Lookup, Settings = Core.Layout, Core.Lookup, Core.Settings

local Clock = {}

local function colourScreen()
    local ok, Device = pcall(require, "device")
    if not ok or not Device or not Device.screen then return false end
    local ok2, on = pcall(function() return Device.screen:isColorEnabled() end)
    return ok2 and on and true or false
end

-- The look chosen in the settings, as Layout.build parameters.
-- `ink_accent`: the host's accent when the setting is "same as text".
function Clock.style(ink_accent)
    local style = {
        fonts = Core.Fonts.resolve(Settings.get("font_family")),
        emphasis = Layout.EMPHASIS[Settings.choice("emphasis", Settings.EMPHASES).id],
        line_spacing = Settings.choice("line_spacing", Settings.SPACINGS).value,
        align = Settings.choice("align", Settings.ALIGNMENTS).id,
        accent = ink_accent,
    }
    local colour = colourScreen()
    if not colour and style.emphasis == Layout.EMPHASIS.none then
        -- Plain needs a colour to show; on a greyscale screen, bold.
        style.emphasis = Layout.EMPHASIS.bold
    end
    local accent = Settings.choice("accent", Settings.ACCENTS)
    if accent.rgb and colour then
        local Blitbuffer = require("ffi/blitbuffer")
        style.accent = Blitbuffer.ColorRGB32(accent.rgb[1], accent.rgb[2], accent.rgb[3], 0xFF)
    end
    return style
end

--- Builds the clock widget.
-- o.width, o.height, o.max_height, o.size, o.min_size, o.max_size and the
-- colours are passed to Layout.build (see there).
-- o.legible: the smallest quote font size a quote may need to be chosen
-- over a shorter one for the same minute (default: o.min_size).
-- o.now: time to show (default: now).
function Clock.build(o)
    -- Fixed font size: one size everywhere, whatever the card. A quote is
    -- still chosen to fit at that size when the minute has one that does;
    -- otherwise the shortest is cut with an ellipsis.
    local fixed = Settings.fixedFontSize()
    if fixed then
        local f = {}
        for k, v in pairs(o) do f[k] = v end
        f.size, f.min_size, f.max_size, f.legible = fixed, fixed, fixed, fixed
        o = f
    end
    local now = o.now or os.time()
    local target = o.height or o.max_height
    local legible = o.legible or o.min_size or 10
    local show_attr = Settings.get("show_attribution")
    local style = Clock.style(o.accent)

    local fits
    if target then
        fits = function(q)
            return Layout.fitsAt({
                quote = q[1], title = q[2], author = q[3],
                show_attribution = show_attr, width = o.width,
                min_size = o.min_size, max_size = o.max_size,
                fonts = style.fonts, emphasis = style.emphasis,
                line_spacing = style.line_spacing,
            }, legible, target)
        end
    end
    local q = Lookup.pick(now, Settings.get("sfw_only"), fits)

    local p = {}
    for k, v in pairs(o) do p[k] = v end
    for k, v in pairs(style) do p[k] = v end
    if q then
        p.quote, p.title, p.author = q[1], q[2], q[3]
        p.show_attribution = show_attr
    else
        -- A minute the dataset does not cover (31 a day with the
        -- safe-for-work filter on): a line from core/fallbacks.lua.
        local text, attribution = Core.Filler.pick(now)
        p.quote = text
        p.title, p.author = "", attribution
        p.show_attribution = show_attr and attribution ~= ""
    end
    return Layout.build(p)
end

return Clock
