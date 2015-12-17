
--- === hs.doc ===
---
--- Create documentation objects for interactive help within Hammerspoon
---
--- The documentation object created is a table with tostring metamethods allowing access to a specific functions documentation by appending the path to the method or function to the object created.
---
--- From the Hammerspoon console:
---
---       doc = require("hs.doc").fromRegisteredFiles()
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
--- By default, the internal core documentation and portions of the Lua 5.3 manual, located at http://www.lua.org/manual/5.3/manual.html, are already registered for inclusion within this documentation object, but you can register additional documentation from 3rd party modules with `hs.registerJSONFile(...)` or limit the documentation to a single specific file with `hs.fromJSONFile(...)`.

local module = {}

-- private variables and methods -----------------------------------------

local json    = require("hs.json")
local fs      = require("hs.fs")
local fnutils = require("hs.fnutils")

local sortFunction = function(m,n) -- sort function so lua manual toc sorts correctly
    if m:match("^_%d") and n:match("^_%d") then
        local a, b =  fnutils.split(m:match("^_([^%s]+)"), "_"),
                      fnutils.split(n:match("^_([^%s]+)"), "_")

        if tonumber(a[1]) ~= tonumber(b[1]) then
            return tonumber(a[1]) < tonumber(b[1])
        elseif a[2] == nil then return true
        elseif b[2] == nil then return false
        elseif tonumber(a[2]) ~= tonumber(b[2]) then
            return tonumber(a[2]) < tonumber(b[2])
        elseif a[3] == nil then return true
        elseif b[3] == nil then return false
        else
            return tonumber(a[3]) < tonumber(b[3])
        end
    else
        return m < n
    end
end

local function item_tostring(item)
  return item[2] .. ": " .. item[1] .. "\n\n" .. item[3] .. "\n"
end

local function group_tostring(group)
  local str = group.__doc .. "\n\n"

  str = str .. "[submodules]\n"
  for name, item in fnutils.sortByKeys(group, sortFunction) do
    if name ~= '__doc' and name ~= '__name' and getmetatable(item) == getmetatable(group) then
      str = str .. item.__name .. "\n"
    end
  end

  str = str .. "\n" .. "[subitems]\n"
  for name, item in fnutils.sortByKeys(group, sortFunction) do
    if name ~= '__doc' and name ~= '__name' and getmetatable(item) ~= getmetatable(group) then
      str = str .. item[1] .. "\n"
    end
  end

  return str .. "\n"
end

local function doc_tostring(doc)
  local str = '[modules]\n'

  for name, group in fnutils.sortByKeys(doc, sortFunction) do
    str = str .. group.__name .. '\n'
  end

  return str
end

local group_metatable = {__tostring = group_tostring}
local item_metatable = {__tostring = item_tostring}

