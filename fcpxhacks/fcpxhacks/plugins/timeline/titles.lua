-- Imports
local fcp				= require("hs.finalcutpro")
local settings			= require("hs.settings")
local dialog			= require("hs.fcpxhacks.modules.dialog")
local chooser			= require("hs.chooser")
local screen			= require("hs.screen")
local drawing			= require("hs.drawing")
local timer				= require("hs.timer")
local hacksconsole		= require("hs.fcpxhacks.modules.hacksconsole")

local log				= require("hs.logger").new("titles")
local inspect			= require("hs.inspect")

-- Constants
local PRIORITY = 3000

local MAX_SHORTCUTS = 5

-- The Module

local mod = {}

function mod.getShortcuts()
	return settings.get("fcpxHacks." .. fcp:getCurrentLanguage() .. ".titlesShortcuts") or {}	
end

function mod.setShortcut(number, value)
	assert(number >= 1 and number <= MAX_SHORTCUTS)
	local shortcuts = mod.getShortcuts()
	shortcuts[number] = value
	settings.set("fcpxHacks." .. fcp:getCurrentLanguage() .. ".titlesShortcuts", shortcuts)	
end

function mod.getTitles()
	return settings.get("fcpxHacks." .. fcp:getCurrentLanguage() .. ".allTitles")
end

--------------------------------------------------------------------------------
-- TITLES SHORTCUT PRESSED:
-- The shortcut may be a number from 1-5, in which case the 'assigned' shortcut is applied,
-- or it may be the name of the title to apply in the current FCPX language.
--------------------------------------------------------------------------------
function mod.apply(shortcut)

	--------------------------------------------------------------------------------
	-- Get settings:
	--------------------------------------------------------------------------------
	if type(shortcut) == "number" then
		shortcut = mod.getShortcuts()[shortcut]
	end

	if shortcut == nil then
		dialog.displayMessage(i18n("noTitleShortcut"))
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Save the main Browser layout:
	--------------------------------------------------------------------------------
	local browser = fcp:browser()
	local browserLayout = browser:saveLayout()

	--------------------------------------------------------------------------------
	-- Get Titles Browser:
	--------------------------------------------------------------------------------
	local generators = fcp:generators()
	local generatorsShowing = generators:isShowing()
	local generatorsLayout = generators:saveLayout()

	
	--------------------------------------------------------------------------------
	-- Make sure FCPX is at the front.
	--------------------------------------------------------------------------------
	fcp:launch()

	--------------------------------------------------------------------------------
	-- Make sure the panel is open:
	--------------------------------------------------------------------------------
	generators:show()
	
	if not generators:isShowing() then
		dialog.displayErrorMessage("Unable to display the Titles panel.\n\nError occurred in titles.apply(...)")
		return false
	end

	--------------------------------------------------------------------------------
	-- Make sure there's nothing in the search box:
	--------------------------------------------------------------------------------
	generators:search():clear()

	--------------------------------------------------------------------------------
	-- Click 'All':
	--------------------------------------------------------------------------------
	generators:showAllTitles()

	--------------------------------------------------------------------------------
	-- Make sure "Installed Titles" is selected:
	--------------------------------------------------------------------------------
	generators:showInstalledTitles()

	--------------------------------------------------------------------------------
	-- Perform Search:
	--------------------------------------------------------------------------------
	generators:search():setValue(shortcut)

	--------------------------------------------------------------------------------
	-- Get the list of matching effects
	--------------------------------------------------------------------------------
	local matches = generators:currentItemsUI()
	if not matches or #matches == 0 then
		--------------------------------------------------------------------------------
		-- If Needed, Search Again Without Text Before First Dash:
		--------------------------------------------------------------------------------
		local index = string.find(shortcut, "-")
		if index ~= nil then
			local trimmedShortcut = string.sub(shortcut, index + 2)
			effects:search():setValue(trimmedShortcut)

			matches = generators:currentItemsUI()
			if not matches or #matches == 0 then
				dialog.displayErrorMessage("Unable to find a transition called '"..shortcut.."'.\n\nError occurred in titles.apply(...).")
				return "Fail"
			end
		end
	end

	local generator = matches[1]

	--------------------------------------------------------------------------------
	-- Apply the selected Transition:
	--------------------------------------------------------------------------------
	hideTouchbar()

	generators:applyItem(generator)

	-- TODO: HACK: This timer exists to  work around a mouse bug in Hammerspoon Sierra
	timer.doAfter(0.1, function()
		showTouchbar()

		generators:loadLayout(generatorsLayout)
		if browserLayout then browser:loadLayout(browserLayout) end
		if not generatorsShowing then generators:hide() end
	end)

end

-- TODO: A Global function which should be removed once other classes no longer depend on it
function titlesShortcut(shortcut)
	log.d("deprecated: titlesShortcut called")
	return mod.apply(shortcut)
end

