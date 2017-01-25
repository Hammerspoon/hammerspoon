local fcp			= require("hs.finalcutpro")
local settings		= require("hs.settings")
local dialog		= require("hs.fcpxhacks.modules.dialog")

local PRIORITY = 1000

local mod = {}

function mod.isEditable()
	return settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro") or false
end

function mod.setEditable(enabled)
	settings.set("fcpxHacks.enableHacksShortcutsInFinalCutPro", enabled)
end

function mod.toggleEditable()
	mod.setEditable(not mod.isEditable())
end

function mod.editCommands()
	fcp:launch()
	fcp:commandEditor():show()
end

--------------------------------------------------------------------------------
-- DISPLAY A LIST OF ALL SHORTCUTS:
--------------------------------------------------------------------------------
function mod.displayShortcutList()
	dialog.displayMessage(i18n("defaultShortcutsDescription"))
end

local function createMenuItem()
	--------------------------------------------------------------------------------
	-- Get Enable Hacks Shortcuts in Final Cut Pro from Settings:
	--------------------------------------------------------------------------------
	local hacksInFcpx = mod.isEditable()
	
	if hacksInFcpx then
		return { title = i18n("openCommandEditor"), fn = mod.editCommands, disabled = not fcp:isRunning() }
	else
		return { title = i18n("displayKeyboardShortcuts"), fn = mod.displayShortcutList }
	end
end

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.top"] = "top"
}

function plugin.init(deps)
	-- Add the menu item to the top section.
	deps.top:addItem(PRIORITY, createMenuItem)
	
	return mod
end

return plugin