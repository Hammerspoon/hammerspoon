local fcp			= require("hs.finalcutpro")

local mod = {}

--------------------------------------------------------------------------------
-- TOGGLE BACKGROUND RENDER:
--------------------------------------------------------------------------------
function mod.toggleBackgroundRender(optionalValue)

	--------------------------------------------------------------------------------
	-- Make sure it's active:
	--------------------------------------------------------------------------------
	fcp:launch()

	--------------------------------------------------------------------------------
	-- If we're setting rather than toggling...
	--------------------------------------------------------------------------------
	if optionalValue ~= nil and optionalValue == fcp:getPreference("FFAutoStartBGRender", true) then
		return
	end

	--------------------------------------------------------------------------------
	-- Define FCPX:
	--------------------------------------------------------------------------------
	local prefs = fcp:preferencesWindow()

	--------------------------------------------------------------------------------
	-- Toggle the checkbox:
	--------------------------------------------------------------------------------
	if not prefs:playbackPanel():toggleAutoStartBGRender() then
		dialog.displayErrorMessage("Failed to toggle 'Enable Background Render'.\n\nError occurred in toggleBackgroundRender().")
		return "Failed"
	end

	--------------------------------------------------------------------------------
	-- Close the Preferences window:
	--------------------------------------------------------------------------------
	prefs:hide()

end

function mod.getAutoRenderDelay()
	return tonumber(fcp:getPreference("FFAutoRenderDelay", "0.3"))
end

--- The module

local PRIORITY = 2000

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.shortcuts"] = "shortcuts"	
}

function plugin.init(deps)
	deps.shortcuts:addItems(PRIORITY, function()
		local fcpxRunning = fcp:isRunning()
		
		return {
			{ title = i18n("enableBackgroundRender", {count = mod.getAutoRenderDelay()}),		fn = mod.toggleBackgroundRender, 					checked = fcp:getPreference("FFAutoStartBGRender", true),						disabled = not fcpxRunning },
		}
	end)
	
	return mod
end

return plugin