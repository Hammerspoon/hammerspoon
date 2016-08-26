--[[--
 Container Prototype.

 This module supplies the root prototype object from which every other
 object is descended.  There are no classes as such, rather new objects
 are created by cloning an existing object, and then changing or adding
 to the clone. Further objects can then be made by cloning the changed
 object, and so on.

 The functionality of a container based object is entirely defined by its
 *meta*methods. However, since we can store *any* object in a container,
 we cannot rely on the `__index` metamethod, because it is only a
 fallback for when that key is not already in the container itself. Of
 course that does not entirely preclude the use of `__index` with
 containers, so long as this limitation is observed.

 When making your own prototypes, derive from @{prototype.container.prototype}
 if you want to access the contents of your containers with the `[]`
 operator, otherwise from @{prototype.object.prototype} if you want to access
 the functionality of your objects with named object methods.

 Prototype Chain
 ---------------

      table
       `-> Container

 @module std.prototype.container
]]

local error		= error
local getmetatable	= getmetatable
local next		= next
local nonempty		= next
local select		= select
local setmetatable	= setmetatable
local type		= type

local string_format	= string.format
local table_concat	= table.concat


local _			= require "std.prototype._base"

local Module		= _.Module
local argcheck		= _.typecheck and _.typecheck.argcheck
local argscheck		= _.typecheck and _.typecheck.argscheck
local copy		= _.copy
local extramsg_toomany	= _.typecheck and _.typecheck.extramsg_toomany
local getmetamethod	= _.getmetamethod
local mapfields		= _.mapfields
local opairs		= _.opairs
local str		= _.str

local _ENV		= _.strict and _.strict {} or {}

_ = nil



--[[ ================= ]]--
--[[ Helper Functions. ]]--
--[[ ================= ]]--


local function argerror (name, i, extramsg, level)
  level = level or 1
  local s = string_format ("bad argument #%d to '%s'", i, name)
  if extramsg ~= nil then
    s = s .. " (" .. extramsg .. ")"
  end
  error (s, level + 1)
end


--- Instantiate a new object based on *proto*.
--
-- This is equivalent to:
--
--     merge (copy (proto), t or {})
--
-- Except that, by not checking arguments or metatables, it is faster.
-- @tparam table proto base object to copy from
-- @tparam[opt={}] table t additional fields to merge in
-- @treturn table a new table with fields from proto and t merged in.
local function instantiate (proto, t)
  local obj = {}
  for k, v in next, proto   do obj[k] = v end
  for k, v in next, t or {} do obj[k] = v end
  return obj
end



--[[ ================= ]]--
--[[ Container Object. ]]--
--[[ ================= ]]--


--- Container prototype.
-- @object prototype
-- @string[opt="Container"] _type object name
-- @tfield[opt] table|function _init object initialisation
-- @usage
-- local Container = require "prototype.container".prototype
-- local Graph = Container { _type = "Graph" }
-- local function nodes (graph)
--   local n = 0
--   for _ in pairs (graph) do n = n + 1 end
--   return n
-- end
-- local g = Graph { "node1", "node2" }
-- assert (nodes (g) == 2)
local prototype = {
  _type = "Container",

  --- Metamethods
  -- @section metamethods

  --- Return a clone of this container and its metatable.
  --
  -- Like any Lua table, a container is essentially a collection of
  -- `field_n = value_n` pairs, except that field names beginning with
  -- an underscore `_` are usually kept in that container's metatable
  -- where they define the behaviour of a container object rather than
  -- being part of its actual contents.  In general, cloned objects
  -- also clone the behaviour of the object they cloned, unless...
  --
  -- When calling @{prototype.container.prototype}, you pass a single table
  -- argument with additional fields (and values) to be merged into the
  -- clone. Any field names beginning with an underscore `_` are copied
  -- to the clone's metatable, and all other fields to the cloned
  -- container itself.  For instance, you can change the name of the
  -- cloned object by setting the `_type` field in the argument table.
  --
  -- The `_init` private field is also special: When set to a sequence of
  -- field names, unnamed fields in the call argument table are assigned
  -- to those field names in subsequent clones, like the example below.
  --
  -- Alternatively, you can set the `_init` private field of a cloned
  -- container object to a function instead of a sequence, in which case
  -- all the arguments passed when *it* is called/cloned (including named
  -- and unnamed fields in the initial table argument, if there is one)
  -- are passed through to the `_init` function, following the nascent
  -- cloned object. See the @{mapfields} usage example below.
  -- @function prototype:__call
  -- @param ... arguments to prototype's *\_init*, often a single table
  -- @treturn prototype clone of this container, with shared or
  --   merged metatable as appropriate
  -- @usage
  -- local Cons = Container {_type="Cons", _init={"car", "cdr"}}
  -- local list = Cons {"head", Cons {"tail", nil}}
  __call = function (self, ...)
    local mt     = getmetatable (self)
    local obj_mt = mt
    local obj    = {}

    -- This is the slowest part of cloning for any objects that have
    -- a lot of fields to test and copy.
    for k, v in next, self do
      obj[k] = v
    end

    if type (mt._init) == "function" then
      obj = mt._init (obj, ...)
    else
      obj = (self.mapfields or mapfields) (obj, (...), mt._init)
    end

    -- If a metatable was set, then merge our fields and use it.
    if nonempty (getmetatable (obj) or {}) then
      obj_mt = instantiate (mt, getmetatable (obj))

      -- Merge object methods.
      if type (obj_mt.__index) == "table" and
        type ((mt or {}).__index) == "table"
      then
        obj_mt.__index = instantiate (mt.__index, obj_mt.__index)
      end
    end

    return setmetatable (obj, obj_mt)
  end,

  --- Return an in-order iterator over public object fields.
  -- @function prototype:__pairs
  -- @treturn function iterator function
  -- @treturn Object *self*
  -- @usage
  -- for k, v in pairs (anobject) do process (k, v) end
  __pairs = opairs,

  --- Return a compact string representation of this object.
  --
  -- First the container name, and then between { and } an ordered list
  -- of the array elements of the contained values with numeric keys,
  -- followed by asciibetically sorted remaining public key-value pairs.
  --
  -- This metamethod doesn't recurse explicitly, but relies upon
  -- suitable `__tostring` metamethods for non-primitive content objects.
  -- @function prototype:__tostring
  -- @treturn string stringified object representation
  -- @see tostring
  -- @usage
  -- assert (tostring (list) == 'Cons {car="head", cdr=Cons {car="tail"}}')
  __tostring = function (self)
    return table_concat {
      -- Pass a shallow copy to render to avoid triggering __tostring
      -- again and blowing the stack.
      getmetatable (self)._type, " ", str (copy (self)),
    }
  end,
}


if argcheck then
  local __call = prototype.__call

  prototype.__call = function (self, ...)
    local mt = getmetatable (self)

    -- A function initialised object can be passed arguments of any
    -- type, so only argcheck non-function initialised objects.
    if type (mt._init) ~= "function" then
      local name, n = mt._type, select ("#", ...)
      -- Don't count `self` as an argument for error messages, because
      -- it just refers back to the object being called: `prototype {"x"}.
      argcheck (name, 1, "table", (...))
      if n > 1 then
        argerror (name, 2, extramsg_toomany ("argument", 1, n), 2)
      end
    end

    return __call (self, ...)
  end
end


local function X (decl, fn)
  return argscheck and argscheck ("prototype.container." .. decl, fn) or fn
end

return Module {
  prototype = setmetatable ({}, prototype),

  --- Module Functions
  -- @section modulefunctions

  --- Return *new* with references to the fields of *src* merged in.
  --
  -- This is the function used to instantiate the contents of a newly
  -- cloned container, as called by @{__call} above, to split the
  -- fields of a @{__call} argument table into private "_" prefixed
  -- field namess, -- which are merged into the *new* metatable, and
  -- public (everything else) names, which are merged into *new* itself.
  --
  -- You might want to use this function from `_init` functions of your
  -- own derived containers.
  -- @function mapfields
  -- @tparam table new partially instantiated clone container
  -- @tparam table src @{__call} argument table that triggered cloning
  -- @tparam[opt={}] table map key renaming specification in the form
  --   `{old_key=new_key, ...}`
  -- @treturn table merged public fields from *new* and *src*, with a
  --   metatable of private fields (if any), both renamed according to
  --   *map*
  -- @usage
  -- local Bag = Container {
  --   _type = "Bag",
  --   _init = function (new, ...)
  --     if type (...) == "table" then
  --       return container.mapfields (new, (...))
  --     end
  --     return functional.reduce (operator.set, new, ipairs, {...})
  --   end,
  -- }
  -- local groceries = Bag ("apple", "banana", "banana")
  -- local purse = Bag {_type = "Purse"} ("cards", "cash", "id")
  mapfields = X ("mapfields (table, table|object, ?table)", mapfields),
}
