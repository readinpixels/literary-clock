--[[
Font picker: one row per font family, each name drawn in its own typeface,
ten to a page, with the current choice's name in the title.

Adapted from Bookshelf's lib/bookshelf_font_picker.lua
(https://github.com/AndyHazz/bookshelf.koplugin), Copyright (C) AndyHazz
and the Bookshelf contributors, licensed under the GNU Affero General Public
License v3.0. Bookshelf's picker was itself ported from bookends'
showFontPicker. Changes here: the list comes from core/fonts.lua and is
keyed by family name; Bookshelf's own helpers (colour text, spacing,
pagination, popup buttons, i18n) are replaced by KOReader's; closing runs
an on_done callback.

    FontPicker.show{
        current   = family name (nil: the default),
        default   = the default family's name,
        families  = list of { name =, file = } (core/fonts.lua),
        on_select = function(name) end, -- on every tap, for a live preview;
                                         -- Cancel and a tap outside call it
                                         -- again with the original name
        on_done   = function() end,      -- after the picker closes, any way
    }
]]

local Core = ...

local Blitbuffer      = require("ffi/blitbuffer")
local Button          = require("ui/widget/button")
local ButtonTable     = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local GestureRange    = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InputContainer  = require("ui/widget/container/inputcontainer")
local LeftContainer   = require("ui/widget/container/leftcontainer")
local LineWidget      = require("ui/widget/linewidget")
local Size            = require("ui/size")
local TextWidget      = require("ui/widget/textwidget")
local TopContainer    = require("ui/widget/container/topcontainer")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local logger          = require("logger")
local Screen          = Device.screen
local _               = require("gettext")

local FontPicker = {}

-- First / previous / "Page X of Y" / next / last, as text chevrons.
local function pageNav(page, total_pages, on_goto, show_parent)
    local function chevron(text, target, enabled)
        return Button:new{
            text = text,
            bordersize = 0,
            enabled = enabled,
            show_parent = show_parent,
            callback = function() on_goto(target) end,
        }
    end
    local gap = HorizontalSpan:new{ width = Screen:scaleBySize(16) }
    return HorizontalGroup:new{
        align = "center",
        chevron("\xC2\xAB", 1, page > 1), gap,                         -- «
        chevron("\xE2\x80\xB9", page - 1, page > 1), gap,              -- ‹
        Button:new{
            text = string.format(_("Page %d of %d"), page, total_pages),
            bordersize = 0, enabled = false, show_parent = show_parent,
            callback = function() end,
        },
        gap,
        chevron("\xE2\x80\xBA", page + 1, page < total_pages), gap,    -- ›
        chevron("\xC2\xBB", total_pages, page < total_pages),          -- »
    }
end

