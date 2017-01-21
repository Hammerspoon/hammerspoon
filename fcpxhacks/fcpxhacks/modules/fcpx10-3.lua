--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  			  ===========================================
--
--  			             F C P X    H A C K S
--
--			      ===========================================
--
--
--  Thrown together by Chris Hocking @ LateNite Films
--  https://latenitefilms.com
--
--  You can download the latest version here:
--  https://latenitefilms.com/blog/final-cut-pro-hacks/
--
--  Please be aware that I'm a filmmaker, not a programmer, so... apologies!
--
--------------------------------------------------------------------------------
--  LICENSE:
--------------------------------------------------------------------------------
--
-- The MIT License (MIT)
--
-- Copyright (c) 2016 Chris Hocking.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   T H E    M A I N    S C R I P T                          --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- BEGIN MODULE:
--------------------------------------------------------------------------------

local mod = {}

--------------------------------------------------------------------------------
-- STANDARD EXTENSIONS:
--------------------------------------------------------------------------------

local application								= require("hs.application")
local base64									= require("hs.base64")
local chooser									= require("hs.chooser")
local console									= require("hs.console")
local distributednotifications					= require("hs.distributednotifications")
local drawing 									= require("hs.drawing")
local eventtap									= require("hs.eventtap")
local fnutils 									= require("hs.fnutils")
local fs										= require("hs.fs")
local geometry									= require("hs.geometry")
local host										= require("hs.host")
local hotkey									= require("hs.hotkey")
local http										= require("hs.http")
local image										= require("hs.image")
local inspect									= require("hs.inspect")
local keycodes									= require("hs.keycodes")
local logger									= require("hs.logger")
local menubar									= require("hs.menubar")
local messages									= require("hs.messages")
local mouse										= require("hs.mouse")
local notify									= require("hs.notify")
local osascript									= require("hs.osascript")
local pasteboard								= require("hs.pasteboard")
local pathwatcher								= require("hs.pathwatcher")
local screen									= require("hs.screen")
local settings									= require("hs.settings")
local sharing									= require("hs.sharing")
local timer										= require("hs.timer")
local window									= require("hs.window")
local windowfilter								= require("hs.window.filter")

--------------------------------------------------------------------------------
-- EXTERNAL EXTENSIONS:
--------------------------------------------------------------------------------

local ax 										= require("hs._asm.axuielement")
local touchbar 									= require("hs._asm.touchbar")

local fcp										= require("hs.finalcutpro")
local plist										= require("hs.plist")

--------------------------------------------------------------------------------
-- MODULES:
--------------------------------------------------------------------------------

local metadata									= require("hs.fcpxhacks.metadata")
local dialog									= require("hs.fcpxhacks.modules.dialog")
local slaxdom 									= require("hs.fcpxhacks.modules.slaxml.slaxdom")
local slaxml									= require("hs.fcpxhacks.modules.slaxml")
local tools										= require("hs.fcpxhacks.modules.tools")
local just										= require("hs.just")

--------------------------------------------------------------------------------
-- PLUGINS:
--------------------------------------------------------------------------------

local clipboard									= require("hs.fcpxhacks.modules.clipboard")
local hacksconsole								= require("hs.fcpxhacks.modules.hacksconsole")
local hackshud									= require("hs.fcpxhacks.modules.hackshud")
local voicecommands 							= require("hs.fcpxhacks.modules.voicecommands")

local kc										= require("hs.fcpxhacks.modules.shortcuts.keycodes")

--------------------------------------------------------------------------------
-- DEFAULT SETTINGS:
--------------------------------------------------------------------------------

local defaultSettings = {
												["enableHacksShortcutsInFinalCutPro"] 			= false,
												["enableVoiceCommands"]							= false,
												["chooserRememberLast"]							= true,
												["chooserShowShortcuts"] 						= true,
												["chooserShowHacks"] 							= true,
												["chooserShowVideoEffects"] 					= true,
												["chooserShowAudioEffects"] 					= true,
												["chooserShowTransitions"] 						= true,
												["chooserShowTitles"] 							= true,
												["chooserShowGenerators"] 						= true,
												["chooserShowMenuItems"]						= true,
												["menubarToolsEnabled"] 						= true,
												["menubarHacksEnabled"] 						= true,
												["enableCheckForUpdates"]						= true,
												["hudShowInspector"]							= true,
												["hudShowDropTargets"]							= true,
												["hudShowButtons"]								= true,
												["checkForUpdatesInterval"]						= 600,
												["highlightPlayheadTime"]						= 3,
												["notificationPlatform"]						= {},
												["displayHighlightColour"]						= "Red",
}

--------------------------------------------------------------------------------
-- VARIABLES:
--------------------------------------------------------------------------------

local execute									= hs.execute									-- Execute!
local touchBarSupported					 		= touchbar.supported()							-- Touch Bar Supported?
local log										= logger.new("fcpx10-3")

mod.debugMode									= false											-- Debug Mode is off by default.
mod.releaseColorBoardDown						= false											-- Color Board Shortcut Currently Being Pressed
mod.mouseInsideTouchbar							= false											-- Mouse Inside Touch Bar?
mod.shownUpdateNotification		 				= false											-- Shown Update Notification Already?

mod.touchBarWindow 								= nil			 								-- Touch Bar Window

mod.browserHighlight 							= nil											-- Used for Highlight Browser Playhead
mod.browserHighlightTimer 						= nil											-- Used for Highlight Browser Playhead

mod.finalCutProShortcutKey 						= nil											-- Table of all Final Cut Pro Shortcuts
mod.finalCutProShortcutKeyPlaceholders 			= nil											-- Table of all needed Final Cut Pro Shortcuts
mod.newDeviceMounted 							= nil											-- New Device Mounted Volume Watcher
mod.lastCommandSet								= nil											-- Last Keyboard Shortcut Command Set
mod.allowMovingMarkers							= nil											-- Used in generateMenuBar
mod.FFPeriodicBackupInterval 					= nil											-- Used in generateMenuBar
mod.FFSuspendBGOpsDuringPlay 					= nil											-- Used in generateMenuBar
mod.FFEnableGuards								= nil											-- Used in generateMenuBar
mod.FFAutoRenderDelay							= nil											-- Used in generateMenuBar

mod.hacksLoaded 								= false											-- Has FCPX Hacks Loaded Yet?

mod.isFinalCutProActive 						= false											-- Is Final Cut Pro Active? Used by Watchers.
mod.wasFinalCutProOpen							= false											-- Used by Assign Transitions/Effects/Titles/Generators Shortcut


--------------------------------------------------------------------------------
-- Retrieves the plugins manager.
-- If `pluginPath` is provided, the named plugin will be returned. If not, the plugins
-- module is returned.
--------------------------------------------------------------------------------
function plugins(pluginPath)
	if not mod._plugins then
		mod._plugins = require("hs.plugins")
		mod._plugins.init("hs.fcpxhacks.plugins")
	end

	if pluginPath then
		return mod._plugins(pluginPath)
	else
		return mod._plugins
	end
end

--------------------------------------------------------------------------------
-- Retrieves the FCPX Hacks menu manager
--------------------------------------------------------------------------------
function menuManager()
	if not mod._menuManager then
		mod._menuManager = plugins("hs.fcpxhacks.plugins.menu.manager")

		--- TODO: Remove this once all menu manaement is migrated to plugins.
		local manualSection = mod._menuManager.addSection(10000)
		manualSection:addItems(0, function() return generateMenuBar(true) end)

		local preferences = plugins("hs.fcpxhacks.plugins.menu.preferences")
		preferences:addItems(10000, function() return generatePreferencesMenuBar() end)

		local menubarPrefs = plugins("hs.fcpxhacks.plugins.menu.preferences.menubar")
		menubarPrefs:addItems(10000, function() return generateMenubarPrefsMenuBar() end)
	end
	return mod._menuManager
end

