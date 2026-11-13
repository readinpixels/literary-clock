-- Tests for the fallback lines (core/timewords.lua, core/filler.lua,
-- core/fallbacks.lua). Plain Lua 5.1 / LuaJIT, no KOReader needed:
--
--     luajit tests/test_fallbacks.lua        (from the repository root)

local dir = (arg and arg[0] or ""):match("^(.*)/tests/[^/]*$") or "."
local PLUGIN = dir .. "/literaryclock.koplugin"

local Core = { dir = PLUGIN }
Core.TimeWords = assert(loadfile(PLUGIN .. "/core/timewords.lua"))(Core)
Core.Filler    = assert(loadfile(PLUGIN .. "/core/filler.lua"))(Core)
local TW, Filler = Core.TimeWords, Core.Filler
local lines = dofile(PLUGIN .. "/core/fallbacks.lua")

local failures = 0
local function check(cond, msg)
    if not cond then failures = failures + 1; print("FAIL: " .. msg) end
end
local function has(list, s)
    for _i, v in ipairs(list) do if v == s then return true end end
    return false
end
local function at(h, m)
    return os.time{ year = 2026, month = 11, day = 13, hour = h, min = m, sec = 0 }
end

-- 1. Time in words ----------------------------------------------------------
check(has(TW.forms(9, 33), "nine thirty-three"), "9:33 -> nine thirty-three")
check(has(TW.forms(9, 33), "twenty-seven minutes to ten"), "9:33 -> twenty-seven minutes to ten")
check(has(TW.forms(23, 15), "a quarter past eleven"), "23:15 -> a quarter past eleven")
check(has(TW.forms(10, 30), "half past ten"), "10:30 -> half past ten")
check(has(TW.forms(21, 45), "a quarter to ten"), "21:45 -> a quarter to ten")
check(has(TW.forms(10, 5), "five past ten"), "10:05 -> five past ten")
check(has(TW.forms(9, 5), "nine oh five"), "9:05 -> nine oh five")
check(has(TW.forms(13, 1), "one minute past one"), "13:01 -> one minute past one")
check(has(TW.forms(11, 59), "one minute to twelve"), "11:59 -> one minute to twelve")
check(has(TW.forms(0, 0), "midnight"), "0:00 -> midnight")
check(has(TW.forms(12, 0), "noon"), "12:00 -> noon")
check(has(TW.forms(0, 20), "twelve twenty"), "0:20 -> twelve twenty (12-hour)")

local HOURS = {}
for _i, w in ipairs({ "one", "two", "three", "four", "five", "six", "seven",
        "eight", "nine", "ten", "eleven", "twelve" }) do HOURS[w] = true end
for h = 0, 23 do
    for m = 0, 59 do
        local forms = TW.forms(h, m)
        check(#forms >= 1, string.format("%02d:%02d has forms", h, m))
        for _i, f in ipairs(forms) do
            local where = string.format("%02d:%02d '%s'", h, m, f)
            check(not f:find("zero"), where .. " has no 'zero'")
            check(not f:lower():find("[ap]%.?m%.?$"), where .. " has no am/pm")
            check(not f:find("teen o'clock") and not f:find("twenty%S* o'clock"),
                where .. " is 12-hour")
            local hour_word = f:match("past (%S+)$") or f:match("to (%S+)$") or f:match("^(%S+)")
            check(HOURS[hour_word] or f == "midnight" or f == "noon"
                or f:match("^a? ?quarter") or f:match("^half") or f:match("^%S+ minutes?")
                or f:match("^%S+ past") or f:match("^%S+ to"),
                where .. " names an hour from one to twelve")
        end
        local w = TW.time_to_words(h, m)
        check(has(forms, w), string.format("%02d:%02d time_to_words picks a form", h, m))
    end
end

-- 2. Every line, every form: capital first letter, one highlighted time ---------
local count = 0
for _i, family in ipairs({ "narrator", "reader" }) do
    check(#lines[family] > 0, family .. " has lines")
    for _j, template in ipairs(lines[family]) do
        check(select(2, template:gsub("{time}", "")) == 1, "one {time} in: " .. template)
        for h = 0, 23 do
            for m = 0, 59 do
                for _k, words in ipairs(TW.forms(h, m)) do
                    local s = Filler.render(template, words)
                    count = count + 1
                    local plain = s:gsub("[\1-\4]", "")
                    if not plain:match("^%u") then
                        check(false, "capital first letter: " .. plain)
                    end
                    check(s:match("\3[^\3\4]+\4") ~= nil and select(2, s:gsub("\3", "")) == 1,
                        "time highlighted once: " .. plain)
                    check(not s:find("{time}", 1, true), "no {time} left: " .. plain)
                end
            end
        end
    end
end
check(Filler.render("{time}.", "nine thirty-three") == "\3Nine thirty-three\4.",
    "{time} at the start is capitalised inside the highlight")
check(Filler.render("At {time} x.", "nine thirty-three") == "At \3nine thirty-three\4 x.",
    "{time} in the middle stays lower case")

-- 3. Alternation and no repeats ---------------------------------------------------
Filler.reset()
local prev_family, prev_text = nil, {}
local t0 = at(9, 0)
for i = 0, 499 do
    local text, attribution = Filler.pick(t0 + i * 60)
    local family = Filler.last_family
    check(attribution == "", "attribution empty by default")
    if prev_family then check(family ~= prev_family, "families alternate (pick " .. i .. ")") end
    -- Same line twice in a row within a family? Compare the templates: strip
    -- the time, which changes from minute to minute.
    local shape = text:gsub("\3[^\4]*\4", "{time}")
    check(shape ~= prev_text[family], "no repeat within " .. family .. " (pick " .. i .. ")")
    prev_text[family], prev_family = shape, family
end

-- 4. Same minute, same line ------------------------------------------------------
Filler.reset()
local a = Filler.pick(at(10, 28))
local b = Filler.pick(at(10, 28) + 30)
check(a == b, "a redraw within the minute keeps the line")
local fam = Filler.last_family
Filler.pick(at(10, 28) + 45)
check(Filler.last_family == fam, "a redraw within the minute does not move the alternation")

print(string.format("%d rendered lines checked, %d failure(s)", count, failures))
os.exit(failures == 0 and 0 or 1)
