
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

local module = {}

module.spoonsupport  = require("hs.doc.spoonsupport")

-- private variables and methods -----------------------------------------

local json      = require("hs.json")
local fs        = require("hs.fs")
local fnutils   = require("hs.fnutils")
local inspect   = require("hs.inspect")
local watchable = require("hs.watchable")

local sortFunction = function(m,n) -- sort function so lua manual toc sorts correctly
    if m:match("^_%d") and n:match("^_%d") then
        local a, b =  fnutils.split(m:match("^_([^%s]+)"), "_"),
                      fnutils.split(n:match("^_([^%s]+)"), "_")

        if tonumber(a[1]) ~= tonumber(b[1]) then
            return tonumber(a[1]) < tonumber(b[1])
        elseif a[2] == nil and b[2] == nil then return false
        elseif a[2] == nil then return true
        elseif b[2] == nil then return false
        elseif tonumber(a[2]) ~= tonumber(b[2]) then
            return tonumber(a[2]) < tonumber(b[2])
        elseif a[3] == nil and b[3] == nil then return false
        elseif a[3] == nil then return true
        elseif b[3] == nil then return false
        else
            return tonumber(a[3]) < tonumber(b[3])
        end
    else
        return m < n
    end
end

local fixLinks = function(text)
    -- replace internal link references which work well in html and dash with something
    -- more appropriate to inline textual help
    local content = text:gsub("%[([^%]\r\n]+)%]%(#([^%)\r\n]+)%)", "`%1`")
    return content
end

local coredocs = {}
local rawdocs = { spoon = {} }

local docMT
docMT = {
    __index = function(self, key)
        local path, pos = rawget(self, "__path"), rawget(self, "__pos")
        local result
        if not path then
            result = rawdocs[key] and setmetatable({ __path = key, __pos = rawdocs[key] }, docMT) or nil
        else
            result = pos[key] and setmetatable({ __path = path .. "." .. key, __pos = pos[key] }, docMT) or nil
        end
        return result
    end,
    __tostring = function(self)
        local result
        local path, pos = rawget(self, "__path"), rawget(self, "__pos")
        if not pos then
            result = "[modules]\n"
            for k,_ in fnutils.sortByKeys(rawdocs, function(a,b) return a:lower() < b:lower() end) do
                result = result .. k .. "\n"
            end
        elseif path == "spoon" then
            result = "[spoons]\n"
            for k,_ in fnutils.sortByKeys(pos, function(a,b) return a:lower() < b:lower() end) do
                result = result .. k .. "\n"
            end
        elseif pos.__ and not pos.__.json.items then
            result = pos.__.json.type .. ": " .. (pos.__.json.signature or pos.__.json.def) .. "\n\n" .. pos.__.json.doc .. "\n"
        else
            if pos.__ then
                result = pos.__.json.doc .. "\n\n"
            else
                result = "** DOCUMENTATION MISSING **\n\n"
            end
            local submodules, items = "", ""
            for k, v in fnutils.sortByKeys(pos, sortFunction) do
                if k ~= "__" then
                -- spoons placeholder will not have __ and older docs (lua) will not have a type for sections (modules)
                    if not v.__ or not v.__.json.type or v.__.json.type == "Module" then
                        submodules = submodules .. k .. "\n"
                    else
                        items = items .. (v.__.json.signature or v.__.json.def) .. "\n"
                    end
                end
            end

            result = result .. "[submodules]\n" .. submodules .. "\n"
            result = result .. "[subitems]\n" .. items .. "\n"
        end
        return fixLinks(result)
    end,
    __pairs = function(self)
        local _, pos = rawget(self, "__path"), rawget(self, "__pos")
        local source
        if not pos then
            source = rawdocs
        else
            source = pos
        end
        return function(_, k)
            local v
            k, v = next(source, k)
            if k == "__" then
                k, v = next(source, k)
            end
            return k, v
        end, self, nil
    end
}

local helpHolder = setmetatable({}, docMT)

-- Public interface ------------------------------------------------------

