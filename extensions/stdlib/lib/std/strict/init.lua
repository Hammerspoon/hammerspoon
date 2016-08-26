--[[--
 Diagnose uses of undeclared variables.

 All variables (including functions!) must be "declared" through a regular
 assignment (even assigning `nil` will do) in a strict scope before being
 used anywhere or assigned to inside a nested scope.

 Use the callable returned by this module to interpose a strictness check
 proxy table to the given environment.  The callable runs `setfenv`
 appropriately in Lua 5.1 interpreters to ensure the semantic equivalence.

 @module std.strict
]]

local _ENV = {
  error		= error,
  pcall		= pcall,
  rawset	= rawset,
  require	= require,
  setfenv	= setfenv or function () end,
  setmetatable	= setmetatable,

  debug_getinfo	= debug.getinfo,
}
setfenv (1, _ENV)


--- What kind of variable declaration is this?
-- @treturn string "C", "Lua" or "main"
local function what ()
  local d = debug_getinfo (3, "S")
  return d and d.what or "C"
end


return setmetatable ({
  --- Module table.
  -- @table strict
  -- @string version release version identifier


  --- Require variable declarations before use in scope *env*.
  --
  -- Normally the module @{strict:__call} metamethod is all you need,
  -- but you can use this method for more complex situations.
  -- @function strict
  -- @tparam table env lexical environment table
  -- @treturn table *env* proxy table with metamethods to enforce strict declarations
  -- @usage
  -- local _ENV = setmetatable ({}, {__index = _G})
  -- if require "std.debug_init"._DEBUG.strict then
  --   _ENV = require "strict".strict (_ENV)
  -- end
  -- -- ...and for Lua 5.1 compatibility:
  -- if rawget (_G, "setfenv") ~= nil then setfenv (1, _ENV) end
  strict = function (env)
    -- The set of declared variables in this scope.
    local declared = {}

    --- Environment Metamethods
    -- @section environmentmetamethods

    return setmetatable ({}, {
      --- Detect dereference of undeclared variable.
      -- @function env:__index
      -- @string n name of the variable being dereferenced
      __index = function (_, n)
        local v = env[n]
        if v ~= nil then
          declared[n] = true
        elseif not declared[n] and what () ~= "C" then
          error ("variable '" .. n .. "' is not declared", 2)
        end
        return v
      end,

      --- Detect assignment to undeclared variable.
      -- @function env:__newindex
      -- @string n name of the variable being declared
      -- @param v initial value of the variable
      __newindex = function (_, n, v)
        local x = env[n]
        if x == nil and not declared[n] then
          local w = what ()
          if w ~= "main" and w ~= "C" then
            error ("assignment to undeclared variable '" .. n .. "'", 2)
          end
        end
        declared[n] = true
        env[n] = v
      end,
    })
  end,
}, {
  --- Module Metamethods
  -- @section modulemetamethods

  --- Enforce strict variable declarations in *env*.
  -- @function strict:__call
  -- @tparam table env lexical environment table
  -- @treturn table *env* which must be assigned to `_ENV`
  -- @usage
  -- local _ENV = require "strict" (_G)
  __call = function (self, env)
    env = self.strict (env)
    setfenv (2, env)
    return env
  end,

  --- Lazy loading of strict submodules.
  -- Don't load everything on initial startup, wait until first attempt
  -- to access a submodule, and then load it on demand.
  -- @function __index
  -- @string name submodule name
  -- @treturn table|nil the submodule that was loaded to satisfy the missing
  --   `name`, otherwise `nil` if nothing was found
  -- @usage
  -- local strict = require "std.strict"
  -- local version = strict.version
  __index = function (self, name)
    local ok, t = pcall (require, "std.strict." .. name)
    if ok then
      rawset (self, name, t)
      return t
    end
  end,
})
