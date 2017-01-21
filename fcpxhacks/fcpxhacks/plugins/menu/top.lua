--- The top menu section.

local PRIORITY = 0

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.manager"] = "manager"
}

function plugin.init(dependencies)
	return dependencies.manager.addSection(PRIORITY)
end

return plugin