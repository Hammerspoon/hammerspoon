local fcp			= require("hs.finalcutpro")

--- The function

local PRIORITY = 0

local function openFcpx()
	fcp:launch()
end

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.top"] = "top"	
}

function plugin.init(deps)
	local top = deps.top
	
	top:addItem(PRIORITY, function()
		return { title = i18n("open") .. " Final Cut Pro",	fn = openFcpx }
	end)
	
	return openFcpx
end

return plugin