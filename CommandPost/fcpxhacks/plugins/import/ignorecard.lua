-- Imports

local settings					= require("hs.settings")
local fs						= require("hs.fs")
local fcp						= require("hs.finalcutpro")
local application				= require("hs.application")
local timer						= require("hs.timer")

-- Constants

local PRIORITY = 20000

-- Local Functions

-- The Module
local mod = {}

--------------------------------------------------------------------------------
-- RETURNS THE CURRENT ENABLED STATUS
--------------------------------------------------------------------------------
function mod.isEnabled()
	return settings.get("fcpxHacks.enableMediaImportWatcher") or false
end

--------------------------------------------------------------------------------
-- SETS THE ENABLED STATUS AND UPDATES THE WATCHER APPROPRIATELY
--------------------------------------------------------------------------------
function mod.setEnabled(enabled)
	settings.set("fcpxHacks.enableMediaImportWatcher", enabled)
	mod.update()
end

--------------------------------------------------------------------------------
-- TOGGLE MEDIA IMPORT WATCHER:
--------------------------------------------------------------------------------
function mod.toggleEnabled()
	mod.setEnabled(not mod.isEnabled())
end

--------------------------------------------------------------------------------
-- UPDATES THE WATCHER BASED ON THE ENABLED STATUS
--------------------------------------------------------------------------------
function mod.update()
	local watcher = mod.getDeviceWatcher()
	if mod.isEnabled() then
		watcher:start()
	else
		watcher:stop()
	end
end

--------------------------------------------------------------------------------
-- MEDIA IMPORT WINDOW WATCHER:
--------------------------------------------------------------------------------
function mod.getDeviceWatcher()
	if not mod.newDeviceMounted then
		debugMessage("Watching for new media...")
		mod.newDeviceMounted = fs.volume.new(function(event, table)
			if event == fs.volume.didMount then

				debugMessage("Media Inserted.")

				local mediaImport = fcp:mediaImport()

				if mediaImport:isShowing() then
					-- Media Import was already open. Bail!
					debugMessage("Already in Media Import. Continuing...")
					return
				end

				local mediaImportCount = 0
				local stopMediaImportTimer = false
				local currentApplication = application.frontmostApplication()
				debugMessage("Currently using '"..currentApplication:name().."'")

				local fcpxHidden = not fcp:isShowing()

				mediaImportTimer = timer.doUntil(
					function()
						return stopMediaImportTimer
					end,
					function()
						if not fcp:isRunning() then
							debugMessage("FCPX is not running. Stop watching.")
							stopMediaImportTimer = true
						else
							if mediaImport:isShowing() then
								mediaImport:hide()
								if fcpxHidden then fcp:hide() end
								currentApplication:activate()
								debugMessage("Hid FCPX and returned to '"..currentApplication:name().."'.")
								stopMediaImportTimer = true
							end
							mediaImportCount = mediaImportCount + 1
							if mediaImportCount == 500 then
								debugMessage("Gave up watching for the Media Import window after 5 seconds.")
								stopMediaImportTimer = true
							end
						end
					end,
					0.01
				)

			end
		end)
	end
	return mod.newDeviceMounted
end

-- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.automation.options"] = "options",
}

function plugin.init(deps)
	
	-- Add the menu item
	local section = deps.options:addSection(PRIORITY)
	section:addSeparator(100)
	section:addItem(200, function() 
		return { title = i18n("closeMediaImport"),	fn = mod.toggleEnabled,	checked = mod.isEnabled() }
	end)
	section:addSeparator(900)
	
	-- Update the watcher status based on the settings
	mod.update()
	
	return mod
end

return plugin