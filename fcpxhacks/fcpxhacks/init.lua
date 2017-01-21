--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--                ===========================================
--
--                           F C P X    H A C K S
--
--                ===========================================
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
--  FCPX HACKS LOGO DESIGNED BY:
--------------------------------------------------------------------------------
--
--  > Sam Woodhall (https://twitter.com/SWDoctor)
--
--------------------------------------------------------------------------------
--  USING SNIPPETS OF CODE FROM:
--------------------------------------------------------------------------------
--
--  > http://www.hammerspoon.org/go/
--  > https://github.com/asmagill/hs._asm.axuielement
--  > https://github.com/asmagill/hammerspoon_asm/tree/master/touchbar
--  > https://github.com/Hammerspoon/hammerspoon/issues/272
--  > https://github.com/Hammerspoon/hammerspoon/issues/1021#issuecomment-251827969
--  > https://github.com/Hammerspoon/hammerspoon/issues/1027#issuecomment-252024969
--
--------------------------------------------------------------------------------
--  HUGE SPECIAL THANKS TO THESE AMAZING DEVELOPERS FOR ALL THEIR HELP:
--------------------------------------------------------------------------------
--
--  > Aaron Magill              https://github.com/asmagill
--  > Chris Jones               https://github.com/cmsj
--  > Bill Cheeseman            http://pfiddlesoft.com
--  > David Peterson            https://github.com/randomeizer
--  > Yvan Koenig               http://macscripter.net/viewtopic.php?id=45148
--  > Tim Webb                  https://twitter.com/_timwebb_
--
--------------------------------------------------------------------------------
--  VERY SPECIAL THANKS TO THESE AWESOME TESTERS & SUPPORTERS:
--------------------------------------------------------------------------------
--
--  > The always incredible Karen Hocking!
--  > Daniel Daperis & David Hocking
--  > Alex Gollner (http://alex4d.com)
--  > Scott Simmons (http://www.scottsimmons.tv)
--  > FCPX Editors InSync Facebook Group
--  > Isaac J. Terronez (https://twitter.com/ijterronez)
--  > Андрей Смирнов, Al Piazza, Shahin Shokoui, Ilyas Akhmedov & Tim Webb
--
--  Latest credits at: https://latenitefilms.com/blog/final-cut-pro-hacks/
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                        T H E    M O D U L E                                --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local mod = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                    T H E    M A I N    S C R I P T                         --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- LOAD EXTENSIONS:
--------------------------------------------------------------------------------

local application               = require("hs.application")
local console                   = require("hs.console")
local drawing                   = require("hs.drawing")
local fs                        = require("hs.fs")
local geometry                  = require("hs.geometry")
local inspect                   = require("hs.inspect")
local keycodes                  = require("hs.keycodes")
local logger                    = require("hs.logger")
local mouse                     = require("hs.mouse")
local settings                  = require("hs.settings")
local styledtext                = require("hs.styledtext")
local timer                     = require("hs.timer")

local ax                        = require("hs._asm.axuielement")

local metadata					= require("hs.fcpxhacks.metadata")

local tools                     = require("hs.fcpxhacks.modules.tools")
local semver                    = require("hs.fcpxhacks.modules.semver.semver")

--------------------------------------------------------------------------------
-- DEBUG MODE:
--------------------------------------------------------------------------------
if settings.get("fcpxHacks.debugMode") then

    --------------------------------------------------------------------------------
    -- Logger Level (defaults to 'warn' if not specified)
    --------------------------------------------------------------------------------
    logger.defaultLogLevel = 'debug'

    --------------------------------------------------------------------------------
    -- This will test that our global/local values are set up correctly
    -- by forcing a garbage collection.
    --------------------------------------------------------------------------------
    timer.doAfter(5, collectgarbage)

end

--------------------------------------------------------------------------------
-- SETUP I18N LANGUAGES:
--------------------------------------------------------------------------------
i18n = require("hs.fcpxhacks.modules.i18n")
local languagePath = "hs/fcpxhacks/languages/"
for file in fs.dir(languagePath) do
	if file:sub(-4) == ".lua" then
		i18n.loadFile(languagePath .. file)
	end
end
local userLocale = nil
if settings.get("fcpxHacks.language") == nil then
	userLocale = tools.userLocale()
else
	userLocale = settings.get("fcpxHacks.language")
end
i18n.setLocale(userLocale)

--------------------------------------------------------------------------------
-- LOAD MORE EXTENSIONS:
--------------------------------------------------------------------------------

local dialog                    = require("hs.fcpxhacks.modules.dialog")
local fcp                       = require("hs.finalcutpro")

--------------------------------------------------------------------------------
-- VARIABLES:
--------------------------------------------------------------------------------

local hsBundleID                = hs.processInfo["bundleID"]

--------------------------------------------------------------------------------
-- LOAD SCRIPT:
--------------------------------------------------------------------------------
function mod.init()

    --------------------------------------------------------------------------------
    -- Clear The Console:
    --------------------------------------------------------------------------------
    console.clearConsole()

    --------------------------------------------------------------------------------
    -- Display Welcome Message In The Console:
    --------------------------------------------------------------------------------
    writeToConsole("-----------------------------", true)
    writeToConsole("| FCPX Hacks v" .. metadata.scriptVersion .. "          |", true)
    writeToConsole("| Created by LateNite Films |", true)
    writeToConsole("-----------------------------", true)

    --------------------------------------------------------------------------------
    -- Check All The Required Files Exist:
    --------------------------------------------------------------------------------
    -- NOTE: Only check for a few files otherwise it slows down startup too much.
    local requiredFiles = {
        "hs/finalcutpro/init.lua",
        "hs/fcpxhacks/init.lua",
        "hs/fcpxhacks/assets/fcpxhacks.icns",
        "hs/fcpxhacks/languages/en.lua",
        }
    local checkFailed = false
    for i=1, #requiredFiles do
        if fs.attributes(requiredFiles[i]) == nil then checkFailed = true end
    end
    if checkFailed then
        dialog.displayAlertMessage(i18n("missingFiles"))
        application.applicationsForBundleID(hsBundleID)[1]:kill()
    end

    --------------------------------------------------------------------------------
    -- Check Hammerspoon Version:
    --------------------------------------------------------------------------------
    local requiredHammerspoonVersion        = semver("0.9.52")
    local hammerspoonVersion                = semver(hs.processInfo["version"])
    if hammerspoonVersion < requiredHammerspoonVersion then
        if hs.canCheckForUpdates() then
            hs.checkForUpdates()
            return self
        else
            dialog.displayAlertMessage(i18n("wrongHammerspoonVersionError", {version=tostring(requiredHammerspoonVersion)}))
            application.applicationsForBundleID(hsBundleID)[1]:kill()
        end
    end

    --------------------------------------------------------------------------------
    -- Check Versions & Language:
    --------------------------------------------------------------------------------
    local fcpVersion    = fcp:getVersion()
    local fcpPath		= fcp:getPath()
    local osVersion     = tools.macOSVersion()
    local fcpLanguage   = fcp:getCurrentLanguage()

    --------------------------------------------------------------------------------
    -- Display Useful Debugging Information in Console:
    --------------------------------------------------------------------------------
                                                writeToConsole("Hammerspoon Version:            " .. tostring(hammerspoonVersion),          true)
    if osVersion ~= nil then                    writeToConsole("macOS Version:                  " .. tostring(osVersion),                   true) end
    if fcpVersion ~= nil then                   writeToConsole("Final Cut Pro Version:          " .. tostring(fcpVersion),                  true) end
    if fcpLanguage ~= nil then                  writeToConsole("Final Cut Pro Language:         " .. tostring(fcpLanguage),                 true) end
        										writeToConsole("FCPX Hacks Locale:              " .. tostring(i18n.getLocale()),          	true)
    if keycodes.currentLayout() ~= nil then     writeToConsole("Current Keyboard Layout:        " .. tostring(keycodes.currentLayout()),    true) end
	if fcpPath ~= nil then						writeToConsole("Final Cut Pro Path:             " .. tostring(fcpPath),                 	true) end
                                                writeToConsole("", true)

    local validFinalCutProVersion = false
    if fcpVersion == "10.2.3" then
        validFinalCutProVersion = true
        require("hs.fcpxhacks.modules.fcpx10-2-3")
    end
    if fcpVersion:sub(1,4) == "10.3" then
        validFinalCutProVersion = true
        require("hs.fcpxhacks.modules.fcpx10-3")
    end
    if not validFinalCutProVersion then
        dialog.displayAlertMessage(i18n("noValidFinalCutPro"))
        application.applicationsForBundleID(hsBundleID)[1]:kill()
    end

    return self

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                     C O M M O N    F U N C T I O N S                       --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- REPLACE THE BUILT-IN PRINT FEATURE:
--------------------------------------------------------------------------------
print = function(value)
    if type(value) == "table" then
        value = inspect(value)
    else
        value = tostring(value)
    end

    --------------------------------------------------------------------------------
    -- Reformat hs.logger values:
    --------------------------------------------------------------------------------
    if string.sub(value, 1, 8) == string.match(value, "%d%d:%d%d:%d%d") then
        value = string.sub(value, 9, string.len(value)) .. " [" .. string.sub(value, 1, 8) .. "]"
        value = string.gsub(value, "     ", " ")
        value = " > " .. string.gsub(value, "^%s*(.-)%s*$", "%1")
        local consoleStyledText = styledtext.new(value, {
            color = drawing.color.definedCollections.hammerspoon["red"],
            font = { name = "Menlo", size = 12 },
        })
        console.printStyledtext(consoleStyledText)
        return
    end

    if (value:sub(1, 21) ~= "-- Loading extension:") and (value:sub(1, 8) ~= "-- Done.") then
        value = string.gsub(value, "     ", " ")
        value = string.gsub(value, "^%s*(.-)%s*$", "%1")
        local consoleStyledText = styledtext.new(" > " .. value, {
            color = drawing.color.definedCollections.hammerspoon["red"],
            font = { name = "Menlo", size = 12 },
        })
        console.printStyledtext(consoleStyledText)
    end
end

--------------------------------------------------------------------------------
-- WRITE TO CONSOLE:
--------------------------------------------------------------------------------
function writeToConsole(value, overrideLabel)
    if value ~= nil then
        if not overrideLabel then
            value = "> "..value
        end
        if type(value) == "string" then value = string.gsub(value, "\n\n", "\n > ") end
        local consoleStyledText = styledtext.new(tostring(value), {
            color = drawing.color.definedCollections.hammerspoon["blue"],
            font = { name = "Menlo", size = 12 },
        })
        console.printStyledtext(consoleStyledText)
    end
end

--------------------------------------------------------------------------------
-- DEBUG MESSAGE:
--------------------------------------------------------------------------------
function debugMessage(value, value2)
    if value2 ~= nil then
        local consoleStyledText = styledtext.new(" > " .. tostring(value) .. ": " .. tostring(value2), {
            color = drawing.color.definedCollections.hammerspoon["red"],
            font = { name = "Menlo", size = 12 },
        })
        console.printStyledtext(consoleStyledText)
    else
        if value ~= nil then
            if type(value) == "string" then value = string.gsub(value, "\n\n", "\n > ") end
            if settings.get("fcpxHacks.debugMode") then
                local consoleStyledText = styledtext.new(" > " .. value, {
                    color = drawing.color.definedCollections.hammerspoon["red"],
                    font = { name = "Menlo", size = 12 },
                })
                console.printStyledtext(consoleStyledText)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- ELEMENT AT MOUSE:
--------------------------------------------------------------------------------
function _elementAtMouse()
    return ax.systemElementAtPosition(mouse.getAbsolutePosition())
end

--------------------------------------------------------------------------------
-- INSPECT ELEMENT AT MOUSE:
--------------------------------------------------------------------------------
function _inspectAtMouse(options)
    options = options or {}
    local element = _elementAtMouse()
    if options.parents then
        for i=1,options.parents do
            element = element ~= nil and element:parent()
        end
    end

    if element then
        local result = ""
        if options.type == "path" then
            local path = element:path()
            for i,e in ipairs(path) do
                result = result .._inspectElement(e, options, i)
            end
            return result
        else
            return inspect(element:buildTree(options.depth))
        end
    else
        return "<no element found>"
    end
end

--------------------------------------------------------------------------------
-- INSPECT:
--------------------------------------------------------------------------------
function _inspect(e, options)
    if e == nil then
        return "<nil>"
    elseif type(e) ~= "userdata" or not e.attributeValue then
        if type(e) == "table" and #e > 0 then
            local item = nil
            local result = ""
            for i=1,#e do
                item = e[i]
                result = result ..
                         "\n= " .. string.format("%3d", i) ..
                         " ========================================" ..
                         _inspect(item, options)
            end
            return result
        else
            return inspect(e)
        end
    else
        return "\n==============================================" ..
               _inspectElement(e, options)
    end
end

--------------------------------------------------------------------------------
-- INSPECT ELEMENT:
--------------------------------------------------------------------------------
function _inspectElement(e, options, i)
    _highlightElement(e)

    i = i or 0
    local depth = options and options.depth or 1
    local out = "\n      Role       = " .. inspect(e:attributeValue("AXRole"))

    local id = e:attributeValue("AXIdentifier")
    if id then
        out = out.. "\n      Identifier = " .. inspect(id)
    end

    out = out.. "\n      Children   = " .. inspect(#e)

    out = out.. "\n==============================================" ..
                "\n" .. inspect(e:buildTree(depth)) .. "\n"

    return out
end

--------------------------------------------------------------------------------
-- HIGHLIGHT ELEMENT:
--------------------------------------------------------------------------------
function _highlightElement(e)
    if not e.frame then
        return
    end

    local eFrame = geometry.rect(e:frame())

    --------------------------------------------------------------------------------
    -- Get Highlight Colour Preferences:
    --------------------------------------------------------------------------------
    local highlightColor = {["red"]=1,["blue"]=0,["green"]=0,["alpha"]=0.75}

    local highlight = drawing.rectangle(eFrame)
    highlight:setStrokeColor(highlightColor)
    highlight:setFill(false)
    highlight:setStrokeWidth(3)
    highlight:show()

    --------------------------------------------------------------------------------
    -- Set a timer to delete the highlight after 3 seconds:
    --------------------------------------------------------------------------------
    local highlightTimer = timer.doAfter(3,
    function()
        highlight:delete()
        highlightTimer = nil
    end)
end

--------------------------------------------------------------------------------
-- INSPECT ELEMENT AT MOUSE PATH:
--------------------------------------------------------------------------------
function _inspectElementAtMousePath()
    return inspect(_elementAtMouse():path())
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                L E T ' S     D O     T H I S     T H I N G !               --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ASSIGN OUR MOD TO THE GLOBAL 'FCPXHACKS' OBJECT:
--------------------------------------------------------------------------------
fcpxhacks = mod

--------------------------------------------------------------------------------
-- KICK IT OFF:
--------------------------------------------------------------------------------
return mod.init()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
