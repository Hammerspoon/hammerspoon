--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F C P X    H A C K S    C O N S O L E                    --
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

local hacksconsole = {}

local chooser									= require("hs.chooser")
local drawing 									= require("hs.drawing")
local fnutils 									= require("hs.fnutils")
local menubar									= require("hs.menubar")
local mouse										= require("hs.mouse")
local screen									= require("hs.screen")
local settings									= require("hs.settings")
local timer										= require("hs.timer")
local plugins									= require("hs.plugins")

local ax 										= require("hs._asm.axuielement")
local fcp										= require("hs.finalcutpro")

hacksconsole.hacksChooser						= nil 		-- the actual hs.chooser
hacksconsole.active 							= false		-- is the Hacks Console Active?
hacksconsole.chooserChoices						= nil		-- Choices Table
hacksconsole.mode 								= "normal"	-- normal, remove, restore
hacksconsole.reduceTransparency					= false

--------------------------------------------------------------------------------
-- LOAD HACKS CONSOLE:
--------------------------------------------------------------------------------
function hacksconsole.new()

	--------------------------------------------------------------------------------
	-- Setup Chooser:
	--------------------------------------------------------------------------------
	hacksconsole.hacksChooser = chooser.new(hacksconsole.completionAction):bgDark(true)
											           				 	  :rightClickCallback(hacksconsole.rightClickAction)
											        				 	  :choices(hacksconsole.choices)

	--------------------------------------------------------------------------------
	-- Allow for Reduce Transparency:
	--------------------------------------------------------------------------------
	local reduceTransparency = screen.accessibilitySettings()["ReduceTransparency"]
	hacksconsole.reduceTransparency = reduceTransparency
	if reduceTransparency then
		hacksconsole.hacksChooser:fgColor(nil)
								 :subTextColor(nil)
	else
		hacksconsole.hacksChooser:fgColor(drawing.color.x11.snow)
								 :subTextColor(drawing.color.x11.snow)

	end

	--------------------------------------------------------------------------------
	-- If Final Cut Pro is running, lets preemptively refresh the choices:
	--------------------------------------------------------------------------------
	if fcp:isRunning() then timer.doAfter(3, hacksconsole.refresh) end

end

--------------------------------------------------------------------------------
-- REFRESH HACKS CONSOLE CHOICES:
--------------------------------------------------------------------------------
function hacksconsole.refresh()
	hacksconsole.hacksChooser:refreshChoicesCallback()
end

--------------------------------------------------------------------------------
-- SHOW HACKS CONSOLE:
--------------------------------------------------------------------------------
function hacksconsole.show()

	--------------------------------------------------------------------------------
	-- Reload Console if Reduce Transparency
	--------------------------------------------------------------------------------
	local reduceTransparency = screen.accessibilitySettings()["ReduceTransparency"]
	if reduceTransparency ~= hacksconsole.reduceTransparency then
		hacksconsole.new()
	end

	--------------------------------------------------------------------------------
	-- The Hacks Console always loads in 'normal' mode:
	--------------------------------------------------------------------------------
	hacksconsole.mode = "normal"
	hacksconsole.refresh()

	--------------------------------------------------------------------------------
	-- Remember last query?
	--------------------------------------------------------------------------------
	local chooserRememberLast = settings.get("fcpxHacks.chooserRememberLast")
	local chooserRememberLastValue = settings.get("fcpxHacks.chooserRememberLastValue") or ""
	if not chooserRememberLast then
		hacksconsole.hacksChooser:query("")
	else
		hacksconsole.hacksChooser:query(chooserRememberLastValue)
	end

	--------------------------------------------------------------------------------
	-- Hacks Console is Active:
	--------------------------------------------------------------------------------
	hacksconsole.active = true

	--------------------------------------------------------------------------------
	-- Show Hacks Console:
	--------------------------------------------------------------------------------
	hacksconsole.hacksChooser:show()

end

--------------------------------------------------------------------------------
-- HIDE HACKS CONSOLE:
--------------------------------------------------------------------------------
function hacksconsole.hide()

	--------------------------------------------------------------------------------
	-- No Longer Active:
	--------------------------------------------------------------------------------
	hacksconsole.active = false

	--------------------------------------------------------------------------------
	-- Hide Chooser:
	--------------------------------------------------------------------------------
	hacksconsole.hacksChooser:hide()

	--------------------------------------------------------------------------------
	-- Save Last Query to Settings:
	--------------------------------------------------------------------------------
	settings.set("fcpxHacks.chooserRememberLastValue", hacksconsole.hacksChooser:query())

	--------------------------------------------------------------------------------
	-- Put focus back on Final Cut Pro:
	--------------------------------------------------------------------------------
	fcp:launch()

