local application		= require("hs.application")
local metadata			= require("hs.fcpxhacks.metadata")

--- The function

local PRIORITY = 9999999

local function quitScript()
	application.applicationsForBundleID(hs.processInfo["bundleID"])[1]:kill()
end

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.bottom"] = "bottom"
}

function plugin.init(deps)
	deps.bottom:addItem(PRIORITY, function()
		return { title = i18n("quit") .. " " .. metadata.scriptName,	fn = quitScript }
	end)

	return quitScript
end

return plugin