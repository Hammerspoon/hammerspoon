--- === inspect ===
---
--- For inspecting tables and stuff.
--- See also:
---  - http://github.com/kikito/inspect.lua
---  - `hydra.licenses`

--- inspect.inspect(t) -> string
--- Returns a pretty-printed string of the table.
--- You can also use `inspect(t)` instead.

inspect ={
  _VERSION = 'inspect.lua 2.0.0',
  _URL     = 'http://github.com/kikito/inspect.lua',
  _DESCRIPTION = 'human-readable representations of tables',
  _LICENSE = [[
    MIT LICENSE

    Copyright (c) 2013 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]
}

-- Apostrophizes the string if it has quotes, but not aphostrophes
-- Otherwise, it returns a regular quoted string
local function smartQuote(str)
  if str:match('"') and not str:match("'") then
    return "'" .. str .. "'"
  end
  return '"' .. str:gsub('"', '\\"') .. '"'
end

local controlCharsTranslation = {
  ["\a"] = "\\a",  ["\b"] = "\\b", ["\f"] = "\\f",  ["\n"] = "\\n",
  ["\r"] = "\\r",  ["\t"] = "\\t", ["\v"] = "\\v"
}

local function escapeChar(c) return controlCharsTranslation[c] end

local function escape(str)
  local result = str:gsub("\\", "\\\\"):gsub("(%c)", escapeChar)
  return result
end

local function isIdentifier(str)
  return type(str) == 'string' and str:match( "^[_%a][_%a%d]*$" )
end

local function isArrayKey(k, length)
  return type(k) == 'number' and 1 <= k and k <= length
end

local function isDictionaryKey(k, length)
  return not isArrayKey(k, length)
end

local defaultTypeOrders = {
  ['number']   = 1, ['boolean']  = 2, ['string'] = 3, ['table'] = 4,
  ['function'] = 5, ['userdata'] = 6, ['thread'] = 7
}

local function sortKeys(a, b)
  local ta, tb = type(a), type(b)

  -- strings and numbers are sorted numerically/alphabetically
  if ta == tb and (ta == 'string' or ta == 'number') then return a < b end

  local dta, dtb = defaultTypeOrders[ta], defaultTypeOrders[tb]
  -- Two default types are compared according to the defaultTypeOrders table
  if dta and dtb then return defaultTypeOrders[ta] < defaultTypeOrders[tb]
  elseif dta     then return true  -- default types before custom ones
  elseif dtb     then return false -- custom types after default ones
  end

  -- custom types are sorted out alphabetically
  return ta < tb
end

local function getDictionaryKeys(t)
  local keys, length = {}, #t
  for k,_ in pairs(t) do
    if isDictionaryKey(k, length) then table.insert(keys, k) end
  end
  table.sort(keys, sortKeys)
  return keys
end

local function getToStringResultSafely(t, mt)
  local __tostring = type(mt) == 'table' and rawget(mt, '__tostring')
  local str, ok
  if type(__tostring) == 'function' then
    ok, str = pcall(__tostring, t)
    str = ok and str or 'error: ' .. tostring(str)
  end
  if type(str) == 'string' and #str > 0 then return str end
end

local maxIdsMetaTable = {
  __index = function(self, typeName)
    rawset(self, typeName, 0)
    return 0
  end
}

local idsMetaTable = {
  __index = function (self, typeName)
    local col = setmetatable({}, {__mode = "kv"})
    rawset(self, typeName, col)
    return col
  end
}

local function countTableAppearances(t, tableAppearances)
  tableAppearances = tableAppearances or setmetatable({}, {__mode = "k"})

  if type(t) == 'table' then
    if not tableAppearances[t] then
      tableAppearances[t] = 1
      for k,v in pairs(t) do
        countTableAppearances(k, tableAppearances)
        countTableAppearances(v, tableAppearances)
      end
      countTableAppearances(getmetatable(t), tableAppearances)
    else
      tableAppearances[t] = tableAppearances[t] + 1
    end
  end

  return tableAppearances
end

local function parse_filter(filter)
  if type(filter) == 'function' then return filter end
  -- not a function, so it must be a table or table-like
  filter = type(filter) == 'table' and filter or {filter}
  local dictionary = {}
  for _,v in pairs(filter) do dictionary[v] = true end
  return function(x) return dictionary[x] end
end

local function makePath(path, key)
  local newPath, len = {}, #path
  for i=1, len do newPath[i] = path[i] end
  newPath[len+1] = key
  return newPath
end

-------------------------------------------------------------------
function inspect.inspect(rootObject, options)
  options       = options or {}
  local depth   = options.depth or math.huge
  local filter  = parse_filter(options.filter or {})

  local tableAppearances = countTableAppearances(rootObject)

  local buffer = {}
  local maxIds = setmetatable({}, maxIdsMetaTable)
  local ids    = setmetatable({}, idsMetaTable)
  local level  = 0
  local blen   = 0 -- buffer length

  local function puts(...)
    local args = {...}
    for i=1, #args do
      blen = blen + 1
      buffer[blen] = tostring(args[i])
    end
  end

  local function down(f)
    level = level + 1
    f()
    level = level - 1
  end

  local function tabify()
    puts("\n", string.rep("  ", level))
  end

  local function commaControl(needsComma)
    if needsComma then puts(',') end
    return true
  end

  local function alreadyVisited(v)
    return ids[type(v)][v] ~= nil
  end

  local function getId(v)
    local tv = type(v)
    local id = ids[tv][v]
    if not id then
      id         = maxIds[tv] + 1
      maxIds[tv] = id
      ids[tv][v] = id
    end
    return id
  end

  local putValue -- forward declaration that needs to go before putTable & putKey

  local function putKey(k)
    if isIdentifier(k) then return puts(k) end
    puts( "[" )
    putValue(k, {})
    puts("]")
  end

  local function putTable(t, path)
    if alreadyVisited(t) then
      puts('<table ', getId(t), '>')
    elseif level >= depth then
      puts('{...}')
    else
      if tableAppearances[t] > 1 then puts('<', getId(t), '>') end

      local dictKeys          = getDictionaryKeys(t)
      local length            = #t
      local mt                = getmetatable(t)
      local to_string_result  = getToStringResultSafely(t, mt)

      puts('{')
      down(function()
        if to_string_result then
          puts(' -- ', escape(to_string_result))
          if length >= 1 then tabify() end -- tabify the array values
        end

        local needsComma = false
        for i=1, length do
          needsComma = commaControl(needsComma)
          puts(' ')
          putValue(t[i], makePath(path, i))
        end

        for _,k in ipairs(dictKeys) do
          needsComma = commaControl(needsComma)
          tabify()
          putKey(k)
          puts(' = ')
          putValue(t[k], makePath(path, k))
        end

        if mt then
          needsComma = commaControl(needsComma)
          tabify()
          puts('<metatable> = ')
          putValue(mt, makePath(path, '<metatable>'))
        end
      end)

      if #dictKeys > 0 or mt then -- dictionary table. Justify closing }
        tabify()
      elseif length > 0 then -- array tables have one extra space before closing }
        puts(' ')
      end

      puts('}')
    end

  end

  -- putvalue is forward-declared before putTable & putKey
  putValue = function(v, path)
    if filter(v, path) then
      puts('<filtered>')
    else
      local tv = type(v)

      if tv == 'string' then
        puts(smartQuote(escape(v)))
      elseif tv == 'number' or tv == 'boolean' or tv == 'nil' then
        puts(tostring(v))
      elseif tv == 'table' then
        putTable(v, path)
      else
        puts('<',tv,' ',getId(v),'>')
      end
    end
  end

  putValue(rootObject, {})

  return table.concat(buffer)
end

setmetatable(inspect, { __call = function(_, ...) return inspect.inspect(...) end })