function FontPicker.show(o)
    local fonts = o.families or {}
    local by_name = {}
    for _i, f in ipairs(fonts) do by_name[f.name] = f end
    local default_name = o.default
    local original = o.current or default_name
    local selected = original
    local on_select = o.on_select or function() end

    local function pick(name)
        selected = name
        on_select(name)
    end

    local per_page = 10
    local total_pages = math.max(1, math.ceil(#fonts / per_page))
    local page = 1
    for i, f in ipairs(fonts) do
        if f.name == selected then page = math.ceil(i / per_page); break end
    end

    local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
    local width = math.floor(math.min(screen_w, screen_h) * 0.9)
    local font_size = 22
    local row_height = Screen:scaleBySize(42)
    local left_pad = Size.padding.large
    local check_width = Screen:scaleBySize(30)

    local picker

    local function faceOf(name)
        local f = by_name[name]
        return f and Font:getFace(f.file, font_size) or Font:getFace("cfont", font_size)
    end

    local function buildPage()
        -- "Font: <name>", the name in its own typeface.
        local title_row_height = Screen:scaleBySize(48)
        local title_baseline = math.floor(title_row_height * 0.7)
        local title_text = TextWidget:new{
            text = _("Font") .. ": ",
            face = Font:getFace("infofont", font_size),
            fgcolor = Blitbuffer.COLOR_BLACK,
            bold = true,
            forced_height = title_row_height,
            forced_baseline = title_baseline,
        }
        local name_widget = TextWidget:new{
            text = selected or "",
            face = faceOf(selected),
            max_width = width - title_text:getWidth() - 2 * left_pad,
            fgcolor = Blitbuffer.COLOR_BLACK,
            forced_height = title_row_height,
            forced_baseline = title_baseline,
        }
        local title_row = LeftContainer:new{
            dimen = Geom:new{ w = width, h = title_row_height },
            HorizontalGroup:new{
                HorizontalSpan:new{ width = left_pad },
                title_text,
                name_widget,
            },
        }

        local list_group = VerticalGroup:new{ align = "left" }
        local baseline = math.floor(row_height * 0.65)
        local first = (page - 1) * per_page + 1
        for i = first, math.min(first + per_page - 1, #fonts) do
            local f = fonts[i]
            local is_selected = f.name == selected
            local label = f.name .. ((f.name == default_name) and "  \xE2\x98\x85" or "") -- ★ default
            local row = InputContainer:new{
                dimen = Geom:new{ w = width, h = row_height },
                HorizontalGroup:new{
                    HorizontalSpan:new{ width = left_pad },
                    CenterContainer:new{
                        dimen = Geom:new{ w = check_width, h = row_height },
                        TextWidget:new{
                            -- A radio mark: only one font is ever the chosen one.
                            text = is_selected and "\xE2\x97\x89 " or "\xE2\x97\xAF ",
                            face = Font:getFace("cfont", font_size),
                            forced_height = row_height,
                            forced_baseline = baseline,
                            fgcolor = Blitbuffer.COLOR_BLACK,
                            bold = true,
                        },
                    },
                    TextWidget:new{
                        text = label,
                        face = faceOf(f.name),
                        forced_height = row_height,
                        forced_baseline = baseline,
                        max_width = width - 2 * left_pad - check_width,
                        fgcolor = Blitbuffer.COLOR_BLACK,
                        bold = is_selected,
                    },
                },
            }
            row.ges_events = {
                TapSelect = { GestureRange:new{ ges = "tap", range = row.dimen } },
            }
            local name = f.name
            row.onTapSelect = function()
                pick(name)
                picker:rebuild()
                return true
            end
            list_group[#list_group + 1] = row
        end

        local nav = pageNav(page, total_pages, function(p) page = p; picker:rebuild() end, picker)
        -- Cancel puts back the font it opened on, Default picks the default,
        -- Done keeps.
        local actions = ButtonTable:new{
            width = width,
            buttons = { {
                { text = _("Cancel"), callback = function() picker:revertAndClose() end },
                {
                    text = _("Default"),
                    enabled = selected ~= default_name,
                    callback = function()
                        pick(default_name)
                        UIManager:close(picker)
                    end,
                },
                {
                    text = _("Done"),
                    is_enter_default = true,
                    callback = function() UIManager:close(picker) end,
                },
            } },
            zero_sep = true,
            show_parent = picker,
        }
        -- Rounded as the frame is, so the end buttons' white boxes don't
        -- square off its bottom corners.
        for _r, brow in ipairs(actions.buttons_layout or {}) do
            for _c, b in ipairs(brow) do
                if b.frame then b.frame.radius = Size.radius.window end
            end
        end

        return FrameContainer:new{
            radius = Size.radius.window,
            bordersize = Size.border.window,
            padding = 0,
            margin = 0,
            background = Blitbuffer.COLOR_WHITE,
            VerticalGroup:new{
                align = "center",
                title_row,
                LineWidget:new{
                    background = Blitbuffer.COLOR_BLACK,
                    dimen = Geom:new{ w = width, h = Size.line.thick },
                },
                TopContainer:new{
                    dimen = Geom:new{ w = width, h = per_page * row_height },
                    list_group,
                },
                VerticalSpan:new{ width = Size.span.vertical_default },
                CenterContainer:new{
                    dimen = Geom:new{ w = width, h = nav:getSize().h },
                    nav,
                },
                VerticalSpan:new{ width = Size.span.vertical_default },
                LineWidget:new{
                    background = Blitbuffer.COLOR_DARK_GRAY,
                    dimen = Geom:new{ w = width, h = Size.line.thin },
                },
                actions,
            },
        }
    end

    picker = InputContainer:new{
        ges_events = {
            TapClose = { GestureRange:new{ ges = "tap",
                range = Geom:new{ w = screen_w, h = screen_h } } },
            Swipe = { GestureRange:new{ ges = "swipe",
                range = Geom:new{ w = screen_w, h = screen_h } } },
        },
    }

    function picker:revertAndClose()
        if selected ~= original then pick(original) end
        UIManager:close(self)
    end

    function picker:rebuild()
        local ok, frame = xpcall(buildPage, debug.traceback)
        if not ok then
            logger.warn("literaryclock: font picker failed to build:", frame)
            UIManager:close(self)
            return
        end
        self[1] = CenterContainer:new{
            dimen = Geom:new{ w = screen_w, h = screen_h },
            frame,
        }
        self.frame = frame
        UIManager:setDirty(self, "ui")
    end

    function picker:onSwipe(_arg, ges_ev)
        local dir = ges_ev.direction
        if (dir == "west" or dir == "north") and page < total_pages then
            page = page + 1
            self:rebuild()
        elseif (dir == "east" or dir == "south") and page > 1 then
            page = page - 1
            self:rebuild()
        end
        return true
    end

    function picker:onTapClose(_arg, ges_ev)
        if self.frame and ges_ev.pos and not ges_ev.pos:intersectWith(self.frame.dimen) then
            self:revertAndClose()
            return true
        end
        return false
    end

    function picker:onShow()
        UIManager:setDirty(self, "ui")
        return true
    end

    function picker:onCloseWidget()
        UIManager:setDirty(nil, "ui")
        if o.on_done then UIManager:nextTick(o.on_done) end
    end

    picker:rebuild()
    UIManager:show(picker)
    return picker
end

return FontPicker