--------------------------------------------------------------------------------
-- LOAD SCRIPT:
--------------------------------------------------------------------------------
function loadScript()

	--------------------------------------------------------------------------------
	-- Debug Mode:
	--------------------------------------------------------------------------------
	mod.debugMode = settings.get("fcpxHacks.debugMode") or false
	debugMessage("Debug Mode Activated.")

	--------------------------------------------------------------------------------
	-- Activate Menu Manager
	--------------------------------------------------------------------------------
	menuManager()

	--------------------------------------------------------------------------------
	-- Need Accessibility Activated:
	--------------------------------------------------------------------------------
	hs.accessibilityState(true)

	--------------------------------------------------------------------------------
	-- Limit Error Messages for a clean console:
	--------------------------------------------------------------------------------
	console.titleVisibility("hidden")
	hotkey.setLogLevel("warning")
	windowfilter.setLogLevel(0) -- The wfilter errors are too annoying.
	windowfilter.ignoreAlways['System Events'] = true

	--------------------------------------------------------------------------------
	-- First time running 10.3? If so, let's trash the settings incase there's
	-- compatibility issues with an older version of FCPX Hacks:
	--------------------------------------------------------------------------------
	if settings.get("fcpxHacks.firstTimeRunning103") == nil then

		writeToConsole("First time running Final Cut Pro 10.3. Trashing settings.")

		--------------------------------------------------------------------------------
		-- Trash all FCPX Hacks Settings:
		--------------------------------------------------------------------------------
		for i, v in ipairs(settings.getKeys()) do
			if (v:sub(1,10)) == "fcpxHacks." then
				settings.set(v, nil)
			end
		end

		settings.set("fcpxHacks.firstTimeRunning103", false)

	end

	--------------------------------------------------------------------------------
	-- Check for Final Cut Pro Updates:
	--------------------------------------------------------------------------------
	local lastFinalCutProVersion = settings.get("fcpxHacks.lastFinalCutProVersion")
	if lastFinalCutProVersion == nil then
		settings.set("fcpxHacks.lastFinalCutProVersion", fcp:getVersion())
	else
		if lastFinalCutProVersion ~= fcp:getVersion() then
			for i, v in ipairs(settings.getKeys()) do
				if (v:sub(1,10)) == "fcpxHacks." then
					if v:sub(-16) == "chooserMenuItems" then
						settings.set(v, nil)
					end
				end
			end
			settings.set("fcpxHacks.lastFinalCutProVersion", fcp:getVersion())
		end
	end

	--------------------------------------------------------------------------------
	-- Apply Default Settings:
	--------------------------------------------------------------------------------
	for k, v in pairs(defaultSettings) do
		if settings.get("fcpxHacks." .. k) == nil then
			settings.set("fcpxHacks." .. k, v)
		end
	end

	--------------------------------------------------------------------------------
	-- Check if we need to update the Final Cut Pro Shortcut Files:
	--------------------------------------------------------------------------------
	if settings.get("fcpxHacks.lastVersion") == nil then
		settings.set("fcpxHacks.lastVersion", metadata.scriptVersion)
		settings.set("fcpxHacks.enableHacksShortcutsInFinalCutPro", false)
	else
		if tonumber(settings.get("fcpxHacks.lastVersion")) < tonumber(metadata.scriptVersion) then
			if settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro") then
				local finalCutProRunning = fcp:isRunning()
				if finalCutProRunning then
					dialog.displayMessage(i18n("newKeyboardShortcuts"))
					updateKeyboardShortcuts()
					if not fcp:restart() then
						--------------------------------------------------------------------------------
						-- Failed to restart Final Cut Pro:
						--------------------------------------------------------------------------------
						dialog.displayErrorMessage(i18n("restartFinalCutProFailed"))
						return "Failed"
					end
				else
					dialog.displayMessage(i18n("newKeyboardShortcuts"))
					updateKeyboardShortcuts()
				end
			end
		end
		settings.set("fcpxHacks.lastVersion", metadata.scriptVersion)
	end

	--------------------------------------------------------------------------------
	-- Setup Touch Bar:
	--------------------------------------------------------------------------------
	if touchBarSupported then

		--------------------------------------------------------------------------------
		-- New Touch Bar:
		--------------------------------------------------------------------------------
		mod.touchBarWindow = touchbar.new()

		--------------------------------------------------------------------------------
		-- Touch Bar Watcher:
		--------------------------------------------------------------------------------
		mod.touchBarWindow:setCallback(touchbarWatcher)

		--------------------------------------------------------------------------------
		-- Get last Touch Bar Location from Settings:
		--------------------------------------------------------------------------------
		local lastTouchBarLocation = settings.get("fcpxHacks.lastTouchBarLocation")
		if lastTouchBarLocation ~= nil then	mod.touchBarWindow:topLeft(lastTouchBarLocation) end

		--------------------------------------------------------------------------------
		-- Draggable Touch Bar:
		--------------------------------------------------------------------------------
		local events = eventtap.event.types
		touchbarKeyboardWatcher = eventtap.new({events.flagsChanged, events.keyDown, events.leftMouseDown}, function(ev)
			if mod.mouseInsideTouchbar then
				if ev:getType() == events.flagsChanged and ev:getRawEventData().CGEventData.flags == 524576 then
					mod.touchBarWindow:backgroundColor{ red = 1 }
								  	:movable(true)
								  	:acceptsMouseEvents(false)
				elseif ev:getType() ~= events.leftMouseDown then
					mod.touchBarWindow:backgroundColor{ white = 0 }
								  :movable(false)
								  :acceptsMouseEvents(true)
					settings.set("fcpxHacks.lastTouchBarLocation", mod.touchBarWindow:topLeft())
				end
			end
			return false
		end):start()

	end

	--------------------------------------------------------------------------------
	-- Setup Watches:
	--------------------------------------------------------------------------------

		--------------------------------------------------------------------------------
		-- Final Cut Pro Application Watcher:
		--------------------------------------------------------------------------------
		fcp:watch({
			active		= finalCutProActive,
			inactive	= finalCutProNotActive,
		})

		--------------------------------------------------------------------------------
		-- Final Cut Pro Window Watcher:
		--------------------------------------------------------------------------------
		finalCutProWindowWatcher()

		--------------------------------------------------------------------------------
		-- Watch For Hammerspoon Script Updates:
		--------------------------------------------------------------------------------
		hammerspoonWatcher = pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hammerspoonConfigWatcher):start()

		--------------------------------------------------------------------------------
		-- Watch for Final Cut Pro plist Changes:
		--------------------------------------------------------------------------------
		preferencesWatcher = pathwatcher.new("~/Library/Preferences/", finalCutProSettingsWatcher):start()

		--------------------------------------------------------------------------------
		-- Watch for Shared Clipboard Changes:
		--------------------------------------------------------------------------------
		local sharedClipboardPath = settings.get("fcpxHacks.sharedClipboardPath")
		if sharedClipboardPath ~= nil then
			if tools.doesDirectoryExist(sharedClipboardPath) then
				sharedClipboardWatcher = pathwatcher.new(sharedClipboardPath, sharedClipboardFileWatcher):start()
			else
				writeToConsole("The Shared Clipboard Directory could not be found, so disabling.")
				settings.set("fcpxHacks.sharedClipboardPath", nil)
				settings.set("fcpxHacks.enableSharedClipboard", false)
			end
		end

		--------------------------------------------------------------------------------
		-- Watch for Shared XML Changes:
		--------------------------------------------------------------------------------
		local enableXMLSharing = settings.get("fcpxHacks.enableXMLSharing") or false
		if enableXMLSharing then
			local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")
			if xmlSharingPath ~= nil then
				if tools.doesDirectoryExist(xmlSharingPath) then
					sharedXMLWatcher = pathwatcher.new(xmlSharingPath, sharedXMLFileWatcher):start()
				else
					writeToConsole("The Shared XML Folder(s) could not be found, so disabling.")
					settings.set("fcpxHacks.xmlSharingPath", nil)
					settings.set("fcpxHacks.enableXMLSharing", false)
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Clipboard Watcher:
		--------------------------------------------------------------------------------
		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false
		local enableSharedClipboard = settings.get("fcpxHacks.enableSharedClipboard") or false
		if enableClipboardHistory or enableSharedClipboard then clipboard.startWatching() end

		--------------------------------------------------------------------------------
		-- Notification Watcher:
		--------------------------------------------------------------------------------
		local notificationPlatform = settings.get("fcpxHacks.notificationPlatform")
		if next(notificationPlatform) ~= nil then notificationWatcher() end

	--------------------------------------------------------------------------------
	-- Bind Keyboard Shortcuts:
	--------------------------------------------------------------------------------
	mod.lastCommandSet = fcp:getActiveCommandSetPath()
	bindKeyboardShortcuts()

	--------------------------------------------------------------------------------
	-- Load Hacks HUD:
	--------------------------------------------------------------------------------
	if settings.get("fcpxHacks.enableHacksHUD") then
		hackshud.new()
	end

	--------------------------------------------------------------------------------
	-- Activate the correct modal state:
	--------------------------------------------------------------------------------
	if fcp:isFrontmost() then
		--------------------------------------------------------------------------------
		-- Used by Watchers to prevent double-ups:
		--------------------------------------------------------------------------------
		mod.isFinalCutProActive = true

		--------------------------------------------------------------------------------
		-- Enable Final Cut Pro Shortcut Keys:
		--------------------------------------------------------------------------------
		hotkeys:enter()

		--------------------------------------------------------------------------------
		-- Show Hacks HUD:
		--------------------------------------------------------------------------------
		if settings.get("fcpxHacks.enableHacksHUD") then
			hackshud.show()
		end

		--------------------------------------------------------------------------------
		-- Enable Voice Commands:
		--------------------------------------------------------------------------------
		if settings.get("fcpxHacks.enableVoiceCommands") then
			voicecommands.start()
		end

	else
		--------------------------------------------------------------------------------
		-- Used by Watchers to prevent double-ups:
		--------------------------------------------------------------------------------
		mod.isFinalCutProActive = false

		--------------------------------------------------------------------------------
		-- Disable Final Cut Pro Shortcut Keys:
		--------------------------------------------------------------------------------
		hotkeys:exit()
	end

	-------------------------------------------------------------------------------
	-- Set up Chooser:
	-------------------------------------------------------------------------------
	hacksconsole.new()

	--------------------------------------------------------------------------------
	-- All loaded!
	--------------------------------------------------------------------------------
	writeToConsole("Successfully loaded.")
	dialog.displayNotification("FCPX Hacks (v" .. metadata.scriptVersion .. ") " .. i18n("hasLoaded"))

	--------------------------------------------------------------------------------
	-- Check for Script Updates:
	--------------------------------------------------------------------------------
	local checkForUpdatesInterval = settings.get("fcpxHacks.checkForUpdatesInterval")
	checkForUpdatesTimer = timer.doEvery(checkForUpdatesInterval, checkForUpdates)
	checkForUpdatesTimer:fire()

	mod.hacksLoaded = true

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   D E V E L O P M E N T      T O O L S                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- TESTING GROUND (CONTROL + OPTION + COMMAND + Q):
--------------------------------------------------------------------------------
function testingGround()

	--------------------------------------------------------------------------------
	-- Clear Console:
	--------------------------------------------------------------------------------
	--console.clearConsole()

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                    K E Y B O A R D     S H O R T C U T S                   --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DEFAULT SHORTCUT KEYS:
--------------------------------------------------------------------------------
function defaultShortcutKeys()

	local control					= {"ctrl"}
	local controlShift 				= {"ctrl", "shift"}
	local controlOptionCommand 		= {"ctrl", "option", "command"}
	local controlOptionCommandShift = {"ctrl", "option", "command", "shift"}

    local defaultShortcutKeys = {
        FCPXHackLaunchFinalCutPro                                   = { characterString = kc.keyCodeTranslator("l"),            modifiers = controlOptionCommand,                   fn = function() fcp:launch() end,                                   releasedFn = nil,                                                       repeatFn = nil,         global = true },
        FCPXHackShowListOfShortcutKeys                              = { characterString = kc.keyCodeTranslator("f1"),           modifiers = controlOptionCommand,                   fn = displayShortcutList,                          releasedFn = nil,                                                       repeatFn = nil,         global = true },

        FCPXHackHighlightBrowserPlayhead                            = { characterString = kc.keyCodeTranslator("h"),            modifiers = controlOptionCommand,                   fn = function() highlightFCPXBrowserPlayhead() end,                 releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRevealInBrowserAndHighlight                         = { characterString = kc.keyCodeTranslator("f"),            modifiers = controlOptionCommand,                   fn = function() matchFrameThenHighlightFCPXBrowserPlayhead() end,   releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSingleMatchFrameAndHighlight                        = { characterString = kc.keyCodeTranslator("s"),            modifiers = controlOptionCommand,                   fn = function() singleMatchFrame() end,                             releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRevealMulticamClipInBrowserAndHighlight             = { characterString = kc.keyCodeTranslator("d"),            modifiers = controlOptionCommand,                   fn = function() multicamMatchFrame(true) end,                       releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRevealMulticamClipInAngleEditorAndHighlight         = { characterString = kc.keyCodeTranslator("g"),            modifiers = controlOptionCommand,                   fn = function() multicamMatchFrame(false) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackBatchExportFromBrowser                              = { characterString = kc.keyCodeTranslator("e"),            modifiers = controlOptionCommand,                   fn = function() batchExport() end,                                  releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackChangeBackupInterval                                = { characterString = kc.keyCodeTranslator("b"),            modifiers = controlOptionCommand,                   fn = function() changeBackupInterval() end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackToggleTimecodeOverlays                              = { characterString = kc.keyCodeTranslator("t"),            modifiers = controlOptionCommand,                   fn = function() toggleTimecodeOverlay() end,                        releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackToggleMovingMarkers                                 = { characterString = kc.keyCodeTranslator("y"),            modifiers = controlOptionCommand,                   fn = function() toggleMovingMarkers() end,                          releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackAllowTasksDuringPlayback                            = { characterString = kc.keyCodeTranslator("p"),            modifiers = controlOptionCommand,                   fn = function() togglePerformTasksDuringPlayback() end,             releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackSelectColorBoardPuckOne                             = { characterString = kc.keyCodeTranslator("m"),            modifiers = controlOptionCommand,                   fn = function() colorBoardSelectPuck("*", "global") end,            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectColorBoardPuckTwo                             = { characterString = kc.keyCodeTranslator(","),            modifiers = controlOptionCommand,                   fn = function() colorBoardSelectPuck("*", "shadows") end,           releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectColorBoardPuckThree                           = { characterString = kc.keyCodeTranslator("."),            modifiers = controlOptionCommand,                   fn = function() colorBoardSelectPuck("*", "midtones") end,          releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectColorBoardPuckFour                            = { characterString = kc.keyCodeTranslator("/"),            modifiers = controlOptionCommand,                   fn = function() colorBoardSelectPuck("*", "highlights") end,        releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackRestoreKeywordPresetOne                             = { characterString = kc.keyCodeTranslator("1"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(1) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRestoreKeywordPresetTwo                             = { characterString = kc.keyCodeTranslator("2"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(2) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRestoreKeywordPresetThree                           = { characterString = kc.keyCodeTranslator("3"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(3) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRestoreKeywordPresetFour                            = { characterString = kc.keyCodeTranslator("4"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(4) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRestoreKeywordPresetFive                            = { characterString = kc.keyCodeTranslator("5"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(5) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRestoreKeywordPresetSix                             = { characterString = kc.keyCodeTranslator("6"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(6) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRestoreKeywordPresetSeven                           = { characterString = kc.keyCodeTranslator("7"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(7) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRestoreKeywordPresetEight                           = { characterString = kc.keyCodeTranslator("8"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(8) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackRestoreKeywordPresetNine                            = { characterString = kc.keyCodeTranslator("9"),            modifiers = controlOptionCommand,                   fn = function() restoreKeywordSearches(9) end,                      releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackHUD                                                 = { characterString = kc.keyCodeTranslator("a"),            modifiers = controlOptionCommand,                   fn = function() toggleEnableHacksHUD() end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackToggleTouchBar                                      = { characterString = kc.keyCodeTranslator("z"),            modifiers = controlOptionCommand,                   fn = function() toggleTouchBar() end,                               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackScrollingTimeline                                   = { characterString = kc.keyCodeTranslator("w"),            modifiers = controlOptionCommand,                   fn = function() toggleScrollingTimeline() end,                      releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackChangeTimelineClipHeightUp                          = { characterString = kc.keyCodeTranslator("+"),            modifiers = controlOptionCommand,                   fn = function() changeTimelineClipHeight("up") end,                 releasedFn = function() changeTimelineClipHeightRelease() end,          repeatFn = nil },
        FCPXHackChangeTimelineClipHeightDown                        = { characterString = kc.keyCodeTranslator("-"),            modifiers = controlOptionCommand,                   fn = function() changeTimelineClipHeight("down") end,               releasedFn = function() changeTimelineClipHeightRelease() end,          repeatFn = nil },

        FCPXHackSelectForward                                       = { characterString = kc.keyCodeTranslator("right"),        modifiers = controlOptionCommand,                   fn = function() selectAllTimelineClips(true) end,                   releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectBackwards                                     = { characterString = kc.keyCodeTranslator("left"),         modifiers = controlOptionCommand,                   fn = function() selectAllTimelineClips(false) end,                  releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackSaveKeywordPresetOne                                = { characterString = kc.keyCodeTranslator("1"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(1) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSaveKeywordPresetTwo                                = { characterString = kc.keyCodeTranslator("2"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(2) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSaveKeywordPresetThree                              = { characterString = kc.keyCodeTranslator("3"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(3) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSaveKeywordPresetFour                               = { characterString = kc.keyCodeTranslator("4"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(4) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSaveKeywordPresetFive                               = { characterString = kc.keyCodeTranslator("5"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(5) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSaveKeywordPresetSix                                = { characterString = kc.keyCodeTranslator("6"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(6) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSaveKeywordPresetSeven                              = { characterString = kc.keyCodeTranslator("7"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(7) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSaveKeywordPresetEight                              = { characterString = kc.keyCodeTranslator("8"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(8) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSaveKeywordPresetNine                               = { characterString = kc.keyCodeTranslator("9"),            modifiers = controlOptionCommandShift,              fn = function() saveKeywordSearches(9) end,                         releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackEffectsOne                                          = { characterString = kc.keyCodeTranslator("1"),            modifiers = controlShift,                           fn = function() effectsShortcut(1) end,                             releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackEffectsTwo                                          = { characterString = kc.keyCodeTranslator("2"),            modifiers = controlShift,                           fn = function() effectsShortcut(2) end,                             releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackEffectsThree                                        = { characterString = kc.keyCodeTranslator("3"),            modifiers = controlShift,                           fn = function() effectsShortcut(3) end,                             releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackEffectsFour                                         = { characterString = kc.keyCodeTranslator("4"),            modifiers = controlShift,                           fn = function() effectsShortcut(4) end,                             releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackEffectsFive                                         = { characterString = kc.keyCodeTranslator("5"),            modifiers = controlShift,                           fn = function() effectsShortcut(5) end,                             releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackConsole                                             = { characterString = kc.keyCodeTranslator("space"),        modifiers = control,                                fn = function() hacksconsole.show() end,							releasedFn = nil,                                     					repeatFn = nil },

		FCPXCopyWithCustomLabel			 							= { characterString = "",                                   modifiers = {},                                     fn = function() copyWithCustomLabel() end,                         	releasedFn = nil,                                                       repeatFn = nil },
		FCPXCopyWithCustomLabelAndFolder		 					= { characterString = "",                                   modifiers = {},                                     fn = function() copyWithCustomLabelAndFolder() end,                	releasedFn = nil,                                                       repeatFn = nil },

        FCPXAddNoteToSelectedClip	 								= { characterString = "",                                   modifiers = {},                                     fn = function() addNoteToSelectedClip() end,                        releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackMoveToPlayhead                                      = { characterString = "",                                   modifiers = {},                                     fn = function() moveToPlayhead() end,                               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackLockPlayhead                                        = { characterString = "",                                   modifiers = {},                                     fn = function() togglePlayheadLock() end,                           releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackToggleVoiceCommands                                 = { characterString = "",                                   modifiers = {},                                     fn = function() toggleEnableVoiceCommands() end,                    releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackTransitionsOne                                      = { characterString = "",                                   modifiers = {},                                     fn = function() transitionsShortcut(1) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackTransitionsTwo                                      = { characterString = "",                                   modifiers = {},                                     fn = function() transitionsShortcut(2) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackTransitionsThree                                    = { characterString = "",                                   modifiers = {},                                     fn = function() transitionsShortcut(3) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackTransitionsFour                                     = { characterString = "",                                   modifiers = {},                                     fn = function() transitionsShortcut(4) end,                         releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackTransitionsFive                                     = { characterString = "",                                   modifiers = {},                                     fn = function() transitionsShortcut(5) end,                         releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackTitlesOne                                           = { characterString = "",                                   modifiers = {},                                     fn = function() titlesShortcut(1) end,                              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackTitlesTwo                                           = { characterString = "",                                   modifiers = {},                                     fn = function() titlesShortcut(2) end,                              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackTitlesThree                                         = { characterString = "",                                   modifiers = {},                                     fn = function() titlesShortcut(3) end,                              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackTitlesFour                                          = { characterString = "",                                   modifiers = {},                                     fn = function() titlesShortcut(4) end,                              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackTitlesFive                                          = { characterString = "",                                   modifiers = {},                                     fn = function() titlesShortcut(5) end,                              releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackGeneratorsOne                                       = { characterString = "",                                   modifiers = {},                                     fn = function() generatorsShortcut(1) end,                          releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackGeneratorsTwo                                       = { characterString = "",                                   modifiers = {},                                     fn = function() generatorsShortcut(2) end,                          releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackGeneratorsThree                                     = { characterString = "",                                   modifiers = {},                                     fn = function() generatorsShortcut(3) end,                          releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackGeneratorsFour                                      = { characterString = "",                                   modifiers = {},                                     fn = function() generatorsShortcut(4) end,                          releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackGeneratorsFive                                      = { characterString = "",                                   modifiers = {},                                     fn = function() generatorsShortcut(5) end,                          releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackColorPuckOne                                        = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "global") end,                    releasedFn = nil,                                           repeatFn = nil },
        FCPXHackColorPuckTwo                                        = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "shadows") end,                   releasedFn = nil,                                           repeatFn = nil },
        FCPXHackColorPuckThree                                      = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "midtones") end,                  releasedFn = nil,                                           repeatFn = nil },
        FCPXHackColorPuckFour                                       = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "highlights") end,                releasedFn = nil,                                           repeatFn = nil },

        FCPXHackSaturationPuckOne                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "global") end,               releasedFn = nil,                                           repeatFn = nil },
        FCPXHackSaturationPuckTwo                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "shadows") end,              releasedFn = nil,                                           repeatFn = nil },
        FCPXHackSaturationPuckThree                                 = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "midtones") end,             releasedFn = nil,                                           repeatFn = nil },
        FCPXHackSaturationPuckFour                                  = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "highlights") end,           releasedFn = nil,                                           repeatFn = nil },

        FCPXHackExposurePuckOne                                     = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "global") end,                 releasedFn = nil,                                           repeatFn = nil },
        FCPXHackExposurePuckTwo                                     = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "shadows") end,                releasedFn = nil,                                           repeatFn = nil },
        FCPXHackExposurePuckThree                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "midtones") end,               releasedFn = nil,                                           repeatFn = nil },
        FCPXHackExposurePuckFour                                    = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "highlights") end,             releasedFn = nil,                                           repeatFn = nil },

        FCPXHackColorPuckOneUp                                      = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "global", "up") end,              releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckTwoUp                                      = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "shadows", "up") end,             releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckThreeUp                                    = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "midtones", "up") end,            releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckFourUp                                     = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "highlights", "up") end,          releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },

        FCPXHackColorPuckOneDown                                    = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "global", "down") end,            releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckTwoDown                                    = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "shadows", "down") end,           releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckThreeDown                                  = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "midtones", "down") end,          releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckFourDown                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "highlights", "down") end,        releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },

        FCPXHackColorPuckOneLeft                                    = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "global", "left") end,            releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckTwoLeft                                    = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "global", "left") end,            releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckThreeLeft                                  = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "global", "left") end,            releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckFourLeft                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "global", "left") end,            releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },

        FCPXHackColorPuckOneRight                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "global", "right") end,           releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckTwoRight                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "shadows", "right") end,          releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckThreeRight                                 = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "midtones", "right") end,         releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackColorPuckFourRight                                  = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("color", "highlights", "right") end,       releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },

        FCPXHackSaturationPuckOneUp                                 = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "global", "up") end,         releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackSaturationPuckTwoUp                                 = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "shadows", "up") end,        releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackSaturationPuckThreeUp                               = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "midtones", "up") end,       releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackSaturationPuckFourUp                                = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "highlights", "up") end,     releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },

        FCPXHackSaturationPuckOneDown                               = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "global", "down") end,       releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackSaturationPuckTwoDown                               = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "shadows", "down") end,      releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackSaturationPuckThreeDown                             = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "midtones", "down") end,     releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackSaturationPuckFourDown                              = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("saturation", "highlights", "down") end,   releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },

        FCPXHackExposurePuckOneUp                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "global", "up") end,           releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackExposurePuckTwoUp                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "shadows", "up") end,          releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackExposurePuckThreeUp                                 = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "midtones", "up") end,         releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackExposurePuckFourUp                                  = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "highlights", "up") end,       releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },

        FCPXHackExposurePuckOneDown                                 = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "global", "down") end,         releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackExposurePuckTwoDown                                 = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "shadows", "down") end,        releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackExposurePuckThreeDown                               = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "midtones", "down") end,       releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },
        FCPXHackExposurePuckFourDown                                = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardSelectPuck("exposure", "highlights", "down") end,     releasedFn = function() colorBoardSelectPuckRelease() end,  repeatFn = nil },

        FCPXHackCreateOptimizedMediaOn                              = { characterString = "",                                   modifiers = {},                                     fn = function() toggleCreateOptimizedMedia(true) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCreateOptimizedMediaOff                             = { characterString = "",                                   modifiers = {},                                     fn = function() toggleCreateOptimizedMedia(false) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCreateMulticamOptimizedMediaOn                      = { characterString = "",                                   modifiers = {},                                     fn = function() toggleCreateMulticamOptimizedMedia(true) end,       releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCreateMulticamOptimizedMediaOff                     = { characterString = "",                                   modifiers = {},                                     fn = function() toggleCreateMulticamOptimizedMedia(false) end,      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCreateProxyMediaOn                                  = { characterString = "",                                   modifiers = {},                                     fn = function() toggleCreateProxyMedia(true) end,                   releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCreateProxyMediaOff                                 = { characterString = "",                                   modifiers = {},                                     fn = function() toggleCreateProxyMedia(false) end,                  releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackLeaveInPlaceOn                                      = { characterString = "",                                   modifiers = {},                                     fn = function() toggleLeaveInPlace(true) end,                       releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackLeaveInPlaceOff                                     = { characterString = "",                                   modifiers = {},                                     fn = function() toggleLeaveInPlace(false) end,                      releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackBackgroundRenderOn                                  = { characterString = "",                                   modifiers = {},                                     fn = function() toggleBackgroundRender(true) end,                   releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackBackgroundRenderOff                                 = { characterString = "",                                   modifiers = {},                                     fn = function() toggleBackgroundRender(false) end,                  releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackChangeSmartCollectionsLabel                         = { characterString = "",                                   modifiers = {},                                     fn = function() changeSmartCollectionsLabel() end,                  releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackSelectClipAtLaneOne                                 = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(1) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneTwo                                 = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(2) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneThree                               = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(3) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneFour                                = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(4) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneFive                                = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(5) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneSix                                 = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(6) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneSeven                               = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(7) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneEight                               = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(8) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneNine                                = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(9) end,                            releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackSelectClipAtLaneTen                                 = { characterString = "",                                   modifiers = {},                                     fn = function() selectClipAtLane(10) end,                           releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackPuckOneMouse                                        = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("*", "global") end,             releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackPuckTwoMouse                                        = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("*", "shadows") end,            releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackPuckThreeMouse                                      = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("*", "midtones") end,           releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackPuckFourMouse                                       = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("*", "highlights") end,         releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },

        FCPXHackColorPuckOneMouse                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("color", "global") end,         releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackColorPuckTwoMouse                                   = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("color", "shadows") end,        releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackColorPuckThreeMouse                                 = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("color", "midtones") end,       releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackColorPuckFourMouse                                  = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("color", "highlights") end,     releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },

        FCPXHackSaturationPuckOneMouse                              = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("saturation", "global") end,    releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackSaturationPuckTwoMouse                              = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("saturation", "shadows") end,   releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackSaturationPuckThreeMouse                            = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("saturation", "midtones") end,  releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackSaturationPuckFourMouse                             = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("saturation", "highlights") end,releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },

        FCPXHackExposurePuckOneMouse                                = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("exposure", "global") end,      releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackExposurePuckTwoMouse                                = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("exposure", "shadows") end,     releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackExposurePuckThreeMouse                              = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("exposure", "midtones") end,    releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },
        FCPXHackExposurePuckFourMouse                               = { characterString = "",                                   modifiers = {},                                     fn = function() colorBoardMousePuck("exposure", "highlights") end,  releasedFn = function() colorBoardMousePuckRelease() end,               repeatFn = nil },

        FCPXHackCutSwitchAngle01Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 1) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle02Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 2) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle03Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 3) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle04Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 4) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle05Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 5) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle06Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 6) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle07Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 7) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle08Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 8) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle09Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 9) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle10Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 10) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle11Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 11) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle12Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 12) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle13Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 13) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle14Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 14) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle15Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 15) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle16Video                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Video", 16) end,              releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackCutSwitchAngle01Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 1) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle02Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 2) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle03Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 3) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle04Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 4) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle05Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 5) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle06Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 6) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle07Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 7) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle08Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 8) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle09Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 9) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle10Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 10) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle11Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 11) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle12Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 12) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle13Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 13) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle14Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 14) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle15Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 15) end,              releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle16Audio                               = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Audio", 16) end,              releasedFn = nil,                                                       repeatFn = nil },

        FCPXHackCutSwitchAngle01Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 1) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle02Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 2) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle03Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 3) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle04Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 4) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle05Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 5) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle06Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 6) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle07Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 7) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle08Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 8) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle09Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 9) end,                releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle10Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 10) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle11Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 11) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle12Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 12) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle13Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 13) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle14Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 14) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle15Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 15) end,               releasedFn = nil,                                                       repeatFn = nil },
        FCPXHackCutSwitchAngle16Both                                = { characterString = "",                                   modifiers = {},                                     fn = function() cutAndSwitchMulticam("Both", 16) end,               releasedFn = nil,                                                       repeatFn = nil },
    }
	return defaultShortcutKeys
end

--------------------------------------------------------------------------------
-- BIND KEYBOARD SHORTCUTS:
--------------------------------------------------------------------------------
function bindKeyboardShortcuts()

	--------------------------------------------------------------------------------
	-- Get Enable Hacks Shortcuts in Final Cut Pro from Settings:
	--------------------------------------------------------------------------------
	local enableHacksShortcutsInFinalCutPro = settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro")
	if enableHacksShortcutsInFinalCutPro == nil then enableHacksShortcutsInFinalCutPro = false end

	--------------------------------------------------------------------------------
	-- Hacks Shortcuts Enabled:
	--------------------------------------------------------------------------------
	if enableHacksShortcutsInFinalCutPro then

		--------------------------------------------------------------------------------
		-- Get Shortcut Keys from plist:
		--------------------------------------------------------------------------------
		mod.finalCutProShortcutKey = nil
		mod.finalCutProShortcutKey = {}
		mod.finalCutProShortcutKeyPlaceholders = nil
		mod.finalCutProShortcutKeyPlaceholders = defaultShortcutKeys()

		--------------------------------------------------------------------------------
		-- Remove the default shortcut keys:
		--------------------------------------------------------------------------------
		for k, v in pairs(mod.finalCutProShortcutKeyPlaceholders) do
			mod.finalCutProShortcutKeyPlaceholders[k]["characterString"] = ""
			mod.finalCutProShortcutKeyPlaceholders[k]["modifiers"] = {}
		end

		--------------------------------------------------------------------------------
		-- If something goes wrong:
		--------------------------------------------------------------------------------
		if getShortcutsFromActiveCommandSet() ~= true then
			dialog.displayErrorMessage(i18n("customKeyboardShortcutsFailed"))
			enableHacksShortcutsInFinalCutPro = false
		end

	end

	--------------------------------------------------------------------------------
	-- Hacks Shortcuts Disabled:
	--------------------------------------------------------------------------------
	if not enableHacksShortcutsInFinalCutPro then

		--------------------------------------------------------------------------------
		-- Update Active Command Set:
		--------------------------------------------------------------------------------
		fcp:getActiveCommandSet(nil, true)

		--------------------------------------------------------------------------------
		-- Use Default Shortcuts Keys:
		--------------------------------------------------------------------------------
		mod.finalCutProShortcutKey = nil
		mod.finalCutProShortcutKey = defaultShortcutKeys()

	end

	--------------------------------------------------------------------------------
	-- Reset Modal Hotkey for Final Cut Pro Commands:
	--------------------------------------------------------------------------------
	hotkeys = nil

	--------------------------------------------------------------------------------
	-- Reset Global Hotkeys:
	--------------------------------------------------------------------------------
	local currentHotkeys = hotkey.getHotkeys()
	for i=1, #currentHotkeys do
		result = currentHotkeys[i]:delete()
	end

	--------------------------------------------------------------------------------
	-- Create a modal hotkey object with an absurd triggering hotkey:
	--------------------------------------------------------------------------------
	hotkeys = hotkey.modal.new({"command", "shift", "alt", "control"}, "F19")

	--------------------------------------------------------------------------------
	-- Enable Hotkeys Loop:
	--------------------------------------------------------------------------------
	for k, v in pairs(mod.finalCutProShortcutKey) do
		if v['characterString'] ~= "" and v['fn'] ~= nil then
			if v['global'] == true then
				--------------------------------------------------------------------------------
				-- Global Shortcut:
				--------------------------------------------------------------------------------
				hotkey.bind(v['modifiers'], v['characterString'], v['fn'], v['releasedFn'], v['repeatFn'])
			else
				--------------------------------------------------------------------------------
				-- Final Cut Pro Specific Shortcut:
				--------------------------------------------------------------------------------
				hotkeys:bind(v['modifiers'], v['characterString'], v['fn'], v['releasedFn'], v['repeatFn'])
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Development Shortcut:
	--------------------------------------------------------------------------------
	if mod.debugMode then
		hotkey.bind({"ctrl", "option", "command"}, "q", function() testingGround() end)
	end

	--------------------------------------------------------------------------------
	-- Enable Hotkeys:
	--------------------------------------------------------------------------------
	hotkeys:enter()

	--------------------------------------------------------------------------------
	-- Let user know that keyboard shortcuts have loaded:
	--------------------------------------------------------------------------------
	dialog.displayNotification(i18n("keyboardShortcutsUpdated"))

