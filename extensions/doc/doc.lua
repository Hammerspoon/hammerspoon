
--- === hs.doc ===
---
--- Create documentation objects for interactive help within Hammerspoon
---
--- The documentation object created is a table with tostring metamethods allowing access to a specific functions documentation by appending the path to the method or function to the object created.
---
--- From the Hammerspoon console:
---
---       doc = require("hs.doc")
---       doc.hs.application
---
--- Results in:
---
---       Manipulate running applications
---
---       [submodules]
---       hs.application.watcher
---
---       [subitems]
---       hs.application:activate([allWindows]) -> bool
---       hs.application:allWindows() -> window[]
---           ...
---       hs.application:visibleWindows() -> win[]
---
--- By default, the internal core documentation and portions of the Lua 5.3 manual, located at http://www.lua.org/manual/5.3/manual.html, are already registered for inclusion within this documentation object, but you can register additional documentation from 3rd party modules with `hs.registerJSONFile(...)`.

local USERDATA_TAG  = "hs.doc"
local module        = require("hs.libdoc")
local moduleMT      = getmetatable(module)

-- autoloaded by __index -- see end of file
local submodules = {
    markdown = USERDATA_TAG .. ".markdown",
    hsdocs   = USERDATA_TAG .. ".hsdocs",
    builder  = USERDATA_TAG .. ".builder",
}

local fnutils   = require("hs.fnutils")
local watchable = require("hs.watchable")
local fs        = require "hs.fs"

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

local changeCount = watchable.new("hs.doc")
changeCount.changeCount = 0

local triggerChangeCount = function()
    changeCount.changeCount = changeCount.changeCount + 1
end

-- so we can trigger this from the C side
moduleMT._registerTriggerFunction(triggerChangeCount)

-- forward declarations for hsdocs
local _jsonForSpoons = nil
local _jsonForModules = nil

module._changeCountWatcher = watchable.watch("hs.doc", "changeCount", function(w, p, k, o, n) -- luacheck: ignore
    _jsonForModules = nil
    _jsonForSpoons  = nil
end)

-- forward declaration of things we're going to wrap
local _help = module.help
local _registeredFilesFunction = module.registeredFiles

local helperMT
helperMT = {
    __index = function(self, key)
        local parent = rawget(self, "_parent") or ""
        if parent ~= "" then parent = parent .. "." end
        parent = parent .. self._key
        local children = moduleMT._children(parent)
        if fnutils.contains(children, key) then
            return setmetatable({ _key = key, _parent = parent }, helperMT)
        end
    end,
    __tostring = function(self)
        local entry = rawget(self, "_parent")
        if entry then entry = entry .. "." else entry = "" end
        entry = entry .. self._key
        return _help(entry)
    end,
    __pairs = function(self)
        local parent = rawget(self, "_parent") or ""
        if parent ~= "" then parent = parent .. "." end
        parent = parent .. self._key
        local children = {}
        for i, v in ipairs(moduleMT._children(parent)) do children[v] = i end
        return function(_, k)
                local v
                k, v = next(children, k)
                return k, v
            end, self, nil
    end,
    __len = function(self)
        local parent = rawget(self, "_parent") or ""
        if parent ~= "" then parent = parent .. "." end
        parent = parent .. self._key
        return #moduleMT._children(parent)
    end,
}

-- Public interface ------------------------------------------------------

--- hs.doc.registeredFiles() -> table
--- Function
--- Returns the list of registered JSON files.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the list of registered JSON files
---
--- Notes:
---  * The table returned by this function has a metatable including a __tostring method which allows you to see the list of registered files by simply typing `hs.doc.registeredFiles()` in the Hammerspoon Console.
---
---  * By default, the internal core documentation and portions of the Lua 5.3 manual, located at http://www.lua.org/manual/5.3/manual.html, are already registered for inclusion within this documentation object.
---
---  * You can unregister these defaults if you wish to start with a clean slate with the following commands:
---    * `hs.doc.unregisterJSONFile(hs.docstrings_json_file)` -- to unregister the Hammerspoon API docs
---    * `hs.doc.unregisterJSONFile((hs.docstrings_json_file:gsub("/docs.json$","/lua.json")))` -- to unregister the Lua 5.3 Documentation.
module.registeredFiles = function(...)
    return setmetatable(_registeredFilesFunction(...), {
        __tostring = function(self)
            local result = ""
            for _,v in pairs(self) do
                result = result..v.."\n"
            end
            return result
        end,
    })
end

