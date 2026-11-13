--[[
Literary Clock: tells the time with a quote from a book, on the home screen
of Bookshelf or SimpleUI.

Bookshelf finds bookshelf_modules/literary_clock.lua by itself (a "module
pack"), so this file only has to register the SimpleUI module.
]]

local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger          = require("logger")

local PLUGIN_DIR = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."

local sui_module = nil

-- SimpleUI's registry is reachable with require once SimpleUI is loaded.
-- Returns true when registered (or already registered).
local function registerSimpleUI()
    if sui_module then return true end
    local ok, Registry = pcall(require, "modules/moduleregistry")
    if not (ok and type(Registry) == "table" and type(Registry.register) == "function"
            and type(Registry.getCategories) == "function") then
        return false
    end
    local ok_m, mod = pcall(function()
        return dofile(PLUGIN_DIR .. "/simpleui/module_literary_clock.lua")(PLUGIN_DIR)
    end)
    if not ok_m then
        logger.warn("literaryclock: cannot load the SimpleUI module:", mod)
        return true -- do not retry
    end
    Registry.register(mod)
    sui_module = mod
    -- Registered after the home screen was built: rebuild it so the module
    -- shows (only matters if the user has it enabled).
    local SE = package.loaded["engines/sui_screen_engine"]
    local hs = SE and SE.getInstance and SE.getInstance("hs")
    if hs and hs._refreshImmediate then pcall(hs._refreshImmediate, hs, true) end
    return true
end

local LiteraryClock = WidgetContainer:extend{
    name = "literaryclock",
    is_doc_only = false,
}

function LiteraryClock:init()
    -- Plugins load in no fixed order: if SimpleUI is not loaded yet, try
    -- again once every plugin is.
    if not registerSimpleUI() then
        UIManager:nextTick(registerSimpleUI)
    end
end

function LiteraryClock:onSuspend()
    if sui_module then sui_module.ticker.cancel() end
end

function LiteraryClock:onResume()
    if sui_module then sui_module.ticker.schedule() end
end

return LiteraryClock
