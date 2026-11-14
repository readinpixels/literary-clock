--[[
Font families for the quote: KOReader's own fonts and any the user added
(the folders KOReader scans, such as koreader/fonts or, on a Kobo,
/mnt/onboard/fonts).

A family is stored by name ("Noto Serif"), not by file, so it survives a
font folder being moved. Its four styles are found from the metadata
KOReader keeps for every font file (family name, bold, italic):

    Fonts.families()        -> sorted list of { name =, file = } (regular file)
    Fonts.resolve(name)     -> { [0] = regular, [1] = italic, [2] = bold,
                                 [3] = bold italic, fake_bold = { [style] = true } }

A missing style falls back on another one: no italic -> upright, no bold ->
the regular drawn with KOReader's synthetic bold.
]]

local Core = ...

local Fonts = {}

Fonts.DEFAULT = "Noto Serif"
local DEFAULT_FILES = {
    [0] = "NotoSerif-Regular.ttf",
    [1] = "NotoSerif-Italic.ttf",
    [2] = "NotoSerif-Bold.ttf",
    [3] = "NotoSerif-BoldItalic.ttf",
}

-- Words that mark a weight other than regular in a file name.
local OTHER_WEIGHTS = { "thin", "light", "medium", "semibold", "demibold",
    "extrabold", "ultrabold", "heavy", "black", "condensed", "narrow" }

local function fontList()
    local ok, FontList = pcall(require, "fontlist")
    if not ok or not FontList then return nil end
    FontList:getFontList() -- scans once, then cached by KOReader
    return FontList
end

-- How far a file is from the plain upright regular of its family: lower is
-- closer. Ties go to the shorter path, so the result never depends on the
-- order pairs() visits the files in.
local function regularRank(file)
    local base = (file:match("([^/]+)$") or file):lower()
    local rank = 0
    if base:find("regular", 1, true) then rank = rank - 2 end
    for _i, w in ipairs(OTHER_WEIGHTS) do
        if base:find(w, 1, true) then rank = rank + 1 end
    end
    return rank
end

local function better(a, b)
    if not b then return true end
    local ra, rb = regularRank(a), regularRank(b)
    if ra ~= rb then return ra < rb end
    if #a ~= #b then return #a < #b end
    return a < b
end

-- Fonts that cannot set an English quote: symbol and icon fonts, and fonts
-- for other scripts. KOReader records which languages each font covers; a
-- font with no record (some older CFF fonts) is kept unless its name says
-- it is a symbol font.
local SYMBOL_NAMES = { "symbol", "dingbat", "nerd font", "emoji", "icons" }
local function usable(info)
    local lname = info.name:lower()
    for _i, w in ipairs(SYMBOL_NAMES) do
        if lname:find(w, 1, true) then return false end
    end
    if type(info.langs) == "table" and next(info.langs) ~= nil and not info.langs.en then
        return false
    end
    return true
end

-- family name -> { [style] = file }, built once.
local by_family
local function index()
    if by_family then return by_family end
    by_family = {}
    local FontList = fontList()
    if not FontList then return by_family end
    for file, info_list in pairs(FontList.fontinfo or {}) do
        local info = type(info_list) == "table" and info_list[1]
        if info and info.name and not info.mono and usable(info) then
            local style = (info.italic and 1 or 0) + (info.bold and 2 or 0)
            local fam = by_family[info.name]
            if not fam then fam = {}; by_family[info.name] = fam end
            if better(file, fam[style]) then fam[style] = file end
        end
    end
    return by_family
end

--- Forget the scanned fonts (after the user adds some, say).
function Fonts.reset()
    by_family = nil
    Fonts._resolved = {}
end
Fonts._resolved = {}

--- Every family that has an upright regular (or, failing that, any style)
--- FreeType can open, sorted by name.
function Fonts.families()
    local Font = require("ui/font")
    local list = {}
    for name, fam in pairs(index()) do
        local file = fam[0] or fam[2] or fam[1] or fam[3]
        local face = file and Font:getFace(file, 12)
        -- Must open, and must have Latin letters of its own.
        if face and face.ftsize:hasGlyph(0x61) and face.ftsize:hasGlyph(0x51)
                and face.ftsize:hasGlyph(0x2019) then
            list[#list + 1] = { name = name, file = file }
        end
    end
    local ok_u, ffiUtil = pcall(require, "ffi/util")
    local before = ok_u and ffiUtil.strcoll or function(a, b) return a < b end
    table.sort(list, function(a, b) return before(a.name, b.name) end)
    return list
end

--- The four style files of `name` (nil or unknown -> the default family).
function Fonts.resolve(name)
    name = name or Fonts.DEFAULT
    local hit = Fonts._resolved[name]
    if hit then return hit end
    local set
    if name == Fonts.DEFAULT then
        set = { [0] = DEFAULT_FILES[0], [1] = DEFAULT_FILES[1],
                [2] = DEFAULT_FILES[2], [3] = DEFAULT_FILES[3], fake_bold = {} }
    else
        local fam = index()[name]
        if not fam or not (fam[0] or fam[1] or fam[2] or fam[3]) then
            return Fonts.resolve(Fonts.DEFAULT)
        end
        local regular = fam[0] or fam[1] or fam[2] or fam[3]
        local italic = fam[1] or regular
        set = { fake_bold = {} }
        set[0] = regular
        set[1] = italic
        if fam[2] then set[2] = fam[2] else set[2] = regular; set.fake_bold[2] = true end
        if fam[3] then set[3] = fam[3]
        elseif fam[2] then set[3] = fam[2]
        else set[3] = italic; set.fake_bold[3] = true end
    end
    set.name = name
    set.key = table.concat({ set[0], set[1], set[2], set[3],
        set.fake_bold[2] and "fb2" or "", set.fake_bold[3] and "fb3" or "" }, "|")
    Fonts._resolved[name] = set
    return set
end

return Fonts
