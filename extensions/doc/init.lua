--- === hs.doc ===
---
--- Create doc objects which can be access from within the command line tool or the Hammerspoon console for module documentation.
---
--- e.g. `doc = hs.doc.from_json_file('path-to-docs.json')`
---
--- You can use the `hs.docstrings_json_file` constant, e.g. `doc = hs.doc.from_json_file(hs.docstrings_json_file)`
---

local module = {}

-- private variables and methods -----------------------------------------

local json = require("hs.json")

-- Provide function 'f' as per _Programming_In_Lua,_3rd_ed_, page 52; otherwise order is ascii order ascending.
-- e.g. function(m,n) return not (m < n) end would do descending ascii, assuming string keys.
local sorted_keys = function(t, f)
    if t then
        local a = {}
        for n in pairs(t) do table.insert(a, n) end
        table.sort(a, f)
        local i = 0      -- iterator variable
        local iter = function ()   -- iterator function
            i = i + 1
            if a[i] == nil then return nil
                else return a[i], t[a[i]]
            end
        end
        return iter
    else
        return function() return nil end
    end
end

local function item_tostring(item)
  return item[2] .. ": " .. item[1] .. "\n\n" .. item[3] .. "\n"
end

local function group_tostring(group)
  local str = group.__doc .. "\n\n"

  str = str .. "[submodules]\n"
  for name, item in sorted_keys(group) do
    if name ~= '__doc' and name ~= '__name' and getmetatable(item) == getmetatable(group) then
      str = str .. item.__name .. "\n"
    end
  end

  str = str .. "\n" .. "[subitems]\n"
  for name, item in sorted_keys(group) do
    if name ~= '__doc' and name ~= '__name' and getmetatable(item) ~= getmetatable(group) then
      str = str .. item[1] .. "\n"
    end
  end

  return str .. "\n"
end

local function doc_tostring(doc)
  local str = '[modules]\n'

  for name, group in sorted_keys(doc) do
    str = str .. group.__name .. '\n'
  end

  return str
end

local group_metatable = {__tostring = group_tostring}
local item_metatable = {__tostring = item_tostring}

local internalBuild = function(content)
  local rawdocs = json.decode(content)

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
      if _G["debug.docs.module"] == "build" then
        print(mod.name, item, item.def)
        if item.name == nil and package.searchpath("inspect",package.path) then
            print(require("inspect")(item))
        end
      end
      m[item.name] = setmetatable({__name = item.name, item.def, item.type, item.doc}, item_metatable)
    end
  end
  return doc
end

local split = function(div,str)
    if (div=='') then return { str } end
    local pos,arr = 0,{}
    for st,sp in function() return string.find(str,div,pos) end do
        table.insert(arr,string.sub(str,pos,st-1))
        pos = sp + 1
    end
    if string.sub(str,pos) ~= "" then
        table.insert(arr,string.sub(str,pos))
    end
    return arr
end

-- Holder object so we can autoupdate for package.loaded without caring where
-- the user actually stores the reference.  We return a reference to
-- package_loaded_holder, which never changes, and then use meta-methods so
-- that any direct access is passed through to the internal results, which
-- does change every time the update is invoked.

local package_loaded_holder = { results = {} }
setmetatable(package_loaded_holder, {
    __tostring = function(o) return tostring(o.results) end,
    __index = function(o,k) return o.results[k] end
})

local do_package_loaded_update = function()
    local packageLoadedArray = {}
    for i,v in pairs(package.loaded) do table.insert(packageLoadedArray, i) end
    package_loaded_holder.results = module.from_array(packageLoadedArray)
end

-- Public interface ------------------------------------------------------

--- hs.doc.from_json_file(jsonfile) -> doc-array
--- Function
--- Builds a doc array construct from the json file provided.  Usually this will be the json file provided with the Hammerspoon application, but this json file will only contain the documentation for modules recognized by the Hammerspoon builders and the built in modules and not modules from other sources.  For those, use `hs.doc.from_array` and `hs.doc.from_package_loaded`.
function module.from_json_file(docsfile)
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
  return internalBuild(content)
