-- Imports

local fcp 			= require("hs.finalcutpro")
local dialog		= require("hs.fcpxhacks.modules.dialog")
local tools			= require("hs.fcpxhacks.modules.tools")
local settings		= require("hs.settings")
local just			= require("hs.just")

-- Constants

local PRIORITY = 2000

-- The Module

local mod = {}

--------------------------------------------------------------------------------
-- Trigger Export:
--------------------------------------------------------------------------------
local function selectShare(destinationPreset)
	return fcp:menuBar():selectMenu("File", "Share", function(menuItem)
		if destinationPreset == nil then
			return menuItem:attributeValue("AXMenuItemCmdChar") ~= nil
		else
			local title = menuItem:attributeValue("AXTitle")
			return title and string.find(title, destinationPreset) ~= nil
		end
	end)

end

--------------------------------------------------------------------------------
-- BATCH EXPORT CLIPS:
--------------------------------------------------------------------------------
local function batchExportClips(libraries, clips, exportPath, destinationPreset, replaceExisting)

	local errorFunction = " Error occurred in batchExportClips()."
	local firstTime = true
	for i,clip in ipairs(clips) do

		--------------------------------------------------------------------------------
		-- Select Item:
		--------------------------------------------------------------------------------
		libraries:selectClip(clip)

		--------------------------------------------------------------------------------
		-- Trigger Export:
		--------------------------------------------------------------------------------
		if not selectShare(destinationPreset) then
			dialog.displayErrorMessage("Could not trigger Share Menu Item." .. errorFunction)
			return false
		end

		--------------------------------------------------------------------------------
		-- Wait for Export Dialog to open:
		--------------------------------------------------------------------------------
		local exportDialog = fcp:exportDialog()
		if not just.doUntil(function() return exportDialog:isShowing() end) then
			dialog.displayErrorMessage("Failed to open the 'Export' window." .. errorFunction)
			return false
		end
		exportDialog:pressNext()

		--------------------------------------------------------------------------------
		-- If 'Next' has been clicked (as opposed to 'Share'):
		--------------------------------------------------------------------------------
		local saveSheet = exportDialog:saveSheet()
		if exportDialog:isShowing() then

			--------------------------------------------------------------------------------
			-- Click 'Save' on the save sheet:
			--------------------------------------------------------------------------------
			if not just.doUntil(function() return saveSheet:isShowing() end) then
				dialog.displayErrorMessage("Failed to open the 'Save' window." .. errorFunction)
				return false
			end

			--------------------------------------------------------------------------------
			-- Set Custom Export Path (or Default to Desktop):
			--------------------------------------------------------------------------------
			if firstTime then
				saveSheet:setPath(exportPath)
				firstTime = false
			end
			saveSheet:pressSave()

		end

		--------------------------------------------------------------------------------
		-- Make sure Save Window is closed:
		--------------------------------------------------------------------------------
		while saveSheet:isShowing() do
			local replaceAlert = saveSheet:replaceAlert()
			if replaceExisting and replaceAlert:isShowing() then
				replaceAlert:pressReplace()
			else
				replaceAlert:pressCancel()

				local originalFilename = saveSheet:filename():getValue()
				if originalFilename == nil then
					dialog.displayErrorMessage("Failed to get the original Filename." .. errorFunction)
					return false
				end

				local newFilename = tools.incrementFilename(originalFilename)

				saveSheet:filename():setValue(newFilename)
				saveSheet:pressSave()
			end
		end

	end
	return true
end

