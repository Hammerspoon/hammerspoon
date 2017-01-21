--- The AUTOMATION > 'Options' menu section

local PRIORITY = 8888888

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.automation"] = "automation"
}

function plugin.init(dependencies)
	return dependencies.automation:addMenu(PRIORITY, function() return i18n("options") end)
end

return plugin