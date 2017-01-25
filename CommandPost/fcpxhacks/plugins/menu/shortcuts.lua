local settings					= require("hs.settings")

--- The SHORTCUTS menu section.

local PRIORITY = 1000

local SETTING = "fcpxHacks.menubarShortcutsEnabled"

local function isSectionDisabled()
	local setting = settings.get(SETTING)
	if setting ~= nil then
		return not setting
	else
		return false
	end
end

local function toggleSectionDisabled()
	local menubarEnabled = settings.get(SETTING)
	settings.set(SETTING, not menubarEnabled)
end

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.manager"] 				= "manager",
	["hs.fcpxhacks.plugins.menu.preferences.menubar"] 	= "menubar",
}

function plugin.init(dependencies)
	-- Create the 'SHORTCUTS' section
	local shortcuts = dependencies.manager.addSection(PRIORITY)
	
	-- Disable the section if the shortcuts option is disabled
	shortcuts:setDisabledFn(isSectionDisabled)
	
	-- Add the separator and title for the section.
	shortcuts:addSeparator(0)
		:addItem(1, function()
			return { title = string.upper(i18n("shortcuts")) .. ":", disabled = true }
		end)
	
	-- Create the menubar preferences item
	dependencies.menubar:addItem(PRIORITY, function() 
		return { title = i18n("showShortcuts"),	fn = toggleSectionDisabled, checked = not isSectionDisabled()}
	end)
	
	return shortcuts
end

return plugin