end

--------------------------------------------------------------------------------
-- READ SHORTCUT KEYS FROM FINAL CUT PRO PLIST:
--------------------------------------------------------------------------------
function getShortcutsFromActiveCommandSet()

	local activeCommandSetTable = fcp:getActiveCommandSet(nil, true)

	if activeCommandSetTable ~= nil then
		for k, v in pairs(mod.finalCutProShortcutKeyPlaceholders) do

			if activeCommandSetTable[k] ~= nil then

				--------------------------------------------------------------------------------
				-- Multiple keyboard shortcuts for single function:
				--------------------------------------------------------------------------------
				if type(activeCommandSetTable[k][1]) == "table" then
					for x=1, #activeCommandSetTable[k] do

						local tempModifiers = nil
						local tempCharacterString = nil
						local keypadModifier = false

						if activeCommandSetTable[k][x]["modifiers"] ~= nil then
							if string.find(activeCommandSetTable[k][x]["modifiers"], "keypad") then keypadModifier = true end
							tempModifiers = kc.translateKeyboardModifiers(activeCommandSetTable[k][x]["modifiers"])
						else
							if activeCommandSetTable[k][x]["modifierMask"] ~= nil then
								tempModifiers = kc.translateModifierMask(activeCommandSetTable[k][x]["modifierMask"])
							end
						end

						if activeCommandSetTable[k][x]["characterString"] ~= nil then
							tempCharacterString = kc.translateKeyboardCharacters(activeCommandSetTable[k][x]["characterString"])
						else
							if activeCommandSetTable[k][x]["character"] ~= nil then
								if keypadModifier then
									tempCharacterString = kc.translateKeyboardKeypadCharacters(activeCommandSetTable[k][x]["character"])
								else
									tempCharacterString = kc.translateKeyboardCharacters(activeCommandSetTable[k][x]["character"])
								end
							end
						end

						local tempGlobalShortcut = mod.finalCutProShortcutKeyPlaceholders[k]['global'] or false

						local xValue = ""
						if x ~= 1 then xValue = tostring(x) end

						mod.finalCutProShortcutKey[k .. xValue] = {
							characterString 	= 		tempCharacterString,
							modifiers 			= 		tempModifiers,
							fn 					= 		mod.finalCutProShortcutKeyPlaceholders[k]['fn'],
							releasedFn 			= 		mod.finalCutProShortcutKeyPlaceholders[k]['releasedFn'],
							repeatFn 			= 		mod.finalCutProShortcutKeyPlaceholders[k]['repeatFn'],
							global 				= 		tempGlobalShortcut,
						}

					end
				--------------------------------------------------------------------------------
				-- Single keyboard shortcut for a single function:
				--------------------------------------------------------------------------------
				else

					local tempModifiers = nil
					local tempCharacterString = nil
					local keypadModifier = false

					if activeCommandSetTable[k]["modifiers"] ~= nil then
						tempModifiers = kc.translateKeyboardModifiers(activeCommandSetTable[k]["modifiers"])
					else
						if activeCommandSetTable[k]["modifierMask"] ~= nil then
							tempModifiers = kc.translateModifierMask(activeCommandSetTable[k]["modifierMask"])
						end
					end

					if activeCommandSetTable[k]["characterString"] ~= nil then
						tempCharacterString = kc.translateKeyboardCharacters(activeCommandSetTable[k]["characterString"])
					else
						if activeCommandSetTable[k]["character"] ~= nil then
							if keypadModifier then
								tempCharacterString = kc.translateKeyboardKeypadCharacters(activeCommandSetTable[k]["character"])
							else
								tempCharacterString = kc.translateKeyboardCharacters(activeCommandSetTable[k]["character"])
							end
						end
					end

					local tempGlobalShortcut = mod.finalCutProShortcutKeyPlaceholders[k]['global'] or false

					mod.finalCutProShortcutKey[k] = {
						characterString 	= 		tempCharacterString,
						modifiers 			= 		tempModifiers,
						fn 					= 		mod.finalCutProShortcutKeyPlaceholders[k]['fn'],
						releasedFn 			= 		mod.finalCutProShortcutKeyPlaceholders[k]['releasedFn'],
						repeatFn 			= 		mod.finalCutProShortcutKeyPlaceholders[k]['repeatFn'],
						global 				= 		tempGlobalShortcut,
					}

				end
			end
		end
		return true
	else
		return false
	end

end

--------------------------------------------------------------------------------
-- UPDATE KEYBOARD SHORTCUTS:
--------------------------------------------------------------------------------
function updateKeyboardShortcuts()

	--------------------------------------------------------------------------------
	-- Update Keyboard Settings:
	--------------------------------------------------------------------------------
	local result = enableHacksShortcuts()
	if type(result) == "string" then
		dialog.displayErrorMessage(result)
		settings.set("fcpxHacks.enableHacksShortcutsInFinalCutPro", false)
		return false
	elseif result == false then
		--------------------------------------------------------------------------------
		-- NOTE: When Cancel is pressed whilst entering the admin password, let's
		-- just leave the old Hacks Shortcut Plist files in place.
		--------------------------------------------------------------------------------
		return
	end

end

--------------------------------------------------------------------------------
-- ENABLE HACKS SHORTCUTS:
--------------------------------------------------------------------------------
function enableHacksShortcuts()

	local finalCutProPath = fcp:getPath() .. "/Contents/Resources/"
	local finalCutProLanguages = fcp:getSupportedLanguages()
	local executeCommand = "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/"

	local executeStrings = {
		executeCommand .. "NSProCommandGroups.plist '" .. finalCutProPath .. "NSProCommandGroups.plist'",
		executeCommand .. "NSProCommands.plist '" .. finalCutProPath .. "NSProCommands.plist'",
	}

	for _, whichLanguage in ipairs(finalCutProLanguages) do
		table.insert(executeStrings, executeCommand .. whichLanguage .. ".lproj/Default.commandset '" .. finalCutProPath .. whichLanguage .. ".lproj/Default.commandset'")
		table.insert(executeStrings, executeCommand .. whichLanguage .. ".lproj/NSProCommandDescriptions.strings '" .. finalCutProPath .. whichLanguage .. ".lproj/NSProCommandDescriptions.strings'")
		table.insert(executeStrings, executeCommand .. whichLanguage .. ".lproj/NSProCommandNames.strings '" .. finalCutProPath .. whichLanguage .. ".lproj/NSProCommandNames.strings'")
	end

	local result = tools.executeWithAdministratorPrivileges(executeStrings)
	return result

end

--------------------------------------------------------------------------------
-- DISABLE HACKS SHORTCUTS:
--------------------------------------------------------------------------------
function disableHacksShortcuts()

	local finalCutProPath = fcp:getPath() .. "/Contents/Resources/"
	local finalCutProLanguages = fcp:getSupportedLanguages()
	local executeCommand = "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/"

	local executeStrings = {
		executeCommand .. "NSProCommandGroups.plist '" .. finalCutProPath .. "NSProCommandGroups.plist'",
		executeCommand .. "NSProCommands.plist '" .. finalCutProPath .. "NSProCommands.plist'",
	}

	for _, whichLanguage in ipairs(finalCutProLanguages) do
		table.insert(executeStrings, executeCommand .. whichLanguage .. ".lproj/Default.commandset '" .. finalCutProPath .. whichLanguage .. ".lproj/Default.commandset'")
		table.insert(executeStrings, executeCommand .. whichLanguage .. ".lproj/NSProCommandDescriptions.strings '" .. finalCutProPath .. whichLanguage .. ".lproj/NSProCommandDescriptions.strings'")
		table.insert(executeStrings, executeCommand .. whichLanguage .. ".lproj/NSProCommandNames.strings '" .. finalCutProPath .. whichLanguage .. ".lproj/NSProCommandNames.strings'")
	end

	local result = tools.executeWithAdministratorPrivileges(executeStrings)
	return result

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                     M E N U B A R    F E A T U R E S                       --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- MENUBAR:
--------------------------------------------------------------------------------

	function generateMenuBar(refreshPlistValues)
		--------------------------------------------------------------------------------
		-- Maximum Length of Menubar Strings:
		--------------------------------------------------------------------------------
		local maxTextLength = 25

		--------------------------------------------------------------------------------
		-- Assume FCPX is closed if not told otherwise:
		--------------------------------------------------------------------------------
		local fcpxActive = fcp:isFrontmost()
		local fcpxRunning = fcp:isRunning()

		--------------------------------------------------------------------------------
		-- Current Language:
		--------------------------------------------------------------------------------
		local currentLanguage = fcp:getCurrentLanguage()

		--------------------------------------------------------------------------------
		-- We only refresh plist values if necessary as this takes time:
		--------------------------------------------------------------------------------
		if refreshPlistValues == true then

			--------------------------------------------------------------------------------
			-- Read Final Cut Pro Preferences:
			--------------------------------------------------------------------------------
			local preferences = fcp:getPreferences()
			if preferences == nil then
				dialog.displayErrorMessage(i18n("failedToReadFCPPreferences"))
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Get plist values for Allow Moving Markers:
			--------------------------------------------------------------------------------
			mod.allowMovingMarkers = false
			local result = plist.fileToTable(fcp:getPath() .. "/Contents/Frameworks/TLKit.framework/Versions/A/Resources/EventDescriptions.plist")
			if result ~= nil then
				if result["TLKMarkerHandler"] ~= nil then
					if result["TLKMarkerHandler"]["Configuration"] ~= nil then
						if result["TLKMarkerHandler"]["Configuration"]["Allow Moving Markers"] ~= nil then
							mod.allowMovingMarkers = result["TLKMarkerHandler"]["Configuration"]["Allow Moving Markers"]
						end
					end
				end
			end

			--------------------------------------------------------------------------------
			-- Get plist values for FFPeriodicBackupInterval:
			--------------------------------------------------------------------------------
			if preferences["FFPeriodicBackupInterval"] == nil then
				mod.FFPeriodicBackupInterval = "15"
			else
				mod.FFPeriodicBackupInterval = preferences["FFPeriodicBackupInterval"]
			end

			--------------------------------------------------------------------------------
			-- Get plist values for FFSuspendBGOpsDuringPlay:
			--------------------------------------------------------------------------------
			if preferences["FFSuspendBGOpsDuringPlay"] == nil then
				mod.FFSuspendBGOpsDuringPlay = false
			else
				mod.FFSuspendBGOpsDuringPlay = preferences["FFSuspendBGOpsDuringPlay"]
			end

			--------------------------------------------------------------------------------
			-- Get plist values for FFEnableGuards:
			--------------------------------------------------------------------------------
			if preferences["FFEnableGuards"] == nil then
				mod.FFEnableGuards = false
			else
				mod.FFEnableGuards = preferences["FFEnableGuards"]
			end

			--------------------------------------------------------------------------------
			-- Get plist values for FFAutoRenderDelay:
			--------------------------------------------------------------------------------
			if preferences["FFAutoRenderDelay"] == nil then
				mod.FFAutoRenderDelay = "0.3"
			else
				mod.FFAutoRenderDelay = preferences["FFAutoRenderDelay"]
			end

		end

		--------------------------------------------------------------------------------
		-- Get Enable Hacks Shortcuts in Final Cut Pro from Settings:
		--------------------------------------------------------------------------------
		local enableHacksShortcutsInFinalCutPro = settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro") or false

		--------------------------------------------------------------------------------
		-- Notification Platform:
		--------------------------------------------------------------------------------
		local notificationPlatform = settings.get("fcpxHacks.notificationPlatform")

		--------------------------------------------------------------------------------
		-- Display Touch Bar:
		--------------------------------------------------------------------------------
		local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false

		--------------------------------------------------------------------------------
		-- Enable XML Sharing:
		--------------------------------------------------------------------------------
		local enableXMLSharing 		= settings.get("fcpxHacks.enableXMLSharing") or false

		--------------------------------------------------------------------------------
		-- Enable Clipboard History:
		--------------------------------------------------------------------------------
		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false

		--------------------------------------------------------------------------------
		-- Enable Shared Clipboard:
		--------------------------------------------------------------------------------
		local enableSharedClipboard = settings.get("fcpxHacks.enableSharedClipboard") or false

		--------------------------------------------------------------------------------
		-- Enable Hacks HUD:
		--------------------------------------------------------------------------------
		local enableHacksHUD 		= settings.get("fcpxHacks.enableHacksHUD") or false

		local hudButtonOne 			= settings.get("fcpxHacks." .. currentLanguage .. ".hudButtonOne") 	or " (Unassigned)"
		local hudButtonTwo 			= settings.get("fcpxHacks." .. currentLanguage .. ".hudButtonTwo") 	or " (Unassigned)"
		local hudButtonThree 		= settings.get("fcpxHacks." .. currentLanguage .. ".hudButtonThree") 	or " (Unassigned)"
		local hudButtonFour 		= settings.get("fcpxHacks." .. currentLanguage .. ".hudButtonFour") 	or " (Unassigned)"

		if hudButtonOne ~= " (Unassigned)" then		hudButtonOne = " (" .. 		tools.stringMaxLength(tools.cleanupButtonText(hudButtonOne["text"]),maxTextLength,"...") 	.. ")" end
		if hudButtonTwo ~= " (Unassigned)" then 	hudButtonTwo = " (" .. 		tools.stringMaxLength(tools.cleanupButtonText(hudButtonTwo["text"]),maxTextLength,"...") 	.. ")" end
		if hudButtonThree ~= " (Unassigned)" then 	hudButtonThree = " (" .. 	tools.stringMaxLength(tools.cleanupButtonText(hudButtonThree["text"]),maxTextLength,"...") 	.. ")" end
		if hudButtonFour ~= " (Unassigned)" then 	hudButtonFour = " (" .. 	tools.stringMaxLength(tools.cleanupButtonText(hudButtonFour["text"]),maxTextLength,"...") 	.. ")" end

		--------------------------------------------------------------------------------
		-- Clipboard History Menu:
		--------------------------------------------------------------------------------
		local settingsClipboardHistoryTable = {}
		if enableClipboardHistory then
			local clipboardHistory = clipboard.getHistory()
			if clipboardHistory ~= nil then
				if #clipboardHistory ~= 0 then
					for i=#clipboardHistory, 1, -1 do
						table.insert(settingsClipboardHistoryTable, {title = clipboardHistory[i][2], fn = function() finalCutProPasteFromClipboardHistory(clipboardHistory[i][1]) end, disabled = not fcpxRunning})
					end
					table.insert(settingsClipboardHistoryTable, { title = "-" })
					table.insert(settingsClipboardHistoryTable, { title = "Clear Clipboard History", fn = clearClipboardHistory })
				else
					table.insert(settingsClipboardHistoryTable, { title = "Empty", disabled = true })
				end
			end
		else
			table.insert(settingsClipboardHistoryTable, { title = "Disabled in Settings", disabled = true })
		end

		--------------------------------------------------------------------------------
		-- Shared Clipboard Menu:
		--------------------------------------------------------------------------------
		local settingsSharedClipboardTable = {}

		if enableSharedClipboard then

			--------------------------------------------------------------------------------
			-- Get list of files:
			--------------------------------------------------------------------------------
			local emptySharedClipboard = true
			local sharedClipboardFiles = {}
			local sharedClipboardPath = settings.get("fcpxHacks.sharedClipboardPath")
			for file in fs.dir(sharedClipboardPath) do
				 if file:sub(-10) == ".fcpxhacks" then

					local pathToClipboardFile = sharedClipboardPath .. file
					local plistData = plist.xmlFileToTable(pathToClipboardFile)
					if plistData ~= nil then
						if plistData["SharedClipboardLabel1"] ~= nil then

							local editorName = string.sub(file, 1, -11)
							local submenu = {}
							for i=1, 5 do
								emptySharedClipboard = false
								local currentItem = plistData["SharedClipboardLabel"..tostring(i)]
								if currentItem ~= "" then table.insert(submenu, {title = currentItem, fn = function() pasteFromSharedClipboard(pathToClipboardFile, tostring(i)) end, disabled = not fcpxRunning}) end
							end

							table.insert(settingsSharedClipboardTable, {title = editorName, menu = submenu})
						end
					end


				 end
			end

			if emptySharedClipboard then
				--------------------------------------------------------------------------------
				-- Nothing in the Shared Clipboard:
				--------------------------------------------------------------------------------
				table.insert(settingsSharedClipboardTable, { title = "Empty", disabled = true })
			else
				table.insert(settingsSharedClipboardTable, { title = "-" })
				table.insert(settingsSharedClipboardTable, { title = "Clear Shared Clipboard History", fn = clearSharedClipboardHistory })
			end

		else
			--------------------------------------------------------------------------------
			-- Shared Clipboard Disabled:
			--------------------------------------------------------------------------------
			table.insert(settingsSharedClipboardTable, { title = "Disabled in Settings", disabled = true })
		end

		--------------------------------------------------------------------------------
		-- Shared XML Menu:
		--------------------------------------------------------------------------------
		local settingsSharedXMLTable = {}
		if enableXMLSharing then

			--------------------------------------------------------------------------------
			-- Get list of files:
			--------------------------------------------------------------------------------
			local sharedXMLFiles = {}

			local emptySharedXMLFiles = true
			local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")

			for folder in fs.dir(xmlSharingPath) do

				if tools.doesDirectoryExist(xmlSharingPath .. "/" .. folder) then

					submenu = {}
					for file in fs.dir(xmlSharingPath .. "/" .. folder) do
						if file:sub(-7) == ".fcpxml" then
							emptySharedXMLFiles = false
							local xmlPath = xmlSharingPath .. folder .. "/" .. file
							table.insert(submenu, {title = file:sub(1, -8), fn = function() fcp:importXML(xmlPath) end, disabled = not fcpxRunning})
						end
					end

					if next(submenu) ~= nil then
						table.insert(settingsSharedXMLTable, {title = folder, menu = submenu})
					end

				end

			end

			if emptySharedXMLFiles then
				--------------------------------------------------------------------------------
				-- Nothing in the Shared Clipboard:
				--------------------------------------------------------------------------------
				table.insert(settingsSharedXMLTable, { title = "Empty", disabled = true })
			else
				--------------------------------------------------------------------------------
				-- Something in the Shared Clipboard:
				--------------------------------------------------------------------------------
				table.insert(settingsSharedXMLTable, { title = "-" })
				table.insert(settingsSharedXMLTable, { title = "Clear Shared XML Files", fn = clearSharedXMLFiles })
			end
		else
			--------------------------------------------------------------------------------
			-- Shared Clipboard Disabled:
			--------------------------------------------------------------------------------
			table.insert(settingsSharedXMLTable, { title = "Disabled in Settings", disabled = true })
		end

		--------------------------------------------------------------------------------
		-- Get Menubar Settings:
		--------------------------------------------------------------------------------
		local menubarToolsEnabled = 		settings.get("fcpxHacks.menubarToolsEnabled")
		local menubarHacksEnabled = 		settings.get("fcpxHacks.menubarHacksEnabled")

		local settingsHUDButtons = {
			{ title = i18n("button") .. " " .. i18n("one") .. hudButtonOne, 							fn = function() hackshud.assignButton(1) end },
			{ title = i18n("button") .. " " .. i18n("two") .. hudButtonTwo, 							fn = function() hackshud.assignButton(2) end },
			{ title = i18n("button") .. " " .. i18n("three") .. hudButtonThree, 						fn = function() hackshud.assignButton(3) end },
			{ title = i18n("button") .. " " .. i18n("four") .. hudButtonFour, 							fn = function() hackshud.assignButton(4) end },
		}
		-- The main menu
		local menuTable = {
		}

		local settingsNotificationPlatform = {
			{ title = i18n("prowl"), 																	fn = function() toggleNotificationPlatform("Prowl") end, 			checked = notificationPlatform["Prowl"] == true },
			{ title = i18n("iMessage"), 																fn = function() toggleNotificationPlatform("iMessage") end, 		checked = notificationPlatform["iMessage"] == true },
		}
		local toolsSettings = {
			{ title = i18n("enableClipboardHistory"),													fn = toggleEnableClipboardHistory, 									checked = enableClipboardHistory},
			{ title = i18n("enableSharedClipboard"), 													fn = toggleEnableSharedClipboard, 									checked = enableSharedClipboard},
			{ title = "-" },
			{ title = i18n("enableHacksHUD"), 															fn = toggleEnableHacksHUD, 											checked = enableHacksHUD},
			{ title = i18n("enableXMLSharing"),															fn = toggleEnableXMLSharing, 										checked = enableXMLSharing},
			{ title = "-" },
			{ title = i18n("enableTouchBar"), 															fn = toggleTouchBar, 												checked = displayTouchBar, 									disabled = not touchBarSupported},
			{ title = i18n("enableVoiceCommands"),														fn = toggleEnableVoiceCommands, 									checked = settings.get("fcpxHacks.enableVoiceCommands") },
			{ title = "-" },
			{ title = i18n("enableMobileNotifications"),												menu = settingsNotificationPlatform },
		}
		local toolsTable = {
			{ title = "-" },
			{ title = string.upper(i18n("tools")) .. ":", 												disabled = true },
			{ title = i18n("importSharedXMLFile"),														menu = settingsSharedXMLTable },
			{ title = i18n("pasteFromClipboardHistory"),												menu = settingsClipboardHistoryTable },
			{ title = i18n("pasteFromSharedClipboard"), 												menu = settingsSharedClipboardTable },
			{ title = i18n("assignHUDButtons"), 														menu = settingsHUDButtons },
			{ title = i18n("options"),																	menu = toolsSettings },
		}
		local advancedTable = {
			{ title = "-" },
			{ title = i18n("enableHacksShortcuts"), 													fn = toggleEnableHacksShortcutsInFinalCutPro, 						checked = enableHacksShortcutsInFinalCutPro},
			{ title = i18n("enableTimecodeOverlay"), 													fn = toggleTimecodeOverlay, 										checked = mod.FFEnableGuards },
			{ title = i18n("enableMovingMarkers"), 														fn = toggleMovingMarkers, 											checked = mod.allowMovingMarkers },
			{ title = i18n("enableRenderingDuringPlayback"),											fn = togglePerformTasksDuringPlayback, 								checked = not mod.FFSuspendBGOpsDuringPlay },
			{ title = "-" },
			{ title = i18n("changeBackupInterval") .. " (" .. tostring(mod.FFPeriodicBackupInterval) .. " " .. i18n("mins") .. ")", fn = changeBackupInterval },
			{ title = i18n("changeSmartCollectionLabel"),												fn = changeSmartCollectionsLabel },
		}
		local hacksTable = {
			{ title = "-" },
			{ title = string.upper(i18n("hacks")) .. ":", 												disabled = true },
			{ title = i18n("advancedFeatures"),															menu = advancedTable },
		}

		--------------------------------------------------------------------------------
		-- Setup Menubar:
		--------------------------------------------------------------------------------
		if menubarToolsEnabled then 		menuTable = fnutils.concat(menuTable, toolsTable)		end
		if menubarHacksEnabled then 		menuTable = fnutils.concat(menuTable, hacksTable)		end

		--------------------------------------------------------------------------------
		-- Check for Updates:
		--------------------------------------------------------------------------------
		if latestScriptVersion ~= nil then
			if latestScriptVersion > metadata.scriptVersion then
				table.insert(menuTable, 1, { title = i18n("updateAvailable") .. " (" .. i18n("version") .. " " .. latestScriptVersion .. ")", fn = getScriptUpdate})
				table.insert(menuTable, 2, { title = "-" })
			end
		end

		return menuTable
	end

	function generatePreferencesMenuBar()
		--------------------------------------------------------------------------------
		-- Get Sizing Preferences:
		--------------------------------------------------------------------------------
		local displayHighlightShape = nil
		displayHighlightShape = settings.get("fcpxHacks.displayHighlightShape")
		local displayHighlightShapeRectangle = false
		local displayHighlightShapeCircle = false
		local displayHighlightShapeDiamond = false
		if displayHighlightShape == nil then 			displayHighlightShapeRectangle = true		end
		if displayHighlightShape == "Rectangle" then 	displayHighlightShapeRectangle = true		end
		if displayHighlightShape == "Circle" then 		displayHighlightShapeCircle = true			end
		if displayHighlightShape == "Diamond" then 		displayHighlightShapeDiamond = true			end

		--------------------------------------------------------------------------------
		-- Get Highlight Colour Preferences:
		--------------------------------------------------------------------------------
		local displayHighlightColour = settings.get("fcpxHacks.displayHighlightColour") or nil

		--------------------------------------------------------------------------------
		-- Hammerspoon Settings:
		--------------------------------------------------------------------------------
		local startHammerspoonOnLaunch = hs.autoLaunch()
		local hammerspoonCheckForUpdates = hs.automaticallyCheckForUpdates()
		local hammerspoonDockIcon = hs.dockIcon()
		local hammerspoonMenuIcon = hs.menuIcon()

		--------------------------------------------------------------------------------
		-- Touch Bar Location:
		--------------------------------------------------------------------------------
		local displayTouchBarLocation = settings.get("fcpxHacks.displayTouchBarLocation") or "Mouse"
		local displayTouchBarLocationMouse = false
		if displayTouchBarLocation == "Mouse" then displayTouchBarLocationMouse = true end
		local displayTouchBarLocationTimelineTopCentre = false
		if displayTouchBarLocation == "TimelineTopCentre" then displayTouchBarLocationTimelineTopCentre = true end

		--------------------------------------------------------------------------------
		-- HUD Preferences:
		--------------------------------------------------------------------------------
		local hudShowInspector 		= settings.get("fcpxHacks.hudShowInspector")
		local hudShowDropTargets 	= settings.get("fcpxHacks.hudShowDropTargets")
		local hudShowButtons 		= settings.get("fcpxHacks.hudShowButtons")

		--------------------------------------------------------------------------------
		-- Get Highlight Playhead Time:
		--------------------------------------------------------------------------------
		local highlightPlayheadTime = settings.get("fcpxHacks.highlightPlayheadTime")

		--------------------------------------------------------------------------------
		-- Enable Check for Updates:
		--------------------------------------------------------------------------------
		local enableCheckForUpdates = settings.get("fcpxHacks.enableCheckForUpdates") or false

		--------------------------------------------------------------------------------
		-- Setup Menu:
		--------------------------------------------------------------------------------
		local settingsShapeMenuTable = {
			{ title = i18n("rectangle"), 																fn = function() changeHighlightShape("Rectangle") end,				checked = displayHighlightShapeRectangle	},
			{ title = i18n("circle"), 																	fn = function() changeHighlightShape("Circle") end, 				checked = displayHighlightShapeCircle		},
			{ title = i18n("diamond"),																	fn = function() changeHighlightShape("Diamond") end, 				checked = displayHighlightShapeDiamond		},
		}
		local settingsColourMenuTable = {
			{ title = i18n("red"), 																		fn = function() changeHighlightColour("Red") end, 					checked = displayHighlightColour == "Red" },
			{ title = i18n("blue"), 																	fn = function() changeHighlightColour("Blue") end, 					checked = displayHighlightColour == "Blue" },
			{ title = i18n("green"), 																	fn = function() changeHighlightColour("Green") end, 				checked = displayHighlightColour == "Green"	},
			{ title = i18n("yellow"), 																	fn = function() changeHighlightColour("Yellow") end, 				checked = displayHighlightColour == "Yellow" },
			{ title = "-" },
			{ title = i18n("custom"), 																	fn = function() changeHighlightColour("Custom") end, 				checked = displayHighlightColour == "Custom" },
		}
		local settingsHammerspoonSettings = {
			{ title = i18n("console") .. "...", 														fn = openHammerspoonConsole },
			{ title = "-" },
			{ title = i18n("showDockIcon"),																fn = toggleHammerspoonDockIcon, 									checked = hammerspoonDockIcon		},
			{ title = i18n("showMenuIcon"), 															fn = toggleHammerspoonMenuIcon, 									checked = hammerspoonMenuIcon		},
			{ title = "-" },
			{ title = i18n("launchAtStartup"), 															fn = toggleLaunchHammerspoonOnStartup, 								checked = startHammerspoonOnLaunch		},
			{ title = i18n("checkForUpdates"), 															fn = toggleCheckforHammerspoonUpdates, 								checked = hammerspoonCheckForUpdates	},
		}
		local settingsTouchBarLocation = {
			{ title = i18n("mouseLocation"), 															fn = function() changeTouchBarLocation("Mouse") end,				checked = displayTouchBarLocationMouse, disabled = not touchBarSupported },
			{ title = i18n("topCentreOfTimeline"), 														fn = function() changeTouchBarLocation("TimelineTopCentre") end,	checked = displayTouchBarLocationTimelineTopCentre, disabled = not touchBarSupported },
			{ title = "-" },
			{ title = i18n("touchBarTipOne"), 															disabled = true },
			{ title = i18n("touchBarTipTwo"), 															disabled = true },
		}
		local settingsHUD = {
			{ title = i18n("showInspector"), 															fn = function() toggleHUDOption("hudShowInspector") end, 			checked = hudShowInspector},
			{ title = i18n("showDropTargets"), 															fn = function() toggleHUDOption("hudShowDropTargets") end, 			checked = hudShowDropTargets},
			{ title = i18n("showButtons"), 																fn = function() toggleHUDOption("hudShowButtons") end, 				checked = hudShowButtons},
		}
		local settingsVoiceCommand = {
			{ title = i18n("enableAnnouncements"), 														fn = toggleVoiceCommandEnableAnnouncements, 						checked = settings.get("fcpxHacks.voiceCommandEnableAnnouncements") },
			{ title = i18n("enableVisualAlerts"), 														fn = toggleVoiceCommandEnableVisualAlerts, 							checked = settings.get("fcpxHacks.voiceCommandEnableVisualAlerts") },
			{ title = "-" },
			{ title = i18n("openDictationPreferences"), 												fn = function()
				osascript.applescript([[
					tell application "System Preferences"
						activate
						reveal anchor "Dictation" of pane "com.apple.preference.speech"
					end tell]]) end },
		}
		local settingsHighlightPlayheadTime = {
			{ title = i18n("one") .. " " .. i18n("secs", {count=1}), 									fn = function() changeHighlightPlayheadTime(1) end, 					checked = highlightPlayheadTime == 1 },
			{ title = i18n("two") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(2) end, 					checked = highlightPlayheadTime == 2 },
			{ title = i18n("three") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(3) end, 					checked = highlightPlayheadTime == 3 },
			{ title = i18n("four") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(4) end, 					checked = highlightPlayheadTime == 4 },
			{ title = i18n("five") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(5) end, 					checked = highlightPlayheadTime == 5 },
			{ title = i18n("six") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(6) end, 					checked = highlightPlayheadTime == 6 },
			{ title = i18n("seven") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(7) end, 					checked = highlightPlayheadTime == 7 },
			{ title = i18n("eight") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(8) end, 					checked = highlightPlayheadTime == 8 },
			{ title = i18n("nine") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(9) end, 					checked = highlightPlayheadTime == 9 },
			{ title = i18n("ten") .. " " .. i18n("secs", {count=2}), 									fn = function() changeHighlightPlayheadTime(10) end, 					checked = highlightPlayheadTime == 10 },
		}
		local settingsMenuTable = {
			{ title = i18n("hudOptions"), 																menu = settingsHUD},
			{ title = i18n("voiceCommandOptions"), 														menu = settingsVoiceCommand},
			{ title = "Hammerspoon " .. i18n("options"),												menu = settingsHammerspoonSettings},
			{ title = "-" },
			{ title = i18n("touchBarLocation"), 														menu = settingsTouchBarLocation},
			{ title = "-" },
			{ title = i18n("highlightPlayheadColour"), 													menu = settingsColourMenuTable},
			{ title = i18n("highlightPlayheadShape"), 													menu = settingsShapeMenuTable},
			{ title = i18n("highlightPlayheadTime"), 													menu = settingsHighlightPlayheadTime},
			{ title = "-" },
			{ title = i18n("checkForUpdates"), 															fn = toggleCheckForUpdates, 										checked = enableCheckForUpdates},
			{ title = i18n("enableDebugMode"), 															fn = toggleDebugMode, 												checked = mod.debugMode},
			{ title = "-" },
			{ title = i18n("trashFCPXHacksPreferences"), 												fn = resetSettings },
			{ title = "-" },
			{ title = i18n("provideFeedback"),															fn = emailBugReport },
			{ title = "-" },
			{ title = i18n("createdBy") .. " LateNite Films", 											fn = gotoLateNiteSite },
			{ title = i18n("scriptVersion") .. " " .. metadata.scriptVersion,							disabled = true },
		}

		return settingsMenuTable
	end

	function generateMenubarPrefsMenuBar()
		--------------------------------------------------------------------------------
		-- Get Menubar Settings:
		--------------------------------------------------------------------------------
		local menubarToolsEnabled = 		settings.get("fcpxHacks.menubarToolsEnabled")
		local menubarHacksEnabled = 		settings.get("fcpxHacks.menubarHacksEnabled")

		--------------------------------------------------------------------------------
		-- Get Enable Proxy Menu Item:
		--------------------------------------------------------------------------------
		local enableProxyMenuIcon = settings.get("fcpxHacks.enableProxyMenuIcon") or false

		--------------------------------------------------------------------------------
		-- Get Menubar Display Mode from Settings:
		--------------------------------------------------------------------------------
		local displayMenubarAsIcon = settings.get("fcpxHacks.displayMenubarAsIcon") or false

		local settingsMenubar = {
			{ title = i18n("showTools"), 																fn = function() toggleMenubarDisplay("Tools") end, 					checked = menubarToolsEnabled},
			{ title = i18n("showHacks"), 																fn = function() toggleMenubarDisplay("Hacks") end, 					checked = menubarHacksEnabled},
			{ title = "-" },
			{ title = i18n("displayProxyOriginalIcon"), 												fn = toggleEnableProxyMenuIcon, 									checked = enableProxyMenuIcon},
			{ title = i18n("displayThisMenuAsIcon"), 													fn = toggleMenubarDisplayMode, 										checked = displayMenubarAsIcon},
		}
		return settingsMenubar
	end

	--------------------------------------------------------------------------------
	-- UPDATE MENUBAR ICON:
	--------------------------------------------------------------------------------
	function updateMenubarIcon()
		menuManager():updateMenubarIcon()
	end

