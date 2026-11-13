--[[
Finds the quotes for a given minute.

The data lives in data/<lang>/HH.lua, one file per hour, each returning
{ ["HH:MM"] = { { quote, title, author, sfw }, ... } }. Only the hour on
screen is kept in memory: the file for the next hour is read when the clock
gets there.
]]

local Lookup = {}

local base_dir   -- the plugin folder, set by Lookup.init
local lang = "en"
local cache_hour, cache_data

function Lookup.init(plugin_dir)
    base_dir = plugin_dir
end

local function loadHour(hh)
    if cache_hour == hh then return cache_data end
    local path = string.format("%s/data/%s/%s.lua", base_dir, lang, hh)
    local ok, data = pcall(dofile, path)
    if not ok or type(data) ~= "table" then data = {} end
    cache_hour, cache_data = hh, data
    return data
end

--- The quotes for "HH:MM", as a list of { text, title, author, sfw }.
function Lookup.quotesAt(hhmm, sfw_only)
    local list = loadHour(hhmm:sub(1, 2))[hhmm] or {}
    if not sfw_only then return list end
    local out = {}
    for _i, q in ipairs(list) do
        if q[4] then out[#out + 1] = q end
    end
    return out
end

--- Picks the quote to show at time `now` (seconds).
-- `fits(q)` tells whether a quote is readable in the card. Among the quotes
-- that fit, the pick rotates from day to day, so the same minute does not
-- always show the same passage; it stays the same for the whole minute, so
-- a redraw does not swap it. When none fits, the shortest one is used.
-- Returns nil when the minute has no quote.
function Lookup.pick(now, sfw_only, fits)
    local hhmm = os.date("%H:%M", now)
    local list = Lookup.quotesAt(hhmm, sfw_only)
    local n = #list
    if n == 0 then return nil, hhmm end
    local day = tonumber(os.date("%j", now)) + tonumber(os.date("%Y", now)) * 366
    local start = day % n
    for i = 0, n - 1 do
        local q = list[(start + i) % n + 1]
        if not fits or fits(q) then return q, hhmm end
    end
    local best
    for _i, q in ipairs(list) do
        if not best or #q[1] < #best[1] then best = q end
    end
    return best, hhmm
end

return Lookup
