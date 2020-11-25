local USERDATA_TAG = "luaskin.objectWrapper"

local ls   = _G["ls"]
local owMT = debug.getregistry()[USERDATA_TAG]

-- private variables and methods -----------------------------------------

-- copied from `hs.fnutils` to keep this file independant of Hammerspoon
-- sorts a key-value table by the keys and returns an iterator function usable by the lua `for` command
local _sortByKeys = function(t, f)
  -- a default, simple comparison that treats keys as strings only if their types differ
  f = f or function(m,n) if type(m) ~= type(n) then return tostring(m) < tostring(n) else return m < n end end
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


-- meta table used by `ls.makeConstantsTable` to prevent changes to tables which contain runtime constants
-- which should not be changed
local _kMetaTable = {}
_kMetaTable._k = setmetatable({}, {__mode = "k"})
_kMetaTable._t = setmetatable({}, {__mode = "k"})
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
            for k,v in _sortByKeys(_kMetaTable._k[obj]) do
                if _kMetaTable._t[obj] == "table" then
                    result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
                        ((type(v) == "table") and "{ table }" or tostring(v)))
                else
                    result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable
_makeConstantsTable = function(theTable)
    if type(theTable) ~= "table" then
        local dbg = debug.getinfo(2)
        local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
        print(msg)
        return theTable
    end
    for k,v in pairs(theTable) do
        if type(v) == "table" then
            local count = 0
            for a,b in pairs(v) do count = count + 1 end
            local results = _makeConstantsTable(v)
            if #v > 0 and #v == count then
                _kMetaTable._t[results] = "array"
            else
                _kMetaTable._t[results] = "table"
            end
            theTable[k] = results
        end
    end
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    local count = 0
    for a,b in pairs(theTable) do count = count + 1 end
    if #theTable > 0 and #theTable == count then
        _kMetaTable._t[results] = "array"
    else
        _kMetaTable._t[results] = "table"
    end
    return results
end

-- Public interface ------------------------------------------------------

owMT.__pairs = function(self)
    local keys, values = self:children(), {}
    for _, v in ipairs(keys) do values[v] = self[v] end
    return function(_, k)
            local v
            k, v = next(values, k)
            return k, v
        end, self, nil
end

owMT.__index = function(self, key)
    return rawget(owMT, key) or owMT.__index2(self, key)
end

ls.makeConstantsTable = _makeConstantsTable

ls.deprecated = function(module, name, message)
    assert(type(module)  == "table",  "expected module table for argument 1")
    assert(type(name)    == "string", "expected string specifying function name for argument 2")
    assert(type(message) == "string", "expected string specifying deprecation message for argument 3")

    local shortName = name:match("%.([%w_]+)$") or name
    assert(module[shortName] == nil,       string.format("%s defined in module; can't deprecate", name))

    module[shortName] = function(...)  -- luacheck: ignore
        error(string.format("%s has been deprecated; %s", name, message), 2)
    end
end

local warningsIssued = {}

ls.deprecationWarning = function(module, name, message, fn)
    assert(type(module)  == "table",  "expected module table for argument 1")
    assert(type(name)    == "string", "expected string specifying function name for argument 2")
    assert(type(message) == "string", "expected string specifying deprecation message for argument 3")

    local shortName = name:match("%.([%w_]+)$") or name
    if type(fn) == "nil" then fn = module[shortName] end
    if type(module[shortName]) ~= "nil" then
        assert(module[shortName] == fn, "if function predefined, specified function must match or be nil")
    end
    assert(type(fn) == "function" or (getmetatable(fn) or {}).__call, "expected function for argument 4")

    -- use math.random instead of hs.host.uuid to keep this non hammerspoon specific
    local uniqueKey = math.random(1000000)
    while type(warningsIssued[uniqueKey]) ~= "nil" do uniqueKey = math.random(1000000) end

    warningsIssued[uniqueKey] = false
    module[shortName] = function(...)
        if not warningsIssued[uniqueKey] then
            warningsIssued[uniqueKey] = true
            if hs and hs.openConsole then hs.openConsole() end
            print(string.format("%s has been deprecated and may go away in the future; %s", name, message))
        end
        return fn(...)
    end
end
