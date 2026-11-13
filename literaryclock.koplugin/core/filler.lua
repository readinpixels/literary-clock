--[[
Picks the fallback line for a minute with no quote. The lines themselves
live in core/fallbacks.lua.

    Filler.pick(now) -> text (with the time marked \3...\4 like a real
                        quote's time phrase), attribution ("" for none)

The families alternate from one fallback to the next; within a family the
line is random but never the previous one. The pick is kept for the whole
minute, so redrawing the card does not change it or move the alternation on.
]]

local Core = ...

local Filler = {}

local FAMILIES = { "narrator", "reader" }

local lines           -- the loaded fallbacks.lua
local next_family = 1 -- index into FAMILIES
local last_index = {} -- family -> index of the line used last time
local cached_minute, cached_text, cached_attr

local function load()
    if lines then return lines end
    -- KOReader's random module seeds math.random from the clock when first
    -- loaded; without it every boot would replay the same picks.
    pcall(require, "random")
    local ok, t = pcall(dofile, Core.dir .. "/core/fallbacks.lua")
    if not ok or type(t) ~= "table" then
        local ok_log, logger = pcall(require, "logger")
        if ok_log then logger.warn("literaryclock: cannot load core/fallbacks.lua:", t) end
        t = {}
    end
    for _i, name in ipairs(FAMILIES) do
        local list = {}
        for _j, s in ipairs(type(t[name]) == "table" and t[name] or {}) do
            if type(s) == "string" and s:find("{time}", 1, true) then list[#list + 1] = s end
        end
        t[name] = list
    end
    if type(t.attribution) ~= "string" then t.attribution = "" end
    lines = t
    return lines
end

-- Random index in 1..n, never `avoid` (unless n == 1).
local function randomIndex(n, avoid)
    if n <= 1 then return 1 end
    local i = math.random(n - 1)
    if avoid and i >= avoid then i = i + 1 end
    return i
end

-- Upper-cases the first letter of `s`, skipping the time markers.
local function capitalise(s)
    return (s:gsub("^([\1-\4]*)(%l)", function(marks, c) return marks .. c:upper() end))
end
Filler.capitalise = capitalise

--- Fills `template` with the time in words.
function Filler.render(template, time_words)
    local marked = "\3" .. time_words .. "\4"
    return capitalise((template:gsub("{time}", function() return marked end)))
end

function Filler.pick(now)
    now = now or os.time()
    local minute = math.floor(now / 60)
    if minute == cached_minute then return cached_text, cached_attr end

    local t = load()
    local hour, min = tonumber(os.date("%H", now)), tonumber(os.date("%M", now))
    local words = Core.TimeWords.time_to_words(hour, min)

    -- Next family that has any lines.
    local family, list
    for _k = 1, #FAMILIES do
        family = FAMILIES[next_family]
        next_family = next_family % #FAMILIES + 1
        list = t[family]
        if #list > 0 then break end
    end

    local text
    if list and #list > 0 then
        local i = randomIndex(#list, last_index[family])
        last_index[family] = i
        text = Filler.render(list[i], words)
    else
        text = Filler.render("{time}.", words)
    end
    Filler.last_family = family -- for tests
    cached_minute, cached_text, cached_attr = minute, text, t.attribution
    return text, t.attribution
end

--- Forgets the loaded lines and the state (for tests, or after editing).
function Filler.reset()
    lines, next_family, last_index = nil, 1, {}
    cached_minute, cached_text, cached_attr = nil, nil, nil
end

return Filler