local buildHoldingTable = function(self)
    local holder = {}
    for _,v in pairs(coredocs) do
        if v.spoon == self.__spoon then
            for _, v2 in ipairs(v.json) do
                if not (self.__ignore and (v2.name:match("^" .. self.__ignore .. "$") or v2.name:match("^" .. self.__ignore .. "[%.:]"))) then
                    table.insert(holder, v2)
                end
            end
        end
    end
    table.sort(holder, function(a,b) return sortFunction(a.name:lower(), b.name:lower()) end)
    return holder
end

local jsonMT = {
    __index = function(self, key)
        local holder = buildHoldingTable(self)
        return holder[key]
    end,
    __pairs = function(self)
        local holder = buildHoldingTable(self)
        return function(_, k)
            local v
            k, v = next(holder, k)
            return k, v
        end, self, nil
    end,
    __len = function(self)
        local holder = buildHoldingTable(self)
        return #holder
    end,
}

local changeCount = watchable.new("hs.doc")
changeCount.changeCount = 0

module._jsonForSpoons    = setmetatable({ __spoon = true,  __ignore = false }, jsonMT)
module._jsonForNonSpoons = setmetatable({ __spoon = false, __ignore = false }, jsonMT)
module._jsonForModules   = setmetatable({ __spoon = false, __ignore = "lua" }, jsonMT)

--module._coredocs = coredocs
--module._help     = helpHolder
--module._rawdocs  = rawdocs

--- hs.doc.validateJSONFile(jsonfile) -> status, message|table
--- Function
--- Validate a JSON file potential inclusion in the Hammerspoon internal documentation.
---
--- Parameters:
---  * jsonfile - A string containing the location of a JSON file
---
--- Returns:
---  * status - Boolean flag indicating if the file was validated or not.
---  * message|table - If the file did not contain valid JSON data, then a message indicating the error is returned; otherwise the parsed JSON data is returned as a table.
module.validateJSONFile = function(jsonFile)
    local f = io.open(jsonFile)
    if not f then
        return false, "Unable to open '"..jsonFile.."'"
    else
        local content = f:read("*a")
        f:close()
        return pcall(json.decode, content)
    end
end

--- hs.doc.registerJSONFile(jsonfile) -> status[, message]
--- Function
--- Register a JSON file for inclusion when Hammerspoon generates internal documentation.
---
--- Parameters:
---  * jsonfile - A string containing the location of a JSON file
---
--- Returns:
---  * status - Boolean flag indicating if the file was registered or not.  If the file was not registered, then a message indicating the error is also returned.
module.registerJSONFile = function(docFile, isSpoon)
    if type(docFile) ~= "string" then
        -- most likely this was called with the result of the locateJSONFile function,
        -- and the locate function was unable to find the JSON file...
        return false, "Provided path is not a string."
    end

    docFile = fs.pathToAbsolute(docFile)

    local status, message = module.validateJSONFile(docFile)
    if status then
        if coredocs[docFile] then
            return false, "File '"..docFile.."' already registered"
        end
        coredocs[docFile] = {
            spoon = (isSpoon and type(isSpoon) == "boolean") and true or false,
            json  = message
        }

        for _, entry in ipairs(message) do
            local current = coredocs[docFile].spoon and rawdocs.spoon or rawdocs
            for s in string.gmatch(entry.name, "[%w_]+") do
                current[s] = current[s] or {}
                current = current[s]
            end
            if current.__ then
                print("** hs.doc - duplicate module entry at " .. entry.name .. " -> " .. inspect(entry, { depth = 1 }))
            else
                current.__ = { json = entry, file = docFile }
            end
            for _, subitem in ipairs(entry.items or {}) do
                local itemDocName = subitem.name:gsub("[^%w_]", "")
                current[itemDocName] = current[itemDocName] or {}
                if current[itemDocName].__ then
                    print("** hs.doc - duplicate item entry at " .. entry.name .. "." .. subitem.name .. " -> " .. inspect(subitem, { depth = 1 }))
                else
                    current[itemDocName].__ = { json = subitem, file = docFile }
                end
            end
        end
        changeCount.changeCount = changeCount.changeCount + 1
        return status
    end
    return status, message
end

