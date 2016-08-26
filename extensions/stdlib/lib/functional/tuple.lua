--[[--
 Tuple container.

 An interned, immutable, nil-preserving tuple object.

 Like Lua strings, tuples with the same elements can be quickly compared
 with a straight-forward `==` comparison.

 The immutability guarantees only work if you don't change the contents
 of tables after adding them to a tuple.  Don't do that!

 @module functional.tuple
]]


local error		= error
local getmetatable	= getmetatable
local next		= next
local select		= select
local setmetatable	= setmetatable
local tonumber		= tonumber

local string_format	= string.format
local table_concat	= table.concat
local table_unpack	= table.unpack or unpack


local _			= require "functional._base"

local toqstring		= _.toqstring

local _ENV		= _.strict and _.strict {} or {}

_ = nil



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


-- We maintain a weak table of all distinct Tuples, where each value is
-- the tuple object itself, and the associated key is the stringified
-- list of elements contained by the tuple, e.g the 0-tuple:
--
--    intern[""] = setmetatable ({n = 0}, Tuple)
--
-- In order to make a tuple immutable, it needs to have a __newindex
-- metamethod that diagnoses attempts to insert new elements, which in
-- turn means that the actual elements need to be kept in a proxy table
-- (because if we stored the first element in the tuple table, then
-- __newindex would not fire when the first element was written to).
-- Rather that using metamethods to access a wholly separate proxy
-- table, we use the proxey table as a key in the tuple object proper
-- (it would be impossible to accidentally assign to a unique table
-- address key, so __newindex will still work) and use a copy of the
-- intern stringified elements key as the associated value there, e.g.
-- for the 0-tuple again:
--
--    { [{n = 0}] = "" }
--
-- This means we have a pleasant property to enable fast stringification
-- of any tuple we hold:
--
--    proxy_table, stringified_element_list = next (tuple)


--- Immutable Tuple container.
-- @object Tuple
-- @string[opt="Tuple"] _type object name
-- @int n number of tuple elements
-- @usage
-- local Tuple = require "functional.tuple"
-- function count (...)
--   argtuple = Tuple (...)
--   return argtuple.n
-- end
-- count () --> 0
-- count (nil) --> 1
-- count (false) --> 1
-- count (false, nil, true, nil) --> 4
local Tuple = {
  _type = "Tuple",

  --- Metamethods
  -- @section metamethods

  --- Unpack tuple values between index *i* and *j*, inclusive.
  -- @function __call
  -- @int[opt=1] i first index to unpack
  -- @int[opt=self.n] j last index to unpack
  -- @return ... values at indices *i* through *j*, inclusive
  -- @usage
  -- tup = Tuple (1, 3, 2, 5)
  -- --> 3, 2, 5
  -- tup (2)
  __call = function (self, i, j)
    return table_unpack (next (self), tonumber (i) or 1, tonumber (j) or self.n)
  end,

  __index = function (self, k)
    return next (self) [k]
  end,

  --- Return the length of this tuple.
  -- @function prototype:__len
  -- @treturn int number of elements in *tup*
  -- @usage
  -- -- Only works on Lua 5.2 or newer:
  -- #Tuple (nil, 2, nil) --> 3
  -- -- For compatibility with Lua 5.1, use @{functional.operator.len}
  -- len (Tuple (nil, 2, nil)
  __len = function (self)
    return self.n
  end,

  --- Prevent mutation of *tup*.
  -- @function prototype:__newindex
  -- @param k tuple key
  -- @param v tuple value
  -- @raise cannot change immutable tuple object
  __newindex = function (self, k, v)
    error ("cannot change immutable tuple object", 2)
  end,

  --- Return a string representation of *tup*
  -- @function prototype:__tostring
  -- @treturn string representation of *tup*
  -- @usage
  -- -- 'Tuple ("nil", nil, false)'
  -- print (Tuple ("nil", nil, false))
  __tostring = function (self)
    local _, argstr = next (self)
    return string_format ("%s (%s)", getmetatable (self)._type, argstr)
  end,
}


-- Maintain a weak functable of all interned tuples.
-- @function intern
-- @int n number of elements in *t*, including trailing `nil`s
-- @tparam table t table of elements
-- @treturn table interned *n*-tuple *t*
local intern = setmetatable ({}, {
  __mode = "kv",

  __call = function (self, k, t)
    if self[k] == nil then
      self[k] = setmetatable ({[t] = k}, Tuple)
    end
    return self[k]
  end,
})


-- Call the value returned from requiring this module with a list of
-- elements to get an interned tuple made with those elements.
return function (...)
  local n = select ("#", ...)
  local buf, tup = {}, {n = n, ...}
  for i = 1, n do buf[i] = toqstring (tup[i]) end
  return intern (table_concat (buf, ", "), tup)
end
