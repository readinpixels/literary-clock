--[[
Literary Clock settings, shared by every home screen the clock appears on.

Stored in KOReader's own settings (G_reader_settings) under one table, so a
change made from Bookshelf shows on SimpleUI too and the other way round.
]]

local KEY = "literary_clock"

local Settings = {}

-- Fixed font size: default and the range offered. Sizes are KOReader font
-- sizes (scaled to the screen's DPI by KOReader, like every other text).
Settings.FONT_SIZE_DEFAULT = 16
Settings.FONT_SIZE_MIN = 8
Settings.FONT_SIZE_MAX = 48

local DEFAULTS = {
    sfw_only = true,          -- skip quotes the dataset marks as not safe for work
    show_attribution = true,  -- title and author under the quote
    font_mode = "adaptive",   -- "adaptive": largest size that fills the card; "fixed": font_size
    font_size = Settings.FONT_SIZE_DEFAULT,
}

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

--- The fixed font size when "fixed" is on, else nil.
function Settings.fixedFontSize()
    if Settings.get("font_mode") ~= "fixed" then return nil end
    local s = tonumber(Settings.get("font_size")) or Settings.FONT_SIZE_DEFAULT
    return math.max(Settings.FONT_SIZE_MIN, math.min(Settings.FONT_SIZE_MAX, math.floor(s)))
end

return Settings