end

--- hs.doc.from_array(array) -> doc-array
--- Function
--- Builds a doc array construct from the lua files of the modules listed in the provided array.  Useful for creating doc objects for in progress modules or local files.
function module.from_array(theArray)
    -- bin/gencomments

    local lines = {}
    for i,v in ipairs(theArray) do
        if package.searchpath(v,package.path) then
            local f = io.open(package.searchpath(v, package.path), 'r')
            local r = f:read('*a') ; f:close()
            local partial = {}
            local incomment = false
            for _,l in ipairs(split("[\r\n]",r)) do
                if l:match("^[/%-][/%-][/%-]") and not l:match("^[/%-][/%-][/%-][/%-]") then
                    incomment = true
                    table.insert(partial, (l:gsub("^[/%-][/%-][/%-]%s?","")))
                elseif incomment then
                    incomment = false
                    table.insert(lines, partial)
                    partial = {}
                end
            end
        end
    end

    -- bin/genjson

    local mods, items = {}, {}
    for i,v in ipairs(lines) do
        if v[1]:match("===") then
            local name = string.match(v[1]:gsub("=",""), "^[%s\r\n]*([^%s\r\n].*[^%s\r\n])[%s\r\n]*$")
            local doc = ""
            local items = {}
            for a = 2, #v, 1 do doc = doc..v[a].."\n" end
            doc = doc:match("^[%s\r\n]*([^%s\r\n].*[^%s\r\n])[%s\r\n]*$") or "--not provided--"
            table.insert(mods, {name = name, doc = doc, items = items})
        else
            local name = ""
            local def = v[1] or ""
            local i_type = v[2] or ""
            local doc = ""
            for a = 3, #v, 1 do doc = doc..v[a].."\n" end
            doc = doc:match("^[%s\r\n]*([^%s\r\n].*[^%s\r\n])[%s\r\n]*$") or "--not provided--"
            table.insert(items, {name = name, def = def, type = i_type, doc = doc})
        end
    end
    table.sort(mods, function(m,n) return not (m.name < n.name) end)

    for i,v in ipairs(items) do
        local mod
        for a,b in ipairs(mods) do
            if v.def:match("^"..b.name:gsub("%.","%%.").."[%.:]") then
                mod = b
                break
            end
        end
        if not mod then
            print("parse error: no module for entity '"..v.def.."'... skipping.")
        else
            local name,sep = v.def:match("^"..mod.name:gsub("%.","%%.").."[%.:]([%w_]+)(.?)")
            if _G["debug.docs.module"] == "genjson" then print(name,sep) end
            if sep == "." or sep == ":" then
                print("parse error: '"..name.."' is not a defined submodule of '"..mod.name.."'... skipping.")
            else
                v.name = name
                table.insert(mod.items, v)
            end
        end
    end
    table.sort(mods, function(m,n) return m.name < n.name end)

    if _G["debug.docs.module"] then
        doc_module_json = json.encode(mods,true)
        doc_module_array = mods
    end
    return internalBuild(json.encode(mods,true))
end

--- hs.doc.from_package_loaded([bool]) -> doc-array
--- Function
--- Builds a doc array construct from the lua files of all modules currently tracked in `package.loaded`, which is where Lua stores modules which have been loaded by `require`.  If the optional boolean value provided is true, then the doc array will be refreshed everytime a new module is loaded via `require`.
module.from_package_loaded = function(autorefresh)
    do_package_loaded_update()

    if autorefresh then
        setmetatable(package.loaded, {
            __newindex = function(o,k,v)
                rawset(o,k,v)
                do_package_loaded_update()
            end
        })
    end
    return autorefresh and package_loaded_holder or package_loaded_helper.results
end

-- Return Module Object --------------------------------------------------

return module
