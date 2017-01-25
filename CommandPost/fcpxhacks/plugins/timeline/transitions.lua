-- Imports
local fcp				= require("hs.finalcutpro")
local settings			= require("hs.settings")
local dialog			= require("hs.fcpxhacks.modules.dialog")
local chooser			= require("hs.chooser")
local screen			= require("hs.screen")
local drawing			= require("hs.drawing")
local timer				= require("hs.timer")
local hacksconsole		= require("hs.fcpxhacks.modules.hacksconsole")

local log				= require("hs.logger").new("transitions")
local inspect			= require("hs.inspect")

-- Constants
local MAX_SHORTCUTS = 5

-- The Module

local mod = {}

function mod.getShortcuts()
	return settings.get("fcpxHacks." .. fcp:getCurrentLanguage() .. ".transitionsShortcuts") or {}	
end

function mod.setShortcut(number, value)
	assert(number >= 1 and number <= MAX_SHORTCUTS)
	local shortcuts = mod.getShortcuts()
	shortcuts[number] = value
	settings.set("fcpxHacks." .. fcp:getCurrentLanguage() .. ".transitionsShortcuts", shortcuts)	
end

function mod.getTransitions()
	return settings.get("fcpxHacks." .. fcp:getCurrentLanguage() .. ".allTransitions")
end

--------------------------------------------------------------------------------
-- TRANSITIONS SHORTCUT PRESSED:
-- The shortcut may be a number from 1-5, in which case the 'assigned' shortcut is applied,
-- or it may be the name of the transition to apply in the current FCPX language.
--------------------------------------------------------------------------------
function mod.apply(shortcut)

	--------------------------------------------------------------------------------
	-- Get settings:
	--------------------------------------------------------------------------------
	local currentLanguage = fcp:getCurrentLanguage()
	
	if type(shortcut) == "number" then
		shortcut = mod.getShortcuts()[shortcut]
	end

	if shortcut == nil then
		dialog.displayMessage(i18n("noTransitionShortcut"))
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Save the Effects Browser layout:
	--------------------------------------------------------------------------------
	local effects = fcp:effects()
	local effectsLayout = effects:saveLayout()

	--------------------------------------------------------------------------------
	-- Get Transitions Browser:
	--------------------------------------------------------------------------------
	local transitions = fcp:transitions()
	local transitionsShowing = transitions:isShowing()
	local transitionsLayout = transitions:saveLayout()

	--------------------------------------------------------------------------------
	-- Make sure panel is open:
	--------------------------------------------------------------------------------
	transitions:show()

	--------------------------------------------------------------------------------
	-- Make sure "Installed Transitions" is selected:
	--------------------------------------------------------------------------------
	transitions:showInstalledTransitions()

	--------------------------------------------------------------------------------
	-- Make sure there's nothing in the search box:
	--------------------------------------------------------------------------------
	transitions:search():clear()

	--------------------------------------------------------------------------------
	-- Click 'All':
	--------------------------------------------------------------------------------
	transitions:showAllTransitions()

	--------------------------------------------------------------------------------
	-- Perform Search:
	--------------------------------------------------------------------------------
	transitions:search():setValue(shortcut)

	--------------------------------------------------------------------------------
	-- Get the list of matching transitions
	--------------------------------------------------------------------------------
	local matches = transitions:currentItemsUI()
	if not matches or #matches == 0 then
		--------------------------------------------------------------------------------
		-- If Needed, Search Again Without Text Before First Dash:
		--------------------------------------------------------------------------------
		local index = string.find(shortcut, "-")
		if index ~= nil then
			local trimmedShortcut = string.sub(shortcut, index + 2)
			transitions:search():setValue(trimmedShortcut)

			matches = transitions:currentItemsUI()
			if not matches or #matches == 0 then
				dialog.displayErrorMessage("Unable to find a transition called '"..shortcut.."'.\n\nError occurred in transitionsShortcut().")
				return "Fail"
			end
		end
	end

	local transition = matches[1]

	--------------------------------------------------------------------------------
	-- Apply the selected Transition:
	--------------------------------------------------------------------------------
	hideTouchbar()

	transitions:applyItem(transition)

	-- TODO: HACK: This timer exists to  work around a mouse bug in Hammerspoon Sierra
	timer.doAfter(0.1, function()
		showTouchbar()

		transitions:loadLayout(transitionsLayout)
		if effectsLayout then effects:loadLayout(effectsLayout) end
		if not transitionsShowing then transitions:hide() end
	end)

