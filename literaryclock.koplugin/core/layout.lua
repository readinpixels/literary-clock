--[[
Lays out a quote with its time phrase highlighted, plus title and author,
and finds the largest font size that fits a given box.

KOReader's TextBoxWidget draws a whole block in one style, so it cannot make
a few words bold. This module does its own word wrapping instead: the quote
is split into words, each word into styled pieces, and the result is one
widget that paints every piece with RenderText. No background is painted, so
the card or home screen behind it shows through.

The quote string comes from data/<lang>/HH.lua with its styling inline:
  \1 ... \2  italic     \3 ... \4  time phrase     \n  line break
]]

local Blitbuffer = require("ffi/blitbuffer")
local Font       = require("ui/font")
local Geom       = require("ui/geometry")
local RenderText = require("ui/rendertext")
local Widget     = require("ui/widget/widget")
local bit        = require("bit")

local ITALIC, BOLD = 1, 2

local Layout = {}

-- Font files for each style bit combination. Noto Serif ships with KOReader
-- on every platform.
Layout.FONTS = {
    [0]               = "NotoSerif-Regular.ttf",
    [ITALIC]          = "NotoSerif-Italic.ttf",
    [BOLD]            = "NotoSerif-Bold.ttf",
    [ITALIC + BOLD]   = "NotoSerif-BoldItalic.ttf",
}

local ELLIPSIS = "…"

-- ---------------------------------------------------------------------------
-- Tokenising
-- ---------------------------------------------------------------------------

