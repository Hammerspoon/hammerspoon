--- The 'Preferences > Menubar Options' menu section

local PRIORITY = 3000

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.preferences"] = "prefs"
}

function plugin.init(dependencies)
	local section = dependencies.prefs:addSection(PRIORITY)
	
	return section
		:addMenu(1000, function() return i18n("menubarOptions") end)
end

return plugin