local internalBuild = function(rawdocs)
  local doc = setmetatable({}, {__tostring = doc_tostring})
  for _, mod in pairs(rawdocs) do
    local parts = {}
    for s in string.gmatch(mod.name, "[%w_]+") do
      table.insert(parts, s)
    end

    local parent = doc
    local keyname = parts[#parts]
    parts[#parts] = nil
    local subname = nil
    for _, s in ipairs(parts) do
      subname = subname and subname.."."..s or s
      if type(parent[s]) == "nil" then
        parent[s] = setmetatable({__doc = subname, __name = subname}, group_metatable)
      end
      parent = parent[s]
    end

    local m = setmetatable({__doc = mod.doc, __name = mod.name}, group_metatable)
    parent[keyname] = m

    for _, item in pairs(mod.items) do
      m[item.name] = setmetatable({__name = item.name, item.def, item.type, item.doc}, item_metatable)
    end
  end
  return doc
end

local __tostring_for_arrays = function(self)
    local result = ""
    for i,v in fnutils.sortByKeyValues(self) do
        result = result..v.."\n"
    end
    return result
end

local registeredJSONFiles = setmetatable({
        hs.docstrings_json_file,
        (hs.docstrings_json_file:gsub("/docs.json$","/extensions/hs/doc/lua.json"))
    }, {__tostring = __tostring_for_arrays})

local validateJSONFile = function(jsonFile)
    local f = io.open(jsonFile)
    if not f then
        return false, "Unable to open '"..jsonFile.."'"
    else
        local content = f:read("*a")
        f:close()
        return pcall(json.decode, content)
    end
end

local fixLinks = function(text)
    -- replace internal link references which work well in html and dash with something
    -- more appropriate to inline textual help
    local content, count = text:gsub("%[([^%]\r\n]+)%]%(#([^%)\r\n]+)%)", "`%1`")
    return content
end

-- Public interface ------------------------------------------------------

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
module.registerJSONFile = function(docFile)
    if type(docFile) ~= "string" then
        -- most likely this was called with the result of the locateJSONFile function,
        -- and the locate function was unable to find the JSON file...
        return false, "Provided path is not a string."
    end
    local status, message = module.validateJSONFile(docFile)
    if status then
        local alreadyRegistered = false
        for _, v in ipairs(registeredJSONFiles) do
            if v == docFile then
                alreadyRegistered = true
                break
            end
        end
        if alreadyRegistered then
            return false, "File '"..docFile.."' already registered"
        end
        table.insert(registeredJSONFiles, docFile)
        return status
    end
    return status, message
end

--- hs.doc.unregisterJSONFile(jsonfile) -> status[, message]
--- Function
--- Remove a JSON file from the list of registered files.
---
--- Parameters:
---  * jsonfile - A string containing the location of a JSON file
---
--- Returns:
---  * status - Boolean flag indicating if the file was unregistered or not.  If the file was not unregistered, then a message indicating the error is also returned.
module.unregisterJSONFile = function(docFile)
    local indexNumber, found = false
    for i, v in ipairs(registeredJSONFiles) do
        if v == docFile then
            found = true
            indexNumber = i
            break
        end
    end
    if found then
        table.remove(registeredJSONFiles, indexNumber)
        return true
    else
        return false, "File '"..docFile.."' was not registered"
    end
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
module.registeredFiles = function(docFile)
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
---  * The JSON should be named 'full.module.name.json' and located in the same directory as the `lua` or `so` file which is used when the module is loaded via `require`.
module.locateJSONFile = function(moduleName)
  local asLua = package.searchpath(moduleName, package.path)
  local asC   = package.searchpath(moduleName, package.cpath)

  if asLua then
      local pathPart = asLua:match("^(.*/).+%.lua$")
      if pathPart then
          if fs.attributes(pathPart..moduleName..".json") then
              return pathPart..moduleName..".json"
          else
              return false, "No JSON file for "..moduleName.." found"
          end
      else
          return false, "Unable to parse package.path for "..moduleName
      end
  elseif asC then
      local pathPart = asC:match("^(.*/).+%.so$")
      if pathPart then
          if fs.attributes(pathPart..moduleName..".json") then
              return pathPart..moduleName..".json"
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

--- hs.doc.fromJSONFile(jsonfile) -> doc-array
--- Function
--- Builds a doc array construct from the JSON file provided.
---
--- Parameters:
---  * jsonfile - A string containing the location of a JSON file
---
--- Returns:
---  * A table containing the documentation data loaded from the JSON file
function module.fromJSONFile(docsfile)
  local f = io.open(docsfile)
  if not f then
    print("Documentation file '"..docsfile.."' not found...")
    return setmetatable(
        {"Documentation file '"..docsfile.."' not found..."},
        {__tostring = function(a) return a[1] end}
    )
  end
  local content = f:read("*a")
  f:close()
  content = fixLinks(content)
  return internalBuild(json.decode(content))
end

--- hs.doc.fromRegisteredFiles() -> doc-array
--- Function
--- Builds a doc array construct from the registered JSON files.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing the documentation data loaded from the registered JSON files
---
--- Notes:
---  * By default, the internal core documentation is already registered.  If you wish to remove it from the list of registered sources, issue the command `hs.doc.unregisterJSONFile(hs.docstrings_json_file)`.
---  * The documentation object is created from the sources that are registered at the time of its invocation. If you register additional files later, you will need to reissue this command to build the updated documentation object.
function module.fromRegisteredFiles()
  local docData = {}
  for _, v in ipairs(registeredJSONFiles) do
    local f = io.open(v)
    if not f then
      print("Documentation file '"..docsfile.."' not found...")
      return setmetatable(
          {"Documentation file '"..docsfile.."' not found..."},
          {__tostring = function(a) return a[1] end}
      )
    end
    local content = f:read("*a")
    f:close()
    content = fixLinks(content)
    for _, j in pairs(json.decode(content)) do
      table.insert(docData, j)
    end
  end

  return internalBuild(docData)
end

local coredocs = module.fromRegisteredFiles()

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
    local tree = coredocs
    local result = tree

    for word in string.gmatch(identifier, '([^.]+)') do
        result = result[word]
    end

    print(result)
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
        __call = function(_, ...) return module.help(...) end,
        __index = coredocs,
        __tostring = function(obj) return tostring(coredocs) end,
})

