--[[
Literary Clock as a SimpleUI home screen module.

Loaded by main.lua and handed to SimpleUI's module registry:
    local M = dofile(dir .. "/simpleui/module_literary_clock.lua")(dir)
    Registry.register(M)

Contract: see the header of SimpleUI's modules/moduleregistry.lua.

Minute updates. SimpleUI's own minute timer belongs to its Clock module and
is not offered to other modules, so this module keeps its own, aligned to the
minute like SimpleUI's. build() returns a fixed-size holder; each minute the
holder's content is rebuilt and only the holder's area is refreshed, which
cannot move the modules around it. A tick does nothing (and stops the chain)
when the home screen it was built for is gone or no longer shows the holder,
and does nothing while a book is open or the device is suspended; main.lua
restarts the chain on resume, and every build() restarts it too.
]]

return function(plugin_dir)

local Device          = require("device")
local Geom            = require("ui/geometry")
local Screen          = Device.screen
local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _               = require("gettext")

local Core = dofile(plugin_dir .. "/core/init.lua")(plugin_dir)
local Settings = Core.Settings

local ok_cfg, Config = pcall(require, "infra/sui_config")
if not ok_cfg then Config = nil end

local M = {}

M.id          = "literary_clock"
M.name        = _("Literary Clock")
M.category    = "extras"
M.label       = nil
M.enabled_key = "literary_clock_enabled"
M.default_on  = false
M.fills_row_height = true

local BASE_H       = 170   -- unscaled card height
local BASE_MAX_FS  = 28    -- largest quote font size at 100%
local BASE_LEGIBLE = 13    -- a quote that needs a smaller font makes way for a shorter one

local function scaleOf(ctx)
    local s = 1
    if Config and Config.getModuleScale then
        local ok, v = pcall(Config.getModuleScale, M.id, ctx and ctx.pfx)
        if ok and type(v) == "number" then s = v end
    end
    return s * ((ctx and ctx.landscape_factor) or 1)
end

function M.getHeight(ctx)
    return math.floor(Screen:scaleBySize(BASE_H) * scaleOf(ctx))
end

-- ---------------------------------------------------------------------------
-- Building
-- ---------------------------------------------------------------------------

local function buildContent(args)
    local widget = Core.Clock.build{
        width = args.w, height = args.h,
        min_size = 8,
        max_size = math.max(10, math.floor(BASE_MAX_FS * args.scale + 0.5)),
        legible  = math.max(9, math.floor(BASE_LEGIBLE * args.scale + 0.5)),
        fg = args.fg, muted = args.muted, accent = args.fg,
    }
    return widget
end

-- The minute timer's state. Only one SimpleUI home screen shows at a time,
-- so one holder is tracked: the last one built.
local live = nil      -- { holder, screen, args }
local timer = nil
M.ticker = {}

local function containsWidget(node, target, depth)
    if node == target then return true end
    if depth > 60 or type(node) ~= "table" then return false end
    for i = 1, #node do
        local child = node[i]
        if type(child) == "table" and containsWidget(child, target, depth + 1) then
            return true
        end
    end
    return false
end

local function tick()
    timer = nil
    local state = live
    if not state then return end
    local screen = state.screen

    -- The home screen that built the holder is gone: stop until the next build.
    local SE = package.loaded["engines/sui_screen_engine"]
    if screen and SE and SE.getInstance and screen._id
            and SE.getInstance(screen._id) ~= screen then
        live = nil
        return
    end
    -- Suspended (main.lua restarts the chain on resume).
    if Device.screen_saver_mode or (screen and screen._suspended) then return end
    -- A book is open: nothing to draw, check again next minute.
    local RUI = package.loaded["apps/reader/readerui"]
    if RUI and RUI.instance then
        M.ticker.schedule()
        return
    end
    -- The holder is no longer on the page (another page, module removed).
    if not (screen and containsWidget(screen, state.holder, 0)) then
        M.ticker.schedule()
        return
    end

    local ok, content = pcall(buildContent, state.args)
    if ok and content then
        state.holder[1] = content
        local holder = state.holder
        UIManager:setDirty(screen, function() return "ui", holder.dimen end)
    end
    M.ticker.schedule()
end

function M.ticker.schedule()
    if timer then UIManager:unschedule(timer) end
    if not live then timer = nil; return end
    timer = tick
    UIManager:scheduleIn(60 - (os.time() % 60) + 1, timer)
end

function M.ticker.cancel()
    if timer then UIManager:unschedule(timer) end
    timer = nil
end

function M.build(w, ctx)
    ctx = ctx or {}
    local h = M.getHeight(ctx) + (ctx.grow_h or 0)
    local ink = ctx.ink
    local args = {
        w = w, h = h, scale = scaleOf(ctx),
        fg = ink and ink.blk or nil,
        muted = ink and ink.sub or nil,
    }
    local holder = WidgetContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = w, h = h },
        buildContent(args),
    }
    live = { holder = holder, screen = ctx._screen_widget, args = args }
    M.ticker.schedule()
    return holder
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

function M.getMenuItems(ctx_menu)
    local _lc = (ctx_menu and ctx_menu._) or _
    local refresh = ctx_menu and ctx_menu.refresh or function() end
    local rows = Core.SettingsUI.menuItems(refresh, _lc)
    local pfx = ctx_menu and ctx_menu.pfx
    if Config and Config.makeScaleItem and Config.buildModuleMenu then
        local ok, menu = pcall(function()
            local scale_item = Config.makeScaleItem({
                text_func    = function() return _lc("Scale") end,
                enabled_func = function() return not Config.isScaleLinked() end,
                title        = _lc("Scale"),
                info         = _lc("Scale for this module.\n100% is the default size."),
                get          = function() return Config.getModuleScalePct(M.id, pfx) end,
                set          = function(v) Config.setModuleScale(v, M.id, pfx) end,
                refresh      = refresh,
            })
            return Config.buildModuleMenu({
                content = rows,
                appearance = { size = { scale_item } },
            }, ctx_menu)
        end)
        if ok and type(menu) == "table" then return menu end
    end
    return rows
end

return M

end