--------------------------------------------------------------------------------
-- HELP:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- DISPLAY A LIST OF ALL SHORTCUTS:
	--------------------------------------------------------------------------------
	function displayShortcutList()
		plugins("hs.fcpxhacks.plugins.fcpx.showshortcuts")()
	end

--------------------------------------------------------------------------------
-- UPDATE EFFECTS/TRANSITIONS/TITLES/GENERATORS LISTS:
--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- GET LIST OF EFFECTS:
	--------------------------------------------------------------------------------
	function updateEffectsList()
		plugins("hs.fcpxhacks.plugins.timeline.effects").updateEffectsList()
	end

	--------------------------------------------------------------------------------
	-- GET LIST OF TRANSITIONS:
	--------------------------------------------------------------------------------
	function updateTransitionsList()
		plugins("hs.fcpxhacks.plugins.timeline.transitions").updateTransitionsList()
	end

	--------------------------------------------------------------------------------
	-- GET LIST OF TITLES:
	--------------------------------------------------------------------------------
	function updateTitlesList()
		plugins("hs.fcpxhacks.plugins.timeline.titles").updateTitlesList()
	end

	--------------------------------------------------------------------------------
	-- GET LIST OF GENERATORS:
	--------------------------------------------------------------------------------
	function updateGeneratorsList()
		plugins("hs.fcpxhacks.plugins.timeline.generators").updateGeneratorsList()
	end

