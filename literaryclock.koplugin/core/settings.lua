--[[
Literary Clock settings, shared by every home screen the clock appears on.

Stored in KOReader's own settings (G_reader_settings) under one table, so a
change made from Bookshelf shows on SimpleUI too and the other way round.
]]

local KEY = "literary_clock"

local DEFAULTS = {
    sfw_only = true,          -- skip quotes the dataset marks as not safe for work
    show_attribution = true,  -- title and author under the quote
}

local Settings = {}

local function all()
    local t = G_reader_settings and G_reader_settings:readSetting(KEY)
    return type(t) == "table" and t or {}
end

function Settings.get(name)
    local v = all()[name]
    if v == nil then return DEFAULTS[name] end
    return v
end

function Settings.set(name, value)
    if not G_reader_settings then return end
    local t = all()
    t[name] = value
    G_reader_settings:saveSetting(KEY, t)
    Settings.changed = (Settings.changed or 0) + 1
end

function Settings.toggle(name)
    Settings.set(name, not Settings.get(name))
end

return Settings
