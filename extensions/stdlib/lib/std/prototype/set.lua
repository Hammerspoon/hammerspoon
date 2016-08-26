--[[--
 Set Prototype.

 This module returns a table of set operators, as well as the prototype
 for a Set container object.

 Every possible object or primitive value is always present in any Set
 container exactly zero or one times.

 In addition to the functionality described here, Set containers also
 have all the methods and metamethods of the @{prototype.container.prototype}
 (except where overridden here).

 Prototype Chain
 ---------------

      table
       `-> Container
            `-> Set

 @module std.prototype.set
]]


local getmetatable	= getmetatable
local nonempty		= next
local rawget		= rawget
local rawset		= rawset
local setmetatable	= setmetatable
local type		= type

local table_concat	= table.concat
local table_sort	= table.sort


local Container		= require "std.prototype.container".prototype
local _			= require "std.prototype._base"

local Module		= _.Module
local argscheck		= _.typecheck and _.typecheck.argscheck
local pairs		= _.pairs
local str		= _.str

local _ENV		= _.strict and _.strict {} or {}

_ = nil



local Set -- forward declaration



--[[ ==================== ]]--
--[[ Primitive Functions. ]]--
--[[ ==================== ]]--


-- These functions know about internal implementatation.
-- The representation is a table whose tags are the elements, and
-- whose values are true.


local elems = pairs


local function insert (set, e)
  return rawset (set, e, true)
end


local function member (set, e)
  return rawget (set, e) == true
end



--[[ ===================== ]]--
--[[ High Level Functions. ]]--
--[[ ===================== ]]--


-- These functions are independent of the internal implementation.


local difference, symmetric_difference, intersection, union, subset,
      proper_subset, equal


function difference (set1, set2)
  local r = Set {}
  for e in elems (set1) do
    if not member (set2, e) then
      insert (r, e)
    end
  end
  return r
end


function symmetric_difference (set1, set2)
  return difference (union (set1, set2), intersection (set2, set1))
end


function intersection (set1, set2)
  local r = Set {}
  for e in elems (set1) do
    if member (set2, e) then
      insert (r, e)
    end
  end
  return r
end


function union (set1, set2)
  local r = set1 {}
  for e in elems (set2) do
    insert (r, e)
  end
  return r
end


function subset (set1, set2)
  for e in elems (set1) do
    if not member (set2, e) then
      return false
    end
  end
  return true
end


function proper_subset (set1, set2)
  return subset (set1, set2) and not subset (set2, set1)
end


function equal (set1, set2)
  return subset (set1, set2) and subset (set2, set1)
end



--[[ =========== ]]--
--[[ Set Object. ]]--
--[[ =========== ]]--


local function X (decl, fn)
  return argscheck and argscheck ("std.prototype.set." .. decl, fn) or fn
end


--- Set prototype object.
-- @object prototype
-- @string[opt="Set"] _type object name
-- @see prototype.container.prototype
-- @usage
-- local Set = require "std.prototype.set".prototype
-- assert (prototype.type (Set) == "Set")


