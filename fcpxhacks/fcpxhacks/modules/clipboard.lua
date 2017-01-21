--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--           P A S T E B O A R D     S U P P O R T     L I B R A R Y          --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---
--- Authors:
---
---  > David Peterson (https://randomphotons.com/)
---  > Chris Hocking (https://latenitefilms.com)
---
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- THE MODULE:
--------------------------------------------------------------------------------

local clipboard = {}

--------------------------------------------------------------------------------
-- EXTENSIONS:
--------------------------------------------------------------------------------
local base64									= require("hs.base64")
local fs										= require("hs.fs")
local host										= require("hs.host")
local inspect									= require("hs.inspect")
local pasteboard 								= require("hs.pasteboard")
local plist 									= require("hs.plist")
local settings									= require("hs.settings")
local timer										= require("hs.timer")

local plist										= require("hs.plist")
local archiver									= require("hs.plist.archiver")
local protect 									= require("hs.fcpxhacks.modules.protect")
local tools										= require("hs.fcpxhacks.modules.tools")

local log										= require("hs.logger").new("clipboard")

--------------------------------------------------------------------------------
-- LOCAL VARIABLES:
--------------------------------------------------------------------------------

clipboard.customName							= nil									-- Clipboard Custom Name
clipboard.customFolder							= nil									-- Clipboard Custom Folder
clipboard.timer									= nil									-- Clipboard Watcher Timer
clipboard.watcherFrequency 						= 0.5									-- Clipboard Watcher Update Frequency
clipboard.lastChange 							= pasteboard.changeCount()				-- Displays how many times the pasteboard owner has changed (indicates a new copy has been made)
clipboard.currentChange 						= pasteboard.changeCount()				-- Current Change Count
clipboard.history								= {}									-- Clipboard History
clipboard.historyMaximumSize 					= 5										-- Maximum Size of Clipboard History
clipboard.hostname								= host.localizedName()					-- Hostname
clipboard.excludedClassnames					= {"FFAnchoredTimeMarker"}				-- Data we don't want to count when copying.

local CLIPBOARD = protect({
	--------------------------------------------------------------------------------
	-- Standard types:
	--------------------------------------------------------------------------------
	ARRAY 										= "NSMutableArray",
	SET 										= "NSMutableSet",
	OBJECTS 									= "NS.objects",

	--------------------------------------------------------------------------------
	-- Dictionary:
	--------------------------------------------------------------------------------
	DICTIONARY									= "NSDictionary",
	KEYS										= "NS.keys",
	VALUES										= "NS.objects",

	--------------------------------------------------------------------------------
	-- FCPX Types:
	--------------------------------------------------------------------------------
	ANCHORED_ANGLE 								= "FFAnchoredAngle",
	ANCHORED_COLLECTION 						= "FFAnchoredCollection",
	ANCHORED_SEQUENCE 							= "FFAnchoredSequence",
	ANCHORED_CLIP								= "FFAnchoredClip",
	ANCHORED_MEDIA_COMPONENT					= "FFAnchoredMediaComponent",
	GAP 										= "FFAnchoredGapGeneratorComponent",
	GENERATOR									= "FFAnchoredGeneratorComponent",
	TIMERANGE_AND_OBJECT 						= "FigTimeRangeAndObject",

	--------------------------------------------------------------------------------
	-- The default name used when copying from the Timeline:
	--------------------------------------------------------------------------------
	TIMELINE_DISPLAY_NAME 						= "__timelineContainerClip",

	--------------------------------------------------------------------------------
	-- The pasteboard/clipboard property containing the copied clips:
	--------------------------------------------------------------------------------
	PASTEBOARD_OBJECT 							= "ffpasteboardobject",
	UTI 										= "com.apple.flexo.proFFPasteboardUTI"
})

function clipboard.isTimelineClip(data)
	return data.displayName == CLIPBOARD.TIMELINE_DISPLAY_NAME
end

--------------------------------------------------------------------------------
-- PROCESS OBJECT:
--------------------------------------------------------------------------------
-- Processes the provided data object, which should have a '$class' property.
-- Returns: string (primary clip name), integer (number of clips)
--------------------------------------------------------------------------------
function clipboard.processObject(data)
	if type(data) == "table" then
		local class = data['$class']
		if class then
			return clipboard.processContent(data)
		elseif data[1] then
			-- it's an array
			return clipboard.processArray(data)
		end
	end
	return nil, 0
end

function clipboard.isClassnameSupported(classname)
	for i,name in ipairs(clipboard.excludedClassnames) do
		if name == classname then
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- PROCESS ARRAY COLLECTION:
--------------------------------------------------------------------------------
-- Processes an 'array' table
-- Params:
--		* data: 	The data object to process
-- Returns: string (primary clip name), integer (number of clips)
--------------------------------------------------------------------------------
function clipboard.processArray(data)
	local name = nil
	local count = 0
	for i,v in ipairs(data) do
		local n,c = clipboard.processObject(v, objects)
		if name == nil then
			name = n
		end
		count = count + c
	end
	return name, count
end

function clipboard.supportsContainedItems(data)
	local classname = clipboard.getClassname(data)
	return data.containedItems and classname ~= CLIPBOARD.ANCHORED_COLLECTION
end

function clipboard.getClassname(data)
	return data["$class"]["$classname"]
end

--------------------------------------------------------------------------------
-- PROCESS SIMPLE CONTENT:
--------------------------------------------------------------------------------
-- Process objects which have a displayName, such as Compound Clips, Images, etc.
-- Returns: string (primary clip name), integer (number of clips)
--------------------------------------------------------------------------------
function clipboard.processContent(data)
	if not clipboard.isClassnameSupported(classname) then
		return nil, 0
	end

	if clipboard.isTimelineClip(data) then
		-- Just process the contained items directly
		return clipboard.processObject(data.containedItems)
	end

	local displayName = data.displayName
	local count = displayName and 1 or 0

	if clipboard.getClassname(data) == CLIPBOARD.GAP then
		displayName = nil
		count = 0
	end

	if clipboard.supportsContainedItems(data) then
		n, c = clipboard.processObject(data.containedItems)
		count = count + c
		displayName = displayName or n
	end

	if data.anchoredItems then
		n, c = clipboard.processObject(data.anchoredItems)
		count = count + c
		displayName = displayName or n
	end

	if displayName then
		return displayName, count
	else
		return nil, 0
	end
end

--------------------------------------------------------------------------------
-- PROCESS TIME RANGE AND OBJECT:
--------------------------------------------------------------------------------
-- Process 'FigTimeRangeAndObject' objects, typically content copied from the Browser
-- Returns: string (primary clip name), integer (number of clips)
--------------------------------------------------------------------------------
function clipboard.processTimeRangeAndObject(data)
	log.d("processTimeRangeAndObject")
	return clipboard.processObject(data.object)
end

--------------------------------------------------------------------------------
-- FIND CLIP NAME:
--------------------------------------------------------------------------------
-- Searches the Pasteboard binary plist data for the first clip name, and returns it.
-- Returns the 'default' value if the pasteboard contains a media clip but we could not interpret it.
-- Returns `nil` if the data did not contain FCPX Clip data.
-- Example use:
--	 local name = clipboard.findClipName(myFcpxData, "Unknown")
--------------------------------------------------------------------------------
function clipboard.findClipName(fcpxData, default)
	local data = clipboard.unarchiveFCPXData(fcpxData)

	if data then
		local name, count = clipboard.processObject(data.root.objects)

		if name then
			if count > 1 then
				return name.." (+"..(count-1)..")"
			else
				return name
			end
		else
			return default
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Reads FCPX Data from the Pasteboard as a binary Plist, if present.
-- If not, nil is returned.
--------------------------------------------------------------------------------
function clipboard.readFCPXData()
 	local clipboardContent = pasteboard.allContentTypes()
 	if clipboardContent ~= nil then
 		if clipboardContent[1] ~= nil then
			if clipboardContent[1][1] == CLIPBOARD.UTI then
				return pasteboard.readDataForUTI(CLIPBOARD.UTI)
			end
		end
	end
	return nil
end

function clipboard.unarchiveFCPXData(fcpxData)
	if not fcpxData then
		fcpxData = clipboard.readFCPXData()
	end

	local clipboardTable = plist.binaryToTable(fcpxData)
	if clipboardTable then
		local base64Data = clipboardTable[CLIPBOARD.PASTEBOARD_OBJECT]
		if base64Data then
			local fcpxTable = plist.base64ToTable(base64Data)
			if fcpxTable then
				return archiver.unarchive(fcpxTable)
			end
		end
	end
	log.e("The clipboard does not contain any FCPX clip data.")
	return nil
end

function clipboard.writeFCPXData(fcpxData)
	return pasteboard.writeDataForUTI(CLIPBOARD.UTI, fcpxData)
end

--------------------------------------------------------------------------------
-- SET CUSTOM NAME:
--------------------------------------------------------------------------------
function clipboard.setName(value)
	clipboard.customName = value
end

--------------------------------------------------------------------------------
-- SET CUSTOM FOLDER:
--------------------------------------------------------------------------------
function clipboard.setFolder(value)
	clipboard.customFolder = value
end

--------------------------------------------------------------------------------
-- WATCH THE FINAL CUT PRO CLIPBOARD FOR CHANGES:
--------------------------------------------------------------------------------
function clipboard.startWatching()

	--------------------------------------------------------------------------------
	-- Used for debugging:
	--------------------------------------------------------------------------------
	log.d("Starting Clipboard Watcher.")

	--------------------------------------------------------------------------------
	-- Get Clipboard History from Settings:
	--------------------------------------------------------------------------------
	clipboard.history = settings.get("fcpxHacks.clipboardHistory") or {}

	--------------------------------------------------------------------------------
	-- Reset:
	--------------------------------------------------------------------------------
	clipboard.currentChange = pasteboard.changeCount()
	clipboard.lastChange = pasteboard.changeCount()

	--------------------------------------------------------------------------------
	-- Watch for Clipboard Changes:
	--------------------------------------------------------------------------------
	clipboard.timer = timer.new(clipboard.watcherFrequency, function()

		clipboard.currentChange = pasteboard.changeCount()

		if (clipboard.currentChange > clipboard.lastChange) then

			--------------------------------------------------------------------------------
			-- Save Clipboard Data:
			--------------------------------------------------------------------------------
			local currentClipboardData 		= clipboard.readFCPXData()
			local currentClipboardLabel 	= nil

			if currentClipboardData then
				if clipboard.customName ~= nil then
					currentClipboardLabel = clipboard.customName
					clipboard.customName = nil
				else
					currentClipboardLabel = clipboard.findClipName(currentClipboardData, os.date())
				end
			end

			--------------------------------------------------------------------------------
			-- If all is good then...
			--------------------------------------------------------------------------------
			if currentClipboardLabel ~= nil then

				--------------------------------------------------------------------------------
				-- Used for debugging:
				--------------------------------------------------------------------------------
				log.d("Added '"..currentClipboardLabel.."' to FCPX's Clipboard.")

				--------------------------------------------------------------------------------
				-- Shared Clipboard:
				--------------------------------------------------------------------------------
				local enableSharedClipboard = settings.get("fcpxHacks.enableSharedClipboard")
				if enableSharedClipboard then
					local sharedClipboardPath = settings.get("fcpxHacks.sharedClipboardPath")
					if sharedClipboardPath ~= nil then

						local folderName = clipboard.hostname
						if clipboard.customFolder ~= nil then
							folderName = clipboard.customFolder
							clipboard.customFolder = nil
						end

						local sharedClipboardPlistFile = sharedClipboardPath .. folderName .. ".fcpxhacks"

						--------------------------------------------------------------------------------
						-- Create Plist file if one doesn't already exist:
						--------------------------------------------------------------------------------
						if not tools.doesFileExist(sharedClipboardPlistFile) then

							log.d("Creating new Shared Clipboard Plist File.")

local blankPlist = [[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>SharedClipboardLabel1</key>
<string></string>
<key>SharedClipboardLabel2</key>
<string></string>
<key>SharedClipboardLabel3</key>
<string></string>
<key>SharedClipboardLabel4</key>
<string></string>
<key>SharedClipboardLabel5</key>
<string></string>
<key>SharedClipboardData1</key>
<string></string>
<key>SharedClipboardData2</key>
<string></string>
<key>SharedClipboardData3</key>
<string></string>
<key>SharedClipboardData4</key>
<string></string>
<key>SharedClipboardData5</key>
<string></string>
</dict>
</plist>
]]

							local file = io.open(sharedClipboardPlistFile, "w")
							file:write(blankPlist)
							file:close()

						end

						--------------------------------------------------------------------------------
						-- Reading Plist file:
						--------------------------------------------------------------------------------
						if tools.doesFileExist(sharedClipboardPlistFile) then
							local plistData = plist.xmlFileToTable(sharedClipboardPlistFile)
							if plistData ~= nil then

								encodedCurrentClipboardData = base64.encode(currentClipboardData)

								local newPlistData = {}
								newPlistData["SharedClipboardLabel1"] = currentClipboardLabel
								newPlistData["SharedClipboardData1"] = encodedCurrentClipboardData
								newPlistData["SharedClipboardLabel2"] = plistData["SharedClipboardLabel1"]
								newPlistData["SharedClipboardData2"] = plistData["SharedClipboardData1"]
								newPlistData["SharedClipboardLabel3"] = plistData["SharedClipboardLabel2"]
								newPlistData["SharedClipboardData3"] = plistData["SharedClipboardData2"]
								newPlistData["SharedClipboardLabel4"] = plistData["SharedClipboardLabel3"]
								newPlistData["SharedClipboardData4"] = plistData["SharedClipboardData3"]
								newPlistData["SharedClipboardLabel5"] = plistData["SharedClipboardLabel4"]
								newPlistData["SharedClipboardData5"] = plistData["SharedClipboardData4"]


local newPlist = [[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>SharedClipboardLabel1</key>
<string>]] .. newPlistData["SharedClipboardLabel1"] .. [[</string>
<key>SharedClipboardLabel2</key>
<string>]] .. newPlistData["SharedClipboardLabel2"] .. [[</string>
<key>SharedClipboardLabel3</key>
<string>]] .. newPlistData["SharedClipboardLabel3"] .. [[</string>
<key>SharedClipboardLabel4</key>
<string>]] .. newPlistData["SharedClipboardLabel4"] .. [[</string>
<key>SharedClipboardLabel5</key>
<string>]] .. newPlistData["SharedClipboardLabel5"] .. [[</string>
<key>SharedClipboardData1</key>
<string>]] .. newPlistData["SharedClipboardData1"] .. [[</string>
<key>SharedClipboardData2</key>
<string>]] .. newPlistData["SharedClipboardData2"] .. [[</string>
<key>SharedClipboardData3</key>
<string>]] .. newPlistData["SharedClipboardData3"] .. [[</string>
<key>SharedClipboardData4</key>
<string>]] .. newPlistData["SharedClipboardData4"] .. [[</string>
<key>SharedClipboardData5</key>
<string>]] .. newPlistData["SharedClipboardData5"] .. [[</string>
</dict>
</plist>
]]

								local file = io.open(sharedClipboardPlistFile, "w")
								file:write(newPlist)
								file:close()

							else
								log.e("Failed to read Shared Clipboard Plist File.")
							end

						else
							log.e("Shared Clipboard Plist File doesn't appear to exist.")
						end

					end
				end

				--------------------------------------------------------------------------------
				-- Clipboard History:
				--------------------------------------------------------------------------------
				local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false
				if enableClipboardHistory then
					local currentClipboardItem = {currentClipboardData, currentClipboardLabel}

					while (#(clipboard.history) >= clipboard.historyMaximumSize) do
						table.remove(clipboard.history,1)
					end
					table.insert(clipboard.history, currentClipboardItem)

					--------------------------------------------------------------------------------
					-- Update Settings:
					--------------------------------------------------------------------------------
					settings.set("fcpxHacks.clipboardHistory", clipboard.history)
				end
			end
	 	end
		clipboard.lastChange = clipboard.currentChange
	end)
	clipboard.timer:start()

	debugMessage("Started Clipboard Watcher")
end

--------------------------------------------------------------------------------
-- STOP WATCHING THE CLIPBOARD:
--------------------------------------------------------------------------------
function clipboard.stopWatching()
	if clipboard.timer then
		clipboard.timer:stop()
		clipboard.timer = nil
		debugMessage("Stopped Clipboard Watcher")
	end
end

--------------------------------------------------------------------------------
-- IS THIS MODULE WATCHING THE CLIPBOARD:
-------------------------------------------------------------------------------
function clipboard.isWatching()
	return clipboard.timer or false
end

--------------------------------------------------------------------------------
-- GET CLIPBOARD HISTORY:
--------------------------------------------------------------------------------
function clipboard.getHistory()
	return clipboard.history
end

--------------------------------------------------------------------------------
-- CLEAR CLIPBOARD HISTORY:
--------------------------------------------------------------------------------
function clipboard.clearHistory()
	clipboard.history = {}
	settings.set("fcpxHacks.clipboardHistory", clipboard.history)
	clipboard.currentChange = pasteboard.changeCount()
end

return clipboard
