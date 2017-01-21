local application		= require("hs.application")

--- The function

local PRIORITY = 9999999

local function quitFCPXHacks()
	application("Hammerspoon"):kill()
end

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.bottom"] = "bottom"	
}

function plugin.init(deps)
	deps.bottom:addItem(PRIORITY, function()
		return { title = i18n("quit") .. " FCPX Hacks",	fn = quitFCPXHacks }
	end)
	
	return quitFCPXHacks
end

return plugin