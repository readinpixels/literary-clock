--[[
Literary Clock as a Bookshelf micro-module.

Bookshelf loads this file by itself from any plugin that has a
bookshelf_modules/ folder (a "module pack"); see Bookshelf's
micromodules/README.md. The file is called with its own folder as `...`.

self_sized: the quote has to fill the cell at the largest font that fits,
and which quote is shown for a minute depends on the room it has, so the
module does its own sizing instead of the host's fit search.
]]

local MODULE_DIR = ...
local PLUGIN_DIR = (MODULE_DIR or ""):gsub("/+$", ""):gsub("/bookshelf_modules$", "")

local _ = require("gettext")

local Core -- loaded on first use
local function core()
    Core = Core or dofile(PLUGIN_DIR .. "/core/init.lua")(PLUGIN_DIR)
    return Core
end

local function showSettings(ctx)
    local ok_kit, Kit = pcall(require, "lib/bookshelf_module_kit")
    core().SettingsUI.showDialog{
        on_change = function()
            if ctx and ctx.refresh then pcall(ctx.refresh) end
            if ctx and ctx.menu and ctx.menu._reload then pcall(ctx.menu._reload, ctx.menu) end
        end,
        -- Bookshelf's close button on the dialog title, when it has one.
        decorate = ok_kit and Kit.withClose or nil,
    }
end

return {
    key     = "literary_clock", -- stable id stored in user menus; never change it
    title   = _("Literary Clock"),
    summary = _("The time in a quote from a book. Works offline."),
    category = "time",
    min_w   = 2,
    wants_minute_tick = true,
    self_sized = true,
    render = function(ctx)
        local Kit = require("lib/bookshelf_module_kit")
        local scale = (ctx.scale or 100) / 100
        local card = ctx.card
        local fg    = (card and card.ink) or Kit.COLOR_PRIMARY
        local muted = (card and card.muted) or Kit.COLOR_MUTED
        local width = math.max(50, ctx.width or 0)
        local o = {
            width = width,
            fg = fg, muted = muted, accent = fg,
            min_size = 8, legible = 13,
        }
        if ctx.height and ctx.height > 0 then
            -- A grid cell: fill it.
            o.height = ctx.height
            o.max_size = 64
        else
            -- Start menu or picker: natural height at the menu's text size,
            -- under the ceiling when there is one.
            o.size = math.max(9, math.floor(16 * scale + 0.5))
            o.max_size = o.size
            o.max_height = ctx.max_height
        end
        local widget = core().Clock.build(o)
        return widget
    end,
    show_settings = showSettings,
}
