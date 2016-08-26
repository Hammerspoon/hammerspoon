--[[--
  Module table.

  Lazy loading of submodules, and metadata for the Prototype package.

  @module std.prototype
]]

local pcall		= pcall
local rawset		= rawset
local require		= require
local setmetatable	= setmetatable

local _			= require "std.prototype._base"
local _ENV		= _.strict and _.strict {} or {}

_ = nil



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


return setmetatable ({
  --- Module table.
  -- @table prototype
  -- @field version  Release version string
}, {
  --- Metamethods
  -- @section Metamethods

  --- Lazy loading of prototype modules.
  -- Don't load everything on initial startup, wait until first attempt
  -- to access a submodule, and then load it on demand.
  -- @function __index
  -- @string name submodule name
  -- @treturn table|nil the submodule that was loaded to satisfy the missing
  --   `name`, otherwise `nil` if nothing was found
  -- @usage
  -- local prototype = require "prototype"
  -- local Object = prototype.object.prototype
  __index = function (self, name)
    local ok, t = pcall (require, "std.prototype." .. name)
    if ok then
      rawset (self, name, t)
      return t
    end
  end,
})