Set = Container {
  _type = "Set",

  --- Set object initialisation.
  --
  -- Returns partially initialised Set container with contents
  -- from *t*.
  -- @init prototype._init
  -- @tparam table new uninitialised Set container object
  -- @tparam table t initialisation table from `__call`
  _init = function (new, t)
    local mt = {}
    for k, v in pairs (t) do
      local type_k = type (k)
      if type_k == "number" then
        insert (new, v)
      elseif type_k == "string" and k:sub (1, 1) == "_" then
	mt[k] = v
      end
      -- non-underscore-prefixed string keys are discarded!
    end
    return nonempty (mt) and setmetatable (new, mt) or new
  end,

  --- Metamethods
  -- @section metamethods

  --- Union operation.
  -- @function prototype:__add
  -- @tparam prototype s another set
  -- @treturn prototype everything from *this* set plus everything from *s*
  -- @see union
  -- @usage
  -- union = this + s
  __add = union,

  --- Difference operation.
  -- @function prototype:__sub
  -- @tparam prototype s another set
  -- @treturn prototype everything from *this* set that is not also in *s*
  -- @see difference
  -- @usage
  -- difference = this - s
  __sub = difference,

  --- Intersection operation.
  -- @function prototype:__mul
  -- @tparam prototype s another set
  -- @treturn prototype anything in both *this* set and in *s*
  -- @see intersection
  -- @usage
  -- intersection = this * s
  __mul = intersection,

  --- Symmetric difference operation.
  -- @function prototype:__div
  -- @tparam prototype s another set
  -- @treturn prototype everything in *this* set or in *s* but not in both
  -- @see symmetric_difference
  -- @usage
  -- symmetric_difference = this / s
  __div = symmetric_difference,

  --- Subset operation.
  -- @static
  -- @function prototype:__le
  -- @tparam prototype s another set
  -- @treturn boolean `true` if everything in *this* set is also in *s*
  -- @see subset
  -- @usage
  -- issubset = this <= s
  __le  = subset,

  --- Proper subset operation.
  -- @function prototype:__lt
  -- @tparam prototype s another set
  -- @treturn boolean `true` if *s* is not equal to *this* set, but does
  --   contain everything from *this* set
  -- @see proper_subset
  -- @usage
  -- ispropersubset = this < s
  __lt  = proper_subset,

  --- Return a string representation of this set.
  -- @function prototype:__tostring
  -- @treturn string string representation of a set.
  -- @see tostring
  __tostring = function (self)
    local keys = {}
    for k in pairs (self) do
      keys[#keys + 1] = str (k)
    end
    table_sort (keys)
    return getmetatable (self)._type .. " {" .. table_concat (keys, ", ") .. "}"
  end,
}


return Module {
  prototype = Set,

  --- Module Functions
  -- @section modulefunctions

  --- Delete an element from a set.
  -- @function delete
  -- @tparam prototype set a set
  -- @param e element
  -- @treturn prototype the modified *set*
  -- @usage
  -- set.delete (available, found)
  delete = X ("delete (Set, any)",
              function (set, e) return rawset (set, e, nil) end),

  --- Find the difference of two sets.
  -- @function difference
  -- @tparam prototype set1 a set
  -- @tparam prototype set2 another set
  -- @treturn prototype a copy of *set1* with elements of *set2* removed
  -- @usage
  -- all = set.difference (all, Set {32, 49, 56})
  difference = X ("difference (Set, Set)", difference),

  --- Iterator for sets.
  -- @function elems
  -- @tparam prototype set a set
  -- @return *set* iterator
  -- @todo Make the iterator return only the key
  -- @usage
  -- for code in set.elems (isprintable) do print (code) end
  elems = X ("elems (Set)", elems),

  --- Find whether two sets are equal.
  -- @function equal
  -- @tparam prototype set1 a set
  -- @tparam prototype set2 another set
  -- @treturn boolean `true` if *set1* and *set2* each contain identical
  --   elements, `false` otherwise
  -- @usage
  -- if set.equal (keys, Set {META, CTRL, "x"}) then process (keys) end
  equal = X ( "equal (Set, Set)", equal),

  --- Insert an element into a set.
  -- @function insert
  -- @tparam prototype set a set
  -- @param e element
  -- @treturn prototype the modified *set*
  -- @usage
  -- for byte = 32,126 do
  --   set.insert (isprintable, string.char (byte))
  -- end
  insert = X ("insert (Set, any)", insert),

  --- Find the intersection of two sets.
  -- @function intersection
  -- @tparam prototype set1 a set
  -- @tparam prototype set2 another set
  -- @treturn prototype a new set with elements in both *set1* and *set2*
  -- @usage
  -- common = set.intersection (a, b)
  intersection = X ("intersection (Set, Set)", intersection),

  --- Say whether an element is in a set.
  -- @function difference
  -- @tparam prototype set a set
  -- @param e element
  -- @return `true` if *e* is in *set*, otherwise `false`
  -- otherwise
  -- @usage
  -- if not set.member (keyset, pressed) then return nil end
  member = X ("member (Set, any)", member),

  --- Find whether one set is a proper subset of another.
  -- @function proper_subset
  -- @tparam prototype set1 a set
  -- @tparam prototype set2 another set
  -- @treturn boolean `true` if *set2* contains all elements in *set1*
  --   but not only those elements, `false` otherwise
  -- @usage
  -- if set.proper_subset (a, b) then
  --   for e in set.elems (set.difference (b, a)) do
  --     set.delete (b, e)
  --   end
  -- end
  -- assert (set.equal (a, b))
  proper_subset = X ("proper_subset (Set, Set)", proper_subset),

  --- Find whether one set is a subset of another.
  -- @function subset
  -- @tparam prototype set1 a set
  -- @tparam prototype set2 another set
  -- @treturn boolean `true` if all elements in *set1* are also in *set2*,
  --   `false` otherwise
  -- @usage
  -- if set.subset (a, b) then a = b end
  subset = X ("subset (Set, Set)", subset),

  --- Find the symmetric difference of two sets.
  -- @function symmetric_difference
  -- @tparam prototype set1 a set
  -- @tparam prototype set2 another set
  -- @treturn prototype a new set with elements that are in *set1* or *set2*
  --   but not both
  -- @usage
  -- unique = set.symmetric_difference (a, b)
  symmetric_difference = X ("symmetric_difference (Set, Set)",
                            symmetric_difference),

  --- Find the union of two sets.
  -- @function union
  -- @tparam prototype set1 a set
  -- @tparam prototype set2 another set
  -- @treturn prototype a copy of *set1* with elements in *set2* merged in
  -- @usage
  -- all = set.union (a, b)
  union = X ("union (Set, Set)", union),
}
