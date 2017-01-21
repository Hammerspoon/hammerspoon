--- The bottom menu section.

local PRIORITY = 9999999

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.manager"] = "manager"
}

function plugin.init(dependencies)
	local bottom = dependencies.manager.addSection(PRIORITY)
	
	-- Add separator
	bottom:addItem(0, function()
		return { title = "-" }
	end)
	
	return bottom
end

return plugin