end

-- TODO: A Global function which should be removed once other classes no longer depend on it
function transitionsShortcut(shortcut)
	log.w("deprecated: transitionsShortcut called")
	return mod.apply(shortcut)
end

--------------------------------------------------------------------------------
-- ASSIGN TRANSITIONS SHORTCUT:
--------------------------------------------------------------------------------
function mod.assignTransitionsShortcut(whichShortcut)

	--------------------------------------------------------------------------------
	-- Was Final Cut Pro Open?
	--------------------------------------------------------------------------------
	local wasFinalCutProOpen = fcp:isFrontmost()

	--------------------------------------------------------------------------------
	-- Get settings:
	--------------------------------------------------------------------------------
	local currentLanguage 			= fcp:getCurrentLanguage()
	local transitionsListUpdated 	= mod.isTransitionsListUpdated()
	local allTransitions 			= mod.getTransitions()

	--------------------------------------------------------------------------------
	-- Error Checking:
	--------------------------------------------------------------------------------
	if not transitionsListUpdated 
	   or allTransitions == nil
	   or next(allTransitions) == nil then
		dialog.displayMessage(i18n("assignTransitionsShortcutError"))
		return "Failed"
	end

	--------------------------------------------------------------------------------
	-- Transitions List:
	--------------------------------------------------------------------------------
	local choices = {}
	if allTransitions ~= nil and next(allTransitions) ~= nil then
		for i=1, #allTransitions do
			item = {
				["text"] = allTransitions[i],
				["subText"] = "Transition",
			}
			table.insert(choices, 1, item)
		end
	end

	--------------------------------------------------------------------------------
	-- Sort everything:
	--------------------------------------------------------------------------------
	table.sort(choices, function(a, b) return a.text < b.text end)

	--------------------------------------------------------------------------------
	-- Setup Chooser:
	--------------------------------------------------------------------------------
	local theChooser = nil
	theChooser = chooser.new(function(result)
		theChooser:hide()
		if result ~= nil then
			--------------------------------------------------------------------------------
			-- Save the selection:
			--------------------------------------------------------------------------------
			mod.setShortcut(whichShortcut, result.text)
		end

		--------------------------------------------------------------------------------
		-- Put focus back in Final Cut Pro:
		--------------------------------------------------------------------------------
		if wasFinalCutProOpen then fcp:launch() end
	end)
		
	theChooser:bgDark(true):choices(choices)

	--------------------------------------------------------------------------------
	-- Allow for Reduce Transparency:
	--------------------------------------------------------------------------------
	if screen.accessibilitySettings()["ReduceTransparency"] then
		theChooser:fgColor(nil)
		          :subTextColor(nil)
	else
		theChooser:fgColor(drawing.color.x11.snow)
 		          :subTextColor(drawing.color.x11.snow)
	end

	--------------------------------------------------------------------------------
	-- Show Chooser:
	--------------------------------------------------------------------------------
	theChooser:show()
end

