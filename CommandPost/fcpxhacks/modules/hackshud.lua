--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                       F C P X    H A C K S    H U D                        --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Module created by Chris Hocking (https://github.com/latenitefilms).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- THE MODULE:
--------------------------------------------------------------------------------

local hackshud = {}

--------------------------------------------------------------------------------
-- EXTENSIONS:
--------------------------------------------------------------------------------

local application								= require("hs.application")
local chooser									= require("hs.chooser")
local drawing									= require("hs.drawing")
local eventtap									= require("hs.eventtap")
local fnutils 									= require("hs.fnutils")
local fs 										= require("hs.fs")
local geometry									= require("hs.geometry")
local host										= require("hs.host")
local mouse										= require("hs.mouse")
local screen									= require("hs.screen")
local settings									= require("hs.settings")
local timer										= require("hs.timer")
local urlevent									= require("hs.urlevent")
local webview									= require("hs.webview")
local window									= require("hs.window")
local windowfilter								= require("hs.window.filter")
local plugins									= require("hs.plugins")

local fcp										= require("hs.finalcutpro")
local dialog									= require("hs.fcpxhacks.modules.dialog")
local tools										= require("hs.fcpxhacks.modules.tools")

--------------------------------------------------------------------------------
-- SETTINGS:
--------------------------------------------------------------------------------

hackshud.name									= i18n("hacksHUD")
hackshud.width									= 350
hackshud.heightInspector						= 75
hackshud.heightDropTargets						= 75
hackshud.heightButtons							= 70

hackshud.fcpGreen 								= "#3f9253"
hackshud.fcpRed 								= "#d1393e"

--------------------------------------------------------------------------------
-- VARIABLES:
--------------------------------------------------------------------------------

hackshud.ignoreWindowChange						= true
hackshud.windowID								= nil

hackshud.hsBundleID								= hs.processInfo["bundleID"]

--------------------------------------------------------------------------------
-- CREATE THE HACKS HUD:
--------------------------------------------------------------------------------
function hackshud.new()

	--------------------------------------------------------------------------------
	-- Work out HUD height based off settings:
	--------------------------------------------------------------------------------
	local hudShowInspector 		= settings.get("fcpxHacks.hudShowInspector")
	local hudShowDropTargets 	= settings.get("fcpxHacks.hudShowDropTargets")
	local hudShowButtons 		= settings.get("fcpxHacks.hudShowButtons")

	local hudHeight = 0
	if hudShowInspector then hudHeight = hudHeight + hackshud.heightInspector end
	if hudShowDropTargets then hudHeight = hudHeight + hackshud.heightDropTargets end
	if hudShowButtons then hudHeight = hudHeight + hackshud.heightButtons end

	--------------------------------------------------------------------------------
	-- Get last HUD position from settings otherwise default to centre screen:
	--------------------------------------------------------------------------------
	local screenFrame = screen.mainScreen():frame()
	local defaultHUDRect = {x = (screenFrame['w']/2) - (hackshud.width/2), y = (screenFrame['h']/2) - (hudHeight/2), w = hackshud.width, h = hudHeight}
	local hudPosition = settings.get("fcpxHacks.hudPosition") or {}
	if next(hudPosition) ~= nil then
		defaultHUDRect = {x = hudPosition["_x"], y = hudPosition["_y"], w = hackshud.width, h = hudHeight}
	end

	--------------------------------------------------------------------------------
	-- Setup Web View Controller:
	--------------------------------------------------------------------------------
	hackshud.hudWebViewController = webview.usercontent.new("hackshud")
		:setCallback(hackshud.javaScriptCallback)

	--------------------------------------------------------------------------------
	-- Setup Web View:
	--------------------------------------------------------------------------------
	hackshud.hudWebView = webview.new(defaultHUDRect, {}, hackshud.hudWebViewController)
		:windowStyle({"HUD", "utility", "titled", "nonactivating", "closable"})
		:shadow(true)
		:closeOnEscape(true)
		:html(generateHTML())
		:allowGestures(false)
		:allowNewWindows(false)
		:windowTitle(hackshud.name)
		:level(drawing.windowLevels.modalPanel)

	--------------------------------------------------------------------------------
	-- URL Events:
	--------------------------------------------------------------------------------
	hackshud.urlEvent = urlevent.bind("fcpxhacks", hackshud.hudCallback)

	--------------------------------------------------------------------------------
	-- Window Watcher:
	--------------------------------------------------------------------------------
	hackshud.hudFilter = windowfilter.new(true)
		:setAppFilter(hackshud.name, {activeApplication=true})

	--------------------------------------------------------------------------------
	-- HUD Moved:
	--------------------------------------------------------------------------------
	hackshud.hudFilter:subscribe(windowfilter.windowMoved, function(window, applicationName, event)
		if window:id() == hackshud.windowID then
			if hackshud.active() then
				local result = hackshud.hudWebView:hswindow():frame()
				if result ~= nil then
					settings.set("fcpxHacks.hudPosition", result)
				end
			end
		end
	end, true)

	--------------------------------------------------------------------------------
	-- HUD Closed:
	--------------------------------------------------------------------------------
	hackshud.hudFilter:subscribe(windowfilter.windowDestroyed, function(window, applicationName, event)
		if window:id() == hackshud.windowID then
			if not hackshud.ignoreWindowChange then
				settings.set("fcpxHacks.enableHacksHUD", false)
			end
		end
	end, true)

	--------------------------------------------------------------------------------
	-- HUD Unfocussed:
	--------------------------------------------------------------------------------
	hackshud.hudFilter:subscribe(windowfilter.windowUnfocused, function(window, applicationName, event)
		if window:id() ~= hackshud.windowID then
			local hsFrontmost = application.applicationsForBundleID(hackshud.hsBundleID)[1]:isFrontmost()
			if hsFrontmost ~= nil then
				if not fcp:isFrontmost() and hsFrontmost then
					hackshud.hide()
				else
					--[[
					if not fcp:isFrontmost() and window.frontmostWindow():title() == "Hammerspoon Console" then

						--------------------------------------------------------------------------------
						-- Check to see if user is dragging the HUD:
						--------------------------------------------------------------------------------
						local leftMousePressed = eventtap.checkMouseButtons()[1]
						local mouseLocation = geometry.point(mouse.getAbsolutePosition())
						local hudFrame = hackshud.hudWebView:hswindow():frame()

						if leftMousePressed and mouseLocation:inside(hudFrame) then
							--print("Dragging")
						else
							hackshud.hide()
						end

					end
					--]]
				end
			end
		end
	end, true)

end

--------------------------------------------------------------------------------
-- SHOW THE HACKS HUD:
--------------------------------------------------------------------------------
function hackshud.show()
	hackshud.ignoreWindowChange = true
	if hackshud.hudWebView == nil then
		hackshud.new()
		hackshud.hudWebView:show()
	else
		hackshud.hudWebView:show()
	end

	--------------------------------------------------------------------------------
	-- Keep checking for a window ID until we get an answer:
	--------------------------------------------------------------------------------
	hacksHUDWindowIDTimerDone = false
	timer.doUntil(function() return hacksHUDWindowIDTimerDone end, function()
		if hackshud.hudWebView:hswindow() ~= nil then
			if hackshud.hudWebView:hswindow():id() ~= nil then
				hackshud.windowID = hackshud.hudWebView:hswindow():id()
				hacksHUDWindowIDTimerDone = true
			end
		end
	 end, 0.05):fire()

	hackshud.ignoreWindowChange = false
end

--------------------------------------------------------------------------------
-- IS HACKS HUD ACTIVE:
--------------------------------------------------------------------------------
function hackshud.active()
	if hackshud.hudWebView == nil then
		return false
	end
	if hackshud.hudWebView:hswindow() == nil then
		return false
	else
		return true
	end
end

--------------------------------------------------------------------------------
-- HIDE THE HACKS HUD:
--------------------------------------------------------------------------------
function hackshud.hide()
	if hackshud.active() then
		hackshud.ignoreWindowChange = true
		hackshud.hudWebView:hide()
	end
end

--------------------------------------------------------------------------------
-- DELETE THE HACKS HUD:
--------------------------------------------------------------------------------
function hackshud.delete()
	if hackshud.active() then
		hackshud.hudWebView:delete()
	end
end

--------------------------------------------------------------------------------
-- RELOAD THE HACKS HUD:
--------------------------------------------------------------------------------
function hackshud.reload()

	local enableHacksHUD = settings.get("fcpxHacks.enableHacksHUD")
	local hudActive = hackshud.active()

	hackshud.delete()
	hackshud.ignoreWindowChange	= true
	hackshud.windowID			= nil
	hackshud.new()

	if hudActive and fcp:isFrontmost() then
		hackshud.show()
	end

end

--------------------------------------------------------------------------------
-- REFRESH THE HACKS HUD:
--------------------------------------------------------------------------------
function hackshud.refresh()
	if hackshud.active() then
		hackshud.hudWebView:html(generateHTML())
	end
end

--------------------------------------------------------------------------------
-- ASSIGN HUD BUTTON:
--------------------------------------------------------------------------------
function hackshud.assignButton(button)

	--------------------------------------------------------------------------------
	-- Was Final Cut Pro Open?
	--------------------------------------------------------------------------------
	hackshud.wasFinalCutProOpen = fcp:isFrontmost()
	hackshud.whichButton = button

	hudButtonChooser = chooser.new(hackshud.chooserAction):bgDark(true)
														  :fgColor(drawing.color.x11.snow)
														  :subTextColor(drawing.color.x11.snow)
														  :choices(hackshud.choices)
														  :show()
end

--------------------------------------------------------------------------------
-- CHOOSER ACTION:
--------------------------------------------------------------------------------
function hackshud.chooserAction(result)

	--------------------------------------------------------------------------------
	-- Hide Chooser:
	--------------------------------------------------------------------------------
	hudButtonChooser:hide()

	--------------------------------------------------------------------------------
	-- Perform Specific Function:
	--------------------------------------------------------------------------------
	if result ~= nil then
		--------------------------------------------------------------------------------
		-- Save the selection:
		--------------------------------------------------------------------------------
		local currentLanguage = fcp:getCurrentLanguage()
		if hackshud.whichButton == 1 then settings.set("fcpxHacks." .. currentLanguage .. ".hudButtonOne", 	result) end
		if hackshud.whichButton == 2 then settings.set("fcpxHacks." .. currentLanguage .. ".hudButtonTwo", 	result) end
		if hackshud.whichButton == 3 then settings.set("fcpxHacks." .. currentLanguage .. ".hudButtonThree", 	result) end
		if hackshud.whichButton == 4 then settings.set("fcpxHacks." .. currentLanguage .. ".hudButtonFour", 	result) end
	end

	--------------------------------------------------------------------------------
	-- Put focus back in Final Cut Pro:
	--------------------------------------------------------------------------------
	if hackshud.wasFinalCutProOpen then
		fcp:launch()
	end

	--------------------------------------------------------------------------------
	-- Reload HUD:
	--------------------------------------------------------------------------------
	local enableHacksHUD = settings.get("fcpxHacks.enableHacksHUD")
	if enableHacksHUD then
		hackshud.reload()
	end

end

--------------------------------------------------------------------------------
-- HACKS CONSOLE CHOICES:
--------------------------------------------------------------------------------
function hackshud.choices()

	local result = {}
	local individualEffect = nil

	--------------------------------------------------------------------------------
	-- Hardcoded Choices:
	--------------------------------------------------------------------------------
	local chooserAutomation = {
		{
			["text"] 		= "Toggle Scrolling Timeline",
			["subText"] 	= "Automation",
			["plugin"]		= "hs.fcpxhacks.plugins.timeline.playhead",
			["function"] 	= "toggleScrollingTimeline",
		},
		{
			["text"] = "Highlight Browser Playhead",
			["subText"] = "Automation",
			["function"] = "highlightFCPXBrowserPlayhead",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Reveal in Browser & Highlight",
			["subText"] = "Automation",
			["function"] = "matchFrameThenHighlightFCPXBrowserPlayhead",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 1",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 1,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 2",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 2,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 3",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 3,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 4",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 4,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 5",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 5,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 6",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 6,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 7",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 7,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 8",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 8,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 9",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 9,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 10",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 10,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Single Match Frame & Highlight",
			["subText"] = "Automation",
			["function"] = "singleMatchFrame",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Reveal Multicam in Browser & Highlight",
			["subText"] = "Automation",
			["function"] = "multicamMatchFrame",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Reveal Multicam in Angle Editor & Highlight",
			["subText"] = "Automation",
			["function"] = "multicamMatchFrame",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Color Board Puck 1",
			["subText"] = "Automation",
			["function"] = "colorBoardSelectPuck",
			["function1"] = 1,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Color Board Puck 2",
			["subText"] = "Automation",
			["function"] = "colorBoardSelectPuck",
			["function1"] = 2,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Color Board Puck 3",
			["subText"] = "Automation",
			["function"] = "colorBoardSelectPuck",
			["function1"] = 3,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Color Board Puck 4",
			["subText"] = "Automation",
			["function"] = "colorBoardSelectPuck",
			["function1"] = 4,
			["function2"] = nil,
			["function3"] = nil,
		},
	}
	local chooserShortcuts = {
		{
			["text"] = "Create Optimized Media (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateOptimizedMedia",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Optimized Media (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateOptimizedMedia",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Multicam Optimized Media (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateMulticamOptimizedMedia",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Multicam Optimized Media (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateMulticamOptimizedMedia",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Proxy Media (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateProxyMedia",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Proxy Media (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateProxyMedia",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Leave Files In Place On Import (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleLeaveInPlace",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Leave Files In Place On Import (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleLeaveInPlace",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Background Render (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleBackgroundRender",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Background Render (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleBackgroundRender",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
	}
	local chooserHacks = {
		{
			["text"] = "Change Backup Interval",
			["subText"] = "Hack",
			["function"] = "changeBackupInterval",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Toggle Timecode Overlay",
			["subText"] = "Hack",
			["function"] = "toggleTimecodeOverlay",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Toggle Moving Markers",
			["subText"] = "Hack",
			["function"] = "toggleMovingMarkers",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Toggle Enable Rendering During Playback",
			["subText"] = "Hack",
			["function"] = "togglePerformTasksDuringPlayback",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
	}

	fnutils.concat(result, chooserAutomation)
	fnutils.concat(result, chooserShortcuts)
	fnutils.concat(result, chooserHacks)

	--------------------------------------------------------------------------------
	-- Menu Items:
	--------------------------------------------------------------------------------
	local currentLanguage = fcp:getCurrentLanguage()
	local chooserMenuItems = settings.get("fcpxHacks." .. currentLanguage .. ".chooserMenuItems") or {}
	if next(chooserMenuItems) == nil then
		debugMessage("Building a list of Final Cut Pro menu items for the first time.")
		local fcpxElements = ax.applicationElement(fcp:application())
		if fcpxElements ~= nil then
			local whichMenuBar = nil
			for i=1, fcpxElements:attributeValueCount("AXChildren") do
				if fcpxElements[i]:attributeValue("AXRole") == "AXMenuBar" then
					whichMenuBar = i
				end
			end
			if whichMenuBar ~= nil then
				for i=2, fcpxElements[whichMenuBar]:attributeValueCount("AXChildren") -1 do
					for x=1, fcpxElements[whichMenuBar][i][1]:attributeValueCount("AXChildren") do
						if fcpxElements[whichMenuBar][i][1][x]:attributeValue("AXTitle") ~= "" and fcpxElements[whichMenuBar][i][1][x]:attributeValueCount("AXChildren") == 0 then
							local title = fcpxElements[whichMenuBar][i]:attributeValue("AXTitle") .. " > " .. fcpxElements[whichMenuBar][i][1][x]:attributeValue("AXTitle")
							individualEffect = {
								["text"] = title,
								["subText"] = "Menu Item",
								["function"] = "menuItemShortcut",
								["function1"] = i,
								["function2"] = x,
								["function3"] = "",
								["function4"] = "",
							}
							table.insert(chooserMenuItems, 1, individualEffect)
							table.insert(result, 1, individualEffect)
						end
						if fcpxElements[whichMenuBar][i][1][x]:attributeValueCount("AXChildren") ~= 0 then
							for y=1, fcpxElements[whichMenuBar][i][1][x][1]:attributeValueCount("AXChildren") do
								if fcpxElements[whichMenuBar][i][1][x][1][y]:attributeValue("AXTitle") ~= "" then
									local title = fcpxElements[whichMenuBar][i]:attributeValue("AXTitle") .. " > " .. fcpxElements[whichMenuBar][i][1][x]:attributeValue("AXTitle") .. " > " .. fcpxElements[whichMenuBar][i][1][x][1][y]:attributeValue("AXTitle")
									individualEffect = {
										["text"] = title,
										["subText"] = "Menu Item",
										["function"] = "menuItemShortcut",
										["function1"] = i,
										["function2"] = x,
										["function3"] = y,
										["function4"] = "",
									}
									table.insert(chooserMenuItems, 1, individualEffect)
									table.insert(result, 1, individualEffect)
								end
								if fcpxElements[whichMenuBar][i][1][x][1][y]:attributeValueCount("AXChildren") ~= 0 then
									for z=1, fcpxElements[whichMenuBar][i][1][x][1][y][1]:attributeValueCount("AXChildren") do
										if fcpxElements[whichMenuBar][i][1][x][1][y][1][z]:attributeValue("AXTitle") ~= "" then
											local title = fcpxElements[whichMenuBar][i]:attributeValue("AXTitle") .. " > " .. fcpxElements[whichMenuBar][i][1][x]:attributeValue("AXTitle") .. " > " .. fcpxElements[whichMenuBar][i][1][x][1][y]:attributeValue("AXTitle") .. " > " .. fcpxElements[whichMenuBar][i][1][x][1][y][1][z]:attributeValue("AXTitle")
											individualEffect = {
												["text"] = title,
												["subText"] = "Menu Item",
												["function"] = "menuItemShortcut",
												["function1"] = i,
												["function2"] = x,
												["function3"] = y,
												["function4"] = z,
											}
											table.insert(chooserMenuItems, 1, individualEffect)
											table.insert(result, 1, individualEffect)
										end
									end
								end
							end
						end
					end
				end
			end
		end
		settings.set("fcpxHacks." .. currentLanguage .. ".chooserMenuItems", chooserMenuItems)
	else
		--------------------------------------------------------------------------------
		-- Insert Menu Items from Settings:
		--------------------------------------------------------------------------------
		debugMessage("Using Menu Items from Settings.")
		for i=1, #chooserMenuItems do
			table.insert(result, 1, chooserMenuItems[i])
		end
	end

	--------------------------------------------------------------------------------
	-- Video Effects List:
	--------------------------------------------------------------------------------
	local allVideoEffects = settings.get("fcpxHacks." .. currentLanguage .. ".allVideoEffects")
	if allVideoEffects ~= nil and next(allVideoEffects) ~= nil then
		for i=1, #allVideoEffects do
			individualEffect = {
				["text"] = allVideoEffects[i],
				["subText"] = "Video Effect",
				["function"] = "effectsShortcut",
				["function1"] = allVideoEffects[i],
				["function2"] = "",
				["function3"] = "",
				["function4"] = "",
			}
			table.insert(result, 1, individualEffect)
		end
	end

	--------------------------------------------------------------------------------
	-- Audio Effects List:
	--------------------------------------------------------------------------------
	local allAudioEffects = settings.get("fcpxHacks." .. currentLanguage .. ".allAudioEffects")
	if allAudioEffects ~= nil and next(allAudioEffects) ~= nil then
		for i=1, #allAudioEffects do
			individualEffect = {
				["text"] = allAudioEffects[i],
				["subText"] = "Audio Effect",
				["function"] = "effectsShortcut",
				["function1"] = allAudioEffects[i],
				["function2"] = "",
				["function3"] = "",
				["function4"] = "",
			}
			table.insert(result, 1, individualEffect)
		end
	end

	--------------------------------------------------------------------------------
	-- Transitions List:
	--------------------------------------------------------------------------------
	local allTransitions = settings.get("fcpxHacks." .. currentLanguage .. ".allTransitions")
	if allTransitions ~= nil and next(allTransitions) ~= nil then
		for i=1, #allTransitions do
			local individualEffect = {
				["text"] = allTransitions[i],
				["subText"] = "Transition",
				["function"] = "transitionsShortcut",
				["function1"] = allTransitions[i],
				["function2"] = "",
				["function3"] = "",
				["function4"] = "",
			}
			table.insert(result, 1, individualEffect)
		end
	end

	--------------------------------------------------------------------------------
	-- Titles List:
	--------------------------------------------------------------------------------
	local allTitles = settings.get("fcpxHacks." .. currentLanguage .. ".allTitles")
	if allTitles ~= nil and next(allTitles) ~= nil then
		for i=1, #allTitles do
			individualEffect = {
				["text"] = allTitles[i],
				["subText"] = "Title",
				["function"] = "titlesShortcut",
				["function1"] = allTitles[i],
				["function2"] = "",
				["function3"] = "",
				["function4"] = "",
			}
			table.insert(result, 1, individualEffect)
		end
	end

	--------------------------------------------------------------------------------
	-- Generators List:
	--------------------------------------------------------------------------------
	local allGenerators = settings.get("fcpxHacks." .. currentLanguage .. ".allGenerators")
	if allGenerators ~= nil and next(allGenerators) ~= nil then
		for i=1, #allGenerators do
			local individualEffect = {
				["text"] = allGenerators[i],
				["subText"] = "Generator",
				["function"] = "generatorsShortcut",
				["function1"] = allGenerators[i],
				["function2"] = "",
				["function3"] = "",
				["function4"] = "",
			}
			table.insert(result, 1, individualEffect)
		end
	end

	--------------------------------------------------------------------------------
	-- Sort everything:
	--------------------------------------------------------------------------------
	table.sort(result, function(a, b) return a.text < b.text end)

	return result

end

--------------------------------------------------------------------------------
-- CONVERT HUB BUTTON TABLE TO FUNCTION URL STRING:
--------------------------------------------------------------------------------
local function hudButtonFunctionsToURL(table)

	local result = ""

	if table["function"] ~= nil then
		if table["function"] ~= "" then
			result = "?function=" .. table["function"]
		end
	end
	if table["function1"] ~= nil then
		if table["function1"] ~= "" then
			result = result .. "&function1=" .. table["function1"]
		end
	end
	if table["function2"] ~= nil then
		if table["function2"] ~= "" then
			result = result .. "&function2=" .. table["function2"]
		end
	end
	if table["function3"] ~= nil then
		if table["function3"] ~= "" then
			result = result .. "&function3=" .. table["function3"]
		end
	end
	if table["function4"] ~= nil then
		if table["function4"] ~= "" then
			result = result .. "&function4=" .. table["function4"]
		end
	end

	if result == "" then result = "?function=displayUnallocatedHUDMessage" end
	result = "hammerspoon://fcpxhacks" .. result

	return result

end

--------------------------------------------------------------------------------
-- GENERATE HTML:
--------------------------------------------------------------------------------
function generateHTML()

	--------------------------------------------------------------------------------
	-- HUD Settings:
	--------------------------------------------------------------------------------
	local hudShowInspector 		= settings.get("fcpxHacks.hudShowInspector")
	local hudShowDropTargets 	= settings.get("fcpxHacks.hudShowDropTargets")
	local hudShowButtons 		= settings.get("fcpxHacks.hudShowButtons")

	--------------------------------------------------------------------------------
	-- Get Custom HUD Button Values:
	--------------------------------------------------------------------------------
	local unallocatedButton = {
		["text"] = i18n("unassigned"),
		["subText"] = "",
		["function"] = "",
		["function1"] = "",
		["function2"] = "",
		["function3"] = "",
		["function4"] = "",
	}
	local currentLanguage 	= fcp:getCurrentLanguage()
	local hudButtonOne 		= settings.get("fcpxHacks." .. currentLanguage .. ".hudButtonOne") 	or unallocatedButton
	local hudButtonTwo 		= settings.get("fcpxHacks." .. currentLanguage .. ".hudButtonTwo") 	or unallocatedButton
	local hudButtonThree 	= settings.get("fcpxHacks." .. currentLanguage .. ".hudButtonThree") 	or unallocatedButton
	local hudButtonFour 	= settings.get("fcpxHacks." .. currentLanguage .. ".hudButtonFour") 	or unallocatedButton

	local hudButtonOneURL	= hudButtonFunctionsToURL(hudButtonOne)
	local hudButtonTwoURL	= hudButtonFunctionsToURL(hudButtonTwo)
	local hudButtonThreeURL	= hudButtonFunctionsToURL(hudButtonThree)
	local hudButtonFourURL	= hudButtonFunctionsToURL(hudButtonFour)

	--------------------------------------------------------------------------------
	-- Get Final Cut Pro Preferences:
	--------------------------------------------------------------------------------
	local preferences = fcp:getPreferences()

	--------------------------------------------------------------------------------
	-- FFPlayerQuality
	--------------------------------------------------------------------------------
	-- 10 	= Original - Better Quality
	-- 5 	= Original - Better Performance
	-- 4 	= Proxy
	--------------------------------------------------------------------------------

	if preferences["FFPlayerQuality"] == nil then
		FFPlayerQuality = 5
	else
		FFPlayerQuality = preferences["FFPlayerQuality"]
	end
	local playerQuality = nil

	local originalOptimised = i18n("originalOptimised")
	local betterQuality = i18n("betterQuality")
	local betterPerformance = i18n("betterPerformance")
	local proxy = i18n("proxy")

	if FFPlayerQuality == 10 then
		playerMedia = '<span style="color: ' .. hackshud.fcpGreen .. ';">' .. originalOptimised .. '</span>'
		playerQuality = '<span style="color: ' .. hackshud.fcpGreen .. ';">' .. betterQuality .. '</span>'
	elseif FFPlayerQuality == 5 then
		playerMedia = '<span style="color: ' .. hackshud.fcpGreen .. ';">' .. originalOptimised .. '</span>'
		playerQuality = '<span style="color: ' .. hackshud.fcpRed .. ';">' .. betterPerformance .. '</span>'
	elseif FFPlayerQuality == 4 then
		playerMedia = '<span style="color: ' .. hackshud.fcpRed .. ';">' .. proxy .. '</span>'
		playerQuality = '<span style="color: ' .. hackshud.fcpRed .. ';">' .. proxy .. '</span>'
	end
	if preferences["FFAutoRenderDelay"] == nil then
		FFAutoRenderDelay = "0.3"
	else
		FFAutoRenderDelay = preferences["FFAutoRenderDelay"]
	end
	if preferences["FFAutoStartBGRender"] == nil then
		FFAutoStartBGRender = true
	else
		FFAutoStartBGRender = preferences["FFAutoStartBGRender"]
	end

	local backgroundRender = nil
	if FFAutoStartBGRender then
		backgroundRender = '<span style="color: ' .. hackshud.fcpGreen .. ';">' .. i18n("enabled") .. ' (' .. FFAutoRenderDelay .. " " .. i18n("secs", {count=tonumber(FFAutoRenderDelay)}) .. ')</span>'
	else
		backgroundRender = '<span style="color: ' .. hackshud.fcpRed .. ';">' .. i18n("disabled") .. '</span>'
	end

	local html = [[<!DOCTYPE html>
<html>
	<head>
		<!-- Style Sheets: -->
		<style>
		.button {
			text-align: center;
			display:block;
			width: 136px;
			font-family: -apple-system;
			font-size: 10px;
			text-decoration: none;
			background-color: #333333;
			color: #bfbebb;
			padding: 2px 6px 2px 6px;
			border-top: 1px solid #161616;
			border-right: 1px solid #161616;
			border-bottom: 0.5px solid #161616;
			border-left: 1px solid #161616;
			margin-left: auto;
		    margin-right: auto;
		}
		body {
			background-color:#1f1f1f;
			color: #bfbebb;
			font-family: -apple-system;
			font-size: 11px;
			font-weight: lighter;
		}
		table {
			width:100%;
			text-align:left;
		}
		th {
			width:50%;
		}
		h1 {
			font-size: 12px;
			font-weight: bold;
			text-align: center;
			margin: 0px;
			padding: 0px;
		}
		hr {
			height:1px;
			border-width:0;
			color:gray;
			background-color:#797979;
		    display: block;
			margin-top: 10px;
			margin-bottom: 10px;
			margin-left: auto;
			margin-right: auto;
			border-style: inset;
		}
		input[type=text] {
			width: 100%;
			padding: 5px 5px;
			margin: 8px 0;
			box-sizing: border-box;
			border: 4px solid #22426f;
			border-radius: 4px;
			background-color: black;
			color: white;
			text-align:center;
		}
		</style>

		<!-- Javascript: -->
		<script>

			// Disable Right Clicking:
			document.addEventListener("contextmenu", function(e){
			    e.preventDefault();
			}, false);

			// Something has been dropped onto our Dropbox:
			function dropboxAction() {
				var x = document.getElementById("dropbox");
				var dropboxValue = x.value;

				try {
				webkit.messageHandlers.hackshud.postMessage(dropboxValue);
				} catch(err) {
				console.log('The controller does not exist yet');
				}

				x.value = "]] .. string.upper(i18n("hudDropZoneText")) .. [[";
			}

		</script>
	</head>
	<body>]]

	--------------------------------------------------------------------------------
	-- HUD Inspector:
	--------------------------------------------------------------------------------
	if hudShowInspector then html = html .. [[
		<table>
			<tr>
				<th>Media:</th>
				<th>]] .. playerMedia .. [[<th>
			</tr>
			<tr>
				<th>Quality:</th>
				<th>]] .. playerQuality .. [[<th>
			</tr>

			<tr>
				<th>Background Render:</th>
				<th>]] .. backgroundRender .. [[</th>
			</tr>
		</table>]]
	end

	if (hudShowInspector and hudShowDropTargets) or (hudShowInspector and hudShowButtons) then html = html .. [[
		<hr />]]
	end

	--------------------------------------------------------------------------------
	-- HUD Drop Targets:
	--------------------------------------------------------------------------------
	if hudShowDropTargets then html = html .. [[
		<table>
			<tr>
				<th style="width: 30%;">XML Sharing:</th>
				<th style="width: 70%;"><form><input type="text" id="dropbox" name="dropbox" oninput="dropboxAction()" tabindex="-1" value="]] .. string.upper(i18n("hudDropZoneText")) .. [["></form></th>
			<tr>
		</table>]]
	end

	if hudShowDropTargets and hudShowButtons then html = html .. [[
		<hr />]]
	end

	--------------------------------------------------------------------------------
	-- HUD Buttons:
	--------------------------------------------------------------------------------
	local length = 25
	if hudShowButtons then html = html.. [[
		<table>
			<tr>
				<th><a href="]] .. hudButtonOneURL .. [[" class="button">]] .. tools.stringMaxLength(tools.cleanupButtonText(hudButtonOne["text"]), length) .. [[</a></th>
				<th><a href="]] .. hudButtonTwoURL .. [[" class="button">]] .. tools.stringMaxLength(tools.cleanupButtonText(hudButtonTwo["text"]), length) .. [[</a></th>
			<tr>
			<tr style="padding:80px;"><th></th></tr>
			<tr>
				<th><a href="]] .. hudButtonThreeURL .. [[" class="button">]] .. tools.stringMaxLength(tools.cleanupButtonText(hudButtonThree["text"]), length) .. [[</a></th>
				<th><a href="]] .. hudButtonFourURL .. [[" class="button">]] .. tools.stringMaxLength(tools.cleanupButtonText(hudButtonFour["text"]), length) .. [[</a></th>
			</tr>
		</table>]]
	end

	html = html .. [[
	</body>
</html>
	]]

	return html

end

--------------------------------------------------------------------------------
-- JAVASCRIPT CALLBACK:
--------------------------------------------------------------------------------
function hackshud.javaScriptCallback(message)
	if message["body"] ~= nil then
		if string.find(message["body"], "<!DOCTYPE fcpxml>") ~= nil then
			hackshud.shareXML(message["body"])
		else
			dialog.displayMessage(i18n("hudDropZoneError"))
		end
	end
end

--------------------------------------------------------------------------------
-- URL EVENT CALLBACK:
--------------------------------------------------------------------------------
function hackshud.hudCallback(eventName, params)

	local f1 = params["function1"] or ""
	local f2 = params["function2"] or ""
	local f3 = params["function3"] or ""
	local f4 = params["function4"] or ""

	if tonumber(f1) ~= nil then f1 = tonumber(f1) end
	if tonumber(f2) ~= nil then f2 = tonumber(f2) end
	if tonumber(f3) ~= nil then f3 = tonumber(f3) end
	if tonumber(f4) ~= nil then f4 = tonumber(f4) end

	local source = _G
	if params["plugin"] then
		source = plugins(params["plugin"])
	end

	timer.doAfter(0.0000000001, function() source[params["function"]](f1, f2, f3, f4) end )

	fcp:launch()

end

--------------------------------------------------------------------------------
-- DISPLAY UNALLOCATED HUD MESSAGE:
--------------------------------------------------------------------------------
function displayUnallocatedHUDMessage()
	dialog.displayMessage(i18n("hudButtonError"))
end

--------------------------------------------------------------------------------
-- SHARED XML:
--------------------------------------------------------------------------------
function hackshud.shareXML(incomingXML)

	local enableXMLSharing = settings.get("fcpxHacks.enableXMLSharing") or false

	if enableXMLSharing then

		--------------------------------------------------------------------------------
		-- Get Settings:
		--------------------------------------------------------------------------------
		local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")

		--------------------------------------------------------------------------------
		-- Get only the needed XML content:
		--------------------------------------------------------------------------------
		local startOfXML = string.find(incomingXML, "<?xml version=")
		local endOfXML = string.find(incomingXML, "</fcpxml>")

		--------------------------------------------------------------------------------
		-- Error Detection:
		--------------------------------------------------------------------------------
		if startOfXML == nil or endOfXML == nil then
			dialog.displayErrorMessage("Something went wrong when attempting to translate the XML data you dropped. Please try again.\n\nError occurred in hackshud.shareXML().")
			if incomingXML ~= nil then
				debugMessage("Start of incomingXML.")
				debugMessage(incomingXML)
				debugMessage("End of incomingXML.")
			else
				debugMessage("ERROR: incomingXML is nil.")
			end
			return "fail"
		end

		--------------------------------------------------------------------------------
		-- New XML:
		--------------------------------------------------------------------------------
		local newXML = string.sub(incomingXML, startOfXML - 2, endOfXML + 8)

		--------------------------------------------------------------------------------
		-- Display Text Box:
		--------------------------------------------------------------------------------
		local textboxResult = dialog.displayTextBoxMessage(i18n("hudXMLNameDialog"), i18n("hudXMLNameError"), "")

		--------------------------------------------------------------------------------
		-- Save the XML content to the Shared XML Folder:
		--------------------------------------------------------------------------------
		local newXMLPath = xmlSharingPath .. host.localizedName() .. "/"

		if not tools.doesDirectoryExist(newXMLPath) then
			fs.mkdir(newXMLPath)
		end

		local file = io.open(newXMLPath .. textboxResult .. ".fcpxml", "w")
		currentClipboardData = file:write(newXML)
		file:close()

	else
		dialog.displayMessage(i18n("hudXMLSharingDisabled"))
	end

end

--------------------------------------------------------------------------------
-- END OF MODULE:
--------------------------------------------------------------------------------
return hackshud