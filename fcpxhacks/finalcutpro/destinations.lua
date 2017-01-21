--- Utility class to process custom User Destinations

local fs								= require("hs.fs")
local plist								= require("hs.plist")
local archiver							= require("hs.plist.archiver")

local mod = {}

mod.USER_DESTINATIONS_PATH = "~/Library/Preferences/com.apple.FinalCut.UserDestinations.plist"
mod.DESTINATIONS_KEY = "FFShareDestinationsKey"

--- hs.finalcutpro.destinations.getUserDestinationsAsTable() -> table
--- Function:
--- Loads the 'UserDestinations' plist and returns a basic table containing the structure.
---
--- Params:
--- * N/A
--- Returns:
--- The plist as a table.
function mod.getUserDestinationsAsTable()
	local destinations = plist.fileToTable(mod.USER_DESTINATIONS_PATH)
	if destinations then
		local binary = destinations[mod.DESTINATIONS_KEY]
		if binary then
			local result = plist.base64ToTable(binary)
			return archiver.unarchive(result)
		end
	end
	return nil
end

return mod