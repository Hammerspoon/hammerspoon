--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--            D I A L O G B O X     S U P P O R T     L I B R A R Y           --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Module created by Chris Hocking (https://latenitefilms.com)
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- THE MODULE:
--------------------------------------------------------------------------------

local dialog = {}

local alert										= require("hs.alert")
local console									= require("hs.console")
local fs										= require("hs.fs")
local inspect									= require("hs.inspect")
local osascript									= require("hs.osascript")
local screen									= require("hs.screen")
local settings									= require("hs.settings")
local sharing									= require("hs.sharing")
local inspect									= require("hs.inspect")

local fcp										= require("hs.finalcutpro")

local tools										= require("hs.fcpxhacks.modules.tools")

--------------------------------------------------------------------------------
-- COMMON APPLESCRIPT:
--------------------------------------------------------------------------------
local function as(appleScript)

	local appleScriptStart = [[
		set yesButton to "]] .. i18n("yes") .. [["
		set noButton to "]] .. i18n("no") .. [["

		set okButton to "]] .. i18n("ok") .. [["
		set cancelButton to "]] .. i18n("cancel") .. [["

		set iconPath to (((POSIX path of ((path to home folder as Unicode text) & ".hammerspoon:hs:fcpxhacks:assets:fcpxhacks.icns")) as Unicode text) as POSIX file)

		set errorMessageStart to "]] .. i18n("commonErrorMessageStart") .. [[\n\n"
		set errorMessageEnd to "\n\n]] .. i18n("commonErrorMessageEnd") .. [["

		set finalCutProBundleID to "]] .. fcp:getBundleID() .. [["

		set frontmostApplication to (path to frontmost application as text)
		tell application frontmostApplication
			activate
	]]

	local appleScriptEnd = [[
		end tell
	]]

	local _, result = osascript.applescript(appleScriptStart .. appleScript .. appleScriptEnd)
	return result

end

--------------------------------------------------------------------------------
-- DISPLAY SMALL NUMBER TEXT BOX MESSAGE:
--------------------------------------------------------------------------------
function dialog.displaySmallNumberTextBoxMessage(whatMessage, whatErrorMessage, defaultAnswer)
	local appleScript = [[
		set whatMessage to "]] .. whatMessage .. [["
		set whatErrorMessage to "]] .. whatErrorMessage .. [["
		set defaultAnswer to "]] .. defaultAnswer .. [["
		repeat
			try
				set dialogResult to (display dialog whatMessage default answer defaultAnswer buttons {okButton, cancelButton} with icon iconPath)
			on error
				-- Cancel Pressed:
				return false
			end try
			try
				set usersInput to (text returned of dialogResult) as number -- To accept only entries that coerce directly to class integer.
				if usersInput is not equal to missing value then
					if usersInput is not 0 then
						exit repeat
					end if
				end if
			end try
			display dialog whatErrorMessage buttons {okButton} with icon iconPath
		end repeat
		return usersInput
	]]
	return as(appleScript)
end

--------------------------------------------------------------------------------
-- DISPLAY TEXT BOX MESSAGE:
--------------------------------------------------------------------------------
function dialog.displayTextBoxMessage(whatMessage, whatErrorMessage, defaultAnswer, validationFn)

	::retryDisplayTextBoxMessage::
	local appleScript = [[
		set whatMessage to "]] .. whatMessage .. [["
		set whatErrorMessage to "]] .. whatErrorMessage .. [["
		set defaultAnswer to "]] .. defaultAnswer .. [["
		try
			set response to text returned of (display dialog whatMessage default answer defaultAnswer buttons {okButton, cancelButton} default button 1 with icon iconPath)
		on error
			-- Cancel Pressed:
			return false
		end try
		return response
	]]
	local result = as(appleScript)
	if result == false then return false end

	if validationFn ~= nil then
		if type(validationFn) == "function" then
			if not validationFn(result) then
				dialog.displayMessage(whatErrorMessage)
				goto retryDisplayTextBoxMessage
			end
		end
	end

	return result

end

--------------------------------------------------------------------------------
-- DISPLAY CHOOSE FOLDER DIALOG:
--------------------------------------------------------------------------------
function dialog.displayChooseFolder(whatMessage)
	local appleScript = [[
		set whatMessage to "]] .. whatMessage .. [["

		try
			set whichFolder to POSIX path of (choose folder with prompt whatMessage default location (path to desktop))
			return whichFolder
		on error
			-- Cancel Pressed:
			return false
		end try
	]]
	return as(appleScript)
end

--------------------------------------------------------------------------------
-- DISPLAY ALERT MESSAGE:
--------------------------------------------------------------------------------
function dialog.displayAlertMessage(whatMessage)
	local appleScript = [[
		set whatMessage to "]] .. whatMessage .. [["

		display dialog whatMessage buttons {okButton} with icon stop
	]]
	return as(appleScript)
end

--------------------------------------------------------------------------------
-- DISPLAY ERROR MESSAGE:
--------------------------------------------------------------------------------
function dialog.displayErrorMessage(whatError)

	--------------------------------------------------------------------------------
	-- Write error message to console:
	--------------------------------------------------------------------------------
	writeToConsole(whatError)

	--------------------------------------------------------------------------------
	-- Display Dialog Box:
	--------------------------------------------------------------------------------
	local appleScript = [[
		set whatError to "]] .. whatError .. [["

		display dialog errorMessageStart & whatError & errorMessageEnd buttons {yesButton, noButton} with icon iconPath
		if the button returned of the result is equal to yesButton then
			return true
		else
			return false
		end if
	]]
	local result = as(appleScript)

	--------------------------------------------------------------------------------
	-- Send bug report:
	--------------------------------------------------------------------------------
	if result then emailBugReport() end

end

--------------------------------------------------------------------------------
-- DISPLAY MESSAGE:
--------------------------------------------------------------------------------
function dialog.displayMessage(whatMessage, optionalButtons)

	if optionalButtons == nil or type(optionalButtons) ~= "table" then
		optionalButtons = {i18n("ok")}
	end

	local buttons = 'buttons {'
	for i=1, #optionalButtons do
		buttons = buttons .. '"' .. optionalButtons[i] .. '"'
		if i ~= #optionalButtons then buttons = buttons .. ", " end
	end
	buttons = buttons .. "}"

	local appleScript = [[
		set whatMessage to "]] .. whatMessage .. [["
		set result to button returned of (display dialog whatMessage ]] .. buttons .. [[ with icon iconPath)
		return result
	]]
	return as(appleScript)

end

--------------------------------------------------------------------------------
-- DISPLAY YES OR NO QUESTION:
--------------------------------------------------------------------------------
function dialog.displayYesNoQuestion(whatMessage) -- returns true or false

	local appleScript = [[
		set whatMessage to "]] .. whatMessage .. [["

		display dialog whatMessage buttons {yesButton, noButton} default button 1 with icon iconPath
		if the button returned of the result is equal to yesButton then
			return true
		else
			return false
		end if
	]]
	return as(appleScript)

end

--------------------------------------------------------------------------------
-- DISPLAY CHOOSE FROM LIST:
--------------------------------------------------------------------------------
function dialog.displayChooseFromList(dialogPrompt, listOptions, defaultItems)

	if dialogPrompt == "nil" then dialogPrompt = "Please make your selection:" end
	if dialogPrompt == "" then dialogPrompt = "Please make your selection:" end

	if defaultItems == nil then defaultItems = {} end
	if type(defaultItems) ~= "table" then defaultItems = {} end

	local appleScript = [[
		set dialogPrompt to "]] .. dialogPrompt .. [["
		set listOptions to ]] .. inspect(listOptions) .. "\n\n" .. [[
		set defaultItems to ]] .. inspect(defaultItems) .. "\n\n" .. [[

		return choose from list listOptions with title "FCPX Hacks" with prompt dialogPrompt default items defaultItems
	]]

	return as(appleScript)

end

--------------------------------------------------------------------------------
-- DISPLAY COLOR PICKER:
--------------------------------------------------------------------------------
function dialog.displayColorPicker(customColor) -- Accepts RGB Table

	local defaultColor = {65535, 65535, 65535}
	if type(customColor) == "table" then
		local validColor = true
		if customColor["red"] == nil then validColor = false end
		if customColor["green"] == nil then validColor = false end
		if customColor["blue"] == nil then validColor = false end
		if validColor then
			defaultColor = { customColor["red"] * 257 * 255, customColor["green"] * 257 * 255, customColor["blue"] * 257 * 255 }
		end
	end

	local appleScript = [[
		set defaultColor to ]] .. inspect(defaultColor) .. "\n\n" .. [[
		return choose color default color defaultColor
	]]
	local result = as(appleScript)
	if type(result) == "table" then
		local red = result[1] / 257 / 255
		local green = result[2] / 257 / 255
		local blue = result[3] / 257 / 255
		if red ~= nil and green ~= nil and blue ~= nil then
			if returnToFinalCutPro then fcp:launch() end
			return {red=red, green=green, blue=blue, alpha=1}
		end
	end
	return nil

end

--------------------------------------------------------------------------------
-- DISPLAY ALERT NOTIFICATION:
--------------------------------------------------------------------------------
function dialog.displayNotification(whatMessage)
	alert.closeAll(0)
	alert.show(whatMessage, { textStyle = { paragraphStyle = { alignment = "center" } } })
end

return dialog