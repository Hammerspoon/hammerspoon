--[[--
 Functional programming.

 A selection of higher-order functions to enable a functional style of
 programming in Lua.

 @module functional
]]


local getmetatable	= getmetatable
local loadstring	= loadstring or load
local next		= next
local pcall		= pcall
local select		= select
local setmetatable	= setmetatable
local type		= type

local coroutine_wrap	= coroutine.wrap
local coroutine_yield	= coroutine.yield
local math_ceil		= math.ceil
local table_remove	= table.remove
local table_unpack	= table.unpack or unpack


local _			= require "functional._base"

local argscheck		= _.typecheck and _.typecheck.argscheck
local ipairs		= _.ipairs
local len		= _.len
local pack		= _.pack
local pairs		= _.pairs
local serialize		= _.serialize

local _ENV		= _.strict and _.strict {} or {}

_ = nil



-- FIXME: Figure these two out:

local function ielems (t)
  -- capture ipairs iterator initial state
  local fn, istate, ctrl = ipairs (t)
  return function (state, _)
    local v
    ctrl, v = fn (state, ctrl)
    if ctrl then return v end
  end, istate, true -- wrapped initial state
end


local function leaves (it, tr)
  local function visit (n)
    if type (n) == "table" then
      for _, v in it (n) do
        visit (v)
      end
    else
      coroutine_yield (n)
    end
  end
  return coroutine_wrap (visit), tr
end



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function any (...)
  local fns = pack (...)

  return function (...)
    local argt = {n = 0}
    for i = 1, fns.n do
      argt = pack (fns[i] (...))
      if argt[1] ~= nil then
        return table_unpack (argt, 1, argt.n)
      end
    end
    return table_unpack (argt, 1, argt.n)
  end
end


local function bind (fn, bound)
  return function (...)
    local argt, unbound = {}, pack (...)

    -- Inline `argt = copy (bound)`...
    local n = bound.n or 0
    for k, v in pairs (bound) do
      -- ...but only copy integer keys.
      if type (k) == "number" and math_ceil (k) == k then
        argt[k] = v
        n = k > n and k or n  -- Inline `n = maxn (unbound)` in same pass.
      end
    end

    -- Bind *unbound* parameters sequentially into *argt* gaps.
    local i = 1
    for j = 1, unbound.n do
      while argt[i] ~= nil do i = i + 1 end
      argt[i], i = unbound[j], i + 1
    end

    -- Even if there are gaps remaining above *i*, pass at least *n* args.
    if n >= i then return fn (table_unpack (argt, 1, n)) end

    -- Otherwise, we filled gaps beyond *n*, and pass that many args.
    return fn (table_unpack (argt, 1, i - 1))
  end
end


-- No need to recurse because functables are second class citizens in
-- Lua:
-- func=function () print "called" end
-- func() --> "called"
-- functable=setmetatable ({}, {__call=func})
-- functable() --> "called"
-- nested=setmetatable ({}, {__call=functable})
-- nested()
-- --> stdin:1: attempt to call a table value (global 'd')
-- --> stack traceback:
-- -->	stdin:1: in main chunk
-- -->		[C]: in ?
local function callable (x)
  if type (x) == "function" then return x end
  return (getmetatable (x) or {}).__call
end


local function case (with, branches)
  local match = branches[with] or branches[1]
  if callable (match) then
    return match (with)
  end
  return match
end


