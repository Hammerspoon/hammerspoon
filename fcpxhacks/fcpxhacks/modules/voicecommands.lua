--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--       F C P X   H A C K S   V O I C E   C O M M A N D S   P L U G I N      --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Module created by Chris Hocking (https://latenitefilms.com).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- THE MODULE:
--------------------------------------------------------------------------------

local module = {}

--------------------------------------------------------------------------------
-- EXTENSIONS:
--------------------------------------------------------------------------------

local eventtap								= require("hs.eventtap")
local speech   								= require("hs.speech")
local settings								= require("hs.settings")
local listener								= speech.listener

local fcp									= require("hs.finalcutpro")

local dialog								= require("hs.fcpxhacks.modules.dialog")

--------------------------------------------------------------------------------
-- LISTENER COMMANDS:
--------------------------------------------------------------------------------

local function openFinalCutPro()
	fcp:launch()
end

local function openCommandEditor()
	if fcp:isRunning() then
		fcp:launch()
		fcp:commandEditor():show()
	end
end

local listenerCommands = {
						 	[i18n("keyboardShortcuts")] 				= function() openCommandEditor() end,
						 	[i18n("scrollingTimeline")] 				= function() toggleScrollingTimeline() end,
						 	[i18n("highlight")]							= function() highlightFCPXBrowserPlayhead() end,
						 	[i18n("reveal")]							= function() matchFrameThenHighlightFCPXBrowserPlayhead() end,
						 	[i18n("lane") .. " " .. i18n("one")]		= function() selectClipAtLane(1) end,
						 	[i18n("lane") .. " " .. i18n("two")]		= function() selectClipAtLane(2) end,
						 	[i18n("lane") .. " " .. i18n("three")]		= function() selectClipAtLane(3) end,
						 	[i18n("lane") .. " " .. i18n("four")]		= function() selectClipAtLane(4) end,
						 	[i18n("lane") .. " " .. i18n("five")]		= function() selectClipAtLane(5) end,
						 	[i18n("lane") .. " " .. i18n("six")]		= function() selectClipAtLane(6) end,
						 	[i18n("lane") .. " " .. i18n("seven")]		= function() selectClipAtLane(7) end,
						 	[i18n("lane") .. " " .. i18n("eight")]		= function() selectClipAtLane(8) end,
						 	[i18n("lane") .. " " .. i18n("nine")]		= function() selectClipAtLane(9) end,
						 	[i18n("lane") .. " " .. i18n("ten")]		= function() selectClipAtLane(10) end,
						 	[i18n("play")]								= function() eventtap.keyStroke({}, "space") end,
						 }

--------------------------------------------------------------------------------
-- LISTENER CALLBACK:
--------------------------------------------------------------------------------
local listenerCallback = function(listenerObj, text)

	local voiceCommandEnableVisualAlerts = settings.get("fcpxHacks.voiceCommandEnableVisualAlerts")
	local voiceCommandEnableAnnouncements = settings.get("fcpxHacks.voiceCommandEnableAnnouncements")

	if voiceCommandEnableAnnouncements then
		module.talker:speak(text)
	end

	if voiceCommandEnableVisualAlerts then
		dialog.displayNotification(text)
	end

	listenerCommands[text]()

end

--------------------------------------------------------------------------------
-- NEW:
--------------------------------------------------------------------------------
module.new = function()

	if module.listener == nil then
		module.listener = listener.new("FCPX Hacks")
		if module.listener ~= nil then
			local commands = {}
			for i,v in pairs(listenerCommands) do
				commands[#commands + 1] = i
			end
			module.listener:foregroundOnly(false)
						   :blocksOtherRecognizers(true)
						   :commands(commands)
						   :setCallback(listenerCallback)
		else
			-- Something went wrong:
			return false
		end

		module.talker = speech.new()
	end
	return true

end

--------------------------------------------------------------------------------
-- START:
--------------------------------------------------------------------------------
module.start = function()

	if module.listener == nil then
		local result = module.new()
		if result == false then
			return false
		end
	end
	if module.listener ~= nil then
		module.listener:start()
		return true
	end

end

--------------------------------------------------------------------------------
-- STOP:
--------------------------------------------------------------------------------
module.stop = function()

	if module.listener ~= nil then
		module.listener:delete()
		module.listener = nil
		module.talker = nil
	end

end


--------------------------------------------------------------------------------
-- IS LISTENING:
--------------------------------------------------------------------------------
module.isListening = function()

	if module.listener ~= nil then
		return module.listener:isListening()
	else
		return nil
	end

end

--------------------------------------------------------------------------------
-- END OF MODULE:
--------------------------------------------------------------------------------
return module