--------------------------------------------------------------------------------
-- CHANGE BATCH EXPORT DESTINATION PRESET:
--------------------------------------------------------------------------------
function mod.changeExportDestinationPreset()
	local shareMenuItems = fcp:menuBar():findMenuItemsUI("File", "Share")
	if not shareMenuItems then
		dialog.displayErrorMessage(i18n("batchExportDestinationsNotFound"))
		return
	end

	local destinations = {}

	for i = 1, #shareMenuItems-2 do
		local item = shareMenuItems[i]
		local title = item:attributeValue("AXTitle")
		if title ~= nil then
			local value = string.sub(title, 1, -4)
			if item:attributeValue("AXMenuItemCmdChar") then -- it's the default
				-- Remove (default) text:
				local firstBracket = string.find(value, " %(", 1)
				if firstBracket == nil then
					firstBracket = string.find(value, "（", 1)
				end
				value = string.sub(value, 1, firstBracket - 1)
			end
			destinations[#destinations + 1] = value
		end
	end

	local batchExportDestinationPreset = settings.get("fcpxHacks.batchExportDestinationPreset")
	local defaultItems = {}
	if batchExportDestinationPreset ~= nil then defaultItems[1] = batchExportDestinationPreset end

	local result = dialog.displayChooseFromList(i18n("selectDestinationPreset"), destinations, defaultItems)
	if result and #result > 0 then
		settings.set("fcpxHacks.batchExportDestinationPreset", result[1])
	end
end

--------------------------------------------------------------------------------
-- CHANGE BATCH EXPORT DESTINATION FOLDER:
--------------------------------------------------------------------------------
function mod.changeExportDestinationFolder()
	local result = dialog.displayChooseFolder(i18n("selectDestinationFolder"))
	if result == false then return end

	settings.set("fcpxHacks.batchExportDestinationFolder", result)
end

--------------------------------------------------------------------------------
-- BATCH EXPORT FROM BROWSER:
--------------------------------------------------------------------------------
function mod.batchExport()

	--------------------------------------------------------------------------------
	-- Set Custom Export Path (or Default to Desktop):
	--------------------------------------------------------------------------------
	local batchExportDestinationFolder = settings.get("fcpxHacks.batchExportDestinationFolder")
	local NSNavLastRootDirectory = fcp:getPreference("NSNavLastRootDirectory")
	local exportPath = "~/Desktop"
	if batchExportDestinationFolder ~= nil then
		 if tools.doesDirectoryExist(batchExportDestinationFolder) then
			exportPath = batchExportDestinationFolder
		 end
	else
		if tools.doesDirectoryExist(NSNavLastRootDirectory) then
			exportPath = NSNavLastRootDirectory
		end
	end

	--------------------------------------------------------------------------------
	-- Destination Preset:
	--------------------------------------------------------------------------------
	local destinationPreset = settings.get("fcpxHacks.batchExportDestinationPreset")
	if destinationPreset == nil then

		destinationPreset = fcp:menuBar():findMenuUI("File", "Share", function(menuItem)
			return menuItem:attributeValue("AXMenuItemCmdChar") ~= nil
		end):attributeValue("AXTitle")

		if destinationPreset == nil then
			displayErrorMessage(i18n("batchExportNoDestination"))
			return false
		else
			-- Remove (default) text:
			local firstBracket = string.find(destinationPreset, " %(", 1)
			if firstBracket == nil then
				firstBracket = string.find(destinationPreset, "（", 1)
			end
			destinationPreset = string.sub(destinationPreset, 1, firstBracket - 1)
		end

	end

	--------------------------------------------------------------------------------
	-- Replace Existing Files Option:
	--------------------------------------------------------------------------------
	local replaceExisting = settings.get("fcpxHacks.batchExportReplaceExistingFiles")

	--------------------------------------------------------------------------------
	-- Delete All Highlights:
	--------------------------------------------------------------------------------
	deleteAllHighlights()

	local libraries = fcp:browser():libraries()

	if not libraries:isShowing() then
		dialog.displayErrorMessage(i18n("batchExportEnableBrowser"))
		return "Failed"
	end

	--------------------------------------------------------------------------------
	-- Check if we have any currently-selected clips:
	--------------------------------------------------------------------------------
	local clips = libraries:selectedClipsUI()

	if libraries:sidebar():isFocused() then
		--------------------------------------------------------------------------------
		-- Use All Clips:
		--------------------------------------------------------------------------------
		clips = libraries:clipsUI()
	end

	local batchExportSucceeded = false
	if clips and #clips > 0 then

		--------------------------------------------------------------------------------
		-- Display Dialog:
		--------------------------------------------------------------------------------
		local countText = " "
		if #clips > 1 then countText = " " .. tostring(#clips) .. " " end
		local replaceFilesMessage = ""
		if replaceExisting then
			replaceFilesMessage = i18n("batchExportReplaceYes")
		else
			replaceFilesMessage = i18n("batchExportReplaceNo")
		end
		local result = dialog.displayMessage(i18n("batchExportCheckPath", {count=countText, replace=replaceFilesMessage, path=exportPath, preset=destinationPreset, item=i18n("item", {count=#clips})}), {i18n("buttonContinueBatchExport"), i18n("cancel")})
		if result == nil then return end

		--------------------------------------------------------------------------------
		-- Export the clips:
		--------------------------------------------------------------------------------
		batchExportSucceeded = batchExportClips(libraries, clips, exportPath, destinationPreset, replaceExisting)

	else
		--------------------------------------------------------------------------------
		-- No Clips are Available:
		--------------------------------------------------------------------------------
		dialog.displayErrorMessage(i18n("batchExportNoClipsSelected"))
	end

	--------------------------------------------------------------------------------
	-- Batch Export Complete:
	--------------------------------------------------------------------------------
	if batchExportSucceeded then
		dialog.displayMessage(i18n("batchExportComplete"), {i18n("done")})
	end

end

--------------------------------------------------------------------------------
-- TOGGLE BATCH EXPORT REPLACE EXISTING FILES:
--------------------------------------------------------------------------------
function mod.toggleReplaceExistingFiles()
	local batchExportReplaceExistingFiles = settings.get("fcpxHacks.batchExportReplaceExistingFiles")
	settings.set("fcpxHacks.batchExportReplaceExistingFiles", not batchExportReplaceExistingFiles)
end

-- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.manager"]		= "manager",
	["hs.fcpxhacks.plugins.menu.preferences"]	= "prefs",
}

function plugin.init(deps)
	local fcpxRunning = fcp:isRunning()

	-- Add a secton to the 'Preferences' menu
	local section = deps.prefs:addSection(PRIORITY)
	mod.manager = deps.manager

	section:addSeparator(0)

	local menu = section:addMenu(1000, function() return i18n("batchExportOptions") end)

	menu:addItems(1, function()
		return {
			{ title = i18n("setDestinationPreset"),	fn = mod.changeExportDestinationPreset,	disabled = not fcpxRunning },
			{ title = i18n("setDestinationFolder"),	fn = mod.changeExportDestinationFolder },
			{ title = "-" },
			{ title = i18n("replaceExistingFiles"),	fn = mod.toggleReplaceExistingFiles, checked = settings.get("fcpxHacks.batchExportReplaceExistingFiles") },
		}
	end)

	section:addSeparator(9000)

	-- Return the module
	return mod
end

return plugin