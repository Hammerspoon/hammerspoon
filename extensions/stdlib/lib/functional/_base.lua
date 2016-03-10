local _ENV		= _ENV
local ipairs		= ipairs
local pairs		= pairs
local pcall		= pcall
local require		= require
local setmetatable	= setmetatable
local tostring		= tostring
local type		= type

local string_format	= string.format
local table_concat	= table.concat
local table_pack	= table.pack or pack or false
local table_sort	= table.sort



--[[ ================== ]]--
--[[ Initialize _DEBUG. ]]--
--[[ ================== ]]--


local _DEBUG, argscheck, strict
do
  -- Make sure none of these symbols leak out into the rest of the
  -- module, in case we can enable 'strict' mode at the end of the block.

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
    ok, strict		= pcall (require, "strict")
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
local table_pack = table_pack or function (...)
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


local fallbacks = {
  __index = {
    open  = function (x) return "{" end,
    close = function (x) return "}" end,
    elem  = tostring,
    pair  = function (x, kp, vp, k, v, kstr, vstr) return kstr .. "=" .. vstr end,
    sep   = function (x, kp, vp, kn, vn)
	      return kp ~= nil and kn ~= nil and "," or ""
            end,
    sort  = function (keys) return keys end,
    term  = function (x)
	      return type (x) ~= "table" or getmetamethod (x, "__tostring")
	    end,
  },
}


-- Write pretty-printing based on:
--
--   John Hughes's and Simon Peyton Jones's Pretty Printer Combinators
--
--   Based on "The Design of a Pretty-printing Library in Advanced
--   Functional Programming", Johan Jeuring and Erik Meijer (eds), LNCS 925
--   http://www.cs.chalmers.se/~rjmh/Papers/pretty.ps
--   Heavily modified by Simon Peyton Jones, Dec 96

local function render (x, fns, roots)
  fns = setmetatable (fns or {}, fallbacks)
  roots = roots or {}

  local function stop_roots (x)
    return roots[x] or render (x, fns, copy (roots))
  end

  if fns.term (x) then
    return fns.elem (x)

  else
    local buf, keys = {fns.open (x)}, {}	-- pre-buffer table open
    roots[x] = fns.elem (x)			-- recursion protection

    for k in pairs (x) do			-- collect keys
      keys[#keys + 1] = k
    end
    keys = fns.sort (keys)

    local pair, sep = fns.pair, fns.sep
    local kp, vp				-- previous key and value
    for _, k in ipairs (keys) do
      local v = x[k]
      buf[#buf + 1] = sep (x, kp, vp, k, v)	-- | buffer << separator
      buf[#buf + 1] = pair (x, kp, vp, k, v, stop_roots (k), stop_roots (v))
						-- | buffer << key/value pair
      kp, vp = k, v
    end
    buf[#buf + 1] = sep (x, kp, vp)		-- buffer << trailing separator
    buf[#buf + 1] = fns.close (x)		-- buffer << table close

    return table_concat (buf)			-- stringify buffer
  end
end


local function toqstring (x)
  if type (x) ~= "string" then return tostring (x) end
  return string_format ("%q", x)
end


-- Sort numbers first then asciibetically
local function keysort (a, b)
  if type (a) == "number" then
    return type (b) ~= "number" or a < b
  else
    return type (b) ~= "number" and tostring (a) < tostring (b)
  end
end


local function sortkeys (t)
  table_sort (t, keysort)
  return t
end


local serialize_vtable = {
  elem = toqstring,
  sort = sortkeys,
}


local function serialize (...)
  local seq = table_pack (...)
  local buf = {}
  for i = 1, seq.n do
    buf[i] = render (seq[i], serialize_vtable)
  end
  return table_concat (buf, ",")
end


local tostring_vtable = {
  pair = function (x, kp, vp, k, v, kstr, vstr)
    if k == 1 or type (k) == "number" and k -1 == kp then
      return vstr
    end
    return kstr .. "=" .. vstr
  end,

  -- need to sort numeric keys to be able to skip printing them.
  sort = sortkeys,
}


--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
  _VERSION	= "1.0",

  argscheck	= argscheck,
  getmetamethod	= getmetamethod,
  ipairs	= ipairs,
  len		= len,
  pack		= table_pack,
  pairs		= pairs,
  serialize	= serialize,
  strict	= strict,
  toqstring	= toqstring,
  tostring      = function (x) return render (x, tostring_vtable) end,
}