--------------------------------------------------------------------------------
-- CHANGE:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- CHANGE HIGHLIGHT PLAYHEAD TIME:
	--------------------------------------------------------------------------------
	function changeHighlightPlayheadTime(value)
		settings.set("fcpxHacks.highlightPlayheadTime", value)
	end

	--------------------------------------------------------------------------------
	-- CHANGE TOUCH BAR LOCATION:
	--------------------------------------------------------------------------------
	function changeTouchBarLocation(value)
		settings.set("fcpxHacks.displayTouchBarLocation", value)

		if touchBarSupported then
			local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false
			if displayTouchBar then setTouchBarLocation() end
		end
	end

	--------------------------------------------------------------------------------
	-- CHANGE HIGHLIGHT SHAPE:
	--------------------------------------------------------------------------------
	function changeHighlightShape(value)
		settings.set("fcpxHacks.displayHighlightShape", value)
	end

	--------------------------------------------------------------------------------
	-- CHANGE HIGHLIGHT COLOUR:
	--------------------------------------------------------------------------------
	function changeHighlightColour(value)
		if value=="Custom" then
			local displayHighlightCustomColour = settings.get("fcpxHacks.displayHighlightCustomColour") or nil
			local result = dialog.displayColorPicker(displayHighlightCustomColour)
			if result == nil then return nil end
			settings.set("fcpxHacks.displayHighlightCustomColour", result)
		end
		settings.set("fcpxHacks.displayHighlightColour", value)
	end

	--------------------------------------------------------------------------------
	-- FCPX CHANGE BACKUP INTERVAL:
	--------------------------------------------------------------------------------
	function changeBackupInterval()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		if fcp:getPreference("FFPeriodicBackupInterval") == nil then
			mod.FFPeriodicBackupInterval = 15
		else
			mod.FFPeriodicBackupInterval = fcp:getPreference("FFPeriodicBackupInterval")
		end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp:isRunning() then
			if dialog.displayYesNoQuestion(i18n("changeBackupIntervalMessage") .. "\n\n" .. i18n("doYouWantToContinue")) then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Ask user what to set the backup interval to:
		--------------------------------------------------------------------------------
		local userSelectedBackupInterval = dialog.displaySmallNumberTextBoxMessage(i18n("changeBackupIntervalTextbox"), i18n("changeBackupIntervalError"), mod.FFPeriodicBackupInterval)
		if not userSelectedBackupInterval then
			return "Cancel"
		end

		--------------------------------------------------------------------------------
		-- Update plist:
		--------------------------------------------------------------------------------
		local result = fcp:setPreference("FFPeriodicBackupInterval", tostring(userSelectedBackupInterval))
		if result == nil then
			dialog.displayErrorMessage(i18n("backupIntervalFail"))
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp:restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage(i18n("failedToRestart"))
				return "Failed"
			end
		end

	end

	--------------------------------------------------------------------------------
	-- CHANGE SMART COLLECTIONS LABEL:
	--------------------------------------------------------------------------------
	function changeSmartCollectionsLabel()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		local executeResult,executeStatus = execute("/usr/libexec/PlistBuddy -c \"Print :FFOrganizerSmartCollections\" '" .. fcp:getPath() .. "/Contents/Frameworks/Flexo.framework/Versions/A/Resources/en.lproj/FFLocalizable.strings'")
		if tools.trim(executeResult) ~= "" then FFOrganizerSmartCollections = executeResult end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp:isRunning() then
			if dialog.displayYesNoQuestion(i18n("changeSmartCollectionsLabel") .. "\n\n" .. i18n("doYouWantToContinue")) then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Ask user what to set the backup interval to:
		--------------------------------------------------------------------------------
		local userSelectedSmartCollectionsLabel = dialog.displayTextBoxMessage(i18n("smartCollectionsLabelTextbox"), i18n("smartCollectionsLabelError"), tools.trim(FFOrganizerSmartCollections))
		if not userSelectedSmartCollectionsLabel then
			return "Cancel"
		end

		--------------------------------------------------------------------------------
		-- Update plist for every Flexo language:
		--------------------------------------------------------------------------------
		local executeCommands = {}
		for k, v in pairs(fcp:getFlexoLanguages()) do
			local executeCommand = "/usr/libexec/PlistBuddy -c \"Set :FFOrganizerSmartCollections " .. tools.trim(userSelectedSmartCollectionsLabel) .. "\" '" .. fcp:getPath() .. "/Contents/Frameworks/Flexo.framework/Versions/A/Resources/" .. fcp:getFlexoLanguages()[k] .. ".lproj/FFLocalizable.strings'"
			executeCommands[#executeCommands + 1] = executeCommand
		end
		local result = tools.executeWithAdministratorPrivileges(executeCommands)
		if type(result) == "string" then
			dialog.displayErrorMessage(result)
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp:restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage(i18n("failedToRestart"))
				return "Failed"
			end
		end

	end

--------------------------------------------------------------------------------
-- TOGGLE:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- TOGGLE NOTIFICATION PLATFORM:
	--------------------------------------------------------------------------------
	function toggleNotificationPlatform(value)

		local notificationPlatform 		= settings.get("fcpxHacks.notificationPlatform")
		local prowlAPIKey 				= settings.get("fcpxHacks.prowlAPIKey") or ""
		local iMessageTarget			= settings.get("fcpxHacks.iMessageTarget") or ""

		local returnToFinalCutPro 		= fcp:isFrontmost()

		if value == "Prowl" then
			if not notificationPlatform["Prowl"] then
				::retryProwlAPIKeyEntry::
				local result = dialog.displayTextBoxMessage(i18n("prowlTextbox"), i18n("prowlTextboxError") .. "\n\n" .. i18n("pleaseTryAgain"), prowlAPIKey)
				if result == false then return end
				local prowlAPIKeyValidResult, prowlAPIKeyValidError = prowlAPIKeyValid(result)
				if prowlAPIKeyValidResult then
					if returnToFinalCutPro then fcp:launch() end
					settings.set("fcpxHacks.prowlAPIKey", result)
				else
					dialog.displayMessage(i18n("prowlError") .. " " .. prowlAPIKeyValidError .. ".\n\n" .. i18n("pleaseTryAgain"))
					goto retryProwlAPIKeyEntry
				end
			end
		end

		if value == "iMessage" then
			if not notificationPlatform["iMessage"] then
				local result = dialog.displayTextBoxMessage(i18n("iMessageTextBox"), i18n("pleaseTryAgain"), iMessageTarget)
				if result == false then return end
				settings.set("fcpxHacks.iMessageTarget", result)
			end
		end

		notificationPlatform[value] = not notificationPlatform[value]
		settings.set("fcpxHacks.notificationPlatform", notificationPlatform)

		if next(notificationPlatform) == nil then
			if shareSuccessNotificationWatcher then shareSuccessNotificationWatcher:stop() end
			if shareFailedNotificationWatcher then shareFailedNotificationWatcher:stop() end
		else
			notificationWatcher()
		end

	end

	--------------------------------------------------------------------------------
	-- TOGGLE VOICE COMMAND ENABLE ANNOUNCEMENTS:
	--------------------------------------------------------------------------------
	function toggleVoiceCommandEnableAnnouncements()
		local voiceCommandEnableAnnouncements = settings.get("fcpxHacks.voiceCommandEnableAnnouncements")
		settings.set("fcpxHacks.voiceCommandEnableAnnouncements", not voiceCommandEnableAnnouncements)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE VOICE COMMAND ENABLE VISUAL ALERTS:
	--------------------------------------------------------------------------------
	function toggleVoiceCommandEnableVisualAlerts()
		local voiceCommandEnableVisualAlerts = settings.get("fcpxHacks.voiceCommandEnableVisualAlerts")
		settings.set("fcpxHacks.voiceCommandEnableVisualAlerts", not voiceCommandEnableVisualAlerts)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE SCROLLING TIMELINE:
	--------------------------------------------------------------------------------
	function toggleScrollingTimeline()
		return plugins("hs.fcpxhacks.plugins.timeline.playhead").toggleScrollingTimeline()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE LOCK PLAYHEAD:
	--------------------------------------------------------------------------------
	function togglePlayheadLock()
		return plugins("hs.fcpxhacks.plugins.timeline.playhead").togglePlayheadLock()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE ENABLE HACKS HUD:
	--------------------------------------------------------------------------------
	function toggleEnableVoiceCommands()

		local enableVoiceCommands = settings.get("fcpxHacks.enableVoiceCommands")
		settings.set("fcpxHacks.enableVoiceCommands", not enableVoiceCommands)

		if enableVoiceCommands then
			voicecommands:stop()
		else
			local result = voicecommands:new()
			if result == false then
				dialog.displayErrorMessage(i18n("voiceCommandsError"))
				settings.set("fcpxHacks.enableVoiceCommands", enableVoiceCommands)
				return
			end
			if fcp:isFrontmost() then
				voicecommands:start()
			else
				voicecommands:stop()
			end
		end
	end

	--------------------------------------------------------------------------------
	-- TOGGLE ENABLE HACKS HUD:
	--------------------------------------------------------------------------------
	function toggleEnableHacksHUD()
		local enableHacksHUD = settings.get("fcpxHacks.enableHacksHUD")
		settings.set("fcpxHacks.enableHacksHUD", not enableHacksHUD)

		if enableHacksHUD then
			hackshud.hide()
		else
			if fcp:isFrontmost() then
				hackshud.show()
			end
		end
	end

	--------------------------------------------------------------------------------
	-- TOGGLE DEBUG MODE:
	--------------------------------------------------------------------------------
	function toggleDebugMode()
		settings.set("fcpxHacks.debugMode", not mod.debugMode)
		hs.reload()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE CHECK FOR UPDATES:
	--------------------------------------------------------------------------------
	function toggleCheckForUpdates()
		local enableCheckForUpdates = settings.get("fcpxHacks.enableCheckForUpdates")
		settings.set("fcpxHacks.enableCheckForUpdates", not enableCheckForUpdates)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE MENUBAR DISPLAY:
	--------------------------------------------------------------------------------
	function toggleMenubarDisplay(value)
		local menubarEnabled = settings.get("fcpxHacks.menubar" .. value .. "Enabled")
		settings.set("fcpxHacks.menubar" .. value .. "Enabled", not menubarEnabled)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE HUD OPTION:
	--------------------------------------------------------------------------------
	function toggleHUDOption(value)
		local result = settings.get("fcpxHacks." .. value)
		settings.set("fcpxHacks." .. value, not result)
		hackshud.reload()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE CLIPBOARD HISTORY:
	--------------------------------------------------------------------------------
	function toggleEnableClipboardHistory()

		local enableSharedClipboard = settings.get("fcpxHacks.enableSharedClipboard") or false
		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false

		if not enableClipboardHistory then
			if not enableSharedClipboard then
				clipboard.startWatching()
			end
		else
			if not enableSharedClipboard then
				clipboard.stopWatching()
			end
		end
		settings.set("fcpxHacks.enableClipboardHistory", not enableClipboardHistory)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE SHARED CLIPBOARD:
	--------------------------------------------------------------------------------
	function toggleEnableSharedClipboard()

		local enableSharedClipboard = settings.get("fcpxHacks.enableSharedClipboard") or false
		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false

		if not enableSharedClipboard then

			result = dialog.displayChooseFolder("Which folder would you like to use for the Shared Clipboard?")

			if result ~= false then
				debugMessage("Enabled Shared Clipboard Path: " .. tostring(result))
				settings.set("fcpxHacks.sharedClipboardPath", result)

				--------------------------------------------------------------------------------
				-- Watch for Shared Clipboard Changes:
				--------------------------------------------------------------------------------
				sharedClipboardWatcher = pathwatcher.new(result, sharedClipboardFileWatcher):start()

				if not enableClipboardHistory then
					clipboard.startWatching()
				end

			else
				debugMessage("Enabled Shared Clipboard Choose Path Cancelled.")
				settings.set("fcpxHacks.sharedClipboardPath", nil)
				return "failed"
			end

		else

			--------------------------------------------------------------------------------
			-- Stop Watching for Shared Clipboard Changes:
			--------------------------------------------------------------------------------
			sharedClipboardWatcher:stop()

			if not enableClipboardHistory then
				clipboard.stopWatching()
			end

		end

		settings.set("fcpxHacks.enableSharedClipboard", not enableSharedClipboard)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE XML SHARING:
	--------------------------------------------------------------------------------
	function toggleEnableXMLSharing()

		local enableXMLSharing = settings.get("fcpxHacks.enableXMLSharing") or false

		if not enableXMLSharing then

			xmlSharingPath = dialog.displayChooseFolder("Which folder would you like to use for XML Sharing?")

			if xmlSharingPath ~= false then
				settings.set("fcpxHacks.xmlSharingPath", xmlSharingPath)
			else
				settings.set("fcpxHacks.xmlSharingPath", nil)
				return "Cancelled"
			end

			--------------------------------------------------------------------------------
			-- Watch for Shared XML Folder Changes:
			--------------------------------------------------------------------------------
			sharedXMLWatcher = pathwatcher.new(xmlSharingPath, sharedXMLFileWatcher):start()

		else
			--------------------------------------------------------------------------------
			-- Stop Watchers:
			--------------------------------------------------------------------------------
			sharedXMLWatcher:stop()

			--------------------------------------------------------------------------------
			-- Clear Settings:
			--------------------------------------------------------------------------------
			settings.set("fcpxHacks.xmlSharingPath", nil)
		end

		settings.set("fcpxHacks.enableXMLSharing", not enableXMLSharing)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE HAMMERSPOON DOCK ICON:
	--------------------------------------------------------------------------------
	function toggleHammerspoonDockIcon()
		local originalValue = hs.dockIcon()
		hs.dockIcon(not originalValue)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE HAMMERSPOON MENU ICON:
	--------------------------------------------------------------------------------
	function toggleHammerspoonMenuIcon()
		local originalValue = hs.menuIcon()
		hs.menuIcon(not originalValue)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE LAUNCH HAMMERSPOON ON START:
	--------------------------------------------------------------------------------
	function toggleLaunchHammerspoonOnStartup()
		local originalValue = hs.autoLaunch()
		hs.autoLaunch(not originalValue)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE HAMMERSPOON CHECK FOR UPDATES:
	--------------------------------------------------------------------------------
	function toggleCheckforHammerspoonUpdates()
		local originalValue = hs.automaticallyCheckForUpdates()
		hs.automaticallyCheckForUpdates(not originalValue)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE ENABLE PROXY MENU ICON:
	--------------------------------------------------------------------------------
	function toggleEnableProxyMenuIcon()
		local enableProxyMenuIcon = settings.get("fcpxHacks.enableProxyMenuIcon")
		if enableProxyMenuIcon == nil then
			settings.set("fcpxHacks.enableProxyMenuIcon", true)
			enableProxyMenuIcon = true
		else
			settings.set("fcpxHacks.enableProxyMenuIcon", not enableProxyMenuIcon)
		end

		updateMenubarIcon()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE HACKS SHORTCUTS IN FINAL CUT PRO:
	--------------------------------------------------------------------------------
	function toggleEnableHacksShortcutsInFinalCutPro()

		--------------------------------------------------------------------------------
		-- Get current value from settings:
		--------------------------------------------------------------------------------
		local enableHacksShortcutsInFinalCutPro = settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro")
		if enableHacksShortcutsInFinalCutPro == nil then enableHacksShortcutsInFinalCutPro = false end

		--------------------------------------------------------------------------------
		-- Are we enabling or disabling?
		--------------------------------------------------------------------------------
		local enableOrDisableText = nil
		if enableHacksShortcutsInFinalCutPro then
			enableOrDisableText = "Disabling"
		else
			enableOrDisableText = "Enabling"
		end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp:isRunning() then
			if dialog.displayYesNoQuestion(enableOrDisableText .. " " .. i18n("hacksShortcutsRestart") .. " " .. i18n("doYouWantToContinue")) then
				restartStatus = true
			else
				return "Done"
			end
		else
			if not dialog.displayYesNoQuestion(enableOrDisableText .. " " .. i18n("hacksShortcutAdminPassword") .. " " .. i18n("doYouWantToContinue")) then
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Let's do it!
		--------------------------------------------------------------------------------
		local saveSettings = false
		if enableHacksShortcutsInFinalCutPro then
			--------------------------------------------------------------------------------
			-- Disable Hacks Shortcut in Final Cut Pro:
			--------------------------------------------------------------------------------
			local result = disableHacksShortcuts()
			if type(result) == "string" then
				dialog.displayErrorMessage(result)
				return false
			elseif result == false then
				--------------------------------------------------------------------------------
				-- Cancelled at Admin Password:
				--------------------------------------------------------------------------------
				return
			end
		else
			--------------------------------------------------------------------------------
			-- Enable Hacks Shortcut in Final Cut Pro:
			--------------------------------------------------------------------------------
			local result = enableHacksShortcuts()
			if type(result) == "string" then
				dialog.displayErrorMessage(result)
				return false
			elseif result == false then
				--------------------------------------------------------------------------------
				-- Cancelled at Admin Password:
				--------------------------------------------------------------------------------
				return
			end
		end

		--------------------------------------------------------------------------------
		-- Save new value to settings:
		--------------------------------------------------------------------------------
		settings.set("fcpxHacks.enableHacksShortcutsInFinalCutPro", not enableHacksShortcutsInFinalCutPro)

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp:restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage(i18n("failedToRestart"))
			end
		end

		--------------------------------------------------------------------------------
		-- Refresh the Keyboard Shortcuts:
		--------------------------------------------------------------------------------
		bindKeyboardShortcuts()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE MOVING MARKERS:
	--------------------------------------------------------------------------------
	function toggleMovingMarkers()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		mod.allowMovingMarkers = false
		local executeResult,executeStatus = execute("/usr/libexec/PlistBuddy -c \"Print :TLKMarkerHandler:Configuration:'Allow Moving Markers'\" '" .. fcp:getPath() .. "/Contents/Frameworks/TLKit.framework/Versions/A/Resources/EventDescriptions.plist'")
		if tools.trim(executeResult) == "true" then mod.allowMovingMarkers = true end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp:isRunning() then
			if dialog.displayYesNoQuestion(i18n("togglingMovingMarkersRestart") .. "\n\n" .. i18n("doYouWantToContinue")) then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Update plist:
		--------------------------------------------------------------------------------
		if mod.allowMovingMarkers then
			local result = tools.executeWithAdministratorPrivileges([[/usr/libexec/PlistBuddy -c \"Set :TLKMarkerHandler:Configuration:'Allow Moving Markers' false\" ']] .. fcp:getPath() .. [[/Contents/Frameworks/TLKit.framework/Versions/A/Resources/EventDescriptions.plist']])
			if type(result) == "string" then
				dialog.displayErrorMessage(result)
			end
		else
			local executeStatus = tools.executeWithAdministratorPrivileges([[/usr/libexec/PlistBuddy -c \"Set :TLKMarkerHandler:Configuration:'Allow Moving Markers' true\" ']] .. fcp:getPath() .. [[/Contents/Frameworks/TLKit.framework/Versions/A/Resources/EventDescriptions.plist']])
			if type(result) == "string" then
				dialog.displayErrorMessage(result)
			end
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp:restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage(i18n("failedToRestart"))
				return "Failed"
			end
		end
	end

	--------------------------------------------------------------------------------
	-- TOGGLE PERFORM TASKS DURING PLAYBACK:
	--------------------------------------------------------------------------------
	function togglePerformTasksDuringPlayback()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		if fcp:getPreference("FFSuspendBGOpsDuringPlay") == nil then
			mod.FFSuspendBGOpsDuringPlay = false
		else
			mod.FFSuspendBGOpsDuringPlay = fcp:getPreference("FFSuspendBGOpsDuringPlay")
		end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp:isRunning() then
			if dialog.displayYesNoQuestion(i18n("togglingBackgroundTasksRestart") .. "\n\n" ..i18n("doYouWantToContinue")) then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Update plist:
		--------------------------------------------------------------------------------
		local result = fcp:setPreference("FFSuspendBGOpsDuringPlay", not mod.FFSuspendBGOpsDuringPlay)
		if result == nil then
			dialog.displayErrorMessage(i18n("failedToWriteToPreferences"))
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp:restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage(i18n("failedToRestart"))
				return "Failed"
			end
		end
	end

	--------------------------------------------------------------------------------
	-- TOGGLE TIMECODE OVERLAY:
	--------------------------------------------------------------------------------
	function toggleTimecodeOverlay()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		if fcp:getPreference("FFEnableGuards") == nil then
			mod.FFEnableGuards = false
		else
			mod.FFEnableGuards = fcp:getPreference("FFEnableGuards")
		end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp:isRunning() then
			if dialog.displayYesNoQuestion(i18n("togglingTimecodeOverlayRestart") .. "\n\n" .. i18n("doYouWantToContinue")) then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Update plist:
		--------------------------------------------------------------------------------
		local result = fcp:setPreference("FFEnableGuards", not mod.FFEnableGuards)
		if result == nil then
			dialog.displayErrorMessage(i18n("failedToWriteToPreferences"))
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp:restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage(i18n("failedToRestart"))
				return "Failed"
			end
		end
	end

	--------------------------------------------------------------------------------
	-- TOGGLE MENUBAR DISPLAY MODE:
	--------------------------------------------------------------------------------
	function toggleMenubarDisplayMode()

		local displayMenubarAsIcon = settings.get("fcpxHacks.displayMenubarAsIcon")


		if displayMenubarAsIcon == nil then
			 settings.set("fcpxHacks.displayMenubarAsIcon", true)
		else
			if displayMenubarAsIcon then
				settings.set("fcpxHacks.displayMenubarAsIcon", false)
			else
				settings.set("fcpxHacks.displayMenubarAsIcon", true)
			end
		end

		updateMenubarIcon()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE CREATE MULTI-CAM OPTIMISED MEDIA:
	--------------------------------------------------------------------------------
	function toggleCreateMulticamOptimizedMedia(optionalValue)
		return plugins("hs.fcpxhacks.plugins.fcpx.prefs").toggleCreateMulticamOptimizedMedia(optionalValue)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE CREATE PROXY MEDIA:
	--------------------------------------------------------------------------------
	function toggleCreateProxyMedia(optionalValue)
		return plugins("hs.fcpxhacks.plugins.fcpx.prefs").toggleCreateProxyMedia(optionalValue)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE CREATE OPTIMIZED MEDIA:
	-- TODO: Delete this once commands have been migrated.
	--------------------------------------------------------------------------------
	function toggleCreateOptimizedMedia(optionalValue)
		return plugins("hs.fcpxhacks.plugins.fcpx.prefs").toggleCreateOptimizedMedia(optionalValue)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE LEAVE IN PLACE ON IMPORT:
	--------------------------------------------------------------------------------
	function toggleLeaveInPlace(optionalValue)
		return plugins("hs.fcpxhacks.plugins.fcpx.prefs").toggleLeaveInPlace(optionalValue)
	end

	--------------------------------------------------------------------------------
	-- TOGGLE BACKGROUND RENDER:
	--------------------------------------------------------------------------------
	function toggleBackgroundRender(optionalValue)
		return plugins("hs.fcpxhacks.plugins.fcpx.prefs").toggleBackgroundRender(optionalValue)
	end

--------------------------------------------------------------------------------
-- PASTE:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- PASTE FROM CLIPBOARD HISTORY:
	--------------------------------------------------------------------------------
	function finalCutProPasteFromClipboardHistory(data)

		--------------------------------------------------------------------------------
		-- Write data back to Clipboard:
		--------------------------------------------------------------------------------
		clipboard.stopWatching()
		pasteboard.writeDataForUTI(fcp:getPasteboardUTI(), data)
		clipboard.startWatching()

		--------------------------------------------------------------------------------
		-- Paste in FCPX:
		--------------------------------------------------------------------------------
		fcp:launch()
		if not fcp:performShortcut("Paste") then
			dialog.displayErrorMessage("Failed to trigger the 'Paste' Shortcut.\n\nError occurred in finalCutProPasteFromClipboardHistory().")
			return "Failed"
		end

	end

	--------------------------------------------------------------------------------
	-- PASTE FROM SHARED CLIPBOARD:
	--------------------------------------------------------------------------------
	function pasteFromSharedClipboard(pathToClipboardFile, whichClipboard)

		if tools.doesFileExist(pathToClipboardFile) then
			local plistData = plist.xmlFileToTable(pathToClipboardFile)
			if plistData ~= nil then

				--------------------------------------------------------------------------------
				-- Decode Shared Clipboard Data from Plist:
				--------------------------------------------------------------------------------
				local currentClipboardData = base64.decode(plistData["SharedClipboardData" .. whichClipboard])

				--------------------------------------------------------------------------------
				-- Write data back to Clipboard:
				--------------------------------------------------------------------------------
				clipboard.stopWatching()
				pasteboard.writeDataForUTI(fcp:getPasteboardUTI(), currentClipboardData)
				clipboard.startWatching()

				--------------------------------------------------------------------------------
				-- Paste in FCPX:
				--------------------------------------------------------------------------------
				fcp:launch()
				if not fcp:performShortcut("Paste") then
					dialog.displayErrorMessage("Failed to trigger the 'Paste' Shortcut.\n\nError occurred in pasteFromSharedClipboard().")
					return "Failed"
				end

			else
				dialog.errorMessage(i18n("sharedClipboardNotRead"))
				return "Fail"
			end
		else
			dialog.displayMessage(i18n("sharedClipboardFileNotFound"))
			return "Fail"
		end

	end

--------------------------------------------------------------------------------
-- CLEAR:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- CLEAR CLIPBOARD HISTORY:
	--------------------------------------------------------------------------------
	function clearClipboardHistory()
		clipboard.clearHistory()
	end

	--------------------------------------------------------------------------------
	-- CLEAR SHARED CLIPBOARD HISTORY:
	--------------------------------------------------------------------------------
	function clearSharedClipboardHistory()
		local sharedClipboardPath = settings.get("fcpxHacks.sharedClipboardPath")
		for file in fs.dir(sharedClipboardPath) do
			 if file:sub(-10) == ".fcpxhacks" then
				os.remove(sharedClipboardPath .. file)
			 end
		end
	end

	--------------------------------------------------------------------------------
	-- CLEAR SHARED XML FILES:
	--------------------------------------------------------------------------------
	function clearSharedXMLFiles()

		local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")
		for folder in fs.dir(xmlSharingPath) do
			if tools.doesDirectoryExist(xmlSharingPath .. "/" .. folder) then
				for file in fs.dir(xmlSharingPath .. "/" .. folder) do
					if file:sub(-7) == ".fcpxml" then
						os.remove(xmlSharingPath .. folder .. "/" .. file)
					end
				end
			end
		end
	end

--------------------------------------------------------------------------------
-- OTHER:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- QUIT FCPX HACKS:
	--------------------------------------------------------------------------------
	function quitFCPXHacks()
		plugins("hs.fcpxhacks.plugins.hacks.quit")()
	end

	--------------------------------------------------------------------------------
	-- OPEN HAMMERSPOON CONSOLE:
	--------------------------------------------------------------------------------
	function openHammerspoonConsole()
		hs.openConsole()
	end

	--------------------------------------------------------------------------------
	-- RESET SETTINGS:
	--------------------------------------------------------------------------------
	function resetSettings()

		local finalCutProRunning = fcp:isRunning()

		local resetMessage = i18n("trashFCPXHacksPreferences")
		if finalCutProRunning then
			resetMessage = resetMessage .. "\n\n" .. i18n("adminPasswordRequiredAndRestart")
		else
			resetMessage = resetMessage .. "\n\n" .. i18n("adminPasswordRequired")
		end

		if not dialog.displayYesNoQuestion(resetMessage) then
		 	return
		end

		--------------------------------------------------------------------------------
		-- Remove Hacks Shortcut in Final Cut Pro:
		--------------------------------------------------------------------------------
		local result = disableHacksShortcuts()
		if type(result) == "string" then
			dialog.displayErrorMessage(result)
		end

		--------------------------------------------------------------------------------
		-- Trash all FCPX Hacks Settings:
		--------------------------------------------------------------------------------
		for i, v in ipairs(settings.getKeys()) do
			if (v:sub(1,10)) == "fcpxHacks." then
				settings.set(v, nil)
			end
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro if running:
		--------------------------------------------------------------------------------
		if finalCutProRunning then
			if not fcp:restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayMessage(i18n("restartFinalCutProFailed"))
			end
		end

		--------------------------------------------------------------------------------
		-- Reload Hammerspoon:
		--------------------------------------------------------------------------------
		hs.reload()

	end

	--------------------------------------------------------------------------------
	-- GET SCRIPT UPDATE:
	--------------------------------------------------------------------------------
	function getScriptUpdate()
		os.execute('open "' .. metadata.updateURL .. '"')
	end

	--------------------------------------------------------------------------------
	-- GO TO LATENITE FILMS SITE:
	--------------------------------------------------------------------------------
	function gotoLateNiteSite()
		os.execute('open "' .. metadata.developerURL .. '"')
	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   S H O R T C U T   F E A T U R E S                        --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- KEYWORDS:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- SAVE KEYWORDS:
	--------------------------------------------------------------------------------
	function saveKeywordSearches(whichButton)

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Check to see if the Keyword Editor is already open:
		--------------------------------------------------------------------------------
		local fcpx = fcp:application()
		local fcpxElements = ax.applicationElement(fcpx)
		local whichWindow = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements[i]:attributeValue("AXRole") == "AXWindow" then
				if fcpxElements[i]:attributeValue("AXIdentifier") == "_NS:264" then
					whichWindow = i
				end
			end
		end
		if whichWindow == nil then
			dialog.displayMessage(i18n("keywordEditorAlreadyOpen"))
			return
		end
		fcpxElements = fcpxElements[whichWindow]

		--------------------------------------------------------------------------------
		-- Get Starting Textfield:
		--------------------------------------------------------------------------------
		local startTextField = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if startTextField == nil then
				if fcpxElements[i]:attributeValue("AXIdentifier") == "_NS:102" then
					startTextField = i
					goto startTextFieldDone
				end
			end
		end
		::startTextFieldDone::
		if startTextField == nil then
			--------------------------------------------------------------------------------
			-- Keyword Shortcuts Buttons isn't down:
			--------------------------------------------------------------------------------
			fcpxElements = ax.applicationElement(fcpx)[1] -- Refresh
			for i=1, fcpxElements:attributeValueCount("AXChildren") do
				if fcpxElements[i]:attributeValue("AXIdentifier") == "_NS:276" then
					keywordDisclosureTriangle = i
					goto keywordDisclosureTriangleDone
				end
			end
			::keywordDisclosureTriangleDone::
			if fcpxElements[keywordDisclosureTriangle] == nil then
				dialog.displayMessage(i18n("keywordShortcutsVisibleError"))
				return "Failed"
			else
				local keywordDisclosureTriangleResult = fcpxElements[keywordDisclosureTriangle]:performAction("AXPress")
				if keywordDisclosureTriangleResult == nil then
					dialog.displayMessage(i18n("keywordShortcutsVisibleError"))
					return "Failed"
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Get Values from the Keyword Editor:
		--------------------------------------------------------------------------------
		local savedKeywordValues = {}
		local favoriteCount = 1
		local skipFirst = true
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements[i]:attributeValue("AXRole") == "AXTextField" then
				if skipFirst then
					skipFirst = false
				else
					savedKeywordValues[favoriteCount] = fcpxElements[i]:attributeValue("AXHelp")
					favoriteCount = favoriteCount + 1
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Save Values to Settings:
		--------------------------------------------------------------------------------
		local savedKeywords = settings.get("fcpxHacks.savedKeywords")
		if savedKeywords == nil then savedKeywords = {} end
		for i=1, 9 do
			if savedKeywords['Preset ' .. tostring(whichButton)] == nil then
				savedKeywords['Preset ' .. tostring(whichButton)] = {}
			end
			savedKeywords['Preset ' .. tostring(whichButton)]['Item ' .. tostring(i)] = savedKeywordValues[i]
		end
		settings.set("fcpxHacks.savedKeywords", savedKeywords)

		--------------------------------------------------------------------------------
		-- Saved:
		--------------------------------------------------------------------------------
		dialog.displayNotification(i18n("keywordPresetsSaved") .. " " .. tostring(whichButton))

	end

	--------------------------------------------------------------------------------
	-- RESTORE KEYWORDS:
	--------------------------------------------------------------------------------
	function restoreKeywordSearches(whichButton)

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get Values from Settings:
		--------------------------------------------------------------------------------
		local savedKeywords = settings.get("fcpxHacks.savedKeywords")
		local restoredKeywordValues = {}

		if savedKeywords == nil then
			dialog.displayMessage(i18n("noKeywordPresetsError"))
			return "Fail"
		end
		if savedKeywords['Preset ' .. tostring(whichButton)] == nil then
			dialog.displayMessage(i18n("noKeywordPresetError"))
			return "Fail"
		end
		for i=1, 9 do
			restoredKeywordValues[i] = savedKeywords['Preset ' .. tostring(whichButton)]['Item ' .. tostring(i)]
		end

		--------------------------------------------------------------------------------
		-- Check to see if the Keyword Editor is already open:
		--------------------------------------------------------------------------------
		local fcpx = fcp:application()
		local fcpxElements = ax.applicationElement(fcpx)
		local whichWindow = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements[i]:attributeValue("AXRole") == "AXWindow" then
				if fcpxElements[i]:attributeValue("AXIdentifier") == "_NS:264" then
					whichWindow = i
				end
			end
		end
		if whichWindow == nil then
			dialog.displayMessage(i18n("keywordEditorAlreadyOpen"))
			return
		end
		fcpxElements = fcpxElements[whichWindow]

		--------------------------------------------------------------------------------
		-- Get Starting Textfield:
		--------------------------------------------------------------------------------
		local startTextField = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if startTextField == nil then
				if fcpxElements[i]:attributeValue("AXIdentifier") == "_NS:102" then
					startTextField = i
					goto startTextFieldDone
				end
			end
		end
		::startTextFieldDone::
		if startTextField == nil then
			--------------------------------------------------------------------------------
			-- Keyword Shortcuts Buttons isn't down:
			--------------------------------------------------------------------------------
			local keywordDisclosureTriangle = nil
			for i=1, fcpxElements:attributeValueCount("AXChildren") do
				if fcpxElements[i]:attributeValue("AXIdentifier") == "_NS:276" then
					keywordDisclosureTriangle = i
					goto keywordDisclosureTriangleDone
				end
			end
			::keywordDisclosureTriangleDone::

			if fcpxElements[keywordDisclosureTriangle] ~= nil then
				local keywordDisclosureTriangleResult = fcpxElements[keywordDisclosureTriangle]:performAction("AXPress")
				if keywordDisclosureTriangleResult == nil then
					dialog.displayMessage(i18n("keywordShortcutsVisibleError"))
					return "Failed"
				end
			else
				dialog.displayErrorMessage("Could not find keyword disclosure triangle.\n\nError occurred in restoreKeywordSearches().")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Restore Values to Keyword Editor:
		--------------------------------------------------------------------------------
		local favoriteCount = 1
		local skipFirst = true
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements[i]:attributeValue("AXRole") == "AXTextField" then
				if skipFirst then
					skipFirst = false
				else
					currentKeywordSelection = fcpxElements[i]

					setKeywordResult = currentKeywordSelection:setAttributeValue("AXValue", restoredKeywordValues[favoriteCount])
					keywordActionResult = currentKeywordSelection:setAttributeValue("AXFocused", true)
					eventtap.keyStroke({""}, "return")

					--------------------------------------------------------------------------------
					-- If at first you don't succeed, try, oh try, again!
					--------------------------------------------------------------------------------
					if fcpxElements[i][1]:attributeValue("AXValue") ~= restoredKeywordValues[favoriteCount] then
						setKeywordResult = currentKeywordSelection:setAttributeValue("AXValue", restoredKeywordValues[favoriteCount])
						keywordActionResult = currentKeywordSelection:setAttributeValue("AXFocused", true)
						eventtap.keyStroke({""}, "return")
					end

					favoriteCount = favoriteCount + 1
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Successfully Restored:
		--------------------------------------------------------------------------------
		dialog.displayNotification(i18n("keywordPresetsRestored") .. " " .. tostring(whichButton))

	end

--------------------------------------------------------------------------------
-- MATCH FRAME RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- PERFORM MULTICAM MATCH FRAME:
	--------------------------------------------------------------------------------
	function multicamMatchFrame(goBackToTimeline) -- True or False

		local errorFunction = "\n\nError occurred in multicamMatchFrame()."

		--------------------------------------------------------------------------------
		-- Just in case:
		--------------------------------------------------------------------------------
		if goBackToTimeline == nil then goBackToTimeline = true end
		if type(goBackToTimeline) ~= "boolean" then goBackToTimeline = true end

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		local contents = fcp:timeline():contents()

		--------------------------------------------------------------------------------
		-- Store the originally-selected clips
		--------------------------------------------------------------------------------
		local originalSelection = contents:selectedClipsUI()

		--------------------------------------------------------------------------------
		-- If nothing is selected, select the top clip under the playhead:
		--------------------------------------------------------------------------------
		if not originalSelection or #originalSelection == 0 then
			local playheadClips = contents:playheadClipsUI(true)
			contents:selectClip(playheadClips[1])
		elseif #originalSelection > 1 then
			debugMessage("Unable to match frame on multiple clips." .. errorFunction)
			return false
		end

		--------------------------------------------------------------------------------
		-- Get Multicam Angle:
		--------------------------------------------------------------------------------
		local multicamAngle = getMulticamAngleFromSelectedClip()
		if multicamAngle == false then
			debugMessage("The selected clip is not a multicam clip." .. errorFunction)
			contents:selectClips(originalSelection)
			return false
		end

		--------------------------------------------------------------------------------
		-- Open in Angle Editor:
		--------------------------------------------------------------------------------
		local menuBar = fcp:menuBar()
		if menuBar:isEnabled("Clip", "Open Clip") then
			menuBar:selectMenu("Clip", "Open Clip")
		else
			dialog.displayErrorMessage("Failed to open clip in Angle Editor.\n\nAre you sure the clip you have selected is a Multicam?" .. errorFunction)
			return false
		end

		--------------------------------------------------------------------------------
		-- Put focus back on the timeline:
		--------------------------------------------------------------------------------
		if menuBar:isEnabled("Window", "Go To", "Timeline") then
			menuBar:selectMenu("Window", "Go To", "Timeline")
		else
			dialog.displayErrorMessage("Unable to return to timeline." .. errorFunction)
			return false
		end

		--------------------------------------------------------------------------------
		-- Ensure the playhead is visible:
		--------------------------------------------------------------------------------
		contents:playhead():show()

		contents:selectClipInAngle(multicamAngle)

		--------------------------------------------------------------------------------
		-- Reveal In Browser:
		--------------------------------------------------------------------------------
		if menuBar:isEnabled("File", "Reveal in Browser") then
			menuBar:selectMenu("File", "Reveal in Browser")
		end

		--------------------------------------------------------------------------------
		-- Go back to original timeline if appropriate:
		--------------------------------------------------------------------------------
		if goBackToTimeline then
			if menuBar:isEnabled("View", "Timeline History Back") then
				menuBar:selectMenu("View", "Timeline History Back")
			else
				dialog.displayErrorMessage("Unable to go back to previous timeline." .. errorFunction)
				return false
			end
		end

		--------------------------------------------------------------------------------
		-- Select the original clips again.
		--------------------------------------------------------------------------------
		contents:selectClips(originalSelection)

		--------------------------------------------------------------------------------
		-- Highlight Browser Playhead:
		--------------------------------------------------------------------------------
		highlightFCPXBrowserPlayhead()

	end

		--------------------------------------------------------------------------------
		-- GET MULTICAM ANGLE FROM SELECTED CLIP:
		--------------------------------------------------------------------------------
		function getMulticamAngleFromSelectedClip()

			local errorFunction = "\n\nError occurred in getMulticamAngleFromSelectedClip()."

			--------------------------------------------------------------------------------
			-- Ninja Pasteboard Copy:
			--------------------------------------------------------------------------------
			local result, clipboardData = ninjaPasteboardCopy()
			if not result then
				debugMessage("ERROR: Ninja Pasteboard Copy Failed." .. errorFunction)
				return false
			end

			--------------------------------------------------------------------------------
			-- Convert Binary Data to Table:
			--------------------------------------------------------------------------------
			local fcpxTable = clipboard.unarchiveFCPXData(clipboardData)
			if fcpxTable == nil then
				debugMessage("ERROR: Converting Binary Data to Table failed." .. errorFunction)
				return false
			end

			local timelineClip = fcpxTable.root.objects[1]
			if not clipboard.isTimelineClip(timelineClip) then
				debugMessage("ERROR: Not copied from the Timeline." .. errorFunction)
				return false
			end

			local selectedClips = timelineClip.containedItems
			if #selectedClips ~= 1 or clipboard.getClassname(selectedClips[1]) ~= "FFAnchoredAngle" then
				debugMessage("ERROR: Expected a single Multicam clip to be copied." .. errorFunction)
				return false
			end

			local multicamClip = selectedClips[1]
			local videoAngle = multicamClip.videoAngle

			--------------------------------------------------------------------------------
			-- Find the original media:
			--------------------------------------------------------------------------------
			local mediaId = multicamClip.media.mediaIdentifier
			local media = nil
			for i,item in ipairs(fcpxTable.media) do
				if item.mediaIdentifier == mediaId then
					media = item
					break
				end
			end

			if media == nil or not media.primaryObject or not media.primaryObject.isMultiAngle then
				debugMessage("ERROR: Couldn't find the media for the multicam clip.")
				return false
			end

			--------------------------------------------------------------------------------
			-- Find the Angle
			--------------------------------------------------------------------------------

			local angles = media.primaryObject.containedItems[1].anchoredItems
			for i,angle in ipairs(angles) do
				if angle.angleID == videoAngle then
					return angle.anchoredLane
				end
			end

			debugMessage("ERROR: Failed to get anchoredLane." .. errorFunction)
			return false
		end

	--------------------------------------------------------------------------------
	-- MATCH FRAME THEN HIGHLIGHT FCPX BROWSER PLAYHEAD:
	--------------------------------------------------------------------------------
	function matchFrameThenHighlightFCPXBrowserPlayhead()

		--------------------------------------------------------------------------------
		-- Check the option is available in the current context
		--------------------------------------------------------------------------------
		if not fcp:menuBar():isEnabled("File", "Reveal in Browser") then
			return nil
		end

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Click on 'Reveal in Browser':
		--------------------------------------------------------------------------------
		fcp:menuBar():selectMenu("File", "Reveal in Browser")
		highlightFCPXBrowserPlayhead()

	end

	--------------------------------------------------------------------------------
	-- FCPX SINGLE MATCH FRAME:
	--------------------------------------------------------------------------------
	function singleMatchFrame()

		--------------------------------------------------------------------------------
		-- Check the option is available in the current context
		--------------------------------------------------------------------------------
		if not fcp:menuBar():isEnabled("File", "Reveal in Browser") then
			return nil
		end

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		local libraries = fcp:libraries()
		local selectedClips


		--------------------------------------------------------------------------------
		-- Clear the selection first
		--------------------------------------------------------------------------------
		libraries:deselectAll()

		--------------------------------------------------------------------------------
		-- Trigger the menu item to reveal the clip
		--------------------------------------------------------------------------------
		fcp:menuBar():selectMenu("File", "Reveal in Browser")

		--------------------------------------------------------------------------------
		-- Give FCPX time to find the clip
		--------------------------------------------------------------------------------
		just.doUntil(function()
			selectedClips = libraries:selectedClipsUI()
			return selectedClips and #selectedClips > 0
		end)

		--------------------------------------------------------------------------------
		-- Get Check that there is exactly one Selected Clip
		--------------------------------------------------------------------------------
		if not selectedClips or #selectedClips ~= 1 then
			dialog.displayErrorMessage("Expected exactly 1 selected clip in the Libraries Browser.\n\nError occurred in singleMatchFrame().")
			return nil
		end

		--------------------------------------------------------------------------------
		-- Get Browser Playhead:
		--------------------------------------------------------------------------------
		local playhead = libraries:playhead()
		if not playhead:isShowing() then
			dialog.displayErrorMessage("Unable to find Browser Persistent Playhead.\n\nError occurred in singleMatchFrame().")
			return nil
		end

		--------------------------------------------------------------------------------
		-- Get Clip Name from the Viewer
		--------------------------------------------------------------------------------
		local clipName = fcp:viewer():getTitle()

		if clipName then
			--------------------------------------------------------------------------------
			-- Ensure the Search Bar is visible
			--------------------------------------------------------------------------------
			if not libraries:search():isShowing() then
				libraries:searchToggle():press()
			end

			--------------------------------------------------------------------------------
			-- Search for the title
			--------------------------------------------------------------------------------
			libraries:search():setValue(clipName)
		else
			debugMessage("Unable to find the clip title.")
		end

		--------------------------------------------------------------------------------
		-- Highlight Browser Playhead:
		--------------------------------------------------------------------------------
		highlightFCPXBrowserPlayhead()
	end

--------------------------------------------------------------------------------
-- COLOR BOARD RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- COLOR BOARD - PUCK SELECTION:
	--------------------------------------------------------------------------------
	function colorBoardSelectPuck(aspect, property, whichDirection)

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Show the Color Board with the correct panel
		--------------------------------------------------------------------------------
		local colorBoard = fcp:colorBoard()

		--------------------------------------------------------------------------------
		-- Show the Color Board if it's hidden:
		--------------------------------------------------------------------------------
		if not colorBoard:isShowing() then colorBoard:show() end

		if not colorBoard:isActive() then
			dialog.displayNotification(i18n("pleaseSelectSingleClipInTimeline"))
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- If a Direction is specified:
		--------------------------------------------------------------------------------
		if whichDirection ~= nil then

			--------------------------------------------------------------------------------
			-- Get shortcut key from plist, press and hold if required:
			--------------------------------------------------------------------------------
			mod.releaseColorBoardDown = false
			timer.doUntil(function() return mod.releaseColorBoardDown end, function()
				if whichDirection == "up" then
					colorBoard:shiftPercentage(aspect, property, 1)
				elseif whichDirection == "down" then
					colorBoard:shiftPercentage(aspect, property, -1)
				elseif whichDirection == "left" then
					colorBoard:shiftAngle(aspect, property, -1)
				elseif whichDirection == "right" then
					colorBoard:shiftAngle(aspect, property, 1)
				end
			end, eventtap.keyRepeatInterval())
		else -- just select the puck
			colorBoard:selectPuck(aspect, property)
		end
	end

		--------------------------------------------------------------------------------
		-- COLOR BOARD - RELEASE KEYPRESS:
		--------------------------------------------------------------------------------
		function colorBoardSelectPuckRelease()
			mod.releaseColorBoardDown = true
		end

	--------------------------------------------------------------------------------
	-- COLOR BOARD - PUCK CONTROL VIA MOUSE:
	--------------------------------------------------------------------------------
	function colorBoardMousePuck(aspect, property)
		--------------------------------------------------------------------------------
		-- Stop Existing Color Pucker:
		--------------------------------------------------------------------------------
		if mod.colorPucker then
			mod.colorPucker:stop()
		end

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		colorBoard = fcp:colorBoard()

		--------------------------------------------------------------------------------
		-- Show the Color Board if it's hidden:
		--------------------------------------------------------------------------------
		if not colorBoard:isShowing() then colorBoard:show() end

		if not colorBoard:isActive() then
			dialog.displayNotification(i18n("pleaseSelectSingleClipInTimeline"))
			return "Failed"
		end

		mod.colorPucker = colorBoard:startPucker(aspect, property)
	end

		--------------------------------------------------------------------------------
		-- COLOR BOARD - RELEASE MOUSE KEYPRESS:
		--------------------------------------------------------------------------------
		function colorBoardMousePuckRelease()
			if mod.colorPucker then
				mod.colorPucker:stop()
				mod.colorPicker = nil
			end
		end

--------------------------------------------------------------------------------
-- EFFECTS/TRANSITIONS/TITLES/GENERATOR RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- TRANSITIONS SHORTCUT PRESSED:
	--------------------------------------------------------------------------------
	function transitionsShortcut(whichShortcut)
		return plugins("hs.fcpxhacks.plugins.timeline.transitions").apply(whichShortcut)
	end

	--------------------------------------------------------------------------------
	-- EFFECTS SHORTCUT PRESSED:
	--------------------------------------------------------------------------------
	function effectsShortcut(whichShortcut)
		return plugins("hs.fcpxhacks.plugins.timeline.effects").apply(whichShortcut)
	end

	--------------------------------------------------------------------------------
	-- TITLES SHORTCUT PRESSED:
	--------------------------------------------------------------------------------
	function titlesShortcut(whichShortcut)
		return plugins("hs.fcpxhacks.plugins.timeline.titles").apply(whichShortcut)
	end

	--------------------------------------------------------------------------------
	-- GENERATORS SHORTCUT PRESSED:
	--------------------------------------------------------------------------------
	function generatorsShortcut(whichShortcut)
		return plugins("hs.fcpxhacks.plugins.timeline.generators").apply(whichShortcut)
	end

--------------------------------------------------------------------------------
-- CLIPBOARD RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- COPY WITH CUSTOM LABEL:
	--------------------------------------------------------------------------------
	function copyWithCustomLabel()
		local menuBar = fcp:menuBar()
		if menuBar:isEnabled("Edit", "Copy") then
			local result = dialog.displayTextBoxMessage("Please enter a label for the clipboard item:", "The value you entered is not valid.\n\nPlease try again.", "")
			if result == false then return end
			clipboard.setName(result)
			menuBar:selectMenu("Edit", "Copy")
		end
	end

	--------------------------------------------------------------------------------
	-- COPY WITH CUSTOM LABEL & FOLDER:
	--------------------------------------------------------------------------------
	function copyWithCustomLabelAndFolder()
		local menuBar = fcp:menuBar()
		if menuBar:isEnabled("Edit", "Copy") then
			local result = dialog.displayTextBoxMessage("Please enter a label for the clipboard item:", "The value you entered is not valid.\n\nPlease try again.", "")
			if result == false then return end
			clipboard.setName(result)
			local result = dialog.displayTextBoxMessage("Please enter a folder for the clipboard item:", "The value you entered is not valid.\n\nPlease try again.", "")
			if result == false then return end
			clipboard.setFolder(result)
			menuBar:selectMenu("Edit", "Copy")
		end
	end

--------------------------------------------------------------------------------
-- OTHER SHORTCUTS:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- ADD NOTE TO SELECTED CLIP:
	--------------------------------------------------------------------------------
	function addNoteToSelectedClip()

		local errorFunction = " Error occurred in addNoteToSelectedClip()."

		--------------------------------------------------------------------------------
		-- Make sure the Browser is visible:
		--------------------------------------------------------------------------------
		local libraries = fcp:browser():libraries()
		if not libraries:isShowing() then
			writeToConsole("Library Panel is closed." .. errorFunction)
			return
		end

		--------------------------------------------------------------------------------
		-- Get number of Selected Browser Clips:
		--------------------------------------------------------------------------------
		local clips = libraries:selectedClipsUI()
		if #clips ~= 1 then
			writeToConsole("Wrong number of clips selected." .. errorFunction)
			return
		end

		--------------------------------------------------------------------------------
		-- Check to see if the playhead is moving:
		--------------------------------------------------------------------------------
		local playhead = libraries:playhead()
		local playheadCheck1 = playhead:getPosition()
		timer.usleep(100000)
		local playheadCheck2 = playhead:getPosition()
		timer.usleep(100000)
		local playheadCheck3 = playhead:getPosition()
		timer.usleep(100000)
		local playheadCheck4 = playhead:getPosition()
		timer.usleep(100000)
		local wasPlaying = false
		if playheadCheck1 == playheadCheck2 and playheadCheck2 == playheadCheck3 and playheadCheck3 == playheadCheck4 then
			--debugMessage("Playhead is static.")
			wasPlaying = false
		else
			--debugMessage("Playhead is moving.")
			wasPlaying = true
		end

		--------------------------------------------------------------------------------
		-- Check to see if we're in Filmstrip or List View:
		--------------------------------------------------------------------------------
		local filmstripView = false
		if libraries:isFilmstripView() then
			filmstripView = true
			libraries:toggleViewMode():press()
			if wasPlaying then fcp:menuBar():selectMenu("View", "Playback", "Play") end
		end

		--------------------------------------------------------------------------------
		-- Get Selected Clip & Selected Clip's Parent:
		--------------------------------------------------------------------------------
		local selectedClip = libraries:selectedClipsUI()[1]
		local selectedClipParent = selectedClip:attributeValue("AXParent")

		--------------------------------------------------------------------------------
		-- Get the AXGroup:
		--------------------------------------------------------------------------------
		local axutils = require("hs.finalcutpro.axutils")
		local listHeadingGroup = axutils.childWithRole(selectedClipParent, "AXGroup")

		--------------------------------------------------------------------------------
		-- Find the 'Notes' column:
		--------------------------------------------------------------------------------
		local notesFieldID = nil
		for i=1, listHeadingGroup:attributeValueCount("AXChildren") do
			local title = listHeadingGroup[i]:attributeValue("AXTitle")
			--------------------------------------------------------------------------------
			-- English: 		Notes
			-- German:			Notizen
			-- Spanish:			Notas
			-- French:			Notes
			-- Japanese:		メモ
			-- Chinese:			注释
			--------------------------------------------------------------------------------
			if title == "Notes" or title == "Notizen" or title == "Notas" or title == "メモ" or title == "注释" then
				notesFieldID = i
			end
		end

		--------------------------------------------------------------------------------
		-- If the 'Notes' column is missing:
		--------------------------------------------------------------------------------
		local notesPressed = false
		if notesFieldID == nil then
			listHeadingGroup:performAction("AXShowMenu")
			local menu = axutils.childWithRole(listHeadingGroup, "AXMenu")
			for i=1, menu:attributeValueCount("AXChildren") do
				if not notesPressed then
					local title = menu[i]:attributeValue("AXTitle")
					if title == "Notes" or title == "Notizen" or title == "Notas" or title == "メモ" or title == "注释" then
						menu[i]:performAction("AXPress")
						notesPressed = true
						for i=1, listHeadingGroup:attributeValueCount("AXChildren") do
							local title = listHeadingGroup[i]:attributeValue("AXTitle")
							if title == "Notes" or title == "Notizen" or title == "Notas" or title == "メモ" or title == "注释" then
								notesFieldID = i
							end
						end
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- If the 'Notes' column is missing then error:
		--------------------------------------------------------------------------------
		if notesFieldID == nil then
			errorMessage("FCPX Hacks could not find the Notes Column." .. errorFunction)
			return
		end

		local selectedNotesField = selectedClip[notesFieldID][1]
		local existingValue = selectedNotesField:attributeValue("AXValue")

		--------------------------------------------------------------------------------
		-- Setup Chooser:
		--------------------------------------------------------------------------------
		noteChooser = chooser.new(function(result)
			--------------------------------------------------------------------------------
			-- When Chooser Item is Selected or Closed:
			--------------------------------------------------------------------------------
			noteChooser:hide()
			fcp:launch()

			if result ~= nil then
				selectedNotesField:setAttributeValue("AXFocused", true)
				selectedNotesField:setAttributeValue("AXValue", result["text"])
				selectedNotesField:setAttributeValue("AXFocused", false)
				if not filmstripView then
					eventtap.keyStroke({}, "return") -- List view requires an "return" key press
				end

				local selectedRow = noteChooser:selectedRow()

				local recentNotes = settings.get("fcpxHacks.recentNotes") or {}
				if selectedRow == 1 then
					table.insert(recentNotes, 1, result)
					settings.set("fcpxHacks.recentNotes", recentNotes)
				else
					table.remove(recentNotes, selectedRow)
					table.insert(recentNotes, 1, result)
					settings.set("fcpxHacks.recentNotes", recentNotes)
				end
			end

			if filmstripView then
				libraries:toggleViewMode():press()
			end

			if wasPlaying then fcp:menuBar():selectMenu("View", "Playback", "Play") end

		end):bgDark(true):query(existingValue):queryChangedCallback(function()
			--------------------------------------------------------------------------------
			-- Chooser Query Changed by User:
			--------------------------------------------------------------------------------
			local recentNotes = settings.get("fcpxHacks.recentNotes") or {}

			local currentQuery = noteChooser:query()

			local currentQueryTable = {
				{
					["text"] = currentQuery
				},
			}

			for i=1, #recentNotes do
				table.insert(currentQueryTable, recentNotes[i])
			end

			noteChooser:choices(currentQueryTable)
			return
		end)

		--------------------------------------------------------------------------------
		-- Allow for Reduce Transparency:
		--------------------------------------------------------------------------------
		if screen.accessibilitySettings()["ReduceTransparency"] then
			noteChooser:fgColor(nil)
					   :subTextColor(nil)
		else
			noteChooser:fgColor(drawing.color.x11.snow)
					   :subTextColor(drawing.color.x11.snow)
		end

		--------------------------------------------------------------------------------
		-- Show Chooser:
		--------------------------------------------------------------------------------
		noteChooser:show()

	end

	--------------------------------------------------------------------------------
	-- CHANGE TIMELINE CLIP HEIGHT:
	--------------------------------------------------------------------------------
	function changeTimelineClipHeight(direction)

		--------------------------------------------------------------------------------
		-- Prevent multiple keypresses:
		--------------------------------------------------------------------------------
		if mod.changeTimelineClipHeightAlreadyInProgress then return end
		mod.changeTimelineClipHeightAlreadyInProgress = true

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Change Value of Zoom Slider:
		--------------------------------------------------------------------------------
		shiftClipHeight(direction)

		--------------------------------------------------------------------------------
		-- Keep looping it until the key is released.
		--------------------------------------------------------------------------------
		timer.doUntil(function() return not mod.changeTimelineClipHeightAlreadyInProgress end, function()
			shiftClipHeight(direction)
		end, eventtap.keyRepeatInterval())
	end

		--------------------------------------------------------------------------------
		-- SHIFT CLIP HEIGHT:
		--------------------------------------------------------------------------------
		function shiftClipHeight(direction)
			--------------------------------------------------------------------------------
			-- Find the Timeline Appearance Button:
			--------------------------------------------------------------------------------
			local appearance = fcp:timeline():toolbar():appearance()
			appearance:show()
			if direction == "up" then
				appearance:clipHeight():increment()
			else
				appearance:clipHeight():decrement()
			end
		end

		--------------------------------------------------------------------------------
		-- CHANGE TIMELINE CLIP HEIGHT RELEASE:
		--------------------------------------------------------------------------------
		function changeTimelineClipHeightRelease()
			mod.changeTimelineClipHeightAlreadyInProgress = false
			fcp:timeline():toolbar():appearance():hide()
		end

	--------------------------------------------------------------------------------
	-- SELECT CLIP AT LANE:
	--------------------------------------------------------------------------------
	function selectClipAtLane(whichLane)
		local content = fcp:timeline():contents()
		local playheadX = content:playhead():getPosition()

		local clips = content:clipsUI(false, function(clip)
			local frame = clip:frame()
			return playheadX >= frame.x and playheadX < (frame.x + frame.w)
		end)

		if clips == nil then
			debugMessage("No clips detected in selectClipAtLane().")
			return false
		end

		if whichLane > #clips then
			return false
		end

		--------------------------------------------------------------------------------
		-- Sort the table:
		--------------------------------------------------------------------------------
		table.sort(clips, function(a, b) return a:position().y > b:position().y end)

		content:selectClip(clips[whichLane])

		return true
	end

	--------------------------------------------------------------------------------
	-- MENU ITEM SHORTCUT:
	--------------------------------------------------------------------------------
	function menuItemShortcut(i, x, y, z)

		local fcpxElements = ax.applicationElement(fcp:application())

		local whichMenuBar = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements[i]:attributeValue("AXRole") == "AXMenuBar" then
				whichMenuBar = i
			end
		end

		if whichMenuBar == nil then
			displayErrorMessage("Failed to find menu bar.\n\nError occurred in menuItemShortcut().")
			return
		end

		if i ~= "" and x ~= "" and y == "" and z == "" then
			fcpxElements[whichMenuBar][i][1][x]:performAction("AXPress")
		elseif i ~= "" and x ~= "" and y ~= "" and z == "" then
			fcpxElements[whichMenuBar][i][1][x][1][y]:performAction("AXPress")
		elseif i ~= "" and x ~= "" and y ~= "" and z ~= "" then
			fcpxElements[whichMenuBar][i][1][x][1][y][1][z]:performAction("AXPress")
		end

	end

	--------------------------------------------------------------------------------
	-- TOGGLE TOUCH BAR:
	--------------------------------------------------------------------------------
	function toggleTouchBar()

		--------------------------------------------------------------------------------
		-- Check for compatibility:
		--------------------------------------------------------------------------------
		if not touchBarSupported then
			dialog.displayMessage(i18n("touchBarError"))
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Settings:
		--------------------------------------------------------------------------------
		local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false

		--------------------------------------------------------------------------------
		-- Toggle Touch Bar:
		--------------------------------------------------------------------------------
		setTouchBarLocation()
		if fcp:isRunning() then
			mod.touchBarWindow:toggle()
		end

		--------------------------------------------------------------------------------
		-- Update Settings:
		--------------------------------------------------------------------------------
		settings.set("fcpxHacks.displayTouchBar", not displayTouchBar)
	end

	--------------------------------------------------------------------------------
	-- CUT AND SWITCH MULTI-CAM:
	--------------------------------------------------------------------------------
	function cutAndSwitchMulticam(whichMode, whichAngle)

		if whichMode == "Audio" then
			if not fcp:performShortcut("MultiAngleEditStyleAudio") then
				dialog.displayErrorMessage("We were unable to trigger the 'Cut/Switch Multicam Audio Only' Shortcut.\n\nPlease make sure this shortcut is allocated in the Command Editor.\n\nError Occured in cutAndSwitchMulticam().")
				return "Failed"
			end
		end

		if whichMode == "Video" then
			if not fcp:performShortcut("MultiAngleEditStyleVideo") then
				dialog.displayErrorMessage("We were unable to trigger the 'Cut/Switch Multicam Video Only' Shortcut.\n\nPlease make sure this shortcut is allocated in the Command Editor.\n\nError Occured in cutAndSwitchMulticam().")
				return "Failed"
			end
		end

		if whichMode == "Both" then
			if not fcp:performShortcut("MultiAngleEditStyleAudioVideo") then
				dialog.displayErrorMessage("We were unable to trigger the 'Cut/Switch Multicam Audio and Video' Shortcut.\n\nPlease make sure this shortcut is allocated in the Command Editor.\n\nError Occured in cutAndSwitchMulticam().")
				return "Failed"
			end
		end

		if not fcp:performShortcut("CutSwitchAngle" .. tostring(string.format("%02d", whichAngle))) then
			dialog.displayErrorMessage("We were unable to trigger the 'Cut and Switch to Viewer Angle " .. tostring(whichAngle) .. "' Shortcut.\n\nPlease make sure this shortcut is allocated in the Command Editor.\n\nError Occured in cutAndSwitchMulticam().")
			return "Failed"
		end

	end

	--------------------------------------------------------------------------------
	-- MOVE TO PLAYHEAD:
	--------------------------------------------------------------------------------
	function moveToPlayhead()

		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false

		if enableClipboardHistory then
			clipboard.stopWatching()
		end

		if not fcp:performShortcut("Cut") then
			dialog.displayErrorMessage("Failed to trigger the 'Cut' Shortcut.\n\nError occurred in moveToPlayhead().")
			goto moveToPlayheadEnd
		end

		if not fcp:performShortcut("Paste") then
			dialog.displayErrorMessage("Failed to trigger the 'Paste' Shortcut.\n\nError occurred in moveToPlayhead().")
			goto moveToPlayheadEnd
		end

		::moveToPlayheadEnd::
		if enableClipboardHistory then
			timer.doAfter(2, function() clipboard.startWatching() end)
		end

	end

	--------------------------------------------------------------------------------
	-- HIGHLIGHT FINAL CUT PRO BROWSER PLAYHEAD:
	--------------------------------------------------------------------------------
	function highlightFCPXBrowserPlayhead()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get Browser Persistent Playhead:
		--------------------------------------------------------------------------------
		local playhead = fcp:libraries():playhead()
		if playhead:isShowing() then

			--------------------------------------------------------------------------------
			-- Playhead Position:
			--------------------------------------------------------------------------------
			local frame = playhead:getFrame()

			--------------------------------------------------------------------------------
			-- Highlight Mouse:
			--------------------------------------------------------------------------------
			mouseHighlight(frame.x, frame.y, frame.w, frame.h)

		end

	end

		--------------------------------------------------------------------------------
		-- HIGHLIGHT MOUSE IN FCPX:
		--------------------------------------------------------------------------------
		function mouseHighlight(mouseHighlightX, mouseHighlightY, mouseHighlightW, mouseHighlightH)

			--------------------------------------------------------------------------------
			-- Delete Previous Highlights:
			--------------------------------------------------------------------------------
			deleteAllHighlights()

			--------------------------------------------------------------------------------
			-- Get Sizing Preferences:
			--------------------------------------------------------------------------------
			local displayHighlightShape = nil
			displayHighlightShape = settings.get("fcpxHacks.displayHighlightShape")
			if displayHighlightShape == nil then displayHighlightShape = "Rectangle" end

			--------------------------------------------------------------------------------
			-- Get Highlight Colour Preferences:
			--------------------------------------------------------------------------------
			local displayHighlightColour = settings.get("fcpxHacks.displayHighlightColour") or "Red"
			if displayHighlightColour == "Red" then 	displayHighlightColour = {["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1} 	end
			if displayHighlightColour == "Blue" then 	displayHighlightColour = {["red"]=0,["blue"]=1,["green"]=0,["alpha"]=1}		end
			if displayHighlightColour == "Green" then 	displayHighlightColour = {["red"]=0,["blue"]=0,["green"]=1,["alpha"]=1}		end
			if displayHighlightColour == "Yellow" then 	displayHighlightColour = {["red"]=1,["blue"]=0,["green"]=1,["alpha"]=1}		end
			if displayHighlightColour == "Custom" then
				local displayHighlightCustomColour = settings.get("fcpxHacks.displayHighlightCustomColour")
				displayHighlightColour = {red=displayHighlightCustomColour["red"],blue=displayHighlightCustomColour["blue"],green=displayHighlightCustomColour["green"],alpha=1}
			end

			--------------------------------------------------------------------------------
			-- Highlight the FCPX Browser Playhead:
			--------------------------------------------------------------------------------
			if displayHighlightShape == "Rectangle" then
				mod.browserHighlight = drawing.rectangle(geometry.rect(mouseHighlightX, mouseHighlightY, mouseHighlightW, mouseHighlightH - 12))
			end
			if displayHighlightShape == "Circle" then
				mod.browserHighlight = drawing.circle(geometry.rect((mouseHighlightX-(mouseHighlightH/2)+10), mouseHighlightY, mouseHighlightH-12, mouseHighlightH-12))
			end
			if displayHighlightShape == "Diamond" then
				mod.browserHighlight = drawing.circle(geometry.rect(mouseHighlightX, mouseHighlightY, mouseHighlightW, mouseHighlightH - 12))
			end
			mod.browserHighlight:setStrokeColor(displayHighlightColour)
							    :setFill(false)
							    :setStrokeWidth(5)
							    :bringToFront(true)
							    :show()

			--------------------------------------------------------------------------------
			-- Set a timer to delete the circle after 3 seconds:
			--------------------------------------------------------------------------------
			local highlightPlayheadTime = settings.get("fcpxHacks.highlightPlayheadTime")
			mod.browserHighlightTimer = timer.doAfter(highlightPlayheadTime, function() deleteAllHighlights() end)

		end

	--------------------------------------------------------------------------------
	-- SELECT ALL TIMELINE CLIPS IN SPECIFIC DIRECTION:
	--------------------------------------------------------------------------------
	function selectAllTimelineClips(forwards)

		local content = fcp:timeline():contents()
		local playheadX = content:playhead():getPosition()

		local clips = content:clipsUI(false, function(clip)
			local frame = clip:frame()
			if forwards then
				return playheadX <= frame.x
			else
				return playheadX >= frame.x
			end
		end)

		if clips == nil then
			displayErrorMessage("No clips could be detected.\n\nError occurred in selectAllTimelineClips().")
			return false
		end

		content:selectClips(clips)

		return true

	end

	--------------------------------------------------------------------------------
	-- BATCH EXPORT:
	--------------------------------------------------------------------------------
	function batchExport()
		return plugins("hs.fcpxhacks.plugins.export.batch").batchExport()
	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                     C O M M O N    F U N C T I O N S                       --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GENERAL:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- NINJA PASTEBOARD COPY:
	--------------------------------------------------------------------------------
	function ninjaPasteboardCopy()

		local errorFunction = " Error occurred in ninjaPasteboardCopy()."

		--------------------------------------------------------------------------------
		-- Variables:
		--------------------------------------------------------------------------------
		local ninjaPasteboardCopyError = false
		local finalCutProClipboardUTI = fcp:getPasteboardUTI()
		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false

		--------------------------------------------------------------------------------
		-- Stop Watching Clipboard:
		--------------------------------------------------------------------------------
		if enableClipboardHistory then clipboard.stopWatching() end

		--------------------------------------------------------------------------------
		-- Save Current Clipboard Contents for later:
		--------------------------------------------------------------------------------
		local originalClipboard = clipboard.readFCPXData()

		--------------------------------------------------------------------------------
		-- Trigger 'copy' from Menubar:
		--------------------------------------------------------------------------------
		local menuBar = fcp:menuBar()
		if menuBar:isEnabled("Edit", "Copy") then
			menuBar:selectMenu("Edit", "Copy")
		else
			debugMessage("ERROR: Failed to select Copy from Menubar." .. errorFunction)
			if enableClipboardHistory then clipboard.startWatching() end
			return false
		end

		--------------------------------------------------------------------------------
		-- Wait until something new is actually on the Pasteboard:
		--------------------------------------------------------------------------------
		local newClipboard = nil
		just.doUntil(function()
			newClipboard = clipboard.readFCPXData()
			if newClipboard ~= originalClipboard then
				return true
			end
		end, 10, 0.1)
		if newClipboard == nil then
			debugMessage("ERROR: Failed to get new clipboard contents." .. errorFunction)
			if enableClipboardHistory then clipboard.startWatching() end
			return false
		end

		--------------------------------------------------------------------------------
		-- Restore Original Clipboard Contents:
		--------------------------------------------------------------------------------
		if originalClipboard ~= nil then
			local result = clipboard.writeFCPXData(originalClipboard)
			if not result then
				debugMessage("ERROR: Failed to restore original Clipboard item." .. errorFunction)
				if enableClipboardHistory then clipboard.startWatching() end
				return false
			end
		end

		--------------------------------------------------------------------------------
		-- Start Watching Clipboard:
		--------------------------------------------------------------------------------
		if enableClipboardHistory then clipboard.startWatching() end

		--------------------------------------------------------------------------------
		-- Return New Clipboard:
		--------------------------------------------------------------------------------
		return true, newClipboard

	end

	--------------------------------------------------------------------------------
	-- EMAIL BUG REPORT:
	--------------------------------------------------------------------------------
	function emailBugReport()
		local mailer = sharing.newShare("com.apple.share.Mail.compose"):subject("[FCPX Hacks " .. metadata.scriptVersion .. "] Bug Report"):recipients({metadata.bugReportEmail})
																	   :shareItems({"Please enter any notes, comments or suggestions here.\n\n---",console.getConsole(true), screen.mainScreen():snapshot()})
	end

	--------------------------------------------------------------------------------
	-- PROWL API KEY VALID:
	--------------------------------------------------------------------------------
	function prowlAPIKeyValid(input)

		local result = false
		local errorMessage = nil

		prowlAction = "https://api.prowlapp.com/publicapi/verify?apikey=" .. input
		httpResponse, httpBody, httpHeader = http.get(prowlAction, nil)

		if string.match(httpBody, "success") then
			result = true
		else
			local xml = slaxdom:dom(tostring(httpBody))
			errorMessage = xml['root']['el'][1]['kids'][1]['value']
		end

		return result, errorMessage

	end

	--------------------------------------------------------------------------------
	-- DELETE ALL HIGHLIGHTS:
	--------------------------------------------------------------------------------
	function deleteAllHighlights()
		if mod.browserHighlight ~= nil then
			mod.browserHighlight:delete()
			mod.browserHighlight = nil
			if mod.browserHighlightTimer then
				mod.browserHighlightTimer:stop()
				mod.browserHighlightTimer = nil
			end
		end
	end

	--------------------------------------------------------------------------------
	-- CHECK FOR FCPX HACKS UPDATES:
	--------------------------------------------------------------------------------
	function checkForUpdates()

		local enableCheckForUpdates = settings.get("fcpxHacks.enableCheckForUpdates")
		if enableCheckForUpdates then
			debugMessage("Checking for updates.")
			latestScriptVersion = nil
			updateResponse, updateBody, updateHeader = http.get(metadata.checkUpdateURL, nil)
			if updateResponse == 200 then
				if updateBody:sub(1,8) == "LATEST: " then
					--------------------------------------------------------------------------------
					-- Update Script Version:
					--------------------------------------------------------------------------------
					latestScriptVersion = updateBody:sub(9)

					--------------------------------------------------------------------------------
					-- macOS Notification:
					--------------------------------------------------------------------------------
					if not mod.shownUpdateNotification then
						if latestScriptVersion > metadata.scriptVersion then
							updateNotification = notify.new(function() getScriptUpdate() end):setIdImage(image.imageFromPath(metadata.iconPath))
																:title("FCPX Hacks Update Available")
																:subTitle("Version " .. latestScriptVersion)
																:informativeText("Do you wish to install?")
																:hasActionButton(true)
																:actionButtonTitle("Install")
																:otherButtonTitle("Not Yet")
																:send()
							mod.shownUpdateNotification = true
						end
					end
				end
			end
		end

	end

--------------------------------------------------------------------------------
-- TOUCH BAR:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- SHOW TOUCH BAR:
	--------------------------------------------------------------------------------
	function showTouchbar()
		--------------------------------------------------------------------------------
		-- Check if we need to show the Touch Bar:
		--------------------------------------------------------------------------------
		if touchBarSupported then
			local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false
			if displayTouchBar then mod.touchBarWindow:show() end
		end
	end

	--------------------------------------------------------------------------------
	-- HIDE TOUCH BAR:
	--------------------------------------------------------------------------------
	function hideTouchbar()
		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		if touchBarSupported then mod.touchBarWindow:hide() end
	end

	--------------------------------------------------------------------------------
	-- SET TOUCH BAR LOCATION:
	--------------------------------------------------------------------------------
	function setTouchBarLocation()

		--------------------------------------------------------------------------------
		-- Get Settings:
		--------------------------------------------------------------------------------
		local displayTouchBarLocation = settings.get("fcpxHacks.displayTouchBarLocation") or "Mouse"

		--------------------------------------------------------------------------------
		-- Show Touch Bar at Top Centre of Timeline:
		--------------------------------------------------------------------------------
		local timeline = fcp:timeline()
		if displayTouchBarLocation == "TimelineTopCentre" and timeline:isShowing() then
			--------------------------------------------------------------------------------
			-- Position Touch Bar to Top Centre of Final Cut Pro Timeline:
			--------------------------------------------------------------------------------
			local viewFrame = timeline:contents():viewFrame()

			local topLeft = {x = viewFrame.x + viewFrame.w/2 - mod.touchBarWindow:getFrame().w/2, y = viewFrame.y + 20}
			mod.touchBarWindow:topLeft(topLeft)
		else
			--------------------------------------------------------------------------------
			-- Position Touch Bar to Mouse Pointer Location:
			--------------------------------------------------------------------------------
			mod.touchBarWindow:atMousePosition()

		end

		--------------------------------------------------------------------------------
		-- Save last Touch Bar Location to Settings:
		--------------------------------------------------------------------------------
		settings.set("fcpxHacks.lastTouchBarLocation", mod.touchBarWindow:topLeft())

	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                             W A T C H E R S                                --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AUTOMATICALLY DO THINGS WHEN FINAL CUT PRO IS ACTIVATED OR DEACTIVATED:
--------------------------------------------------------------------------------
function finalCutProWatcher(appName, eventType, appObject)
	if (appName == "Final Cut Pro") then
		if (eventType == application.watcher.activated) then
			finalCutProActive()
		elseif (eventType == application.watcher.deactivated) or (eventType == application.watcher.terminated) then
			finalCutProNotActive()
		end
	end
end

--------------------------------------------------------------------------------
-- AUTOMATICALLY DO THINGS WHEN FINAL CUT PRO WINDOWS ARE CHANGED:
--------------------------------------------------------------------------------
function finalCutProWindowWatcher()

	wasInFullscreenMode = false

	--------------------------------------------------------------------------------
	-- Final Cut Pro Fullscreen Playback Filter:
	--------------------------------------------------------------------------------
	fullscreenPlaybackWatcher = windowfilter.new(true)

	--------------------------------------------------------------------------------
	-- Final Cut Pro Fullscreen Playback Window Created:
	--------------------------------------------------------------------------------
	fullscreenPlaybackWatcher:subscribe(windowfilter.windowCreated,(function(window, applicationName)
		if applicationName == "Final Cut Pro" then
			if window:title() == "" then
				local fcpx = fcp:application()
				if fcpx ~= nil then
					local fcpxElements = ax.applicationElement(fcpx)
					if fcpxElements ~= nil then
						if fcpxElements[1] ~= nil then
							if fcpxElements[1][1] ~= nil then
								if fcpxElements[1][1]:attributeValue("AXIdentifier") == "_NS:523" then
									-------------------------------------------------------------------------------
									-- Hide HUD:
									--------------------------------------------------------------------------------
									if settings.get("fcpxHacks.enableHacksHUD") then
											hackshud:hide()
											wasInFullscreenMode = true
									end
								end
							end
						end
					end
				end
			end
		end
	end), true)

	--------------------------------------------------------------------------------
	-- Final Cut Pro Fullscreen Playback Window Destroyed:
	--------------------------------------------------------------------------------
	fullscreenPlaybackWatcher:subscribe(windowfilter.windowDestroyed,(function(window, applicationName)
		if applicationName == "Final Cut Pro" then
			if window:title() == "" then
				-------------------------------------------------------------------------------
				-- Show HUD:
				--------------------------------------------------------------------------------
				if wasInFullscreenMode then
					if settings.get("fcpxHacks.enableHacksHUD") then
							hackshud:show()
					end
				end
			end
		end
	end), true)

	-- Watch the command editor showing and hiding.
	fcp:commandEditor():watch({
		show = function(commandEditor)
			--------------------------------------------------------------------------------
			-- Disable Hotkeys:
			--------------------------------------------------------------------------------
			if hotkeys ~= nil then -- For the rare case when Command Editor is open on load.
				debugMessage("Disabling Hotkeys")
				hotkeys:exit()
			end
			--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Hide the Touch Bar:
			--------------------------------------------------------------------------------
			hideTouchbar()

			--------------------------------------------------------------------------------
			-- Hide the HUD:
			--------------------------------------------------------------------------------
			hackshud.hide()
		end,
		hide = function(commandEditor)
			--------------------------------------------------------------------------------
			-- Check if we need to show the Touch Bar:
			--------------------------------------------------------------------------------
			showTouchbar()
			--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Refresh Keyboard Shortcuts:
			--------------------------------------------------------------------------------
			timer.doAfter(0.0000000000001, function() bindKeyboardShortcuts() end)
			--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Show the HUD:
			--------------------------------------------------------------------------------
			if settings.get("fcpxHacks.enableHacksHUD") then
				hackshud.show()
			end
		end
	})

	--------------------------------------------------------------------------------
	-- Final Cut Pro Window Moved:
	--------------------------------------------------------------------------------
	finalCutProWindowFilter = windowfilter.new{"Final Cut Pro"}

	finalCutProWindowFilter:subscribe(windowfilter.windowMoved, function()
		debugMessage("Final Cut Pro Window Resized")
		if touchBarSupported then
			local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false
			if displayTouchBar then setTouchBarLocation() end
		end
	end, true)
end

	--------------------------------------------------------------------------------
	-- Final Cut Pro Active:
	--------------------------------------------------------------------------------
	function finalCutProActive()
		--------------------------------------------------------------------------------
		-- Only do once:
		--------------------------------------------------------------------------------
		if mod.isFinalCutProActive then return end
		mod.isFinalCutProActive = true

		--------------------------------------------------------------------------------
		-- Don't trigger until after FCPX Hacks has loaded:
		--------------------------------------------------------------------------------
		if not mod.hacksLoaded then
			timer.waitUntil(function() return mod.hacksLoaded end, function()
				if fcp:isFrontmost() then
					mod.isFinalCutProActive = false
					finalCutProActive()
				end
			end, 0.1)
			return
		end

		--------------------------------------------------------------------------------
		-- Enable Hotkeys:
		--------------------------------------------------------------------------------
		timer.doAfter(0.0000000000001, function()
			hotkeys:enter()
		end)

		--------------------------------------------------------------------------------
		-- Enable Hacks HUD:
		--------------------------------------------------------------------------------
		timer.doAfter(0.0000000000001, function()
			if settings.get("fcpxHacks.enableHacksHUD") then
				hackshud:show()
			end
		end)

		--------------------------------------------------------------------------------
		-- Check if we need to show the Touch Bar:
		--------------------------------------------------------------------------------
		timer.doAfter(0.0000000000001, function()
			showTouchbar()
		end)

		--------------------------------------------------------------------------------
		-- Enable Voice Commands:
		--------------------------------------------------------------------------------
		timer.doAfter(0.0000000000001, function()
			if settings.get("fcpxHacks.enableVoiceCommands") then
				voicecommands.start()
			end
		end)

		--------------------------------------------------------------------------------
		-- Update Current Language:
		--------------------------------------------------------------------------------
		timer.doAfter(0.0000000000001, function()
			fcp:getCurrentLanguage(true)
		end)

	end

	--------------------------------------------------------------------------------
	-- Final Cut Pro Not Active:
	--------------------------------------------------------------------------------
	function finalCutProNotActive()
		--------------------------------------------------------------------------------
		-- Only do once:
		--------------------------------------------------------------------------------
		if not mod.isFinalCutProActive then return end
		mod.isFinalCutProActive = false

		--------------------------------------------------------------------------------
		-- Don't trigger until after FCPX Hacks has loaded:
		--------------------------------------------------------------------------------
		if not mod.hacksLoaded then return end

		--------------------------------------------------------------------------------
		-- Check if we need to hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Disable Voice Commands:
		--------------------------------------------------------------------------------
		if settings.get("fcpxHacks.enableVoiceCommands") then
			voicecommands.stop()
		end

		--------------------------------------------------------------------------------
		-- Disable hotkeys:
		--------------------------------------------------------------------------------
		hotkeys:exit()

		--------------------------------------------------------------------------------
		-- Delete the Mouse Circle:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		-------------------------------------------------------------------------------
		-- If not focussed on Hammerspoon then hide HUD:
		--------------------------------------------------------------------------------
		if settings.get("fcpxHacks.enableHacksHUD") then
			if application.frontmostApplication():bundleID() ~= "org.hammerspoon.Hammerspoon" then
				hackshud:hide()
			end
		end
	end

--------------------------------------------------------------------------------
-- AUTOMATICALLY DO THINGS WHEN FCPX PLIST IS UPDATED:
--------------------------------------------------------------------------------
function finalCutProSettingsWatcher(files)
    doReload = false
    for _,file in pairs(files) do
        if file:sub(-24) == "com.apple.FinalCut.plist" then
            doReload = true
        end
    end
    if doReload then

		--------------------------------------------------------------------------------
		-- Refresh Keyboard Shortcuts if Command Set Changed & Command Editor Closed:
		--------------------------------------------------------------------------------
    	if mod.lastCommandSet ~= fcp:getActiveCommandSetPath() then
    		if not fcp:commandEditor():isShowing() then
	    		timer.doAfter(0.0000000000001, function() bindKeyboardShortcuts() end)
			end
		end

    	--------------------------------------------------------------------------------
    	-- Update Menubar Icon:
    	--------------------------------------------------------------------------------
    	timer.doAfter(0.0000000000001, function() updateMenubarIcon() end)

 		--------------------------------------------------------------------------------
		-- Reload Hacks HUD:
		--------------------------------------------------------------------------------
		if settings.get("fcpxHacks.enableHacksHUD") then
			timer.doAfter(0.0000000000001, function() hackshud:refresh() end)
		end

    end
end

--------------------------------------------------------------------------------
-- NOTIFICATION WATCHER:
--------------------------------------------------------------------------------
function notificationWatcher()

	--------------------------------------------------------------------------------
	-- USED FOR DEVELOPMENT:
	--------------------------------------------------------------------------------
	--foo = distributednotifications.new(function(name, object, userInfo) print(string.format("name: %s\nobject: %s\nuserInfo: %s\n", name, object, inspect(userInfo))) end)
	--foo:start()

	--------------------------------------------------------------------------------
	-- SHARE SUCCESSFUL NOTIFICATION WATCHER:
	--------------------------------------------------------------------------------
	-- NOTE: ProTranscoderDidCompleteNotification doesn't seem to trigger when exporting small clips.
	shareSuccessNotificationWatcher = distributednotifications.new(notificationWatcherAction, "uploadSuccess")
	shareSuccessNotificationWatcher:start()

	--------------------------------------------------------------------------------
	-- SHARE UNSUCCESSFUL NOTIFICATION WATCHER:
	--------------------------------------------------------------------------------
	shareFailedNotificationWatcher = distributednotifications.new(notificationWatcherAction, "ProTranscoderDidFailNotification")
	shareFailedNotificationWatcher:start()

end

	--------------------------------------------------------------------------------
	-- NOTIFICATION WATCHER ACTION:
	--------------------------------------------------------------------------------
	function notificationWatcherAction(name, object, userInfo)
		-- FOR DEBUGGING/DEVELOPMENT
		-- debugMessage(string.format("name: %s\nobject: %s\nuserInfo: %s\n", name, object, hs.inspect(userInfo)))

		local message = nil
		if name == "uploadSuccess" then
			local info = findNotificationInfo(object)
			message = i18n("shareSuccessful", {info = info})
		elseif name == "ProTranscoderDidFailNotification" then
			message = i18n("shareFailed")
		else -- unexpected result
			return
		end

		local notificationPlatform = settings.get("fcpxHacks.notificationPlatform")

		if notificationPlatform["Prowl"] then
			local prowlAPIKey = settings.get("fcpxHacks.prowlAPIKey") or nil
			if prowlAPIKey ~= nil then
				local prowlApplication = http.encodeForQuery("FINAL CUT PRO")
				local prowlEvent = http.encodeForQuery("")
				local prowlDescription = http.encodeForQuery(message)

				local prowlAction = "https://api.prowlapp.com/publicapi/add?apikey=" .. prowlAPIKey .. "&application=" .. prowlApplication .. "&event=" .. prowlEvent .. "&description=" .. prowlDescription
				httpResponse, httpBody, httpHeader = http.get(prowlAction, nil)

				if not string.match(httpBody, "success") then
					local xml = slaxdom:dom(tostring(httpBody))
					local errorMessage = xml['root']['el'][1]['kids'][1]['value'] or nil
					if errorMessage ~= nil then writeToConsole("PROWL ERROR: " .. tools.trim(tostring(errorMessage))) end
				end
			end
		end

		if notificationPlatform["iMessage"] then
			local iMessageTarget = settings.get("fcpxHacks.iMessageTarget") or ""
			if iMessageTarget ~= "" then
				messages.iMessage(iMessageTarget, message)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- FIND NOTIFICATION INFO:
	--------------------------------------------------------------------------------
	function findNotificationInfo(path)
		local plistPath = path .. "/ShareStatus.plist"
		if fs.attributes(plistPath) then
			local shareStatus = plist.fileToTable(plistPath)
			if shareStatus then
				local latestType = nil
				local latestInfo = nil

				for type,results in pairs(shareStatus) do
					local info = results[#results]
					if latestInfo == nil or latestInfo.fullDate < info.fullDate then
						latestInfo = info
						latestType = type
					end
				end

				if latestInfo then
					-- put the first resultStr into a top-level value to make it easier for i18n
					if latestInfo.resultStr then
						latestInfo.result = latestInfo.resultStr[1]
					end
					local message = i18n("shareDetails_"..latestType, latestInfo)
					if not message then
						message = i18n("shareUnknown", {type = latestType})
					end
					return message
				end
			end
		end
		return i18n("shareUnknown", {type = "unknown"})
	end

--------------------------------------------------------------------------------
-- SHARED CLIPBOARD WATCHER:
--------------------------------------------------------------------------------
function sharedClipboardFileWatcher(files)
    doReload = false
    for _,file in pairs(files) do
        if file:sub(-10) == ".fcpxhacks" then
            doReload = true
        end
    end
    if doReload then
		debugMessage("Refreshing Shared Clipboard.")
    end
end

--------------------------------------------------------------------------------
-- SHARED XML FILE WATCHER:
--------------------------------------------------------------------------------
function sharedXMLFileWatcher(files)
	debugMessage("Refreshing Shared XML Folder.")

	for _,file in pairs(files) do
        if file:sub(-7) == ".fcpxml" then
			local testFile = io.open(file, "r")
			if testFile ~= nil then
				testFile:close()

				local editorName = string.reverse(string.sub(string.reverse(file), string.find(string.reverse(file), "/", 1) + 1, string.find(string.reverse(file), "/", string.find(string.reverse(file), "/", 1) + 1) - 1))

				if host.localizedName() ~= editorName then

					local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")
					sharedXMLNotification = notify.new(function() fcp:importXML(file) end)
						:setIdImage(image.imageFromPath(metadata.iconPath))
						:title("New XML Recieved")
						:subTitle(file:sub(string.len(xmlSharingPath) + 1 + string.len(editorName) + 1, -8))
						:informativeText("FCPX Hacks has recieved a new XML file.")
						:hasActionButton(true)
						:actionButtonTitle("Import XML")
						:send()

				end
			end
        end
    end
end

--------------------------------------------------------------------------------
-- TOUCH BAR WATCHER:
--------------------------------------------------------------------------------
function touchbarWatcher(obj, message)

	if message == "didEnter" then
        mod.mouseInsideTouchbar = true
    elseif message == "didExit" then
        mod.mouseInsideTouchbar = false

        --------------------------------------------------------------------------------
	    -- Just in case we got here before the eventtap returned the Touch Bar to normal:
	    --------------------------------------------------------------------------------
        mod.touchBarWindow:movable(false)
        mod.touchBarWindow:acceptsMouseEvents(true)
		settings.set("fcpxHacks.lastTouchBarLocation", mod.touchBarWindow:topLeft())

    end

end

--------------------------------------------------------------------------------
-- AUTOMATICALLY RELOAD HAMMERSPOON WHEN CONFIG FILES ARE UPDATED:
--------------------------------------------------------------------------------
function hammerspoonConfigWatcher(files)
    doReload = false
    for _,file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                L E T ' S     D O     T H I S     T H I N G !               --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

loadScript()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
