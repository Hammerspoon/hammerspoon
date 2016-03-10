--[[--
 Additions to the core math module.

 The module table returned by `std.math` also contains all of the entries from
 the core math table.  An hygienic way to import this module, then, is simply
 to override the core `math` locally:

    local math = require "std.math"

 @corelibrary std.math
]]


local math		= math

local math_floor	= math.floor


local _			= require "std._base"

local argscheck		= _.typecheck and _.typecheck.argscheck
local merge		= _.base.merge

local _ENV		= _.strict and _.strict {} or {}

_ = nil



--[[ ================= ]]--
--[[ Implementatation. ]]--
--[[ ================= ]]--


local M


local function floor (n, p)
  if p and p ~= 0 then
    local e = 10 ^ p
    return math_floor (n * e) / e
  else
    return math_floor (n)
  end
end


local function round (n, p)
  local e = 10 ^ (p or 0)
  return math_floor (n * e + 0.5) / e
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


local function X (decl, fn)
  return argscheck and argscheck ("std.math." .. decl, fn) or fn
end


M = {
  --- Core Functions
  -- @section corefuncs

  --- Extend `math.floor` to take the number of decimal places.
  -- @function floor
  -- @number n number
  -- @int[opt=0] p number of decimal places to truncate to
  -- @treturn number `n` truncated to `p` decimal places
  -- @usage tenths = floor (magnitude, 1)
  floor = X ("floor (number, ?int)", floor),

  --- Round a number to a given number of decimal places
  -- @function round
  -- @number n number
  -- @int[opt=0] p number of decimal places to round to
  -- @treturn number `n` rounded to `p` decimal places
  -- @usage roughly = round (exactly, 2)
  round = X ("round (number, ?int)", round),
}


return merge (M, math)
