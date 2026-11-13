--[[
Settings dialogs shared by the Bookshelf and SimpleUI adapters.
]]

local Core = ...

local SettingsUI = {}

--- Opens a spinner for the fixed font size. Picking a size also switches
--- the font to fixed. `on_done` runs after a change.
function SettingsUI.showFontSizeSpinner(on_done)
    local SpinWidget = require("ui/widget/spinwidget")
    local UIManager  = require("ui/uimanager")
    local _          = require("gettext")
    local Settings   = Core.Settings
    UIManager:show(SpinWidget:new{
        title_text = _("Fixed font size"),
        info_text = _("The same size on every card. A quote too long for the card at this size is cut short."),
        value = tonumber(Settings.get("font_size")) or Settings.FONT_SIZE_DEFAULT,
        value_min = Settings.FONT_SIZE_MIN,
        value_max = Settings.FONT_SIZE_MAX,
        value_step = 1,
        value_hold_step = 4,
        default_value = Settings.FONT_SIZE_DEFAULT,
        ok_text = _("Set"),
        callback = function(spin)
            Settings.set("font_size", spin.value)
            Settings.set("font_mode", "fixed")
            if on_done then on_done() end
        end,
    })
end

return SettingsUI