local function collect (ifn, ...)
  local r = {}
  if not callable (ifn) then
    -- No iterator behaves like npairs, which would collect all integer
    -- key values from the first argument table:
    local k, v = next (ifn)
    repeat
      if type (k) == "number" then r[k] = v end
      k, v = next (ifn, k)
    until k == nil
    return r
  end

  -- Or else result depends on how many return values from ifn?
  local arity = 1
  for e, v in ifn (...) do
    if v then arity, r = 2, {} break end
    -- Build an arity-1 result table on first pass...
    r[#r + 1] = e
  end

  if arity == 2 then
    -- ...oops, it was arity-2 all along, start again!
    for k, v in ifn (...) do
      r[k] = v
    end
  end

  return r
end


local function compose (...)
  local fns = pack (...)

  return function (...)
    local argt = pack (...)
    for i = 1, fns.n do
      argt = pack (fns[i] (table_unpack (argt, 1, argt.n)))
    end
    return table_unpack (argt, 1, argt.n)
  end
end


local function cond (expr, branch, ...)
  if branch == nil and select ("#", ...) == 0 then
    expr, branch = true, expr
  end
  if expr then
    if callable (branch) then
      return branch (expr)
    end
    return branch
  end
  return cond (...)
end


local function curry (fn, n)
  if n <= 1 then
    return fn
  else
    return function (x)
             return curry (bind (fn, {x}), n - 1)
           end
  end
end


local function filter (pfn, ifn, ...)
  local argt, r = pack (...), {}
  if not callable (ifn) then
    ifn, argt = pairs, pack (ifn, ...)
  end

  local nextfn, state, k = ifn (table_unpack (argt, 1, argt.n))

  local t = pack (nextfn (state, k))		-- table of iteration 1
  local arity = #t				-- How many return values from ifn?

  if arity == 1 then
    local v = t[1]
    while v ~= nil do				-- until iterator returns nil
      if pfn (table_unpack (t, 1, t.n)) then	-- pass all iterator results to p
        r[#r + 1] = v
      end

      t = pack (nextfn (state, v))		-- maintain loop invariant
      v = t[1]

      if #t > 1 then				-- unless we discover arity is not 1 after all
        arity, r = #t, {} break
      end
    end
  end

  if arity > 1 then
    -- No need to start over here, because either:
    --   (i) arity was never 1, and the original value of t is correct
    --  (ii) arity used to be 1, but we only consumed nil values, so the
    --       current t with arity > 1 is the correct next value to use
    while t[1] ~= nil do
      local k = t[1]
      if pfn (table_unpack (t, 1, t.n)) then r[k] = t[2] end
      t = pack (nextfn (state, k))
    end
  end

  return r
end


local function flatten (t)
  return collect (leaves, ipairs, t)
end


local function reduce (fn, d, ifn, ...)
  local argt
  if not callable (ifn) then
    ifn, argt = pairs, pack (ifn, ...)
  else
    argt = pack (...)
  end

  local nextfn, state, k = ifn (table_unpack (argt, 1, argt.n))
  local t = pack (nextfn (state, k))		-- table of iteration 1

  local r = d					-- initialise accumulator
  while t[1] ~= nil do				-- until iterator returns nil
    k = t[1]
    r = fn (r, table_unpack (t, 1, t.n))	-- pass all iterator results to fn
    t = pack (nextfn (state, k))		-- maintain loop invariant
  end
  return r
end


local function foldl (fn, d, t)
  if t == nil then
    local tail = {}
    for i = 2, len (d) do tail[#tail + 1] = d[i] end
    d, t = d[1], tail
  end
  return reduce (fn, d, ielems, t)
end


-- Be careful to reverse only the valid sequence part of a table.
local function ireverse (t)
  local oob = 1
  while t[oob] ~= nil do
    oob = oob + 1
  end

  local r = {}
  for i = 1, oob - 1 do r[oob - i] = t[i] end
  return r
end


local function foldr (fn, d, t)
  if t == nil then
    local u, last = {}, len (d)
    for i = 1, last - 1 do u[#u + 1] = d[i] end
    d, t = d[last], u
  end
  return reduce (function (x, y) return fn (y, x) end, d, ielems, ireverse (t))
end


local function id (...)
  return ...
end


local function memoize (fn, mnemonic)
  mnemonic = mnemonic or serialize

  return setmetatable ({}, {
    __call = function (self, ...)
               local k = mnemonic (...)
               local t = self[k]
               if t == nil then
                 t = pack (fn (...))
                 self[k] = t
               end
               return table_unpack (t, 1, t.n)
             end
  })
end


local lambda = memoize (function (s)
  local expr

  -- Support "|args|expression" format.
  local args, body = s:match "^%s*|%s*([^|]*)|%s*(.+)%s*$"
  if args and body then
    expr = "return function (" .. args .. ") return " .. body .. " end"
  end

  -- Support "expression" format.
  if not expr then
    body = s:match "^%s*(_.*)%s*$" or s:match "^=%s*(.+)%s*$"
    if body then
      expr = [[
        return function (...)
          local _1,_2,_3,_4,_5,_6,_7,_8,_9 = ...
	  local _ = _1
	  return ]] .. body .. [[
        end
      ]]
    end
  end

  local ok, fn
  if expr then
    ok, fn = pcall (loadstring (expr))
  end

  -- Diagnose invalid input.
  if not ok then
    return nil, "invalid lambda string '" .. s .. "'"
  end

  return setmetatable ({}, {
    __call = function (self, ...) return fn (...) end,
    __tostring = function (self) return s end,
  })
end, id)


local function map (mapfn, ifn, ...)
  local argt, r = pack (...), {}
  if not callable (ifn) or argt.n == 0 then
    ifn, argt = pairs, pack (ifn, ...)
  end

  local nextfn, state, k = ifn (table_unpack (argt, 1, argt.n))
  local mapargs = pack (nextfn (state, k))

  local arity = 1
  while mapargs[1] ~= nil do
    local d, v = mapfn (table_unpack (mapargs, 1, mapargs.n))
    if v ~= nil then
      arity, r = 2, {} break
    end
    r[#r + 1] = d
    mapargs = {nextfn (state, mapargs[1])}
  end

  if arity > 1 then
    -- No need to start over here, because either:
    --   (i) arity was never 1, and the original value of mapargs is correct
    --  (ii) arity used to be 1, but we only consumed nil values, so the
    --       current mapargs with arity > 1 is the correct next value to use
    while mapargs[1] ~=  nil do
      local k, v = mapfn (table_unpack (mapargs, 1, mapargs.n))
      r[k] = v
      mapargs = pack (nextfn (state, mapargs[1]))
    end
  end
  return r
end


local function map_with (mapfn, tt)
  local r = {}
  for k, v in pairs (tt) do
    r[k] = mapfn (table_unpack (v, 1, len (v)))
  end
  return r
end


local function _product (x, l)
  local r = {}
  for v1 in ielems (x) do
    for v2 in ielems (l) do
      r[#r + 1] = {v1, table_unpack (v2, 1, len (v2))}
    end
  end
  return r
end

local function product (...)
  local argt = {...}
  if not next (argt) then
    return argt
  else
    -- Accumulate a list of products, starting by popping the last
    -- argument and making each member a one element list.
    local d = map (lambda '={_1}', ielems, table_remove (argt))
    -- Right associatively fold in remaining argt members.
    return foldr (_product, d, argt)
  end
end


local function shape (dims, t)
  t = flatten (t)
  -- Check the shape and calculate the size of the zero, if any
  local size = 1
  local zero
  for i, v in ipairs (dims) do
    if v == 0 then
      if zero then -- bad shape: two zeros
        return nil
      else
        zero = i
      end
    else
      size = size * v
    end
  end
  if zero then
    dims[zero] = math_ceil (len (t) / size)
  end
  local function fill (i, d)
    if d > len (dims) then
      return t[i], i + 1
    else
      local r = {}
      for j = 1, dims[d] do
        local e
        e, i = fill (i, d + 1)
        r[#r + 1] = e
      end
      return r, i
    end
  end
  return (fill (1, 1))
end


local function zip (tt)
  local r = {}
  for outerk, inner in pairs (tt) do
    for k, v in pairs (inner) do
      r[k] = r[k] or {}
      r[k][outerk] = v
    end
  end
  return r
end


local function zip_with (fn, tt)
  return map_with (fn, zip (tt))
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


local function X (decl, fn)
  return argscheck and argscheck ("functional." .. decl, fn) or fn
end

return {
  --- Call a series of functions until one returns non-nil.
  -- @function any
  -- @func ... functions to call
  -- @treturn function to call fn1 .. fnN until one returns non-nil.
  -- @usage
  -- old_object_type = any (std.object.type, io.type, type)
  any = X ("any (func...)", any),

  --- Partially apply a function.
  -- @function bind
  -- @func fn function to apply partially
  -- @tparam table argt table of *fn* arguments to bind
  -- @return function with *argt* arguments already bound
  -- @usage
  -- cube = bind (functional.operator.pow, {[2] = 3})
  bind = X ("bind (func, table)", bind),

  --- Identify callable types.
  -- @function callable
  -- @param x an object or primitive
  -- @return `true` if *x* can be called, otherwise `false`
  -- @usage
  -- if callable (functable) then functable (args) end
  callable = X ("callable (?any)", callable),

  --- A rudimentary case statement.
  -- Match *with* against keys in *branches* table.
  -- @function case
  -- @param with expression to match
  -- @tparam table branches map possible matches to functions
  -- @return the value associated with a matching key, or the first non-key
  --   value if no key matches. Function or functable valued matches are
  --   called using *with* as the sole argument, and the result of that call
  --   returned; otherwise the matching value associated with the matching
  --   key is returned directly; or else `nil` if there is no match and no
  --   default.
  -- @see cond
  -- @usage
  -- return case (type (object), {
  --   table  = "table",
  --   string = function ()  return "string" end,
  --            function (s) error ("unhandled type: " .. s) end,
  -- })
  case = X ("case (?any, #table)", case),

  --- Collect the results of an iterator.
  -- @function collect
  -- @func[opt=std.npairs] ifn iterator function
  -- @param ... *ifn* arguments
  -- @treturn table of results from running *ifn* on *args*
  -- @see filter
  -- @see map
  -- @usage
  -- --> {"a", "b", "c"}
  -- collect {"a", "b", "c", x=1, y=2, z=5}
  collect = X ("collect ([func], ?any...)", collect),

  --- Compose functions.
  -- @function compose
  -- @func ... functions to compose
  -- @treturn function composition of fnN .. fn1: note that this is the
  -- reverse of what you might expect, but means that code like:
  --
  --     functional.compose (function (x) return f (x) end,
  --                         function (x) return g (x) end))
  --
  -- can be read from top to bottom.
  -- @usage
  -- vpairs = compose (table.invert, ipairs)
  -- for v, i in vpairs {"a", "b", "c"} do process (v, i) end
  compose = X ("compose (func...)", compose),

  --- A rudimentary condition-case statement.
  -- If *expr* is "truthy" return *branch* if given, otherwise *expr*
  -- itself. If the return value is a function or functable, then call it
  -- with *expr* as the sole argument and return the result; otherwise
  -- return it explicitly.  If *expr* is "falsey", then recurse with the
  -- first two arguments stripped.
  -- @function cond
  -- @param expr a Lua expression
  -- @param branch a function, functable or value to use if *expr* is
  --   "truthy"
  -- @param ... additional arguments to retry if *expr* is "falsey"
  -- @see case
  -- @usage
  -- -- recursively calculate the nth triangular number
  -- function triangle (n)
  --   return cond (
  --     n <= 0, 0,
  --     n == 1, 1,
  --             function () return n + triangle (n - 1) end)
  -- end
  cond = cond, -- any number of any type arguments!

  --- Curry a function.
  -- @function curry
  -- @func fn function to curry
  -- @int n number of arguments
  -- @treturn function curried version of *fn*
  -- @usage
  -- add = curry (function (x, y) return x + y end, 2)
  -- incr, decr = add (1), add (-1)
  curry = X ("curry (func, int)", curry),

  --- Filter an iterator with a predicate.
  -- @function filter
  -- @tparam predicate pfn predicate function
  -- @func[opt=std.pairs] ifn iterator function
  -- @param ... iterator arguments
  -- @treturn table elements e for which `pfn (e)` is not "falsey".
  -- @see collect
  -- @see map
  -- @usage
  -- --> {2, 4}
  -- filter (lambda '|e|e%2==0', std.elems, {1, 2, 3, 4})
  filter = X ("filter (func, [func], ?any...)", filter),

  --- Flatten a nested table into a list.
  -- @function flatten
  -- @tparam table t a table
  -- @treturn table a list of all non-table elements of *t*
  -- @usage
  -- --> {1, 2, 3, 4, 5}
  -- flatten {{1, {{2}, 3}, 4}, 5}
  flatten = X ("flatten (table)", flatten),

  --- Fold a binary function left associatively.
  -- If parameter *d* is omitted, the first element of *t* is used,
  -- and *t* treated as if it had been passed without that element.
  -- @function foldl
  -- @func fn binary function
  -- @param[opt=t[1]] d initial left-most argument
  -- @tparam table t a table
  -- @return result
  -- @see foldr
  -- @see reduce
  -- @usage
  -- foldl (functional.operator.quot, {10000, 100, 10}) == (10000 / 100) / 10
  foldl = X ("foldl (function, [any], table)", foldl),

  --- Fold a binary function right associatively.
  -- If parameter *d* is omitted, the last element of *t* is used,
  -- and *t* treated as if it had been passed without that element.
  -- @function foldr
  -- @func fn binary function
  -- @param[opt=t[1]] d initial right-most argument
  -- @tparam table t a table
  -- @return result
  -- @see foldl
  -- @see reduce
  -- @usage
  -- foldr (functional.operator.quot, {10000, 100, 10}) == 10000 / (100 / 10)
  foldr = X ("foldr (function, [any], table)", foldr),

  --- Identity function.
  -- @function id
  -- @param ... arguments
  -- @return *arguments*
  id = id,  -- any number of any type arguments!

  --- Return a new sequence with element order reversed.
  --
  -- Apart from the order of the elements returned, this function follows
  -- the same rules as @{ipairs} for determining first and last elements.
  -- @function ireverse
  -- @tparam table t a table
  -- @treturn table a new table with integer keyed elements in reverse
  --   order with respect to *t*
  -- @see ipairs
  -- @usage
  -- local rielems = functional.compose (functional.ireverse, std.ielems)
  -- --> bar
  -- --> foo
  -- functional.map (print, rielems, {"foo", "bar", [4]="baz", d=5})
  ireverse = X ("ireverse (table)", ireverse),

  --- Compile a lambda string into a Lua function.
  --
  -- A valid lambda string takes one of the following forms:
  --
  --   1. `'=expression'`: equivalent to `function (...) return expression end`
  --   1. `'|args|expression'`: equivalent to `function (args) return expression end`
  --
  -- The first form (starting with `'='`) automatically assigns the first
  -- nine arguments to parameters `'_1'` through `'_9'` for use within the
  -- expression body.  The parameter `'_1'` is aliased to `'_'`, and if the
  -- first non-whitespace of the whole expression is `'_'`, then the
  -- leading `'='` can be omitted.
  --
  -- The results are memoized, so recompiling a previously compiled
  -- lambda string is extremely fast.
  -- @function lambda
  -- @string s a lambda string
  -- @treturn functable compiled lambda string, can be called like a function
  -- @usage
  -- -- The following are equivalent:
  -- lambda '= _1 < _2'
  -- lambda '|a,b| a<b'
  lambda = X ("lambda (string)", lambda),

  --- Map a function over an iterator.
  -- @function map
  -- @func fn map function
  -- @func[opt=std.pairs] ifn iterator function
  -- @param ... iterator arguments
  -- @treturn table results
  -- @see filter
  -- @see map_with
  -- @see zip
  -- @usage
  -- --> {1, 4, 9, 16}
  -- map (lambda '=_1*_1', std.ielems, {1, 2, 3, 4})
  map = X ("map (func, [func], ?any...)", map),

  --- Map a function over a table of argument lists.
  -- @function map_with
  -- @func fn map function
  -- @tparam table tt a table of *fn* argument lists
  -- @treturn table new table of *fn* results
  -- @see map
  -- @see zip_with
  -- @usage
  -- --> {"123", "45"}, {a="123", b="45"}
  -- conc = bind (map_with, {lambda '|...|table.concat {...}'})
  -- conc {{1, 2, 3}, {4, 5}}, conc {a={1, 2, 3, x="y"}, b={4, 5, z=6}}
  map_with = X ("map_with (function, table of tables)", map_with),

  --- Memoize a function, by wrapping it in a functable.
  --
  -- To ensure that memoize always returns the same results for the same
  -- arguments, it passes arguments to *fn*. You can specify a more
  -- sophisticated function if memoize should handle complicated argument
  -- equivalencies.
  -- @function memoize
  -- @func fn pure function: a function with no side effects
  -- @tparam[opt=std.tostring] mnemonic mnemonicfn how to remember the arguments
  -- @treturn functable memoized function
  -- @usage
  -- local fast = memoize (function (...) --[[ slow code ]] end)
  memoize = X ("memoize (func, ?func)", memoize),

  --- No operation.
  -- This function ignores all arguments, and returns no values.
  -- @function nop
  -- @see id
  -- @usage
  -- if unsupported then vtable["memrmem"] = nop end
  nop = function () end,

  --- Functional list product.
  --
  -- Return a list of each combination possible by taking a single
  -- element from each of the argument lists.
  -- @function product
  -- @param ... operands
  -- @return result
  -- @usage
  -- --> {"000", "001", "010", "011", "100", "101", "110", "111"}
  -- map (table.concat, ielems, product ({0,1}, {0, 1}, {0, 1}))
  product = X ("product (list...)", product),

  --- Fold a binary function into an iterator.
  -- @function reduce
  -- @func fn reduce function
  -- @param d initial first argument
  -- @func[opt=std.pairs] ifn iterator function
  -- @param ... iterator arguments
  -- @return result
  -- @see foldl
  -- @see foldr
  -- @usage
  -- --> 2 ^ 3 ^ 4 ==> 4096
  -- reduce (functional.operator.pow, 2, std.ielems, {3, 4})
  reduce = X ("reduce (func, any, [func], ?any...)", reduce),

  --- Shape a table according to a list of dimensions.
  --
  -- Dimensions are given outermost first and items from the original
  -- list are distributed breadth first; there may be one 0 indicating
  -- an indefinite number. Hence, `{0}` is a flat list,
  -- `{1}` is a singleton, `{2, 0}` is a list of
  -- two lists, and `{0, 2}` is a list of pairs.
  --
  -- Algorithm: turn shape into all positive numbers, calculating
  -- the zero if necessary and making sure there is at most one;
  -- recursively walk the shape, adding empty tables until the bottom
  -- level is reached at which point add table items instead, using a
  -- counter to walk the flattened original list.
  --
  -- @todo Use ileaves instead of flatten (needs a while instead of a
  -- for in fill function)
  -- @function shape
  -- @tparam table dims table of dimensions `{d1, ..., dn}`
  -- @tparam table t a table of elements
  -- @return reshaped list
  -- @usage
  -- --> {{"a", "b"}, {"c", "d"}, {"e", "f"}}
  -- shape ({3, 2}, {"a", "b", "c", "d", "e", "f"})
  shape = X ("shape (table, table)", shape),

  --- Zip a table of tables.
  -- Make a new table, with lists of elements at the same index in the
  -- original table. This function is effectively its own inverse.
  -- @function zip
  -- @tparam table tt a table of tables
  -- @treturn table new table with lists of elements of the same key
  --   from *tt*
  -- @see map
  -- @see zip_with
  -- @usage
  -- --> {{1, 3, 5}, {2, 4}}, {a={x=1, y=3, z=5}, b={x=2, y=4}}
  -- zip {{1, 2}, {3, 4}, {5}}, zip {x={a=1, b=2}, y={a=3, b=4}, z={a=5}}
  zip = X ("zip (table of tables)", zip),

  --- Zip a list of tables together with a function.
  -- @function zip_with
  -- @tparam function fn function
  -- @tparam table tt table of tables
  -- @treturn table a new table of results from calls to *fn* with arguments
  --   made from all elements the same key in the original tables; effectively
  --   the "columns" in a simple list
  -- of lists.
  -- @see map_with
  -- @see zip
  -- @usage
  -- --> {"135", "24"}, {a="1", b="25"}
  -- conc = bind (zip_with, {lambda '|...|table.concat {...}'})
  -- conc {{1, 2}, {3, 4}, {5}}, conc {{a=1, b=2}, x={a=3, b=4}, {b=5}}
  zip_with = X ("zip_with (function, table of tables)", zip_with),
}


--- Types
-- @section Types


--- Signature of a @{memoize} argument normalization callback function.
-- @function mnemonic
-- @param ... arguments
-- @treturn string stable serialized arguments
-- @usage
-- local mnemonic = function (name, value, props) return name end
-- local intern = functional.memoize (mksymbol, mnemonic)


--- Signature of a @{filter} predicate callback function.
-- @function predicate
-- @param ... arguments
-- @treturn boolean "truthy" if the predicate condition succeeds,
--   "falsey" otherwise
-- @usage
-- local predicate = lambda '|k,v|type(v)=="string"'
-- local strvalues = filter (predicate, std.pairs, {name="Roberto", id=12345})
