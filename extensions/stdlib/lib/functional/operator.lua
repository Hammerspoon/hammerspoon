--[[--
 Functional forms of Lua operators.

 @module functional.operator
]]


local tostring		= tostring
local type		= type


local _			= require "functional._base"

local len		= _.len
local serialize		= _.serialize
local _tostring		= _.tostring

local _ENV		= _.strict and _.strict {} or {}

_ = nil



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function eqv (a, b)
  -- If they are the same primitive value, or they share a metatable
  -- with an __eq metamethod that says they are equivalent, we're done!
  if a == b then return true end

  -- Unless we now have two tables, the previous line ensures a ~= b.
  if type (a) ~= "table" or type (b) ~= "table" then return false end

  -- Otherwise, compare serializations of each.
  return serialize (a) == serialize (b)
end


return {
  --- Stringify and concatenate arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return concatenation of stringified arguments.
  -- @usage
  -- --> "=> 1000010010"
  -- functional.foldl (concat, "=> ", {10000, 100, 10})
  concat = function (a, b) return _tostring (a) .. _tostring (b) end,

  --- Equivalent to `#` operation, but respecting `__len` even on Lua 5.1.
  -- @function len
  -- @tparam object|string|table x operand
  -- @treturn int length of list part of *t*
  -- @usage for i = 1, len (t) do process (t[i]) end
  len = len,

  --- Dereference a table.
  -- @tparam table t a table
  -- @param k a key to lookup in *t*
  -- @return value stored at *t[k]* if any, otherwise `nil`
  -- @usage
  -- --> 4
  -- functional.foldl (get, {1, {{2, 3, 4}, 5}}, {2, 1, 3})
  get = function (t, k) return t and t[k] or nil end,

  --- Set a table element, honoring metamethods.
  -- @tparam table t a table
  -- @param k a key to lookup in *t*
  -- @param v a value to set for *k*
  -- @treturn table *t*
  -- @usage
  -- -- destructive table merge:
  -- --> {"one", bar="baz", two=5}
  -- functional.reduce (set, {"foo", bar="baz"}, {"one", two=5})
  set = function (t, k, v) t[k]=v; return t end,

  --- Return the sum of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return the sum of the *a* and *b*
  -- @usage
  -- --> 10110
  -- functional.foldl (sum, {10000, 100, 10})
  sum = function (a, b) return a + b end,

  --- Return the difference of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return the difference between *a* and *b*
  -- @usage
  -- --> 890
  -- functional.foldl (diff, {10000, 100, 10})
  diff = function (a, b) return a - b end,

  --- Return the product of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return the product of *a* and *b*
  -- @usage
  -- --> 10000000
  -- functional.foldl (prod, {10000, 100, 10})
  prod = function (a, b) return a * b end,

  --- Return the quotient of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return the quotient *a* and *b*
  -- @usage
  -- --> 1000
  -- functional.foldr (quot, {10000, 100, 10})
  quot = function (a, b) return a / b end,

  --- Return the modulus of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return the modulus of *a* and *b*
  -- @usage
  -- --> 3
  -- functional.foldl (mod, {65536, 100, 11})
  mod = function (a, b) return a % b end,

  --- Return the exponent of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return the *a* to the power of *b*
  -- @usage
  -- --> 4096
  -- functional.foldl (pow, {2, 3, 4})
  pow = function (a, b) return a ^ b end,

  --- Return the logical conjunction of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return logical *a* and *b*
  -- @usage
  -- --> true
  -- functional.foldl (conj, {true, 1, "false"})
  conj = function (a, b) return a and b end,

  --- Return the logical disjunction of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return logical *a* or *b*
  -- @usage
  -- --> true
  -- functional.foldl (disj, {true, 1, false})
  disj = function (a, b) return a or b end,

  --- Return the logical negation of the arguments.
  -- @param a an argument
  -- @return not *a*
  -- @usage
  -- --> {true, false, false, false}
  -- functional.bind (functional.map, {std.ielems, neg}) {false, true, 1, 0}
  neg = function (a) return not a end,

  --- Recursive table equivalence.
  -- @param a an argument
  -- @param b another argument
  -- @treturn boolean whether *a* and *b* are recursively equivalent
  eqv = eqv,

  --- Return the equality of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return `true` if *a* is *b*, otherwise `false`
  eq = function (a, b) return a == b end,

  --- Return the inequality of the arguments.
  -- @param a an argument
  -- @param b another argument
  -- @return `false` if *a* is *b*, otherwise `true`
  -- @usage
  -- --> true
  -- local f = require "std.functional"
  -- table.empty (f.filter (f.bind (neq, {6}), std.ielems, {6, 6, 6})
  neq = function (a, b) return a ~= b end,

  --- Return whether the arguments are in ascending order.
  -- @param a an argument
  -- @param b another argument
  -- @return `true` if *a* is less then *b*, otherwise `false`
  lt = function (a, b) return a < b end,

  --- Return whether the arguments are not in descending order.
  -- @param a an argument
  -- @param b another argument
  -- @return `true` if *a* is not greater then *b*, otherwise `false`
  lte = function (a, b) return a <= b end,

  --- Return whether the arguments are in descending order.
  -- @param a an argument
  -- @param b another argument
  -- @return `true` if *a* is greater then *b*, otherwise `false`
  gt = function (a, b) return a > b end,

  --- Return whether the arguments are not in ascending order.
  -- @param a an argument
  -- @param b another argument
  -- @return `true` if *a* is not greater then *b*, otherwise `false`
  gte = function (a, b) return a >= b end,
}
