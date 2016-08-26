local _ENV		= _ENV
local getmetatable	= getmetatable
local nonempty		= next
local next		= next
local pairs		= pairs
local select		= select
local setmetatable	= setmetatable
local type		= type
local unpack		= table.unpack or unpack

local table_concat	= table.concat
local table_pack	= table.pack or false
local table_sort	= table.sort



--[[ ================== ]]--
--[[ Initialize _DEBUG. ]]--
--[[ ================== ]]--


local _DEBUG, argscheck, strict
do
  -- Make sure none of these symbols leak out into the rest of the
  -- module, in case we can enable 'strict' mode at the end of the block.
  local pcall		= pcall
  local require		= require

  local ok, debug_init	= pcall (require, "std.debug_init")
  if ok then
    _DEBUG		= debug_init._DEBUG
  else
    local function choose (t)
      for k, v in pairs (t) do
        if _DEBUG == false then
          t[k] = v.fast
        elseif _DEBUG == nil then
          t[k] = v.default
        elseif type (_DEBUG) ~= "table" then
          t[k] = v.safe
        elseif _DEBUG[k] ~= nil then
          t[k] = _DEBUG[k]
        else
          t[k] = v.default
        end
      end
      return t
    end

    _DEBUG = choose {
      strict    = {default = true,  safe = true,  fast = false},
      argcheck  = {default = true,  safe = true,  fast = false},
    }
  end

  -- Unless strict was disabled (`_DEBUG = false`), or that module is not
  -- available, check for use of undeclared variables in this module...
  if _DEBUG.strict then
    ok, strict		= pcall (require, "std.strict")
    if ok then
      _ENV = strict {}
    else
      -- ...otherwise, the strict function is not available at all!
      _DEBUG.strict	= false
      strict		= false
    end
  end

  -- Unless strict was disabled (`_DEBUG = false`), or that module is not
  -- available, check for use of undeclared variables in this module...
  if _DEBUG.argcheck then
    local ok, typecheck	= pcall (require, "typecheck")
    if ok then
      argscheck		= typecheck.argscheck
    else
      -- ...otherwise, the strict function is not available at all!
      _DEBUG.argcheck	= false
      typecheck		= false
    end
  end
end



--[[ ================== ]]--
--[[ Normalize Lua API. ]]--
--[[ ================== ]]--


local function getmetamethod (x, n)
  local m = (getmetatable (x) or {})[n]
  if type (m) == "function" then return m end
  return (getmetatable (m) or {}).__call
end


-- Iterate over keys 1..n, where n is the key before the first nil
-- valued ordinal key (like Lua 5.3).
local ipairs = (_VERSION == "Lua 5.3") and ipairs or function (l)
  return function (l, n)
    n = n + 1
    if l[n] ~= nil then
      return n, l[n]
    end
  end, l, 0
end


-- Respect __len metamethod (like Lua 5.2+), otherwise always return one
-- less than the index of the first nil value in table x.
local function len (x)
  local m = getmetamethod (x, "__len")
  if m then return m (x) end
  if type (x) ~= "table" then return #x end

  local n = #x
  for i = 1, n do
    if x[i] == nil then return i -1 end
  end
  return n
end


-- Respect __pairs method, even in Lua 5.1.
if not pairs(setmetatable({},{__pairs=function() return false end})) then
  local _pairs = pairs
  pairs = function (t)
    return (getmetamethod (t, "__pairs") or _pairs) (t)
  end
end


-- Use the fastest pack implementation available.
local pack = table_pack or function (...)
  return { n = select ("#", ...), ...}
end



--[[ ================= ]]--
--[[ Shared Functions. ]]--
--[[ ================= ]]--


local function copy (dest, src)
  if src == nil then dest, src = {}, dest end
  for k, v in pairs (src) do dest[k] = v end
  return dest
end


local function keysort (a, b)
  if type (a) == "number" then
    return type (b) ~= "number" or a < b
  else
    return type (b) ~= "number" and tostring (a) < tostring (b)
  end
end


local function opairs (t)
  local keys, i = {}, 0
  for k in next, t do keys[#keys + 1] = k end
  table_sort (keys, keysort)
  return function (t)
    i = i + 1
    local k = keys[i]
    if k ~= nil then
      return k, t[k]
    end
  end, t, nil
end


local function str (x, roots)
  roots = roots or {}

  local function stop_roots (x)
    return roots[x] or str (x, copy (roots))
  end

  if type (x) ~= "table" or getmetamethod (x, "__tostring") then
    return tostring (x)

  else
    local buf = {"{"}				-- pre-buffer table open
    roots[x] = tostring (x)			-- recursion protection

    local kp, vp				-- previous key and value
    for k, v in opairs (x) do
      if kp ~= nil and k ~= nil then
        -- semi-colon separator after sequence values, or else comma separator
	buf[#buf + 1] = type (kp) == "number" and k ~= kp + 1 and "; " or ", "
      end
      if k == 1 or type (k) == "number" and k -1 == kp then
	-- no key for sequence values
	buf[#buf + 1] = stop_roots (v)
      else
	buf[#buf + 1] = stop_roots (k) .. "=" .. stop_roots (v)
      end
      kp, vp = k, v
    end
    buf[#buf + 1] = "}"				-- buffer << table close

    return table_concat (buf)			-- stringify buffer
  end
end


return {
  _DEBUG	= _DEBUG,
  strict	= strict,
  typecheck	= typecheck,

  copy		= copy,
  getmetamethod = getmetamethod,
  ipairs        = ipairs,
  len		= len,
  opairs	= opairs,
  pack		= pack,
  pairs         = pairs,
  str		= str,
  unpack	= unpack,


  Module = function (t)
    return setmetatable (t, {
      _type  = "Module",
      __call = function (self, ...) return self.prototype (...) end,
    })
  end,

  mapfields = function (obj, src, map)
    local mt = getmetatable (obj) or {}

    -- Map key pairs.
    -- Copy all pairs when `map == nil`, but discard unmapped src keys
    -- when map is provided (i.e. if `map == {}`, copy nothing).
    if map == nil or nonempty (map) then
      map = map or {}
      for k, v in next, src do
        local key, dst = map[k] or k, obj
        local kind = type (key)
        if kind == "string" and key:sub (1, 1) == "_" then
          mt[key] = v
        elseif nonempty (map) and kind == "number" and len (dst) + 1 < key then
          -- When map is given, but has fewer entries than src, stop copying
          -- fields when map is exhausted.
          break
        else
          dst[key] = v
        end
      end
    end

    -- Only set non-empty metatable.
    if nonempty (mt) then
      setmetatable (obj, mt)
    end
    return obj
  end,
}
