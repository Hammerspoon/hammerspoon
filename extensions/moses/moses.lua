-- - *Utility-belt library for functional programming in Lua.*<br/>
-- Source on [Github](http://github.com/Yonaba/Moses)
-- @author [Roland Yonaba](http://github.com/Yonaba)
-- @copyright 2012-2014
-- @license [MIT](http://www.opensource.org/licenses/mit-license.php)
-- @release 1.4.0
-- @module moses

local _MODULEVERSION = '1.4.0'

-- Internalisation
local next, type, unpack, select, pcall = next, type, unpack, select, pcall
local setmetatable, getmetatable = setmetatable, getmetatable
local t_insert, t_sort = table.insert, table.sort
local t_remove,t_concat = table.remove, table.concat
local randomseed, random, huge = math.randomseed, math.random, math.huge
local floor, max, min = math.floor, math.max, math.min
local rawget = rawget
local unpack = unpack
local pairs,ipairs = pairs,ipairs
local _ = {}


-- ======== Private helpers

local function f_max(a,b) return a>b end
local function f_min(a,b) return a<b end
local function clamp(var,a,b) return (var<a) and a or (var>b and b or var) end
local function isTrue(_,value) return value and true end
local function iNot(value) return not value end

local function count(t)  -- raw count of items in an map-table
  local i = 0
    for k,v in pairs(t) do i = i + 1 end
  return i
end

local function extract(list,comp,transform,...) -- extracts value from a list
  local _ans
  local transform = transform or _.identity
  for index,value in pairs(list) do
    if not _ans then _ans = transform(value,...)
    else
      local value = transform(value,...)
      _ans = comp(_ans,value) and _ans or value
    end
  end
  return _ans
end

local function partgen(t, n, f) -- generates array partitions
  for i = 0, #t, n do
    local s = _.slice(t, i+1, i+n)
    if #s>0 then f(s) end
  end
end

local function permgen(t, n, f) -- taken from PiL: http://www.lua.org/pil/9.3.html
  if n == 0 then f(t) end
  for i = 1,n do
    t[n], t[i] = t[i], t[n]
    permgen(t, n-1, f)
    t[n], t[i] = t[i], t[n]
  end
end

-- Internal counter for unique ids generation
local unique_id_counter = -1

-- - Table functions
-- @section Table functions

-- - Iterates on each key-value pairs in a table. Calls function `f(key, value)` at each step of iteration.
-- <br/><em>Aliased as `forEach`</em>.
-- @name each
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @see eachi
function _.each(t, f, ...)
  for index,value in pairs(t) do
    f(index,value,...)
  end
end

-- - Iterates on each integer key-value pairs in a table. Calls function `f(key, value)`
-- only on values at integer key in a given collection. The table can be a sparse array,
-- or map-like. Iteration will start from the lowest integer key found to the highest one.
-- <br/><em>Aliased as `forEachi`</em>.
-- @name eachi
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @see each
function _.eachi(t, f, ...)
  local lkeys = _.sort(_.select(_.keys(t), function(k,v)
    return _.isInteger(v)
  end))
  for k, key in ipairs(lkeys) do
    f(key, t[key],...)
  end
end

-- - Returns an array of values at specific indexes and keys.
-- @name at
-- @tparam table t a table
-- @tparam vararg ... A variable number of indexes or keys to extract values
-- @treturn table an array-list of values from the passed-in table
function _.at(t, ...)
  local values = {}
  for i, key in ipairs({...}) do
    if _.has(t, key) then values[#values+1] = t[key] end
  end
  return values
end

-- - Counts occurrences of a given value in a table. Uses @{isEqual} to compare values.
-- @name count
-- @tparam table t a table
-- @tparam[opt] value value a value to be searched in the table. If not given, the @{size} of the table will be returned
-- @treturn number the count of occurrences of `value`
-- @see countf
-- @see size
function _.count(t, value)
  if _.isNil(value) then return _.size(t) end
  local count = 0
  _.each(t, function(k,v)
    if _.isEqual(v, value) then count = count + 1 end
  end)
  return count
end

-- - Counts occurrences validating a predicate. Same as @{count}, but uses an iterator.
-- Returns the count for values passing the test `f(key, value, ...)`
-- @name countf
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @treturn number the count of values validating the predicate
-- @see count
-- @see size
function _.countf(t, f, ...)
  return _.count(_.map(t, f, ...), true)
end

-- - Iterates through a table and loops `n` times. The full iteration loop will be
-- repeated `n` times (or forever, if `n` is omitted). In case `n` is lower or equal to 0, it returns
-- an empty function.
-- <br/><em>Aliased as `loop`</em>.
-- @name cycle
-- @tparam table t a table
-- @tparam number n the number of loops
-- @treturn function an iterator function yielding key-value pairs from the passed-in table.
function _.cycle(t, n)
  n = n or 1
  if n<=0 then return function() end end
  local k, fk
  local i = 0
  while true do
    return function()
      k = k and next(t,k) or next(t)
      fk = not fk and k or fk
      if n then
        i = (k==fk) and i+1 or i
        if i > n then
          return
        end
      end
      return k, t[k]
    end
  end
end

-- - Maps function `f(key, value)` on all key-value pairs. Collects
-- and returns the results as a table.
-- <br/><em>Aliased as `collect`</em>.
-- @name map
-- @tparam table t a table
-- @tparam function f  an iterator function, prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @treturn table a table of results
function _.map(t, f, ...)
  local _t = {}
  for index,value in pairs(t) do
    _t[index] = f(index,value,...)
  end
  return _t
end

-- - Reduces a table, left-to-right. Folds the table from the first element to the last element
-- to into a single value, with respect to a given iterator and an initial state.
-- The given function takes a state and a value and returns a new state.
-- <br/><em>Aliased as `inject`, `foldl`</em>.
-- @name reduce
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(state, value)`
-- @tparam[opt] state state an initial state of reduction. Defaults to the first value in the table.
-- @treturn state state the final state of reduction
-- @see reduceRight
function _.reduce(t, f, state)
  for __,value in pairs(t) do
    if state == nil then state = value
    else state = f(state,value)
    end
  end
  return state
end

-- - Reduces a table, right-to-left. Folds the table from the last element to the first element
-- to single value, with respect to a given iterator and an initial state.
-- The given function takes a state and a value, and returns a new state.
-- <br/><em>Aliased as `injectr`, `foldr`</em>.
-- @name reduceRight
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(state,value)`
-- @tparam[opt] state state an initial state of reduction. Defaults to the last value in the table.
-- @treturn state state the final state of reduction
-- @see reduce
function _.reduceRight(t, f, state)
  return _.reduce(_.reverse(t),f,state)
end

-- - Reduces a table while saving intermediate states. Folds the table left-to-right
-- to a single value, with respect to a given iterator and an initial state. The given function
-- takes a state and a value, and returns a new state. It returns an array of intermediate states.
-- <br/><em>Aliased as `mapr`</em>
-- @name mapReduce
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(state, value)`
-- @tparam[opt] state state an initial state of reduction. Defaults to the first value in the table.
-- @treturn table an array of states
-- @see mapReduceRight
function _.mapReduce(t, f, state)
  local _t = {}
  for i,value in pairs(t) do
    _t[i] = not state and value or f(state,value)
    state = _t[i]
  end
  return _t
end

-- - Reduces a table while saving intermediate states. Folds the table right-to-left
-- to a single value, with respect to a given iterator and an initial state. The given function
-- takes a state and a value, and returns a new state. It returns an array of intermediate states.
-- <br/><em>Aliased as `maprr`</em>
-- @name mapReduceRight
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(state,value)`
-- @tparam[opt] state state an initial state of reduction. Defaults to the last value in the table.
-- @treturn table an array of states
-- @see mapReduce
function _.mapReduceRight(t, f, state)
  return _.mapReduce(_.reverse(t),f,state)
end

-- - Search for a value in a table. It does not search in nested tables.
-- <br/><em>Aliased as `any`, `some`</em>
-- @name include
-- @tparam table t a table
-- @tparam value|function value a value to search for
-- @treturn boolean a boolean : `true` when found, `false` otherwise
-- @see detect
-- @see contains
function _.include(t,value)
  local _iter = _.isFunction(value) and value or _.isEqual
  for __,v in pairs(t) do
    if _iter(v,value) then return true end
  end
  return false
end

-- - Search for a value in a table. Returns the key of the value if found.
-- It does not search in nested tables.
-- @name detect
-- @tparam table t a table
-- @tparam value value a value to search for
-- @treturn key the value key or __nil__
-- @see include
-- @see contains
function _.detect(t, value)
  local _iter = _.isFunction(value) and value or _.isEqual
  for key,arg in pairs(t) do
    if _iter(arg,value) then return key end
  end
end

-- - Checks if a value is present in a table.
-- @name contains
-- @tparam table t a table
-- @tparam value value a value to search for
-- @treturn boolean true if present, otherwise false
-- @see include
-- @see detect
function _.contains(t, value)
  return _.toBoolean(_.detect(t, value))
end

-- - Returns the first value having specified keys `props`.
-- @function findWhere
-- @tparam table t a table
-- @tparam table props a set of keys
-- @treturn value a value from the passed-in table
function _.findWhere(t, props)
  local index = _.detect(t, function(v)
    for key in pairs(props) do
      if props[key] ~= v[key] then return false end
    end
    return true
  end)
  return index and t[index]
end

-- - Selects and extracts values passing an iterator test.
-- <br/><em>Aliased as `filter`</em>.
-- @name select
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @treturn table the selected values
-- @see reject
function _.select(t, f, ...)
  local _mapped = _.map(t, f, ...)
  local _t = {}
  for index,value in pairs(_mapped) do
    if value then _t[#_t+1] = t[index] end
  end
  return _t
end

-- - Clones a table while dropping values passing an iterator test.
-- <br/><em>Aliased as `discard`</em>
-- @name reject
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @treturn table the remaining values
-- @see select
function _.reject(t, f, ...)
  local _mapped = _.map(t,f,...)
  local _t = {}
  for index,value in pairs (_mapped) do
    if not value then _t[#_t+1] = t[index] end
  end
  return _t
end

-- - Checks if all values in a table are passing an iterator test.
-- <br/><em>Aliased as `every`</em>
-- @name all
-- @tparam table t a table
-- @tparam function f an iterator function, prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @treturn boolean `true` if all values passes the predicate, `false` otherwise
function _.all(t, f, ...)
  return ((#_.select(_.map(t,f,...), isTrue)) == (#t))
end

-- - Invokes a method on each value in a table.
-- @name invoke
-- @tparam table t a table
-- @tparam function method a function, prototyped as `f(value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `method`
-- @treturn result the result(s) of method call `f(value, ...)`
-- @see pluck
function _.invoke(t, method, ...)
  local args = {...}
  return _.map(t, function(__,v)
    if _.isTable(v) then
      if _.has(v,method) then
        if _.isCallable(v[method]) then
          return v[method](v,unpack(args))
        else
          return v[method]
        end
      else
        if _.isCallable(method) then
          return method(v,unpack(args))
        end
      end
    elseif _.isCallable(method) then
      return method(v,unpack(args))
    end
  end)
end

-- - Extracts property-values from a table of values.
-- @name pluck
-- @tparam table t a table
-- @tparam string a property, will be used to index in each value: `value[property]`
-- @treturn table an array of values for the specified property
function _.pluck(t, property)
  return _.reject(_.map(t,function(__,value)
      return value[property]
    end), iNot)
end

-- - Returns the max value in a collection. If an transformation function is passed, it will
-- be used to extract the value by which all objects will be sorted.
-- @name max
-- @tparam table t a table
-- @tparam[opt] function transform an transformation function, prototyped as `transform(value,...)`, defaults to @{identity}
-- @tparam[optchain] vararg ... Optional extra-args to be passed to function `transform`
-- @treturn value the maximum value found
-- @see min
function _.max(t, transform, ...)
  return extract(t, f_max, transform, ...)
end

-- - Returns the min value in a collection. If an transformation function is passed, it will
-- be used to extract the value by which all objects will be sorted.
-- @name min
-- @tparam table t a table
-- @tparam[opt] function transform an transformation function, prototyped as `transform(value,...)`, defaults to @{identity}
-- @tparam[optchain] vararg ... Optional extra-args to be passed to function `transform`
-- @treturn value the minimum value found
-- @see max
function _.min(t, transform, ...)
  return extract(t, f_min, transform, ...)
end

-- - Returns a shuffled copy of a given collection. If a seed is provided, it will
-- be used to init the random number generator (via `math.randomseed`).
-- @name shuffle
-- @tparam table t a table
-- @tparam[opt] number seed a seed
-- @treturn table a shuffled copy of the given table
function _.shuffle(t, seed)
  if seed then randomseed(seed) end
  local _shuffled = {}
  _.each(t,function(index,value)
     local randPos = floor(random()*index)+1
    _shuffled[index] = _shuffled[randPos]
    _shuffled[randPos] = value
  end)
  return _shuffled
end

-- - Checks if two tables are the same. It compares if both tables features the same values,
-- but not necessarily at the same keys.
-- @name same
-- @tparam table a a table
-- @tparam table b another table
-- @treturn boolean `true` or `false`
function _.same(a, b)
  return _.all(a, function (i,v) return _.include(b,v) end)
     and _.all(b, function (i,v) return _.include(a,v) end)
end

-- - Sorts a table, in-place. If a comparison function is given, it will be used to sort values.
-- @name sort
-- @tparam table t a table
-- @tparam[opt] function comp a comparison function prototyped as `comp(a,b)`, defaults to <tt><</tt> operator.
-- @treturn table the given table, sorted.
function _.sort(t, comp)
  t_sort(t, comp)
  return t
end

-- - Splits a table into subsets. Each subset feature values from the original table grouped
-- by the result of passing it through an iterator.
-- @name groupBy
-- @tparam table t a table
-- @tparam function iter an iterator function, prototyped as `iter(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `iter`
-- @treturn table a new table with values grouped by subsets
function _.groupBy(t, iter, ...)
  local vararg = {...}
  local _t = {}
  _.each(t, function(i,v)
      local _key = iter(i,v, unpack(vararg))
      if _t[_key] then _t[_key][#_t[_key]+1] = v
      else _t[_key] = {v}
      end
    end)
  return _t
end

-- - Groups values in a collection and counts them.
-- @name countBy
-- @tparam table t a table
-- @tparam function iter an iterator function, prototyped as `iter(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `iter`
-- @treturn table a new table with subsets names paired with their count
function _.countBy(t, iter, ...)
  local vararg = {...}
  local stats = {}
  _.each(t,function(i,v)
      local key = iter(i,v,unpack(vararg))
      stats[key] = (stats[key] or 0) +1
    end)
  return stats
end

-- - Counts the number of values in a collection. If being passed more than one args
-- it will return the count of all passed-in args.
-- @name size
-- @tparam[opt] vararg ... Optional variable number of arguments
-- @treturn number a count
-- @see count
-- @see countf
function _.size(...)
  local args = {...}
  local arg1 = args[1]
  if _.isNil(arg1) then
    return 0
  elseif _.isTable(arg1) then
    return count(args[1])
  else
    return count(args)
  end
end

-- - Checks if all the keys of `other` table exists in table `t`. It does not
-- compares values. The test is not commutative, i.e table `t` may contains keys
-- not existing in `other`.
-- @name containsKeys
-- @tparam table t a table
-- @tparam table other another table
-- @treturn boolean `true` or `false`
-- @see sameKeys
function _.containsKeys(t, other)
  for key in pairs(other) do
    if not t[key] then return false end
  end
  return true
end

-- - Checks if both given tables have the same keys. It does not compares values.
-- @name sameKeys
-- @tparam table tA a table
-- @tparam table tB another table
-- @treturn boolean `true` or `false`
-- @see containsKeys
function _.sameKeys(tA, tB)
  for key in pairs(tA) do
    if not tB[key] then return false end
  end
  for key in pairs(tB) do
    if not tA[key] then return false end
  end
  return true
end


-- - Array functions
-- @section Array functions

-- - Converts a vararg list to an array-list.
-- @name toArray
-- @tparam[opt] vararg ... Optional variable number of arguments
-- @treturn table an array-list of all passed-in args
function _.toArray(...) return {...} end

-- - Looks for the first occurrence of a given value in an array. Returns the value index if found.
-- @name find
-- @tparam table array an array of values
-- @tparam value value a value to search for
-- @tparam[opt] number from the index from where to start the search. Defaults to 1.
-- @treturn number|nil the index of the value if found in the array, `nil` otherwise.
function _.find(array, value, from)
  for i = from or 1, #array do
    if _.isEqual(array[i], value) then return i end
  end
end

-- - Reverses values in a given array. The passed-in array should not be sparse.
-- @name reverse
-- @tparam table array an array
-- @treturn table a copy of the given array, reversed
function _.reverse(array)
  local _array = {}
  for i = #array,1,-1 do
    _array[#_array+1] = array[i]
  end
  return _array
end

-- - Collects values from a given array. The passed-in array should not be sparse.
-- This function collects values as long as they satisfy a given predicate.
-- Therefore, it returns on the first falsy test.
-- <br/><em>Aliased as `takeWhile`</em>
-- @name selectWhile
-- @tparam table array an array
-- @tparam function f an iterator function prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @treturn table a new table containing all values collected
-- @see dropWhile
function _.selectWhile(array, f, ...)
  local t = {}
  for i,v in ipairs(array) do
    if f(i,v,...) then t[i] = v else break end
  end
  return t
end

-- - Collects values from a given array. The passed-in array should not be sparse.
-- This function collects values as long as they do not satisfy a given predicate.
-- Therefore it returns on the first true test.
-- <br/><em>Aliased as `rejectWhile`</em>
-- @name dropWhile
-- @tparam table array an array
-- @tparam function f an iterator function prototyped as `f(key,value,...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @treturn table a new table containing all values collected
-- @selectWhile
function _.dropWhile(array, f, ...)
  local _i
  for i,v in ipairs(array) do
    if not f(i,v,...) then
      _i = i
      break
    end
  end
  if _.isNil(_i) then return {} end
  return _.rest(array,_i)
end

-- - Returns the index at which a value should be inserted. This returned index is determined so
-- that it maintains the sort. If a comparison function is passed, it will be used to sort all
-- values.
-- @name sortedIndex
-- @tparam table array an array
-- @tparam value the value to be inserted
-- @tparam[opt] function comp an comparison function prototyped as `f(a, b)`, defaults to <tt><</tt> operator.
-- @tparam[optchain] boolean sort whether or not the passed-in array should be sorted
-- @treturn number the index at which the passed-in value should be inserted
function _.sortedIndex(array, value, comp, sort)
  local _comp = comp or f_min
  if sort then _.sort(array,_comp) end
  for i = 1,#array do
    if not _comp(array[i],value) then return i end
  end
  return #array+1
end

-- - Returns the index of a given value in an array. If the passed-in value exists
-- more than once in the array, it will return the index of the first occurrence.
-- @name indexOf
-- @tparam table array an array
-- @tparam value the value to search for
-- @treturn number|nil the index of the passed-in value
-- @see lastIndexOf
function _.indexOf(array, value)
  for k = 1,#array do
    if array[k] == value then return k end
  end
end

-- - Returns the index of the last occurrence of a given value.
-- @name lastIndexOf
-- @tparam table array an array
-- @tparam value the value to search for
-- @treturn number|nil the index of the last occurrence of the passed-in value or __nil__
-- @see indexOf
function _.lastIndexOf(array, value)
  local key = _.indexOf(_.reverse(array),value)
  if key then return #array-key+1 end
end

-- - Adds all passed-in values at the top of an array. The last arguments will bubble to the
-- top of the given array.
-- @name addTop
-- @tparam table array an array
-- @tparam vararg ... a variable number of arguments
-- @treturn table the passed-in array
-- @see push
function _.addTop(array, ...)
  _.each({...},function(i,v) t_insert(array,1,v) end)
  return array
end

-- - Pushes all passed-in values at the end of an array.
-- @name push
-- @tparam table array an array
-- @tparam vararg ... a variable number of arguments
-- @treturn table the passed-in array
-- @see addTop
function _.push(array, ...)
  _.each({...}, function(i,v) array[#array+1] = v end)
  return array
end

-- - Removes and returns the values at the top of a given array.
-- <br/><em>Aliased as `shift`</em>
-- @name pop
-- @tparam table array an array
-- @tparam[opt] number n the number of values to be popped. Defaults to 1.
-- @treturn vararg a vararg list of values popped from the array
-- @see unshift
function _.pop(array, n)
  n = min(n or 1, #array)
  local ret = {}
  for i = 1, n do
    local retValue = array[1]
    ret[#ret + 1] = retValue
    t_remove(array,1)
  end
  return unpack(ret)
end

-- - Removes and returns the values at the end of a given array.
-- @name unshift
-- @tparam table array an array
-- @tparam[opt] number n the number of values to be unshifted. Defaults to 1.
-- @treturn vararg a vararg list of values
-- @see pop
function _.unshift(array, n)
  n = min(n or 1, #array)
  local ret = {}
  for i = 1, n do
    local retValue = array[#array]
    ret[#ret + 1] = retValue
    t_remove(array)
  end
  return unpack(ret)
end

-- - Removes all provided values in a given array.
-- <br/><em>Aliased as `remove`</em>
-- @name pull
-- @tparam table array an array
-- @tparam vararg ... a variable number of values to be removed from the array
-- @treturn table the passed-in array
function _.pull(array, ...)
  for __, rmValue in ipairs({...}) do
    for i = #array, 1, -1 do
      if _.isEqual(array[i], rmValue) then
        t_remove(array, i)
      end
    end
  end
  return array
end

-- - Trims all values indexed within the range `[start, finish]`.
-- <br/><em>Aliased as `rmRange`</em>
-- @name removeRange
-- @tparam table array an array
-- @tparam[opt] number start the lower bound index, defaults to the first index in the array.
-- @tparam[optchain] number finish the upper bound index, defaults to the array length.
-- @treturn table the passed-in array
function _.removeRange(array, start, finish)
  local array = _.clone(array)
  local i,n = (next(array)),#array
  if n < 1 then return array end

  start = clamp(start or i,i,n)
  finish = clamp(finish or n,i,n)

  if finish < start then return array end

  local count = finish - start + 1
  local i = start
  while count > 0 do
    t_remove(array,i)
    count = count - 1
  end
  return array
end

-- - Chunks together consecutive values. Values are chunked on the basis of the return
-- value of a provided predicate `f(key, value, ...)`. Consecutive elements which return
-- the same value are chunked together. Leaves the first argument untouched if it is not an array.
-- @name chunk
-- @tparam table array an array
-- @tparam function f an iterator function prototyped as `f(key, value, ...)`
-- @tparam[opt] vararg ... Optional extra-args to be passed to function `f`
-- @treturn table a table of chunks (arrays)
-- @see zip
function _.chunk(array, f, ...)
  if not _.isArray(array) then return array end
  local ch, ck, prev = {}, 0
  local mask = _.map(array, f,...)
  _.each(mask, function(k,v)
    prev = (prev==nil) and v or prev
    ck = ((v~=prev) and (ck+1) or ck)
    if not ch[ck] then
      ch[ck] = {array[k]}
    else
      ch[ck][#ch[ck]+1] = array[k]
    end
    prev = v
  end)
  return ch
end

-- - Slices values indexed within `[start, finish]` range.
-- <br/><em>Aliased as `_.sub`</em>
-- @name slice
-- @tparam table array an array
-- @tparam[opt] number start the lower bound index, defaults to the first index in the array.
-- @tparam[optchain] number finish the upper bound index, defaults to the array length.
-- @treturn table a new array
function _.slice(array, start, finish)
  return _.select(array, function(index)
      return (index >= (start or next(array)) and index <= (finish or #array))
    end)
end

-- - Returns the first N values in an array.
-- <br/><em>Aliased as `head`, `take`</em>
-- @name first
-- @tparam table array an array
-- @tparam[opt] number n the number of values to be collected, defaults to 1.
-- @treturn table a new array
-- @see initial
-- @see last
-- @see rest
function _.first(array, n)
  local n = n or 1
  return _.slice(array,1, min(n,#array))
end

-- - Returns all values in an array excluding the last N values.
-- @name initial
-- @tparam table array an array
-- @tparam[opt] number n the number of values to be left, defaults to the array length.
-- @treturn table a new array
-- @see first
-- @see last
-- @see rest
function _.initial(array, n)
  if n and n < 0 then return end
  return _.slice(array,1, n and #array-(min(n,#array)) or #array-1)
end

-- - Returns the last N values in an array.
-- @name last
-- @tparam table array an array
-- @tparam[opt] number n the number of values to be collected, defaults to the array length.
-- @treturn table a new array
-- @see first
-- @see initial
-- @see rest
function _.last(array,n)
  if n and n <= 0 then return end
  return _.slice(array,n and #array-min(n-1,#array-1) or 2,#array)
end

-- - Trims all values before index.
-- <br/><em>Aliased as `tail`</em>
-- @name rest
-- @tparam table array an array
-- @tparam[opt] number index an index, defaults to 1
-- @treturn table a new array
-- @see first
-- @see initial
-- @see last
function _.rest(array,index)
  if index and index > #array then return {} end
  return _.slice(array,index and max(1,min(index,#array)) or 1,#array)
end

-- - Trims all falsy (false and nil) values.
-- @name compact
-- @tparam table array an array
-- @treturn table a new array
function _.compact(array)
  return _.reject(array, function (_,value)
    return not value
  end)
end

-- - Flattens a nested array. Passing `shallow` will only flatten at the first level.
-- @name flatten
-- @tparam table array an array
-- @tparam[opt] boolean shallow specifies the flattening depth
-- @treturn table a new array, flattened
function _.flatten(array, shallow)
  local shallow = shallow or false
  local new_flattened
  local _flat = {}
  for key,value in pairs(array) do
    if _.isTable(value) then
      new_flattened = shallow and value or _.flatten (value)
      _.each(new_flattened, function(_,item) _flat[#_flat+1] = item end)
    else _flat[#_flat+1] = value
    end
  end
  return _flat
end

-- - Returns values from an array not present in all passed-in args.
-- <br/><em>Aliased as `without` and `diff`</em>
-- @name difference
-- @tparam table array an array
-- @tparam table another array
-- @treturn table a new array
-- @see union
-- @see intersection
-- @see symmetricDifference
function _.difference(array, array2)
  if not array2 then return _.clone(array) end
  return _.select(array,function(i,value)
      return not _.include(array2,value)
    end)
end

-- - Returns the duplicate-free union of all passed in arrays.
-- @name union
-- @tparam vararg ... a variable number of arrays arguments
-- @treturn table a new array
-- @see difference
-- @see intersection
-- @see symmetricDifference
function _.union(...)
  return _.uniq(_.flatten({...}))
end

-- - Returns the  intersection of all passed-in arrays.
-- Each value in the result is present in each of the passed-in arrays.
-- @name intersection
-- @tparam table array an array
-- @tparam vararg ... a variable number of array arguments
-- @treturn table a new array
-- @see difference
-- @see union
-- @see symmetricDifference
function _.intersection(array, ...)
  local arg = {...}
  local _intersect = {}
  for i,value in ipairs(array) do
    if _.all(arg,function(i,v)
          return _.include(v,value)
        end) then
      t_insert(_intersect,value)
    end
  end
  return _intersect
end

-- - Performs a symmetric difference. Returns values from `array` not present in `array2` and also values
-- from `array2` not present in `array`.
-- <br/><em>Aliased as `symdiff`</em>
-- @name symmetricDifference
-- @tparam table array an array
-- @tparam table array2 another array
-- @treturn table a new array
-- @see difference
-- @see union
-- @see intersection
function _.symmetricDifference(array, array2)
  return _.difference(
    _.union(array, array2),
    _.intersection(array,array2)
  )
end

-- - Produces a duplicate-free version of a given array.
-- <br/><em>Aliased as `uniq`</em>
-- @name unique
-- @tparam table array an array
-- @treturn table a new array, duplicate-free
-- @see isunique
function _.unique(array)
  local ret = {}
  for i = 1, #array do
    if not _.find(ret, array[i]) then
      ret[#ret+1] = array[i]
    end
  end
  return ret
end

-- - Checks if a given array contains distinct values. Such an array is made of distinct elements,
-- which only occur once in this array.
-- <br/><em>Aliased as `isuniq`</em>
-- @name isunique
-- @tparam table array an array
-- @treturn boolean `true` if the given array is unique, `false` otherwise.
-- @see unique
function _.isunique(array)
  return _.isEqual(array, _.unique(array))
end

-- - Merges values of each of the passed-in arrays in subsets.
-- Only values indexed with the same key in the given arrays are merged in the same subset.
-- @name zip
-- @tparam vararg ... a variable number of array arguments
-- @treturn table a new array
function _.zip(...)
  local arg = {...}
  local _len = _.max(_.map(arg,function(i,v)
      return #v
    end))
  local _ans = {}
  for i = 1,_len do
    _ans[i] = _.pluck(arg,i)
  end
  return _ans
end

-- - Clones `array` and appends `other` values.
-- @name append
-- @tparam table array an array
-- @tparam table other an array
-- @treturn table a new array
function _.append(array, other)
  local t = {}
  for i,v in ipairs(array) do t[i] = v end
  for i,v in ipairs(other) do t[#t+1] = v end
  return t
end

-- - Interleaves arrays. It returns a single array made of values from all
-- passed in arrays in their given order, interleaved.
-- @name interleave
-- @tparam vararg ... a variable list of arrays
-- @treturn table a new array
-- @see interpose
function _.interleave(...) return _.flatten(_.zip(...)) end

-- - Interposes `value` in-between consecutive pair of values in `array`.
-- @name interpose
-- @tparam value value a value
-- @tparam table array an array
-- @treturn table a new array
-- @see interleave
function _.interpose(value, array)
  return _.flatten(_.zip(array, _.rep(value, #array-1)))
end

-- - Produce a flexible list of numbers. If one positive value is passed, will count from 0 to that value,
-- with a default step of 1. If two values are passed, will count from the first one to the second one, with the
-- same default step of 1. A third passed value will be considered a step value.
-- @name range
-- @tparam[opt] number from the initial value of the range
-- @tparam[optchain] number to the final value of the range
-- @tparam[optchain] number step the count step value
-- @treturn table a new array of numbers
function _.range(...)
  local arg = {...}
  local _start,_stop,_step
  if #arg==0 then return {}
  elseif #arg==1 then _stop,_start,_step = arg[1],0,1
  elseif #arg==2 then _start,_stop,_step = arg[1],arg[2],1
  elseif #arg == 3 then _start,_stop,_step = arg[1],arg[2],arg[3]
  end
  if (_step and _step==0) then return {} end
  local _ranged = {}
  local _steps = max(floor((_stop-_start)/_step),0)
  for i=1,_steps do _ranged[#_ranged+1] = _start+_step*i end
  if #_ranged>0 then t_insert(_ranged,1,_start) end
  return _ranged
end

-- - Creates an array list of `n` values, repeated.
-- @name rep
-- @tparam value value a value to be repeated
-- @tparam number n the number of repetitions of the given `value`.
-- @treturn table a new array of `n` values
function _.rep(value, n)
  local ret = {}
  for i = 1, n do ret[#ret+1] = value end
  return ret
end

-- - Iterator returning partitions of an array. It returns arrays of length `n`
-- made of values from the given array. In case the array size is not a multiple
-- of `n`, the last array returned will be made of the rest of the values.
-- @name partition.
-- @tparam table array an array
-- @tparam[opt] number n the size of each partition. Defaults to 1.
-- @treturn function an iterator function
function _.partition(array, n)
  return coroutine.wrap(function()
    partgen(array, n or 1, coroutine.yield)
  end)
end

-- - Iterator returning the permutations of an array. It returns arrays made of all values
-- from the passed-in array, with values permuted.
-- @name permutation
-- @tparam table array an array
-- @treturn function an iterator function
function _.permutation(array)
  return coroutine.wrap(function()
    permgen(array, #array, coroutine.yield)
  end)
end

-- - Swaps keys with values. Produces a new array where previous keys are now values,
-- while previous values are now keys.
-- <br/><em>Aliased as `mirror`</em>
-- @name invert
-- @tparam table array a given array
-- @treturn table a new array
function _.invert(array)
  local _ret = {}
  _.each(array,function(i,v) _ret[v] = i end)
  return _ret
end

-- - Concatenates values in a given array. Handles booleans as well. If `sep` string is
-- passed, it will be used as a separator. Passing `i` and `j` will result in concatenating
-- values within `[i,j]` range.
-- <br/><em>Aliased as `join`</em>
-- @name concat
-- @tparam table array a given array
-- @tparam[opt] string sep a separator string, defaults to `''`.
-- @tparam[optchain] number i the starting index, defaults to 1.
-- @tparam[optchain] number j the final index, defaults to the array length.
-- @treturn string a string
function _.concat(array, sep, i, j)
  local _array = _.map(array,function(i,v)
    return tostring(v)
  end)
  return t_concat(_array,sep,i or 1,j or #array)

end


-- - Utility functions
-- @section Utility functions

-- - Returns the passed-in value. This function seems useless, but it is used internally
-- as a default iterator.
-- @name identity
-- @tparam value value a value
-- @treturn value the passed-in value
function _.identity(value) return value end

-- - Returns a version of `f` that runs only once. Successive calls to `f`
-- will keep yielding the same output, no matter what the passed-in arguments are.
-- It can be used to initialize variables.
-- @name once
-- @tparam function f a function
-- @treturn function a new function
-- @see after
function _.once(f)
  local _internal = 0
  local _args = {}
  return function(...)
      _internal = _internal+1
      if _internal<=1 then _args = {...} end
      return f(unpack(_args))
    end
end

-- - Memoizes a given function by caching the computed result.
-- Useful for speeding-up slow-running functions. If function `hash` is passed,
-- it will be used to compute hash keys for a set of input values to the function for caching.
-- <br/><em>Aliased as `cache`</em>
-- @name memoize
-- @tparam function f a function
-- @tparam[opt] function hash a hash function, defaults to @{identity}
-- @treturn function a new function
function _.memoize(f, hash)
  local _cache = setmetatable({},{__mode = 'kv'})
  local _hasher = hash or _.identity
  return function (...)
      local _hashKey = _hasher(...)
      local _result = _cache[_hashKey]
      if not _result then _cache[_hashKey] = f(...) end
      return _cache[_hashKey]
    end
end

-- - Returns a version of `f` that runs on the `count-th` call.
-- Useful when dealing with asynchronous tasks.
-- @name after
-- @tparam function f a function
-- @tparam number count the number of calls before `f` answers
-- @treturn function a new function
-- @see once
function _.after(f, count)
  local _limit,_internal = count, 0
  return function(...)
      _internal = _internal+1
      if _internal >= _limit then return f(...) end
    end
end

-- - Composes functions. Each passed-in function consumes the return value of the function that follows.
-- In math terms, composing the functions `f`, `g`, and `h` produces the function `f(g(h(...)))`.
-- @name compose
-- @tparam vararg ... a variable number of functions
-- @treturn function a new function
-- @see pipe
function _.compose(...)
  local f = _.reverse {...}
  return function (...)
      local _temp
      for i, func in ipairs(f) do
        _temp = _temp and func(_temp) or func(...)
      end
      return _temp
    end
end

-- - Pipes a value through a series of functions. In math terms,
-- given some functions `f`, `g`, and `h` in that order, it returns `f(g(h(value)))`.
-- @name pipe
-- @tparam value value a value
-- @tparam vararg ... a variable number of functions
-- @treturn value the result of the composition of function calls.
-- @see compose
function _.pipe(value, ...)
  return _.compose(...)(value)
end

-- - Returns the logical complement of a given function. For a given input, the returned
-- function will output `false` if the original function would have returned `true`,
-- and vice-versa.
-- @name complement
-- @tparam function f a function
-- @treturn function  the logical complement of the given function `f`.
function _.complement(f)
  return function(...) return not f(...) end
end

-- - Calls a sequence of passed-in functions with the same argument.
-- Returns a sequence of results.
-- <br/><em>Aliased as `juxt`</em>
-- @name juxtapose
-- @tparam value value a value
-- @tparam vararg ... a variable number of functions
-- @treturn vararg a vargarg list of results.
function _.juxtapose(value, ...)
  local res = {}
  _.each({...}, function(_,f) res[#res+1] = f(value) end)
  return unpack(res)
end

-- - Wraps `f` inside of the `wrapper` function. It passes `f` as the first argument to `wrapper`.
-- This allows the wrapper to execute code before and after `f` runs,
-- adjust the arguments, and execute it conditionally.
-- @name wrap
-- @tparam function f a function to be wrapped, prototyped as `f(...)`
-- @tparam function wrapper a wrapper function, prototyped as `wrapper(f,...)`
-- @treturn function a new function
function _.wrap(f, wrapper)
  return function (...) return  wrapper(f,...) end
end

-- - Runs `iter` function `n` times.
-- Collects the results of each run and returns them in an array.
-- @name times
-- @tparam number n the number of times `iter` should be called
-- @tparam function iter an iterator function, prototyped as `iter(i, ...)`
-- @tparam vararg ... extra-args to be passed to `iter` function
-- @treturn table an array of results
function _.times(n, iter, ...)
  local results = {}
  for i = 1,n do
    results[i] = iter(i,...)
  end
  return results
end

-- - Binds `v` to be the first argument to function `f`. As a result,
-- calling `f(...)` will result to `f(v, ...)`.
-- @name bind
-- @tparam function f a function
-- @tparam value v a value
-- @treturn function a function
-- @see bindn
function _.bind(f, v)
  return function (...)
      return f(v,...)
    end
end

-- - Binds `...` to be the N-first arguments to function `f`. As a result,
-- calling `f(a1, a2, ..., aN)` will result to `f(..., a1, a2, ...,aN)`.
-- @name bindn
-- @tparam function f a function
-- @tparam vararg ... a variable number of arguments
-- @treturn function a function
-- @see bind
function _.bindn(f, ...)
  local iArg = {...}
  return function (...)
      return f(unpack(_.append(iArg,{...})))
    end
end

-- - Generates a unique ID for the current session. If given a string *template*
-- will use this template for output formatting. Otherwise, if *template* is a function,
-- will evaluate `template(id, ...)`.
-- <br/><em>Aliased as `uid`</em>.
-- @name uniqueId
-- @tparam[opt] string|function template either a string or a function template to format the ID
-- @tparam[optchain] vararg ... a variable number of arguments to be passed to *template*, in case it is a function.
-- @treturn value an ID
function _.uniqueId(template, ...)
  unique_id_counter = unique_id_counter + 1
  if template then
    if _.isString(template) then
      return template:format(unique_id_counter)
    elseif _.isFunction(template) then
      return template(unique_id_counter,...)
    end
  end
  return unique_id_counter
end

-- - Object functions
--@section Object functions

-- - Returns the keys of the object properties.
-- @name keys
-- @tparam table obj an object
-- @treturn table an array
function _.keys(obj)
  local _oKeys = {}
  _.each(obj,function(key) _oKeys[#_oKeys+1]=key end)
  return _oKeys
end

-- - Returns the values of the object properties.
-- @name values
-- @tparam table obj an object
-- @treturn table an array
function _.values(obj)
  local _oValues = {}
  _.each(obj,function(_,value) _oValues[#_oValues+1]=value end)
  return _oValues
end

-- - Converts any given value to a boolean
-- @name toBoolean
-- @tparam value value a value. Can be of any type
-- @treturn boolean `true` if value is true, `false` otherwise (false or nil).
function _.toBoolean(value)
  return not not value
end

-- - Extends an object properties. It copies all of the properties of extra passed-in objects
-- into the destination object, and returns the destination object.
-- The last object in the `...` set will override properties of the same name in the previous one
-- @name extend
-- @tparam table destObj a destination object
-- @tparam vararg ... a variable number of array arguments
-- @treturn table the destination object extended
function _.extend(destObj, ...)
  local sources = {...}
  _.each(sources,function(__,source)
    if _.isTable(source) then
      _.each(source,function(key,value)
        destObj[key] = value
      end)
    end
  end)
  return destObj
end

-- - Returns a sorted list of all methods names found in an object. If the given object
-- has a metatable implementing an `__index` field pointing to another table, will also recurse on this
-- table if argument `recurseMt` is provided. If `obj` is omitted, it defaults to the library functions.
-- <br/><em>Aliased as `methods`</em>.
-- @name functions
-- @tparam[opt] table obj an object. Defaults to library functions.
-- @treturn table an array-list of methods names
function _.functions(obj, recurseMt)
  obj = obj or _
  local _methods = {}
  _.each(obj,function(key,value)
    if _.isFunction(value) then
      _methods[#_methods+1]=key
    end
  end)
  if not recurseMt then
    return _.sort(_methods)
  end
  local mt = getmetatable(obj)
  if mt and mt.__index then
    local mt_methods = _.functions(mt.__index)
    _.each(mt_methods, function(k,fn)
      _methods[#_methods+1] = fn
    end)
  end
  return _.sort(_methods)
end

-- - Clones a given object properties. If `shallow` is passed
-- will also clone nested array properties.
-- @name clone
-- @tparam table obj an object
-- @tparam[opt] boolean shallow whether or not nested array-properties should be cloned, defaults to false.
-- @treturn table a copy of the passed-in object
function _.clone(obj, shallow)
  if not _.isTable(obj) then return obj end
  local _obj = {}
  _.each(obj,function(i,v)
    if _.isTable(v) then
      if not shallow then
        _obj[i] = _.clone(v,shallow)
      else _obj[i] = v
      end
    else
      _obj[i] = v
    end
  end)
  return _obj
end

-- - Invokes interceptor with the object, and then returns object.
-- The primary purpose of this method is to "tap into" a method chain, in order to perform operations
-- on intermediate results within the chain.
-- @name tap
-- @tparam table obj an object
-- @tparam function f an interceptor function, should be prototyped as `f(obj, ...)`
-- @tparam[opt] vararg ... Extra-args to be passed to interceptor function
-- @treturn table the passed-in object
function _.tap(obj, f, ...)
  f(obj,...)
  return obj
end

-- - Checks if a given object implements a property.
-- @name has
-- @tparam table obj an object
-- @tparam value key a key property to be checked
-- @treturn boolean `true` or `false`
function _.has(obj, key)
  return obj[key]~=nil
end

-- - Return a filtered copy of the object. The returned object will only have
-- the white-listed properties paired with their original values.
-- <br/><em>Aliased as `choose`</em>.
-- @name pick
-- @tparam table obj an object
-- @tparam vararg ... a variable number of string keys
-- @treturn table the filtered object
function _.pick(obj, ...)
  local whitelist = _.flatten {...}
  local _picked = {}
  _.each(whitelist,function(key,property)
      if not _.isNil(obj[property]) then
        _picked[property] = obj[property]
      end
    end)
  return _picked
end

-- - Return a filtered copy of the object. The returned object will not have
-- the black-listed properties.
-- <br/><em>Aliased as `drop`</em>.
-- @name omit
-- @tparam table obj an object
-- @tparam vararg ... a variable number of string keys
-- @treturn table the filtered object
function _.omit(obj, ...)
  local blacklist = _.flatten {...}
  local _picked = {}
  _.each(obj,function(key,value)
      if not _.include(blacklist,key) then
        _picked[key] = value
      end
    end)
  return _picked
end

-- - Fills nil properties in an object with the given `template` object. Pre-existing
-- properties will be preserved.
-- <br/><em>Aliased as `defaults`</em>.
-- @name template
-- @tparam table obj an object
-- @tparam[opt] table template a template object. Defaults to an empty table `{}`.
-- @treturn table the passed-in object filled
function _.template(obj, template)
  _.each(template or {},function(i,v)
  if not obj[i] then obj[i] = v end
  end)
  return obj
end

-- - Performs a deep comparison test between two objects. Can compare strings, functions
-- (by reference), nil, booleans. Compares tables by reference or by values. If `useMt`
-- is passed, the equality operator `==` will be used if one of the given objects has a
-- metatable implementing `__eq`.
-- <br/><em>Aliased as `_.compare`</em>
-- @name isEqual
-- @tparam table objA an object
-- @tparam table objB another object
-- @tparam[opt] boolean useMt whether or not `__eq` should be used, defaults to false.
-- @treturn boolean `true` or `false`
function _.isEqual(objA, objB, useMt)
  local typeObjA = type(objA)
  local typeObjB = type(objB)

  if typeObjA~=typeObjB then return false end
  if typeObjA~='table' then return (objA==objB) end

  local mtA = getmetatable(objA)
  local mtB = getmetatable(objB)

  if useMt then
    if (mtA or mtB) and (mtA.__eq or mtB.__eq) then
      return mtA.__eq(objA, objB) or mtB.__eq(objB, objA) or (objA==objB)
    end
  end

  if _.size(objA)~=_.size(objB) then return false end

  for i,v1 in pairs(objA) do
    local v2 = objB[i]
    if _.isNil(v2) or not _.isEqual(v1,v2,useMt) then return false end
  end

  for i,v1 in pairs(objB) do
    local v2 = objA[i]
    if _.isNil(v2) then return false end
  end

  return true
end

-- - Invokes an object method. It passes the object itself as the first argument. if `method` is not
-- callable, will return `obj[method]`.
-- @name result
-- @tparam table obj an object
-- @tparam string method a string key to index in object `obj`.
-- @tparam[opt] vararg ... Optional extra-args to be passed to `method`
-- @treturn value the returned value of `method(obj,...)` call
function _.result(obj, method, ...)
  if obj[method] then
    if _.isCallable(obj[method]) then
      return obj[method](obj,...)
    else return obj[method]
    end
  end
  if _.isCallable(method) then
    return method(obj,...)
  end
end

-- - Checks if the given arg is a table.
-- @name isTable
-- @tparam table t a value to be tested
-- @treturn boolean `true` or `false`
function _.isTable(t)
  return type(t) == 'table'
end

-- - Checks if the given argument is an callable. Assumes `obj` is callable if
-- it is either a function or a table having a metatable implementing `__call` metamethod.
-- @name isCallable
-- @tparam table obj an object
-- @treturn boolean `true` or `false`
function _.isCallable(obj)
  return (_.isFunction(obj) or
     (_.isTable(obj) and getmetatable(obj)
                   and getmetatable(obj).__call~=nil) or false)
end

-- - Checks if the given argument is an array. Assumes `obj` is an array
-- if is a table with integer numbers starting at 1.
-- @name isArray
-- @tparam table obj an object
-- @treturn boolean `true` or `false`
function _.isArray(obj)
  if not _.isTable(obj) then return false end
  -- Thanks @Wojak and @Enrique García Cota for suggesting this
  -- See : http://love2d.org/forums/viewtopic.php?f=3&t=77255&start=40#p163624
  local i = 0
  for __ in pairs(obj) do
     i = i + 1
     if _.isNil(obj[i]) then return false end
  end
  return true
end

-- - Checks if the given object is iterable with `pairs` (or `ipairs`).
-- @name isIterable
-- @tparam table obj an object
-- @treturn boolean `true` if the object can be iterated with `pairs`, `false` otherwise
function _.isIterable(obj)
  return _.toBoolean((pcall(pairs, obj)))
end

-- - Checks if the given is empty. If `obj` is a *string*, will return `true`
-- if `#obj == 0`. Otherwise, if `obj` is a table, will return whether or not this table
-- is empty. If `obj` is `nil`, it will return true.
-- @name isEmpty
-- @tparam[opt] table|string obj an object
-- @treturn boolean `true` or `false`
function _.isEmpty(obj)
  if _.isNil(obj) then return true end
  if _.isString(obj) then return #obj==0 end
  if _.isTable(obj) then return next(obj)==nil end
  return true
end

-- - Checks if the given argument is a *string*.
-- @name isString
-- @tparam table obj an object
-- @treturn boolean `true` or `false`
function _.isString(obj)
  return type(obj) == 'string'
end

-- - Checks if the given argument is a function.
-- @name isFunction
-- @tparam table obj an object
-- @treturn boolean `true` or `false`
function _.isFunction(obj)
   return type(obj) == 'function'
end

-- - Checks if the given argument is nil.
-- @name isNil
-- @tparam table obj an object
-- @treturn boolean `true` or `false`
function _.isNil(obj)
  return obj==nil
end

-- - Checks if the given argument is a number.
-- @name isNumber
-- @tparam table obj a number
-- @treturn boolean `true` or `false`
-- @see isNaN
function _.isNumber(obj)
  return type(obj) == 'number'
end

-- - Checks if the given argument is NaN (see [Not-A-Number](http://en.wikipedia.org/wiki/NaN)).
-- @name isNaN
-- @tparam table obj a number
-- @treturn boolean `true` or `false`
-- @see isNumber
function _.isNaN(obj)
  return _.isNumber(obj) and obj~=obj
end

-- - Checks if the given argument is a finite number.
-- @name isFinite
-- @tparam table obj a number
-- @treturn boolean `true` or `false`
function _.isFinite(obj)
  if not _.isNumber(obj) then return false end
  return obj > -huge and obj < huge
end

-- - Checks if the given argument is a boolean.
-- @name isBoolean
-- @tparam table obj a boolean
-- @treturn boolean `true` or `false`
function _.isBoolean(obj)
  return type(obj) == 'boolean'
end

-- - Checks if the given argument is an integer.
-- @name isInteger
-- @tparam table obj a number
-- @treturn boolean `true` or `false`
function _.isInteger(obj)
  return _.isNumber(obj) and floor(obj)==obj
end

-- Aliases

do

  -- Table functions aliases
  _.forEach     = _.each
  _.forEachi    = _.eachi
  _.loop        = _.cycle
  _.collect     = _.map
  _.inject      = _.reduce
  _.foldl       = _.reduce
  _.injectr     = _.reduceRight
  _.foldr       = _.reduceRight
  _.mapr        = _.mapReduce
  _.maprr       = _.mapReduceRight
  _.any         = _.include
  _.some        = _.include
  _.filter      = _.select
  _.discard     = _.reject
  _.every       = _.all

  -- Array functions aliases
  _.takeWhile   = _.selectWhile
  _.rejectWhile = _.dropWhile
  _.shift       = _.pop
  _.remove      = _.pull
  _.rmRange     = _.removeRange
  _.chop        = _.removeRange
  _.sub         = _.slice
  _.head        = _.first
  _.take        = _.first
  _.tail        = _.rest
  _.skip        = _.last
  _.without     = _.difference
  _.diff        = _.difference
  _.symdiff     = _.symmetricDifference
  _.xor         = _.symmetricDifference
  _.uniq        = _.unique
  _.isuniq      = _.isunique
  _.part        = _.partition
  _.perm        = _.permutation
  _.mirror      = _.invert
  _.join        = _.concat

  -- Utility functions aliases
  _.cache       = _.memoize
  _.juxt        = _.juxtapose
  _.uid         = _.uniqueId

  -- Object functions aliases
  _.methods     = _.functions
  _.choose      = _.pick
  _.drop        = _.omit
  _.defaults    = _.template
  _.compare     = _.isEqual

end

-- Setting chaining and building interface

do

  -- Wrapper to Moses
  local f = {}

  -- Will be returned upon requiring, indexes into the wrapper
  local __ = {}
  __.__index = f

  -- Wraps a value into an instance, and returns the wrapped object
  local function new(value)
    local i = {_value = value, _wrapped = true}
    return setmetatable(i, __)
  end

  setmetatable(__,{
    __call  = function(self,v) return new(v) end, -- Calls returns to instantiation
    __index = function(t,key,...) return f[key] end  -- Redirects to the wrapper
  })

  -- - Returns a wrapped object. Calling library functions as methods on this object
  -- will continue to return wrapped objects until @{obj:value} is used. Can be aliased as `_(value)`.
  -- @class function
  -- @name chain
  -- @tparam value value a value to be wrapped
  -- @treturn object a wrapped object
  function __.chain(value)
    return new(value)
  end

  -- - Extracts the value of a wrapped object. Must be called on an chained object (see @{chain}).
  -- @class function
  -- @name obj:value
  -- @treturn value the value previously wrapped
  function __:value()
    return self._value
  end

  -- Register chaining methods into the wrapper
  f.chain, f.value = __.chain, __.value

  -- Register all functions into the wrapper
  for fname,fct in pairs(_) do
    f[fname] = function(v, ...)
      local wrapped = _.isTable(v) and v._wrapped or false
      if wrapped then
        local _arg = v._value
        local _rslt = fct(_arg,...)
        return new(_rslt)
      else
        return fct(v,...)
      end
    end
  end

  -- - Imports all library functions into a context.
  -- @name import
  -- @tparam[opt] table context a context. Defaults to `_G` (global environment) when not given.
  -- @tparam[optchain] boolean noConflict Skips function import in case its key exists in the given context
  -- @treturn table the passed-in context
  f.import = function(context, noConflict)
    context = context or _G
    local funcs = _.functions()
    _.each(funcs, function(k, fname)
      if rawget(context, fname) then
        if not noConflict then
          context[fname] = _[fname]
        end
      else
        context[fname] = _[fname]
      end
    end)
    return context
  end

  -- Descriptive tags
  __._VERSION     = 'Moses v'.._MODULEVERSION
  __._URL         = 'http://github.com/Yonaba/Moses'
  __._LICENSE     = 'MIT <http://raw.githubusercontent.com/Yonaba/Moses/master/LICENSE>'
  __._DESCRIPTION = 'utility-belt library for functional programming in Lua'

  return __

end
