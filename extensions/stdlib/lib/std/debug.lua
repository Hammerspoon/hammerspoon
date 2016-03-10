--[[--
 Additions to the core debug module.

 The module table returned by `std.debug` also contains all of the entries
 from the core debug table.  An hygienic way to import this module, then, is
 simply to override the core `debug` locally:

    local debug = require "std.debug"

 @corelibrary std.debug
]]


local debug		= debug
local setmetatable	= setmetatable
local type		= type

local io_stderr		= io.stderr
local math_huge		= math.huge
local math_max		= math.max
local table_concat	= table.concat


local _			= require "std._base"

local _DEBUG		= _._DEBUG
local _getfenv		= _.debug.getfenv
local _pairs		= _.pairs
local _setfenv		= _.debug.setfenv
local _tostring		= _.tostring
local merge		= _.base.merge

local _ENV		= _.strict and _.strict {} or {}

_ = nil



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


--- Control std.debug function behaviour.
-- To declare debugging state, set _DEBUG either to `false` to disable all
-- runtime debugging; to any "truthy" value (equivalent to enabling everything
-- except *call*, or as documented below.
-- @class table
-- @name _DEBUG
-- @tfield[opt=true] boolean argcheck honor argcheck and argscheck calls
-- @tfield[opt=false] boolean call do call trace debugging
-- @field[opt=nil] deprecate if `false`, deprecated APIs are defined,
--   and do not issue deprecation warnings when used; if `nil` issue a
--   deprecation warning each time a deprecated api is used; any other
--   value causes deprecated APIs not to be defined at all
-- @tfield[opt=1] int level debugging level
-- @tfield[opt=true] boolean strict enforce strict variable declaration
--   before use **in stdlib internals** (if `require "strict"` works)
-- @usage _DEBUG = { argcheck = false, level = 9, strict = false }


local function say (n, ...)
  local level, argt = n, {...}
  if type (n) ~= "number" then
    level, argt = 1, {n, ...}
  end
  if _DEBUG.level ~= math_huge and
      ((type (_DEBUG.level) == "number" and _DEBUG.level >= level) or level <= 1)
  then
    local t = {}
    for k, v in _pairs (argt) do t[k] = _tostring (v) end
    io_stderr:write (table_concat (t, "\t") .. "\n")
  end
end


local level = 0

local function trace (event)
  local t = debug.getinfo (3)
  local s = " >>> "
  for i = 1, level do s = s .. " " end
  if t ~= nil and t.currentline >= 0 then
    s = s .. t.short_src .. ":" .. t.currentline .. " "
  end
  t = debug.getinfo (2)
  if event == "call" then
    level = level + 1
  else
    level = math_max (level - 1, 0)
  end
  if t.what == "main" then
    if event == "call" then
      s = s .. "begin " .. t.short_src
    else
      s = s .. "end " .. t.short_src
    end
  elseif t.what == "Lua" then
    s = s .. event .. " " .. (t.name or "(Lua)") .. " <" ..
      t.linedefined .. ":" .. t.short_src .. ">"
  else
    s = s .. event .. " " .. (t.name or "(C)") .. " [" .. t.what .. "]"
  end
  io_stderr:write (s .. "\n")
end

-- Set hooks according to _DEBUG
if type (_DEBUG) == "table" and _DEBUG.call then
  debug.sethook (trace, "cr")
end



local M = {
  --- Function Environments
  -- @section environments

  --- Extend `debug.getfenv` to unwrap functables correctly.
  -- @function getfenv
  -- @tparam int|function|functable fn target function, or stack level
  -- @treturn table environment of *fn*
  getfenv = _getfenv,

  --- Extend `debug.setfenv` to unwrap functables correctly.
  -- @function setfenv
  -- @tparam function|functable fn target function
  -- @tparam table env new function environment
  -- @treturn function *fn*
  setfenv = _setfenv,


  --- Functions
  -- @section functions

  --- Print a debugging message to `io.stderr`.
  -- Display arguments passed through `std.tostring` and separated by tab
  -- characters when `_DEBUG` is `true` and *n* is 1 or less; or `_DEBUG.level`
  -- is a number greater than or equal to *n*.  If `_DEBUG` is false or
  -- nil, nothing is written.
  -- @function say
  -- @int[opt=1] n debugging level, smaller is higher priority
  -- @param ... objects to print (as for print)
  -- @usage
  -- local _DEBUG = require "std.debug_init"._DEBUG
  -- _DEBUG.level = 3
  -- say (2, "_DEBUG table contents:", _DEBUG)
  say = say,

  --- Trace function calls.
  -- Use as debug.sethook (trace, "cr"), which is done automatically
  -- when `_DEBUG.call` is set.
  -- Based on test/trace-calls.lua from the Lua distribution.
  -- @function trace
  -- @string event event causing the call
  -- @usage
  -- _DEBUG = { call = true }
  -- local debug = require "std.debug"
  trace = trace,
}


--- Metamethods
-- @section metamethods

--- Equivalent to calling `debug.say (1, ...)`
-- @function __call
-- @see say
-- @usage
-- local debug = require "std.debug"
-- debug "oh noes!"
local metatable = {
  __call = function (self, ...)
             M.say (1, ...)
           end,
}


return setmetatable (merge (M, debug), metatable)
