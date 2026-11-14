--[[
The settings, described once and shown two ways:

    SettingsUI.showDialog{ on_change =, decorate = }
        a dialog of rows ("Font: Noto Serif"), each opening its choices;
        used by Bookshelf (long-press the card, Module settings)
    SettingsUI.menuItems(on_change, translate)
        KOReader menu items; used by SimpleUI's module menu

Every change saves at once and calls on_change, so the card behind redraws.
]]

local Core = ...

local SettingsUI = {}

local CHECK = "\xE2\x9C\x93 " -- check mark and a space
local BLANK = "    "

local function T(s) return require("gettext")(s) end

local function colourScreen()
    local ok, on = pcall(function() return require("device").screen:isColorEnabled() end)
    return ok and on and true or false
end

local function fontLabel()
    return Core.Settings.get("font_family") or (Core.Fonts.DEFAULT .. " " .. T("(default)"))
end

local function sizeLabel()
    local S = Core.Settings
    if S.get("font_mode") == "fixed" then
        return string.format(T("Fixed, %d"), tonumber(S.get("font_size")) or S.FONT_SIZE_DEFAULT)
    end
    return T("Adaptive")
end

-- The rows, in order. `list` rows pick one entry of a list stored in Settings.
function SettingsUI.rows()
    local S = Core.Settings
    local rows = {
        { kind = "toggle", key = "sfw_only", label = T("Safe for work quotes only") },
        { kind = "toggle", key = "show_attribution", label = T("Show title and author") },
        { kind = "font", label = T("Font"), value = fontLabel },
        { kind = "size", label = T("Font size"), value = sizeLabel },
        { kind = "list", key = "emphasis", label = T("Time style"), list = S.EMPHASES },
    }
    if colourScreen() then
        rows[#rows + 1] = { kind = "list", key = "accent", label = T("Time colour"), list = S.ACCENTS }
    end
    rows[#rows + 1] = { kind = "list", key = "align", label = T("Alignment"), list = S.ALIGNMENTS }
    rows[#rows + 1] = { kind = "list", key = "line_spacing", label = T("Line spacing"), list = S.SPACINGS }
    for _i, row in ipairs(rows) do
        if row.kind == "list" then
            row.value = function() return T(S.choice(row.key, row.list).label) end
        end
    end
    return rows
end

-- ---------------------------------------------------------------------------
-- Pickers shared by both hosts
-- ---------------------------------------------------------------------------

--- Spinner for the fixed font size. Picking a size also switches to fixed.
function SettingsUI.showFontSizeSpinner(on_done)
    local SpinWidget = require("ui/widget/spinwidget")
    local UIManager  = require("ui/uimanager")
    local Settings   = Core.Settings
    UIManager:show(SpinWidget:new{
        title_text = T("Fixed font size"),
        info_text = T("The same size on every card. A quote too long for the card at this size is cut short."),
        value = tonumber(Settings.get("font_size")) or Settings.FONT_SIZE_DEFAULT,
        value_min = Settings.FONT_SIZE_MIN,
        value_max = Settings.FONT_SIZE_MAX,
        value_step = 1,
        value_hold_step = 4,
        default_value = Settings.FONT_SIZE_DEFAULT,
        ok_text = T("Set"),
        callback = function(spin)
            Settings.set("font_size", spin.value)
            Settings.set("font_mode", "fixed")
            if on_done then on_done() end
        end,
    })
end

--- Full-screen list of the installed font families, paged. `on_done` runs
--- after a pick (not on cancel).
function SettingsUI.showFontPicker(on_done)
    local Menu      = require("ui/widget/menu")
    local UIManager = require("ui/uimanager")
    local Screen    = require("device").screen
    local Settings, Fonts = Core.Settings, Core.Fonts

    Fonts.reset() -- pick up fonts added since the last look
    local current = Settings.get("font_family") or Fonts.DEFAULT
    local menu
    local function item(label, family)
        return {
            text = (family == current and CHECK or BLANK) .. label,
            callback = function()
                Settings.set("font_family", family ~= Fonts.DEFAULT and family or nil)
                UIManager:close(menu)
                if on_done then on_done() end
            end,
        }
    end
    local items = { item(Fonts.DEFAULT .. " " .. T("(default)"), Fonts.DEFAULT) }
    for _i, f in ipairs(Fonts.families()) do
        if f.name ~= Fonts.DEFAULT then items[#items + 1] = item(f.name, f.name) end
    end
    menu = Menu:new{
        title = T("Font"),
        subtitle = T("Fonts you add to KOReader's fonts folder show here too."),
        item_table = items,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
        covers_fullscreen = true,
        is_borderless = true,
        is_popout = false,
    }
    UIManager:show(menu)
end

-- ---------------------------------------------------------------------------
-- Dialog (Bookshelf)
-- ---------------------------------------------------------------------------

local function listDialog(row, after, decorate)
    local ButtonDialog = require("ui/widget/buttondialog")
    local UIManager    = require("ui/uimanager")
    local S = Core.Settings
    local current = S.choice(row.key, row.list).id
    local dialog
    local buttons = {}
    for _i, e in ipairs(row.list) do
        buttons[#buttons + 1] = { {
            text = (e.id == current and CHECK or BLANK) .. T(e.label),
            align = "left",
            callback = function()
                UIManager:close(dialog)
                S.set(row.key, e.id)
                after()
            end,
        } }
    end
    local spec = { title = row.label, title_align = "center", width_factor = 0.7, buttons = buttons }
    if decorate then spec = decorate(spec) or spec end
    dialog = ButtonDialog:new(spec)
    UIManager:show(dialog)
end

--- The settings dialog. o.on_change() runs after every change; o.decorate(spec)
--- may adjust the ButtonDialog spec (Bookshelf adds its close button).
function SettingsUI.showDialog(o)
    o = o or {}
    local ButtonDialog = require("ui/widget/buttondialog")
    local UIManager    = require("ui/uimanager")
    local S = Core.Settings
    local dialog
    local function reopen()
        if o.on_change then pcall(o.on_change) end
        SettingsUI.showDialog(o)
    end
    local buttons = {}
    for _i, row in ipairs(SettingsUI.rows()) do
        local text, callback
        if row.kind == "toggle" then
            text = (S.get(row.key) and CHECK or BLANK) .. row.label
            callback = function()
                UIManager:close(dialog)
                S.toggle(row.key)
                reopen()
            end
        else
            text = row.label .. ": " .. row.value() .. "  \xE2\x80\xBA" -- single right angle quote
            callback = function()
                UIManager:close(dialog)
                if row.kind == "font" then
                    SettingsUI.showFontPicker(reopen)
                elseif row.kind == "size" then
                    SettingsUI.showSizeDialog(reopen, o.decorate)
                else
                    listDialog(row, reopen, o.decorate)
                end
            end
        end
        buttons[#buttons + 1] = { { text = text, align = "left", callback = callback } }
    end
    local spec = { title = T("Literary Clock"), title_align = "center", width_factor = 0.75, buttons = buttons }
    if o.decorate then spec = o.decorate(spec) or spec end
    dialog = ButtonDialog:new(spec)
    UIManager:show(dialog)
end

--- Font size: adaptive, fixed, or change the fixed size.
function SettingsUI.showSizeDialog(after, decorate)
    local ButtonDialog = require("ui/widget/buttondialog")
    local UIManager    = require("ui/uimanager")
    local S = Core.Settings
    local fixed = S.get("font_mode") == "fixed"
    local dialog
    local spec = {
        title = T("Font size"), title_align = "center", width_factor = 0.7,
        buttons = {
            { { text = (fixed and BLANK or CHECK) .. T("Adaptive: fills the card"), align = "left",
                callback = function() UIManager:close(dialog); S.set("font_mode", "adaptive"); after() end } },
            { { text = (fixed and CHECK or BLANK) .. string.format(T("Fixed: %d"),
                    tonumber(S.get("font_size")) or S.FONT_SIZE_DEFAULT), align = "left",
                callback = function() UIManager:close(dialog); S.set("font_mode", "fixed"); after() end } },
            { { text = BLANK .. T("Change fixed size…"), align = "left",
                callback = function() UIManager:close(dialog); SettingsUI.showFontSizeSpinner(after) end } },
        },
    }
    if decorate then spec = decorate(spec) or spec end
    dialog = ButtonDialog:new(spec)
    UIManager:show(dialog)
end

-- ---------------------------------------------------------------------------
-- Menu items (SimpleUI)
-- ---------------------------------------------------------------------------

--- KOReader menu items for every setting. `translate` is the host's gettext
--- (falls back to KOReader's).
function SettingsUI.menuItems(on_change, translate)
    local S = Core.Settings
    local function changed(touchmenu_instance)
        if on_change then pcall(on_change) end
        if touchmenu_instance and touchmenu_instance.updateItems then
            touchmenu_instance:updateItems()
        end
    end
    local items = {}
    for _i, row in ipairs(SettingsUI.rows()) do
        if row.kind == "toggle" then
            items[#items + 1] = {
                text = row.label,
                checked_func = function() return S.get(row.key) end,
                callback = function(tm) S.toggle(row.key); changed(tm) end,
            }
        elseif row.kind == "font" then
            items[#items + 1] = {
                text_func = function() return row.label .. ": " .. row.value() end,
                keep_menu_open = true,
                callback = function(tm) SettingsUI.showFontPicker(function() changed(tm) end) end,
            }
        elseif row.kind == "size" then
            items[#items + 1] = {
                text_func = function() return row.label .. ": " .. row.value() end,
                sub_item_table = {
                    { text = T("Adaptive: fills the card"), radio = true,
                      checked_func = function() return S.get("font_mode") ~= "fixed" end,
                      callback = function(tm) S.set("font_mode", "adaptive"); changed(tm) end },
                    { text_func = function()
                          return string.format(T("Fixed: %d"), tonumber(S.get("font_size")) or S.FONT_SIZE_DEFAULT)
                      end,
                      radio = true,
                      checked_func = function() return S.get("font_mode") == "fixed" end,
                      callback = function(tm) S.set("font_mode", "fixed"); changed(tm) end },
                    { text = T("Change fixed size…"), keep_menu_open = true,
                      callback = function(tm) SettingsUI.showFontSizeSpinner(function() changed(tm) end) end },
                },
            }
        else
            local sub = {}
            for _j, e in ipairs(row.list) do
                sub[#sub + 1] = {
                    text = T(e.label), radio = true,
                    checked_func = function() return S.choice(row.key, row.list).id == e.id end,
                    callback = function(tm) S.set(row.key, e.id); changed(tm) end,
                }
            end
            items[#items + 1] = {
                text_func = function() return row.label .. ": " .. row.value() end,
                sub_item_table = sub,
            }
        end
    end
    return items
end

return SettingsUI
