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

-- Accent colours for the time phrase on colour screens. Saturated enough to
-- read on Kaleido panels, dark enough to keep contrast. "ink" draws the time
-- in the text colour (the only choice on a greyscale screen).
Settings.ACCENTS = {
    { id = "ink",      label = "Same as text" },
    { id = "crimson",  label = "Crimson",  rgb = { 0xB0, 0x24, 0x1E } },
    { id = "burgundy", label = "Burgundy", rgb = { 0x7B, 0x1E, 0x3A } },
    { id = "orange",   label = "Orange",   rgb = { 0xC8, 0x51, 0x0E } },
    { id = "amber",    label = "Amber",    rgb = { 0xA8, 0x6B, 0x00 } },
    { id = "green",    label = "Green",    rgb = { 0x2E, 0x7D, 0x32 } },
    { id = "teal",     label = "Teal",     rgb = { 0x00, 0x6D, 0x6A } },
    { id = "blue",     label = "Blue",     rgb = { 0x15, 0x58, 0xB0 } },
    { id = "navy",     label = "Navy",     rgb = { 0x1F, 0x3A, 0x68 } },
    { id = "purple",   label = "Purple",   rgb = { 0x6A, 0x1B, 0x9A } },
    { id = "pink",     label = "Pink",     rgb = { 0xC2, 0x18, 0x5B } },
    { id = "brown",    label = "Brown",    rgb = { 0x6D, 0x4C, 0x41 } },
}

Settings.EMPHASES = {
    { id = "bold",       label = "Bold" },
    { id = "bolditalic", label = "Bold italic" },
    { id = "italic",     label = "Italic" },
    { id = "none",       label = "Plain (colour only)" },
}

Settings.ALIGNMENTS = {
    { id = "left",    label = "Left" },
    { id = "justify", label = "Justified" },
    { id = "center",  label = "Centred" },
}

Settings.SPACINGS = {
    { id = "normal",  label = "Normal",  value = 1.0 },
    { id = "relaxed", label = "Relaxed", value = 1.15 },
    { id = "loose",   label = "Loose",   value = 1.3 },
}

local DEFAULTS = {
    sfw_only = true,          -- skip quotes the dataset marks as not safe for work
    show_attribution = true,  -- title and author under the quote
    font_mode = "adaptive",   -- "adaptive": largest size that fills the card; "fixed": font_size
    font_size = Settings.FONT_SIZE_DEFAULT,
    font_family = nil,        -- nil: Noto Serif (see core/fonts.lua)
    emphasis = "bold",        -- how the time phrase is drawn (Settings.EMPHASES)
    accent = "ink",           -- colour of the time phrase (Settings.ACCENTS)
    align = "left",           -- Settings.ALIGNMENTS
    line_spacing = "normal",  -- Settings.SPACINGS
}

--- The entry of `list` whose id is the current value of setting `name`
--- (the first entry when the stored value is unknown).
function Settings.choice(name, list)
    local v = Settings.get(name)
    for _i, e in ipairs(list) do
        if e.id == v then return e end
    end
    return list[1]
end

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