end

--------------------------------------------------------------------------------
-- HACKS CONSOLE CHOICES:
--------------------------------------------------------------------------------
function hacksconsole.choices()

	--------------------------------------------------------------------------------
	-- Debug Mode:
	--------------------------------------------------------------------------------
	debugMessage("Updating Hacks Console Choices.")

	--------------------------------------------------------------------------------
	-- Reset Choices:
	--------------------------------------------------------------------------------
	hacksconsole.chooserChoices = nil
	hacksconsole.chooserChoices = {}

	--------------------------------------------------------------------------------
	-- Settings:
	--------------------------------------------------------------------------------
	local currentLanguage 				= fcp:getCurrentLanguage()
	local chooserFavourited				= settings.get("fcpxHacks." .. currentLanguage .. ".chooserFavourited") or {}
	local chooserRemoved 				= settings.get("fcpxHacks." .. currentLanguage .. ".chooserRemoved") or {}
	local chooserShowAutomation 		= settings.get("fcpxHacks.chooserShowAutomation")
	local chooserShowShortcuts 			= settings.get("fcpxHacks.chooserShowShortcuts")
	local chooserShowHacks 				= settings.get("fcpxHacks.chooserShowHacks")
	local chooserShowVideoEffects 		= settings.get("fcpxHacks.chooserShowVideoEffects")
	local chooserShowAudioEffects 		= settings.get("fcpxHacks.chooserShowAudioEffects")
	local chooserShowTransitions 		= settings.get("fcpxHacks.chooserShowTransitions")
	local chooserShowTitles 			= settings.get("fcpxHacks.chooserShowTitles")
	local chooserShowGenerators 		= settings.get("fcpxHacks.chooserShowGenerators")
	local chooserShowMenuItems 			= settings.get("fcpxHacks.chooserShowMenuItems")

	local individualEffect = nil

	if hacksconsole.mode == "normal" or hacksconsole.mode == "remove" then

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

		if chooserShowAutomation then fnutils.concat(hacksconsole.chooserChoices, chooserAutomation) end
		if chooserShowShortcuts then fnutils.concat(hacksconsole.chooserChoices, chooserShortcuts) end
		if chooserShowHacks then fnutils.concat(hacksconsole.chooserChoices, chooserHacks) end

		--------------------------------------------------------------------------------
		-- Menu Items:
		--------------------------------------------------------------------------------
		local chooserMenuItems = settings.get("fcpxHacks." .. currentLanguage .. ".chooserMenuItems") or {}
		if chooserShowMenuItems then
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
									table.insert(hacksconsole.chooserChoices, 1, individualEffect)
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
											table.insert(hacksconsole.chooserChoices, 1, individualEffect)
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
													table.insert(hacksconsole.chooserChoices, 1, individualEffect)
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
					table.insert(hacksconsole.chooserChoices, 1, chooserMenuItems[i])
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Video Effects List:
		--------------------------------------------------------------------------------
		if chooserShowVideoEffects then
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
					table.insert(hacksconsole.chooserChoices, 1, individualEffect)
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Audio Effects List:
		--------------------------------------------------------------------------------
		if chooserShowAudioEffects then
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
					table.insert(hacksconsole.chooserChoices, 1, individualEffect)
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Transitions List:
		--------------------------------------------------------------------------------
		if chooserShowTransitions then
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
					table.insert(hacksconsole.chooserChoices, 1, individualEffect)
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Titles List:
		--------------------------------------------------------------------------------
		if chooserShowTitles then
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
					table.insert(hacksconsole.chooserChoices, 1, individualEffect)
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Generators List:
		--------------------------------------------------------------------------------
		if chooserShowGenerators then
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
					table.insert(hacksconsole.chooserChoices, 1, individualEffect)
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Remove Deleted Items:
		--------------------------------------------------------------------------------
		if next(chooserRemoved) ~= nil then
			for i=1, #chooserRemoved do
				for x=#hacksconsole.chooserChoices,1,-1  do
					if hacksconsole.chooserChoices[x]["text"] == chooserRemoved[i]["text"] and hacksconsole.chooserChoices[x]["subText"] == chooserRemoved[i]["subText"] then
						table.remove(hacksconsole.chooserChoices, x)
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Temporarily Remove Favourited Items:
		--------------------------------------------------------------------------------
		local tempFavouiteItems = {}
		if next(chooserFavourited) ~= nil then
			for i=1, #chooserFavourited do
				for x=#hacksconsole.chooserChoices,1,-1  do
					if hacksconsole.chooserChoices[x]["text"] == chooserFavourited[i]["text"] and hacksconsole.chooserChoices[x]["subText"] == chooserFavourited[i]["subText"] then
						tempFavouiteItems[#tempFavouiteItems + 1] = hacksconsole.chooserChoices[x]
						table.remove(hacksconsole.chooserChoices, x)
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Sort everything:
		--------------------------------------------------------------------------------
		table.sort(hacksconsole.chooserChoices, function(a, b) return a.text < b.text end)
		table.sort(tempFavouiteItems, function(a, b) return a.text < b.text end)

		--------------------------------------------------------------------------------
		-- Merge the Tables Back Together:
		--------------------------------------------------------------------------------
		hacksconsole.chooserChoices = fnutils.concat(tempFavouiteItems, hacksconsole.chooserChoices)

		--------------------------------------------------------------------------------
		-- Return Choices:
		--------------------------------------------------------------------------------
		return hacksconsole.chooserChoices

	elseif hacksconsole.mode == "restore" then
		return chooserRemoved
	end

end

--------------------------------------------------------------------------------
-- HACKS CONSOLE TRIGGER ACTION:
--------------------------------------------------------------------------------
function hacksconsole.completionAction(result)

	local currentLanguage = fcp:getCurrentLanguage()
	local chooserRemoved = settings.get("fcpxHacks." .. currentLanguage .. ".chooserRemoved") or {}

	--------------------------------------------------------------------------------
	-- Nothing selected:
	--------------------------------------------------------------------------------
	if result == nil then
		--------------------------------------------------------------------------------
		-- Hide Hacks Console:
		--------------------------------------------------------------------------------
		hacksconsole.hide()
		return
	end

	--------------------------------------------------------------------------------
	-- Normal Mode:
	--------------------------------------------------------------------------------
	if hacksconsole.mode == "normal" then
		--------------------------------------------------------------------------------
		-- Hide Hacks Console:
		--------------------------------------------------------------------------------
		hacksconsole.hide()

		--------------------------------------------------------------------------------
		-- Perform Specific Function:
		--------------------------------------------------------------------------------
		local source = _G
		if result["plugin"] then
			source = plugins(result["plugin"])
		end
		
		timer.doAfter(0.0000000001, function() source[result["function"]](result["function1"], result["function2"], result["function3"], result["function4"]) end )

	--------------------------------------------------------------------------------
	-- Remove Mode:
	--------------------------------------------------------------------------------
	elseif hacksconsole.mode == "remove" then

		chooserRemoved[#chooserRemoved + 1] = result
		settings.set("fcpxHacks." .. currentLanguage .. ".chooserRemoved", chooserRemoved)
		hacksconsole.refresh()
		hacksconsole.hacksChooser:show()

	--------------------------------------------------------------------------------
	-- Restore Mode:
	--------------------------------------------------------------------------------
	elseif hacksconsole.mode == "restore" then

		for x=#chooserRemoved,1,-1 do
			if chooserRemoved[x]["text"] == result["text"] and chooserRemoved[x]["subText"] == result["subText"] then
				table.remove(chooserRemoved, x)
			end
		end
		settings.set("fcpxHacks." .. currentLanguage .. ".chooserRemoved", chooserRemoved)
		if next(chooserRemoved) == nil then hacksconsole.mode = "normal" end
		hacksconsole.refresh()
		hacksconsole.hacksChooser:show()

	end

end

--------------------------------------------------------------------------------
-- CHOOSER RIGHT CLICK:
--------------------------------------------------------------------------------
function hacksconsole.rightClickAction()

	--------------------------------------------------------------------------------
	-- Settings:
	--------------------------------------------------------------------------------
	local currentLanguage 				= fcp:getCurrentLanguage()
	local chooserRememberLast 			= settings.get("fcpxHacks.chooserRememberLast")
	local chooserRemoved 				= settings.get("fcpxHacks." .. currentLanguage .. ".chooserRemoved") or {}
	local chooserFavourited				= settings.get("fcpxHacks." .. currentLanguage .. ".chooserFavourited") or {}

	--------------------------------------------------------------------------------
	-- Display Options:
	--------------------------------------------------------------------------------
	local chooserShowAutomation 		= settings.get("fcpxHacks.chooserShowAutomation")
	local chooserShowShortcuts 			= settings.get("fcpxHacks.chooserShowShortcuts")
	local chooserShowHacks 				= settings.get("fcpxHacks.chooserShowHacks")
	local chooserShowVideoEffects 		= settings.get("fcpxHacks.chooserShowVideoEffects")
	local chooserShowAudioEffects 		= settings.get("fcpxHacks.chooserShowAudioEffects")
	local chooserShowTransitions 		= settings.get("fcpxHacks.chooserShowTransitions")
	local chooserShowTitles				= settings.get("fcpxHacks.chooserShowTitles")
	local chooserShowGenerators 		= settings.get("fcpxHacks.chooserShowGenerators")
	local chooserShowMenuItems 			= settings.get("fcpxHacks.chooserShowMenuItems")

	local selectedRowContents 			= hacksconsole.hacksChooser:selectedRowContents()

	--------------------------------------------------------------------------------
	-- 'Show All' Display Option:
	--------------------------------------------------------------------------------
	local chooserShowAll = false
	if chooserShowAutomation and chooserShowShortcuts and chooserShowHacks and chooserShowVideoEffects and chooserShowAudioEffects and chooserShowTransitions and chooserShowTitles and chooserShowGenerators then
		chooserShowAll = true
	end

	--------------------------------------------------------------------------------
	-- Menubar:
	--------------------------------------------------------------------------------
	hacksconsole.rightClickMenubar = menubar.new(false)

	local selectedItemMenu = {}
	local rightClickMenu = {}

	if next(hacksconsole.hacksChooser:selectedRowContents()) ~= nil and hacksconsole.mode == "normal" then

		local isFavourite = false
		if next(chooserFavourited) ~= nil then
			for i=1, #chooserFavourited do
				if selectedRowContents["text"] == chooserFavourited[i]["text"] and selectedRowContents["subText"] == chooserFavourited[i]["subText"] then
					isFavourite = true
				end
			end
		end

		local favouriteTitle = "Unfavourite"
		if not isFavourite then favouriteTitle = "Favourite" end

		selectedItemMenu = {
			{ title = string.upper(i18n("highlightedItem")) .. ":", disabled = true },
			{ title = favouriteTitle, fn = function()

				if isFavourite then
					--------------------------------------------------------------------------------
					-- Remove from favourites:
					--------------------------------------------------------------------------------
					for x=#chooserFavourited,1,-1 do
						if chooserFavourited[x]["text"] == selectedRowContents["text"] and chooserFavourited[x]["subText"] == selectedRowContents["subText"] then
							table.remove(chooserFavourited, x)
						end
					end
					settings.set("fcpxHacks." .. currentLanguage .. ".chooserFavourited", chooserRemoved)
				else
					--------------------------------------------------------------------------------
					-- Add to favourites:
					--------------------------------------------------------------------------------
					chooserFavourited[#chooserFavourited + 1] = selectedRowContents
					settings.set("fcpxHacks." .. currentLanguage .. ".chooserFavourited", chooserFavourited)
				end

				hacksconsole.refresh()
				hacksconsole.hacksChooser:show()

			end },
			{ title = i18n("removeFromList"), fn = function()
				chooserRemoved[#chooserRemoved + 1] = selectedRowContents
				settings.set("fcpxHacks." .. currentLanguage .. ".chooserRemoved", chooserRemoved)
				hacksconsole.refresh()
				hacksconsole.hacksChooser:show()
			end },
			{ title = "-" },
		}
	end

	rightClickMenu = {
		{ title = i18n("mode"), menu = {
			{ title = i18n("normal"), 				checked = hacksconsole.mode == "normal",			fn = function() hacksconsole.mode = "normal"; 		hacksconsole.refresh() end },
			{ title = i18n("removeFromList"),		checked = hacksconsole.mode == "remove",			fn = function() hacksconsole.mode = "remove"; 		hacksconsole.refresh() end },
			{ title = i18n("restoreToList"),		disabled = next(chooserRemoved) == nil, 			checked = hacksconsole.mode == "restore",			fn = function() hacksconsole.mode = "restore"; 		hacksconsole.refresh() end },
		}},
     	{ title = "-" },
     	{ title = i18n("displayOptions"), menu = {
			{ title = i18n("showNone"), disabled=hacksconsole.mode == "restore", fn = function()
				settings.set("fcpxHacks.chooserShowAutomation", false)
				settings.set("fcpxHacks.chooserShowShortcuts", false)
				settings.set("fcpxHacks.chooserShowHacks", false)
				settings.set("fcpxHacks.chooserShowVideoEffects", false)
				settings.set("fcpxHacks.chooserShowAudioEffects", false)
				settings.set("fcpxHacks.chooserShowTransitions", false)
				settings.set("fcpxHacks.chooserShowTitles", false)
				settings.set("fcpxHacks.chooserShowGenerators", false)
				settings.set("fcpxHacks.chooserShowMenuItems", false)
				hacksconsole.refresh()
			end },
			{ title = i18n("showAll"), 				checked = chooserShowAll, disabled=hacksconsole.mode == "restore" or chooserShowAll, fn = function()
				settings.set("fcpxHacks.chooserShowAutomation", true)
				settings.set("fcpxHacks.chooserShowShortcuts", true)
				settings.set("fcpxHacks.chooserShowHacks", true)
				settings.set("fcpxHacks.chooserShowVideoEffects", true)
				settings.set("fcpxHacks.chooserShowAudioEffects", true)
				settings.set("fcpxHacks.chooserShowTransitions", true)
				settings.set("fcpxHacks.chooserShowTitles", true)
				settings.set("fcpxHacks.chooserShowGenerators", true)
				settings.set("fcpxHacks.chooserShowMenuItems", true)
				hacksconsole.refresh()
			end },
			{ title = "-" },
			{ title = i18n("showAutomation"), 		checked = chooserShowAutomation,	disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowAutomation", not chooserShowAutomation); 			hacksconsole.refresh() end },
			{ title = i18n("showHacks"), 			checked = chooserShowHacks,			disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowHacks", not chooserShowHacks); 						hacksconsole.refresh() end },
			{ title = i18n("showShortcuts"), 		checked = chooserShowShortcuts,		disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowShortcuts", not chooserShowShortcuts); 				hacksconsole.refresh() end },
			{ title = "-" },
			{ title = i18n("showVideoEffects"), 	checked = chooserShowVideoEffects,	disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowVideoEffects", not chooserShowVideoEffects); 		hacksconsole.refresh() end },
			{ title = i18n("showAudioEffects"), 	checked = chooserShowAudioEffects,	disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowAudioEffects", not chooserShowAudioEffects); 		hacksconsole.refresh() end },
			{ title = "-" },
			{ title = i18n("showTransitions"), 		checked = chooserShowTransitions,	disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowTransitions", not chooserShowTransitions); 			hacksconsole.refresh() end },
			{ title = i18n("showTitles"), 			checked = chooserShowTitles,		disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowTitles", not chooserShowTitles); 					hacksconsole.refresh() end },
			{ title = i18n("showGenerators"), 		checked = chooserShowGenerators,	disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowGenerators", not chooserShowGenerators); 			hacksconsole.refresh() end },
			{ title = "-" },
			{ title = i18n("showMenuItems"), 		checked = chooserShowMenuItems,		disabled=hacksconsole.mode == "restore", 	fn = function() settings.set("fcpxHacks.chooserShowMenuItems", not chooserShowMenuItems); 				hacksconsole.refresh() end },
			},
		},
       	{ title = "-" },
       	{ title = i18n("preferences") .. "...", menu = {
			{ title = i18n("rememberLastQuery"), 	checked = chooserRememberLast,						fn= function() settings.set("fcpxHacks.chooserRememberLast", not chooserRememberLast) end },
			{ title = "-" },
			{ title = i18n("update"), menu = {
				{ title = i18n("effectsShortcuts"),			fn= function() hacksconsole.hide(); 		updateEffectsList();			end },
				{ title = i18n("transitionsShortcuts"),		fn= function() hacksconsole.hide(); 		updateTransitionsList(); 		end },
				{ title = i18n("titlesShortcuts"),			fn= function() hacksconsole.hide(); 		updateTitlesList() 				end },
				{ title = i18n("generatorsShortcuts"),		fn= function() hacksconsole.hide(); 		updateGeneratorsList() 			end },
				{ title = i18n("menuItems"),				fn= function() settings.set("fcpxHacks.chooserMenuItems", nil); 			hacksconsole.refresh() end },
			}},
		}},
	}


	rightClickMenu = fnutils.concat(selectedItemMenu, rightClickMenu)

	hacksconsole.rightClickMenubar:setMenu(rightClickMenu)
	hacksconsole.rightClickMenubar:popupMenu(mouse.getAbsolutePosition())

end

return hacksconsole