--------------------------------------------------------------------------------
-- GET LIST OF TRANSITIONS:
--------------------------------------------------------------------------------
function mod.updateTransitionsList()

	--------------------------------------------------------------------------------
	-- Make sure Final Cut Pro is active:
	--------------------------------------------------------------------------------
	fcp:launch()

	--------------------------------------------------------------------------------
	-- Warning message:
	--------------------------------------------------------------------------------
	dialog.displayMessage(i18n("updateTransitionsListWarning"))

	--------------------------------------------------------------------------------
	-- Save the layout of the Effects panel, in case we switch away...
	--------------------------------------------------------------------------------
	local effects = fcp:effects()
	local effectsLayout = nil
	if effects:isShowing() then
		effectsLayout = effects:saveLayout()
	end

	--------------------------------------------------------------------------------
	-- Make sure Transitions panel is open:
	--------------------------------------------------------------------------------
	local transitions = fcp:transitions()
	local transitionsShowing = transitions:isShowing()
	if not transitions:show():isShowing() then
		dialog.displayErrorMessage("Unable to activate the Transitions panel.\n\nError occurred in updateTransitionsList().")
		return "Fail"
	end

	local transitionsLayout = transitions:saveLayout()

	--------------------------------------------------------------------------------
	-- Make sure "Installed Transitions" is selected:
	--------------------------------------------------------------------------------
	transitions:showInstalledTransitions()

	--------------------------------------------------------------------------------
	-- Make sure there's nothing in the search box:
	--------------------------------------------------------------------------------
	transitions:search():clear()

	--------------------------------------------------------------------------------
	-- Make sure the sidebar is visible:
	--------------------------------------------------------------------------------
	local sidebar = transitions:sidebar()

	transitions:showSidebar()

	if not sidebar:isShowing() then
		dialog.displayErrorMessage("Unable to activate the Transitions sidebar.\n\nError occurred in updateTransitionsList().")
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Click 'All' in the sidebar:
	--------------------------------------------------------------------------------
	transitions:showAllTransitions()

	--------------------------------------------------------------------------------
	-- Get list of All Transitions:
	--------------------------------------------------------------------------------
	local allTransitions = transitions:getCurrentTitles()
	if allTransitions == nil then
		dialog.displayErrorMessage("Unable to get list of all transitions.\n\nError occurred in updateTransitionsList().")
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Restore Effects and Transitions Panels:
	--------------------------------------------------------------------------------
	transitions:loadLayout(transitionsLayout)
	if effectsLayout then effects:loadLayout(effectsLayout) end
	if not transitionsShowing then transitions:hide() end

	--------------------------------------------------------------------------------
	-- Save Results to Settings:
	--------------------------------------------------------------------------------
	local currentLanguage = fcp:getCurrentLanguage()
	settings.set("fcpxHacks." .. currentLanguage .. ".allTransitions", allTransitions)
	settings.set("fcpxHacks." .. currentLanguage .. ".transitionsListUpdated", true)

	--------------------------------------------------------------------------------
	-- Update Chooser:
	--------------------------------------------------------------------------------
	hacksconsole.refresh()

	--------------------------------------------------------------------------------
	-- Let the user know everything's good:
	--------------------------------------------------------------------------------
	dialog.displayMessage(i18n("updateTransitionsListDone"))
end

function mod.isTransitionsListUpdated()
	return settings.get("fcpxHacks." .. fcp:getCurrentLanguage() .. ".transitionsListUpdated") or false
end

-- The Plugin
local PRIORITY = 2000

local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.automation"]	= "automation",
}

function plugin.init(deps)
	local fcpxRunning = fcp:isRunning()
	
	-- The 'Assign Shortcuts' menu
	local menu = deps.automation:addMenu(PRIORITY, function() return i18n("assignTransitionsShortcuts") end)
	
	-- The 'Update' menu
	menu:addItem(1000, function()
		return { title = i18n("updateTransitionsList"),	fn = mod.updateTransitionsList, disabled = not fcpxRunning }
	end)
	menu:addSeparator(2000)
	
	menu:addItems(3000, function()
		--------------------------------------------------------------------------------
		-- Shortcuts:
		--------------------------------------------------------------------------------
		local listUpdated 	= mod.isTransitionsListUpdated()
		local shortcuts		= mod.getShortcuts()
		
		local items = {}
		
		for i = 1, MAX_SHORTCUTS do
			local shortcutName = shortcuts[i] or i18n("unassignedTitle")
			items[i] = { title = i18n("transitionShortcutTitle", { number = i, title = shortcutName}), fn = function() mod.assignTransitionsShortcut(i) end,	disabled = not listUpdated }
		end
		
		return items
	end)
	
	return mod
end

return plugin