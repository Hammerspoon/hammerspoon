--[[--
 StrBuf Prototype.

 Buffers are mutable by default, but being based on objects, they can
 also be used in a functional style:

    local StrBuf = require "std.prototype.strbuf".prototype
    local a = StrBuf {"a"}
    local b = a:concat "b"    -- mutate *a*
    print (a, b)              --> ab   ab
    local c = a {} .. "c"     -- copy and append
    print (a, c)              --> ab   abc

 In addition to the functionality described here, StrBuf objects also
 have all the methods and metamethods of the @{prototype.object.prototype}
 (except where overridden here),

 Prototype Chain
 ---------------

      table
       `-> Container
            `-> Object
                 `-> StrBuf

 @module std.prototype.strbuf
]]


local tostring		= tostring

local table_concat	= table.concat


local Object		= require "std.prototype.object".prototype
local _			= require "std.prototype._base"

local Module		= _.Module
local argscheck		= _.typecheck and _.typecheck.argscheck
local ipairs		= _.ipairs
local _ENV		= _.strict and _.strict {} or {}

_ = nil



--[[ ================= ]]--
--[[ Helper Functions. ]]--
--[[ ================= ]]--


local function __concat (self, x)
  self[#self + 1] = x
  return self
end



--[[ ============== ]]--
--[[ StrBuf Object. ]]--
--[[ ============== ]]--


--- StrBuf prototype object.
-- @object prototype
-- @string[opt="StrBuf"] _type object name
-- @see prototype.object.prototype
-- @usage
-- local StrBuf = require "std.prototype.strbuf".prototype
-- local a = StrBuf {1, 2, 3}
-- local b = StrBuf {a, "five", "six"}
-- a = a .. 4
-- b = b:concat "seven"
-- print (a, b) --> 1234   1234fivesixseven
-- os.exit (0)


local function X (decl, fn)
  return argscheck and argscheck ("std.prototype.strbuf." .. decl, fn) or fn
end


return Module {
  prototype = Object {
    _type = "StrBuf",

    __index = {
      --- Methods
      -- @section methods

      --- Add a object to a buffer.
      -- Elements are stringified lazily, so if you add a table and then
      -- change its contents, the contents of the buffer will be affected
      -- too.
      -- @function prototype:concat
      -- @param x object to add to buffer
      -- @treturn prototype modified buffer
      -- @usage
      -- c = StrBuf {} :concat "append this" :concat (StrBuf {" and", " this"})
      concat = X ("concat (StrBuf, any)", __concat),
    },


    --- Metamethods
    -- @section metamethods

    --- Support concatenation to StrBuf objects.
    -- @function prototype:__concat
    -- @param x a string, or object that can be coerced to a string
    -- @treturn prototype modified *buf*
    -- @see concat
    -- @usage
    -- buf = buf .. x
    __concat = __concat,

    --- Support fast conversion to Lua string.
    -- @function prototype:__tostring
    -- @treturn string concatenation of buffer contents
    -- @see tostring
    -- @usage
    -- str = tostring (buf)
    __tostring = function (self)
      local strs = {}
      for _, e in ipairs (self) do strs[#strs + 1] = tostring (e) end
      return table_concat (strs)
    end,
  },
}
