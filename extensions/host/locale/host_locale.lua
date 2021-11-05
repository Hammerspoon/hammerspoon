--- === hs.host.locale ===
---
--- Retrieve information about the user's Language and Region settings.
---
--- Locales encapsulate information about linguistic, cultural, and technological conventions and standards. Examples of information encapsulated by a locale include the symbol used for the decimal separator in numbers and the way dates are formatted. Locales are typically used to provide, format, and interpret information about and according to the user’s customs and preferences.

local USERDATA_TAG = "hs.host.locale"
local module       = require("hs.libhost_locale")

-- private variables and methods -----------------------------------------

local callbackFunctions = {}

local handleCallbacks = function(...)
    for k,v in pairs(callbackFunctions) do
        local status, message = pcall(v, ...)
        if not status then
            hs.luaSkinLog.ef("%s: callback for %s error: %s", USERDATA_TAG, k, message)
        end
    end
end

module._registerCallback(handleCallbacks)
module._registerCallback = nil  -- never call me again, in fact lose this number :-)

-- Public interface ------------------------------------------------------

--- hs.host.locale.registerCallback(function) -> uuidString
--- Function
--- Registers a function to be invoked when anything in the user's locale settings change
---
--- Parameters:
---  * `fn` - the function to be invoked when a setting changes
---
--- Returns:
---  * a uuid string which can be used to unregister a callback function when you no longer require notification of changes
---
--- Notes:
---  * The callback function will not receive any arguments and should return none.  You can retrieve the new locale settings with [hs.host.locale.localeInformation](#localeInformation) and check its keys to determine if the change is of interest.
---
---  * Any change made within the Language and Region settings panel will trigger this callback, even changes which are not reflected in the locale information provided by [hs.host.locale.localeInformation](#localeInformation).
module.registerCallback = function(fn)
    if type(fn) == "function" then
        local uuid = require"hs.host".uuid()
        callbackFunctions[uuid] = fn
        return uuid
    else
        error("must supply a function", 2)
    end
end

--- hs.host.locale.unregisterCallback(uuidString) -> boolean
--- Function
--- Unregister a callback function when you no longer care about changes to the user's locale
---
--- Parameters:
---  * `uuidString` - the uuidString returned by [hs.host.locale.registerCallback](#registerCallback) when you registered the callback function
---
--- Returns:
---  * true if the callback was successfully unregistered or false if it was not, usually because the uuidString does not correspond to a current callback function.
module.unregisterCallback = function(uuid)
    if callbackFunctions[uuid] then
        callbackFunctions[uuid] = nil
        return true
    else
        return false
    end
end

local details = module.details
module.details = function(...)
    local results = details(...)
    return type(results) == "table" and ls.makeConstantsTable(results) or results
end

local availableLocales = module.availableLocales
module.availableLocales = function(...)
    local results = availableLocales(...)
    return type(results) == "table" and ls.makeConstantsTable(results) or results
end

local preferredLanguages = module.preferredLanguages
module.preferredLanguages = function(...)
    local results = preferredLanguages(...)
    return type(results) == "table" and ls.makeConstantsTable(results) or results
end

-- Return Module Object --------------------------------------------------

return module