--- hs.doc.help(identifier)
--- Function
--- Prints the documentation for some part of Hammerspoon's API and Lua 5.3.  This function has also been aliased as `hs.help` and `help` as a shorthand for use within the Hammerspoon console.
---
--- Parameters:
---  * identifier - A string containing the signature of some part of Hammerspoon's API (e.g. `"hs.reload"`)
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is mainly for runtime API help while using Hammerspoon's Console
---
---  * Documentation files registered with [hs.doc.registerJSONFile](#registerJSONFile) or [hs.doc.preloadSpoonDocs](#preloadSpoonDocs) that have not yet been actually loaded will be loaded when this command is invoked in any of the forms described below.
---
---  * You can also access the results of this function by the following methods from the console:
---    * help("prefix.path") -- quotes are required, e.g. `help("hs.reload")`
---    * help.prefix.path -- no quotes are required, e.g. `help.hs.reload`
---      * `prefix` can be one of the following:
---        * `hs`    - provides documentation for Hammerspoon's builtin commands and modules
---        * `spoon` - provides documentation for the Spoons installed on your system
---        * `lua`   - provides documentation for the version of lua Hammerspoon is using, currently 5.3
---          * `lua._man` - provides the table of contents for the Lua 5.3 manual.  You can pull up a specific section of the lua manual by including the chapter (and subsection) like this: `lua._man._3_4_8`.
---          * `lua._C`   - provides documentation specifically about the Lua C API for use when developing modules which require external libraries.
---      * `path` is one or more components, separated by a period specifying the module, submodule, function, or moethod you wish to view documentation for.
module.help = function(...)
    local answer = _help(...)
    return setmetatable({}, {
        __tostring = function(self) return answer end, -- luacheck: ignore
    })
end

--- hs.doc.locateJSONFile(module) -> path | false, message
--- Function
--- Locates the JSON file corresponding to the specified third-party module or Spoon by searching package.path and package.cpath.
---
--- Parameters:
---  * module - the name of the module to locate a JSON file for
---
--- Returns:
---  * the path to the JSON file, or `false, error` if unable to locate a corresponding JSON file.
---
--- Notes:
---  * The JSON should be named 'docs.json' and located in the same directory as the `lua` or `so` file which is used when the module is loaded via `require`.
---
---  * The documentation for core modules is stored in the JSON file specified by the `hs.docstrings_json_file` variable; this function is intended for use in locating the documentation file for third party modules and Spoons.
module.locateJSONFile = function(moduleName)
    local asLua = package.searchpath(moduleName, package.path)
    local asC   = package.searchpath(moduleName, package.cpath)

    if asLua then
        local pathPart = asLua:match("^(.*/).+%.lua$")
        if pathPart then
            if fs.attributes(pathPart.."docs.json") then
                return pathPart.."docs.json"
            else
                return false, "No JSON file for "..moduleName.." found"
            end
        else
            return false, "Unable to parse package.path for "..moduleName
        end
    elseif asC then
        local pathPart = asC:match("^(.*/).+%.so$")
        if pathPart then
            if fs.attributes(pathPart.."docs.json") then
                return pathPart.."docs.json"
            else
                return false, "No JSON file for "..moduleName.." found"
            end
        else
            return false, "Unable to parse package.cpath for "..moduleName
        end
    else
        return false, "Unable to locate module path for "..moduleName
    end
end

--- hs.doc.preloadSpoonDocs()
--- Function
--- Locates all installed Spoon documentation files and and marks them for loading the next time the [hs.doc.help](#help) function is invoked.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
module.preloadSpoonDocs = function()
    local spoonPaths, installedSpoons = {}, {}
    for path in package.path:gmatch("([^;]+Spoons/%?%.spoon/init%.lua)") do
        table.insert(spoonPaths, path)
    end
    for _, v in ipairs(spoonPaths) do
        local dirPath = v:match("^(.+)/%?%.spoon/init%.lua$")
        if dirPath and fs.dir(dirPath) then
            for file in fs.dir(dirPath) do
                local name = file:match("^(.+)%.spoon$")
                local spoonInit = name and package.searchpath(name, table.concat(spoonPaths, ";"))
                if name and spoonInit then
                    local path     = spoonInit:match("^(.+)/init%.lua$")
                    local docPath  = path .. "/docs.json"
                    local hasDocs  = fs.attributes(docPath) and true or false
                    if hasDocs then
                        module.registerJSONFile(docPath, true)
                        table.insert(installedSpoons, docPath)
                    end
                end
            end
        end
    end
end

-- Return Module Object --------------------------------------------------

module.registerJSONFile(hs.docstrings_json_file)
module.registerJSONFile((hs.docstrings_json_file:gsub("/docs.json$","/lua.json")))

-- we hide some debugging stuff in the metatable but we want to modify it here, and its considered bad style
-- to do so while it's attached to something, so...

local _mt = getmetatable(module) or {} -- in our case, it's not empty, but I cut and paste a lot
setmetatable(module, nil)
_mt.__call = function(_, ...) return module.help(...) end
_mt.__tostring = function() return _help() end
_mt.__index = function(self, key)
    if submodules[key] then
        self[key] = require(submodules[key])
        return self[key]
    end

    _mt._loadRegisteredFiles() -- we have to assume they're accessing this for help or hsdocs, so load files

    -- massage the result for hsdocs, which we should really rewrite at some point
    if key == "_jsonForSpoons" or key == "_jsonForModules" then
        if not _jsonForSpoons then
            _jsonForSpoons = {}
            for _, path in ipairs(module.registeredFiles()) do
                local file = _mt._registeredFilesObject()[path]
                if file.spoon then
                    for _, v in ipairs(file.json) do
                        if not (v.name:match("^lua$") or v.name:match("^lua[%.:]")) then
                            table.insert(_jsonForSpoons, v)
                        end
                    end
                end
            end
            table.sort(_jsonForSpoons, function(a,b) return a.name:lower() < b.name:lower() end)
        end
        if not _jsonForModules then
            _jsonForModules = {}
            for _, path in ipairs(module.registeredFiles()) do
                local file = _mt._registeredFilesObject()[path]
                if not file.spoon then
                    for _, v in ipairs(file.json) do
                        if not (v.name:match("^lua$") or v.name:match("^lua[%.:]")) then
                            table.insert(_jsonForModules, v)
                        end
                    end
                end
            end
            table.sort(_jsonForModules, function(a,b) return a.name:lower() < b.name:lower() end)
        end
        return (key == "_jsonForModules") and _jsonForModules or _jsonForSpoons
    end
    local children = _mt._children()
    if fnutils.contains(children, key) then
        return setmetatable({ _key = key }, helperMT)
    end
    return rawget(self, key)
end

return setmetatable(module, _mt)
