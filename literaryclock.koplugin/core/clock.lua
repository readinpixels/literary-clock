--[[
The one call both home screens make: pick the quote for the current minute
and lay it out in the box they give.
]]

local Core = ...   -- passed by core/init.lua
local Layout, Lookup, Settings = Core.Layout, Core.Lookup, Core.Settings

local Clock = {}

--- Builds the clock widget.
-- o.width, o.height, o.max_height, o.size, o.min_size, o.max_size and the
-- colours are passed to Layout.build (see there).
-- o.legible: the smallest quote font size a quote may need to be chosen
-- over a shorter one for the same minute (default: o.min_size).
-- o.now: time to show (default: now).
function Clock.build(o)
    local now = o.now or os.time()
    local target = o.height or o.max_height
    local legible = o.legible or o.min_size or 10
    local show_attr = Settings.get("show_attribution")

    local fits
    if target then
        fits = function(q)
            return Layout.fitsAt({
                quote = q[1], title = q[2], author = q[3],
                show_attribution = show_attr, width = o.width,
                min_size = o.min_size, max_size = o.max_size,
            }, legible, target)
        end
    end
    local q = Lookup.pick(now, Settings.get("sfw_only"), fits)

    local p = {}
    for k, v in pairs(o) do p[k] = v end
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