--- Splits an encoded string into words ({ segs = { {text, style} } }) and
--- line breaks ({ nl = true }). `base` is OR-ed into every style.
local function tokenize(s, base)
    base = base or 0
    local items, word, buf = {}, nil, {}
    local style = base
    local function flushSeg()
        if #buf > 0 then
            word = word or { segs = {} }
            word.segs[#word.segs + 1] = { text = table.concat(buf), style = style }
            buf = {}
        end
    end
    local function flushWord()
        flushSeg()
        if word then items[#items + 1] = word; word = nil end
    end
    for i = 1, #s do
        local c = s:sub(i, i)
        if c == "\1" then flushSeg(); style = bit.bor(style, ITALIC)
        elseif c == "\2" then flushSeg(); style = bit.bor(bit.band(style, bit.bnot(ITALIC)), base)
        elseif c == "\3" then flushSeg(); style = bit.bor(style, BOLD)
        elseif c == "\4" then flushSeg(); style = bit.bor(bit.band(style, bit.bnot(BOLD)), base)
        elseif c == " " then flushWord()
        elseif c == "\n" then flushWord(); items[#items + 1] = { nl = true }
        else buf[#buf + 1] = c end
    end
    flushWord()
    return items
end
Layout.tokenize = tokenize

-- ---------------------------------------------------------------------------
-- Measuring and wrapping
-- ---------------------------------------------------------------------------

local face_cache = {}
local function getFaces(size)
    local faces = face_cache[size]
    if not faces then
        faces = {}
        for style, file in pairs(Layout.FONTS) do
            faces[style] = Font:getFace(file, size) or Font:getFace("cfont", size)
        end
        local h, asc = faces[0].ftsize:getHeightAndAscender()
        faces.line_h = math.ceil(h)
        faces.ascender = math.floor(asc + 0.5)
        faces.space_w = RenderText:sizeUtf8Text(0, false, faces[0], " ", true).x
        face_cache[size] = faces
    end
    return faces
end

local function textWidth(face, text)
    return RenderText:sizeUtf8Text(0, false, face, text, true).x
end

--- Greedy word wrap. Returns lines ({ w, words = { {x, w, segs} } }) and
--- whether a single word was wider than the box.
local function wrap(items, faces, width)
    local lines, overflow = {}, false
    local cur = { w = 0, words = {} }
    for _i, it in ipairs(items) do
        if it.nl then
            lines[#lines + 1] = cur
            cur = { w = 0, words = {} }
        else
            local ww, segs = 0, {}
            for _j, seg in ipairs(it.segs) do
                local w = textWidth(faces[seg.style], seg.text)
                segs[#segs + 1] = { text = seg.text, style = seg.style, x = ww }
                ww = ww + w
            end
            if ww > width then overflow = true end
            local gap = #cur.words > 0 and faces.space_w or 0
            if #cur.words > 0 and cur.w + gap + ww > width then
                lines[#lines + 1] = cur
                cur = { w = 0, words = {} }
                gap = 0
            end
            cur.words[#cur.words + 1] = { x = cur.w + gap, w = ww, segs = segs }
            cur.w = cur.w + gap + ww
        end
    end
    lines[#lines + 1] = cur
    return lines, overflow
end

-- Ends `line` with an ellipsis, dropping words until it fits `width`.
local function addEllipsis(line, faces, width)
    local ew = textWidth(faces[0], ELLIPSIS)
    while #line.words > 1 and line.w + ew > width do
        table.remove(line.words)
        local last = line.words[#line.words]
        line.w = last.x + last.w
    end
    local last = line.words[#line.words]
    if last then
        last.segs[#last.segs + 1] = { text = ELLIPSIS, style = 0, x = last.w }
        last.w = last.w + ew
        line.w = last.x + last.w
    end
end

-- ---------------------------------------------------------------------------
-- The widget
-- ---------------------------------------------------------------------------

local COLOUR_BB = {}
for _i, name in ipairs({ "TYPE_BBRGB32", "TYPE_BBRGB24", "TYPE_BBRGB16" }) do
    if Blitbuffer[name] then COLOUR_BB[Blitbuffer[name]] = true end
end

-- Decodes one UTF-8 character at byte `i`; returns the code point and the
-- index of the next character.
local function utf8At(s, i)
    local c = s:byte(i)
    if c < 0x80 then return c, i + 1 end
    local n, cp
    if c >= 0xF0 then n, cp = 3, c - 0xF0
    elseif c >= 0xE0 then n, cp = 2, c - 0xE0
    elseif c >= 0xC0 then n, cp = 1, c - 0xC0
    else return 0xFFFD, i + 1 end
    for k = 1, n do
        local b = s:byte(i + k)
        if not b or b < 0x80 or b > 0xBF then return 0xFFFD, i + 1 end
        cp = cp * 64 + (b - 0x80)
    end
    return cp, i + n + 1
end

-- RenderText:renderUtf8Text, but with colorblitFromRGB32 so a colour stays a
-- colour on a colour screen (colorblitFrom turns it into a grey).
local function renderColour(bb, x, baseline, face, text, color)
    local pen_x, prev, i = 0, 0, 1
    while i <= #text do
        local cp
        cp, i = utf8At(text, i)
        local glyph = RenderText:getGlyph(face, cp, false)
        if prev ~= 0 then pen_x = pen_x + face.ftsize:getKerning(prev, cp) end
        bb:colorblitFromRGB32(glyph.bb, x + pen_x + glyph.l, baseline - glyph.t,
            0, 0, glyph.bb:getWidth(), glyph.bb:getHeight(), color)
        pen_x = pen_x + glyph.ax
        prev = cp
    end
end

local QuoteWidget = Widget:extend{
    dimen = nil,
    ops = nil,
}

function QuoteWidget:getSize()
    return self.dimen
end

function QuoteWidget:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local colour_bb = bb.colorblitFromRGB32 and COLOUR_BB[bb:getType()]
    for _i, op in ipairs(self.ops) do
        if colour_bb and not Blitbuffer.isColor8(op.color) then
            renderColour(bb, x + op.x, y + op.baseline, op.face, op.text, op.color)
        else
            RenderText:renderUtf8Text(bb, x + op.x, y + op.baseline, op.face, op.text,
                true, false, op.color)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Fitting
-- ---------------------------------------------------------------------------

local function attributionText(title, author)
    title = title ~= "" and title or nil
    author = author ~= "" and author or nil
    if title and author then return "\1" .. title .. "\2, " .. author end
    if title then return "\1" .. title .. "\2" end
    return author
end

-- Lays everything out at quote font `size`. Returns a table with the lines,
-- their metrics and the total height.
local function layoutAt(p, size)
    local qf = getFaces(size)
    local lines, overflow = wrap(p._quote_items, qf, p.width)
    local res = {
        size = size, qf = qf, lines = lines, overflow = overflow,
        quote_h = #lines * qf.line_h,
    }
    res.h = res.quote_h
    if p._attr_items then
        local asize = math.max(p.min_attr_size or 9, math.floor(size * 0.6 + 0.5))
        local af = getFaces(asize)
        res.af = af
        res.attr_lines = wrap(p._attr_items, af, p.width)
        res.gap = math.floor(qf.line_h * 0.5)
        res.h = res.h + res.gap + #res.attr_lines * af.line_h
    end
    return res
end

-- Drops quote lines from the end, with an ellipsis, until `res` fits `max_h`.
local function clampTo(res, max_h, width)
    local attr_h = res.h - res.quote_h
    local room = math.max(1, math.floor((max_h - attr_h) / res.qf.line_h))
    if room < #res.lines then
        for i = #res.lines, room + 1, -1 do res.lines[i] = nil end
        addEllipsis(res.lines[room], res.qf, width)
        res.quote_h = room * res.qf.line_h
        res.h = res.quote_h + attr_h
        res.clamped = true
    end
end

local function emitLines(ops, lines, faces, top, width, align, colors)
    for i, line in ipairs(lines) do
        local lx = 0
        if align == "right" then lx = width - line.w
        elseif align == "center" then lx = math.floor((width - line.w) / 2) end
        local baseline = top + (i - 1) * faces.line_h + faces.ascender
        for _j, word in ipairs(line.words) do
            for _k, seg in ipairs(word.segs) do
                ops[#ops + 1] = {
                    x = lx + word.x + seg.x, baseline = baseline,
                    face = faces[seg.style], text = seg.text,
                    color = colors(seg.style),
                }
            end
        end
    end
end

local function prepare(p)
    if not p._quote_items then
        p._quote_items = tokenize(p.quote)
        local attr = p.show_attribution ~= false and attributionText(p.title or "", p.author or "")
        p._attr_items = attr and tokenize(attr) or nil
    end
    p.min_size = p.min_size or 10
    p.max_size = math.max(p.min_size, p.max_size or 40)
end

--- Does the quote fit a `p.width` x `height` box at `size` or larger?
function Layout.fitsAt(p, size, height)
    prepare(p)
    local res = layoutAt(p, size)
    return res.h <= height and not res.overflow
end

--- Builds the widget.
-- p.quote, p.title, p.author        the quote (encoded) and its source
-- p.width                           box width
-- p.height                          box height to fill, or nil for natural height
-- p.max_height                      ceiling when p.height is nil
-- p.size                            font size to use when p.height is nil
-- p.min_size, p.max_size            font size range searched to fill p.height
-- p.show_attribution                default true
-- p.fg, p.muted, p.accent           colours (accent: the time phrase)
-- p.align_attribution               "right" (default), "left" or "center"
-- Returns the widget and a table { size =, clamped = }.
function Layout.build(p)
    prepare(p)
    local res
    local target = p.height or p.max_height
    if p.height or (p.max_height and layoutAt(p, p.size or p.max_size).h > p.max_height) then
        -- Largest size whose layout fits the target height.
        local lo, hi = p.min_size, p.height and p.max_size or (p.size or p.max_size)
        local best
        while lo <= hi do
            local mid = math.floor((lo + hi) / 2)
            local r = layoutAt(p, mid)
            if r.h <= target and not r.overflow then best = r; lo = mid + 1
            else hi = mid - 1 end
        end
        res = best or layoutAt(p, p.min_size)
        if res.h > target then clampTo(res, target, p.width) end
    else
        res = layoutAt(p, p.size or p.max_size)
    end

    local fg = p.fg or Blitbuffer.COLOR_BLACK
    local accent = p.accent or fg
    local muted = p.muted or Blitbuffer.COLOR_DARK_GRAY

    local box_h = p.height or res.h
    local top = math.max(0, math.floor((box_h - res.h) / 2))
    local ops = {}
    emitLines(ops, res.lines, res.qf, top, p.width, p.align or "left", function(style)
        return bit.band(style, BOLD) ~= 0 and accent or fg
    end)
    if res.attr_lines then
        emitLines(ops, res.attr_lines, res.af, top + res.quote_h + res.gap, p.width,
            p.align_attribution or "right", function() return muted end)
    end
    local widget = QuoteWidget:new{
        dimen = Geom:new{ x = 0, y = 0, w = p.width, h = box_h },
        ops = ops,
    }
    return widget, { size = res.size, clamped = res.clamped }
end

return Layout
