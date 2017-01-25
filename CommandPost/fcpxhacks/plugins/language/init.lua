-- Imports

local fcp 			= require("hs.finalcutpro")
local settings		= require("hs.settings")
local fs			= require("hs.fs")
local dialog		= require("hs.fcpxhacks.modules.dialog")
local tools			= require("hs.fcpxhacks.modules.tools")

local log			= require("hs.logger").new("lang")
local inspect		= require("hs.inspect")
local metadata		= require("hs.fcpxhacks.metadata")

-- Constants

local PRIORITY = 1000

local LANGUAGE_PATH = metadata.scriptPath .. "/hs/fcpxhacks/languages/"

-- The Module

local mod = {}

mod.installedLanguages = {}

--------------------------------------------------------------------------------
-- Setup i18n Languages:
--------------------------------------------------------------------------------

function mod.loadFCPXHacksLanguages()
	for file in fs.dir(LANGUAGE_PATH) do
		if file:sub(-4) == ".lua" then
			local languageFile = io.open(LANGUAGE_PATH .. file, "r")
			if languageFile ~= nil then
				local languageFileData = languageFile:read("*all")
				if string.find(languageFileData, "-- LANGUAGE: ") ~= nil then
					local fileLanguage = string.sub(languageFileData, string.find(languageFileData, "-- LANGUAGE: ") + 13, string.find(languageFileData, "\n") - 1)
					local languageID = string.sub(file, 1, -5)
					mod.installedLanguages[#mod.installedLanguages + 1] = { id = languageID, language = fileLanguage }
				end
				languageFile:close()
			end
		end
	end
	table.sort(mod.installedLanguages, function(a, b) return a.language < b.language end)
end

function mod.getFCPXHacksLanguages()
	if #mod.installedLanguages == 0 then
		mod.loadFCPXHacksLanguages()
	end
	return mod.installedLanguages
end


function mod.changeFinalCutProLanguage(language)

	--------------------------------------------------------------------------------
	-- If Final Cut Pro is running...
	--------------------------------------------------------------------------------
	local restartStatus = false
	if fcp:isRunning() then
		if dialog.displayYesNoQuestion(i18n("changeFinalCutProLanguage") .. "\n\n" .. i18n("doYouWantToContinue")) then
			restartStatus = true
		else
			return "Done"
		end
	end

	--------------------------------------------------------------------------------
	-- Update Final Cut Pro's settings::
	--------------------------------------------------------------------------------
	local result = fcp:setPreference("AppleLanguages", {language})
	if not result then
		dialog.displayErrorMessage(i18n("failedToChangeLanguage"))
	end

	--------------------------------------------------------------------------------
	-- Change FCPX Hacks Language:
	--------------------------------------------------------------------------------
	fcp:getCurrentLanguage(true, language)

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

-- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.preferences"]	= "prefs",
}

function plugin.init(deps)
	local section = deps.prefs:addSection(PRIORITY)

	section:addSeparator(0)

	-- The FCPX Languages Menu
	local fcpxLangs = section:addMenu(100, function() return i18n("finalCutProLanguage") end)
	fcpxLangs:addItems(1, function()
		local currentLanguage = fcp:getCurrentLanguage()

		return {
			{ title = i18n("german"),			fn = function() mod.changeFinalCutProLanguage("de") end, 				checked = currentLanguage == "de"},
			{ title = i18n("english"), 			fn = function() mod.changeFinalCutProLanguage("en") end, 				checked = currentLanguage == "en"},
			{ title = i18n("spanish"), 			fn = function() mod.changeFinalCutProLanguage("es") end, 				checked = currentLanguage == "es"},
			{ title = i18n("french"), 			fn = function() mod.changeFinalCutProLanguage("fr") end, 				checked = currentLanguage == "fr"},
			{ title = i18n("japanese"), 		fn = function() mod.changeFinalCutProLanguage("ja") end, 				checked = currentLanguage == "ja"},
			{ title = i18n("chineseChina"),		fn = function() mod.changeFinalCutProLanguage("zh_CN") end, 			checked = currentLanguage == "zh_CN"},
		}
	end)

	-- The FCPX Hacks Languages Menu

	local fcpxHacksLangs = section:addMenu(200, function() return metadata.scriptName .. " " .. i18n("language") end)
	fcpxHacksLangs:addItems(1, function()
		local settingsLanguage = {}
		local userLocale = settings.get("fcpxHacks.language") or tools.userLocale()

		local basicUserLocale = nil
		if string.find(userLocale, "_") ~= nil then
			basicUserLocale = string.sub(userLocale, 1, string.find(userLocale, "_") - 1)
		else
			basicUserLocale = userLocale
		end

		for i,language in ipairs(mod.getFCPXHacksLanguages()) do
			settingsLanguage[i] = { title = language["language"], fn = function()
				settings.set("fcpxHacks.language", language["id"])
				i18n.setLocale(language["id"])
			end, checked = (userLocale == language["id"] or basicUserLocale == language["id"]), }
		end

		return settingsLanguage
	end)

	section:addSeparator(9000)

	return mod
end

return plugin