--------------------------------------------------------------------------------
-- ASSIGN TITLES SHORTCUT:
--------------------------------------------------------------------------------
function mod.assignTitlesShortcut(whichShortcut)

	--------------------------------------------------------------------------------
	-- Was Final Cut Pro Open?
	--------------------------------------------------------------------------------
	local wasFinalCutProOpen = fcp:isFrontmost()

	--------------------------------------------------------------------------------
	-- Get settings:
	--------------------------------------------------------------------------------
	local currentLanguage 			= fcp:getCurrentLanguage()
	local titlesListUpdated 	= mod.isTitlesListUpdated()
	local allTitles 			= mod.getTitles()

	--------------------------------------------------------------------------------
	-- Error Checking:
	--------------------------------------------------------------------------------
	if not titlesListUpdated 
	   or allTitles == nil
	   or next(allTitles) == nil then
		dialog.displayMessage(i18n("assignTitlesShortcutError"))
		return "Failed"
	end

	--------------------------------------------------------------------------------
	-- Titles List:
	--------------------------------------------------------------------------------
	local choices = {}
	if allTitles ~= nil and next(allTitles) ~= nil then
		for i=1, #allTitles do
			item = {
				["text"] = allTitles[i],
				["subText"] = "Title",
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
-- GET LIST OF TITLES:
--------------------------------------------------------------------------------
function mod.updateTitlesList()

	--------------------------------------------------------------------------------
	-- Make sure Final Cut Pro is active:
	--------------------------------------------------------------------------------
	fcp:launch()

	--------------------------------------------------------------------------------
	-- Warning message:
	--------------------------------------------------------------------------------
	dialog.displayMessage(i18n("updateTitlesListWarning"))

	local generators = fcp:generators()

	local browserLayout = fcp:browser():saveLayout()

	--------------------------------------------------------------------------------
	-- Make sure Titles and Generators panel is open:
	--------------------------------------------------------------------------------
	if not generators:show():isShowing() then
		dialog.displayErrorMessage("Unable to activate the Titles and Generators panel.\n\nError occurred in updateTitlesList().")
		showTouchbar()
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Make sure there's nothing in the search box:
	--------------------------------------------------------------------------------
	generators:search():clear()

	--------------------------------------------------------------------------------
	-- Click 'Titles':
	--------------------------------------------------------------------------------
	generators:showAllTitles()

	--------------------------------------------------------------------------------
	-- Make sure "Installed Titles" is selected:
	--------------------------------------------------------------------------------
	generators:group():selectItem(1)

	--------------------------------------------------------------------------------
	-- Get list of All Transitions:
	--------------------------------------------------------------------------------
	local effectsList = generators:contents():childrenUI()
	local allTitles = {}
	if effectsList ~= nil then
		for i=1, #effectsList do
			allTitles[i] = effectsList[i]:attributeValue("AXTitle")
		end
	else
		dialog.displayErrorMessage("Unable to get list of all titles.\n\nError occurred in updateTitlesList().")
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Restore Effects or Transitions Panel:
	--------------------------------------------------------------------------------
	fcp:browser():loadLayout(browserLayout)

	--------------------------------------------------------------------------------
	-- Save Results to Settings:
	--------------------------------------------------------------------------------
	local currentLanguage = fcp:getCurrentLanguage()
	settings.set("fcpxHacks." .. currentLanguage .. ".allTitles", allTitles)
	settings.set("fcpxHacks." .. currentLanguage .. ".titlesListUpdated", true)

	--------------------------------------------------------------------------------
	-- Update Chooser:
	--------------------------------------------------------------------------------
	hacksconsole.refresh()

	--------------------------------------------------------------------------------
	-- Let the user know everything's good:
	--------------------------------------------------------------------------------
	dialog.displayMessage(i18n("updateTitlesListDone"))
end

function mod.isTitlesListUpdated()
	return settings.get("fcpxHacks." .. fcp:getCurrentLanguage() .. ".titlesListUpdated") or false
end

-- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.automation"]	= "automation",
}

function plugin.init(deps)
	local fcpxRunning = fcp:isRunning()
	
	-- The 'Assign Shortcuts' menu
	local menu = deps.automation:addMenu(PRIORITY, function() return i18n("assignTitlesShortcuts") end)
	
	-- The 'Update' menu
	menu:addItem(1000, function()
		return { title = i18n("updateTitlesList"),	fn = mod.updateTitlesList, disabled = not fcpxRunning }
	end)
	menu:addSeparator(2000)
	
	menu:addItems(3000, function()
		--------------------------------------------------------------------------------
		-- Shortcuts:
		--------------------------------------------------------------------------------
		local listUpdated 	= mod.isTitlesListUpdated()
		local shortcuts		= mod.getShortcuts()
		
		local items = {}
		
		for i = 1, MAX_SHORTCUTS do
			local shortcutName = shortcuts[i] or i18n("unassignedTitle")
			items[i] = { title = i18n("titleShortcutTitle", { number = i, title = shortcutName}), fn = function() mod.assignTitlesShortcut(i) end,	disabled = not listUpdated }
		end
		
		return items
	end)
	
	return mod
end

return plugin