--- hs.doc.unregisterJSONFile(jsonfile, [isSpoon]) -> status[, message]
--- Function
--- Remove a JSON file from the list of registered files.
---
--- Parameters:
---  * jsonfile - A string containing the location of a JSON file
---  * isSpoon  - an optional boolean, default false, specifying that the documentation should be added to the `spoons` sub heading in the documentation hierarchy.
---
--- Returns:
---  * status - Boolean flag indicating if the file was unregistered or not.  If the file was not unregistered, then a message indicating the error is also returned.
module.unregisterJSONFile = function(docFile)
    if coredocs[docFile] then
        coredocs[docFile] = nil
        local purgeFromInside
        purgeFromInside = function(where)
            for k,v in pairs(where) do
                if k ~= "__" and type(v) == "table" then
                    if purgeFromInside(v) then
                        where[k] = nil
                    end
                end
            end
            if where.__ and where.__.file == docFile then
                return not next(where, "__")
            elseif not where.__ then
                return not next(where)
            else
                return false
            end
        end
        purgeFromInside(rawdocs)
        changeCount.changeCount = changeCount.changeCount + 1
        return true
    end
    return false, "File '"..docFile.."' was not registered"
end

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
---    * `hs.doc.unregisterJSONFile((hs.docstrings_json_file:gsub("/docs.json$","/extensions/hs/doc/lua.json")))` -- to unregister the Lua 5.3 Documentation.
module.registeredFiles = function()
    local registeredJSONFiles = setmetatable({}, {
        __tostring = function(self)
            local result = ""
            for _,v in fnutils.sortByKeyValues(self) do
                result = result..v.."\n"
            end
            return result
        end,
    })

    for k,_ in pairs(coredocs) do table.insert(registeredJSONFiles, k) end
    return registeredJSONFiles
end

--- hs.doc.locateJSONFile(module) -> path | false, message
--- Function
--- Locates the JSON file corresponding to the specified module by searching package.path and package.cpath.
---
--- Parameters:
---  * module - the name of the module to locate a JSON file for
---
--- Returns:
---  * the path to the JSON file, or `false, error` if unable to locate a corresponding JSON file.
---
--- Notes:
---  * The JSON should be named 'docs.json' and located in the same directory as the `lua` or `so` file which is used when the module is loaded via `require`.
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
---  * This function only returns information about the core Hammerspoon API and Lua 5.3.  If you register additional files from 3rd party modules, or deregister the initial files for creating your own `hs.doc` objects, it will not affect the results used by this function.
---
---  * You can also access the results of this function by the following methods from the console:
---    * help("identifier") -- quotes are required, e.g. `help("hs.reload")`
---    * help.identifier.path -- no quotes are required, e.g. `help.hs.reload`
---
---  * Lua information can be accessed by using the `lua` prefix, rather than `hs`.
---    * the identifier `lua._man` provides the table of contents for the Lua 5.3 manual.  You can pull up a specific section of the lua manual by including the chapter (and subsection) like this: `lua._man._3_4_8`.
---    * the identifier `lua._C` will provide information specifically about the Lua C API for use when developing modules which require external libraries.

function module.help(identifier)
    local result = helpHolder

    for word in string.gmatch((identifier or ""), '([^.]+)') do
        result = result[word]
    end

    print(result)
end


-- Return Module Object --------------------------------------------------

module.registerJSONFile(hs.docstrings_json_file)
module.registerJSONFile((hs.docstrings_json_file:gsub("/docs.json$","/extensions/hs/doc/lua.json")))

module.spoonsupport.updateDocsFiles()
local _, details = module.spoonsupport.findSpoons()
for _,v in pairs(details) do if v.hasDocs then module.registerJSONFile(v.docPath, true) end end

-- don't load submodules until needed -- makes it easier to troubleshoot when testing
-- upgrades since hs.doc is loaded by _coresetup, but the others don't have to be, and
-- hsdocs especially uses a lot of other modules we might be testing and dont' want loaded
-- until personal path overrides have been set

local submodules = {
    markdown = "hs.doc.markdown",
    hsdocs   = "hs.doc.hsdocs",
    builder  = "hs.doc.builder",
}

return setmetatable(module, {
    __call = function(_, ...) return module.help(...) end,
    __tostring = function() return tostring(helpHolder) end,
    __index = function(self, key)
        if submodules[key] then
            self[key] = require(submodules[key])
        end
        return helpHolder[key] or rawget(self, key)
    end,
})
