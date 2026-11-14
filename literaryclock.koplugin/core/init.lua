--[[
Loads the Literary Clock core once and shares it between the home screens.

    local Core = dofile(plugin_dir .. "/core/init.lua")(plugin_dir)
    Core.Clock.build{ ... }

The core files are loaded by path rather than with require, so their names
cannot clash with another plugin's modules. Each file gets the Core table as
its `...`.
]]

local KEY = "literaryclock.koplugin/core"

return function(plugin_dir)
    local Core = package.loaded[KEY]
    if Core then return Core end
    Core = { dir = plugin_dir }
    for _i, name in ipairs({ "Settings", "Lookup", "TimeWords", "Filler", "Fonts", "Layout", "Clock", "SettingsUI" }) do
        local chunk = assert(loadfile(plugin_dir .. "/core/" .. name:lower() .. ".lua"))
        Core[name] = chunk(Core)
    end
    Core.Lookup.init(plugin_dir)
    package.loaded[KEY] = Core
    return Core
end
