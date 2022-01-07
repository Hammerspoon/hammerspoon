--- === hs.fnutils ===
---
--- Functional programming utility functions

local fnutils = {}

local pairs,ipairs = pairs,ipairs
local floor = math.floor

--- hs.fnutils.imap(list, fn) -> list
--- Function
--- Execute a function across a list-like table in order, and collect the results
---
--- Parameters:
---  * list - A list-like table, i.e. one whose keys are sequential integers starting from 1
---  * fn - A function that accepts a single parameter (a table element). The values returned from this function
---    will be collected into the result list; when `nil` is returned the relevant element is discarded - the
---    result list won't have any "holes".
---
--- Returns:
---  * A list-like table containing the results of calling the function on every element in the table
---
--- Notes:
---  * If `list` has "holes", all elements after the first hole will be lost, as the table is iterated over with `ipairs`;
---    use `hs.fnutils.map()` if your table has holes
function fnutils.imap(t, fn)
  local nt = {}
  for _, v in ipairs(t) do
    nt[#nt+1] = fn(v) -- or nil < removed, as this precludes inserting false!
  end
  return nt
end

local function isListIndex(k)
  return type(k)=='number' and k>=1 and floor(k)==k -- not using 5.3 syntax (k//1==k), as you never know
end
--- hs.fnutils.map(table, fn) -> table
--- Function
--- Execute a function across a table (in arbitrary order) and collect the results
---
--- Parameters:
---  * table - A table; it can have both a list (or array) part and a hash (or dict) part
---  * fn - A function that accepts a single parameter (a table element). For the hash part, the values returned
---  from this function (if non-nil) will be assigned to the same key in the result list. For the array part, this function
---  behaves like `hs.fnutils.imap()` (i.e. `nil` results are discarded); however all keys, including integer keys after
---  a "hole" in `table`, will be iterated over.
---
--- Returns:
---  * A table containing the results of calling the function on every element in the table
---
--- Notes:
---  * If `table` is a pure array table (list-like) without "holes", use `hs.fnutils.imap()` if you need guaranteed in-order
---  processing and for better performance.
function fnutils.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do -- they'll potentially be out of order, but they always were anyway
    nt[isListIndex(k) and (#nt+1) or k] = fn(v) -- meh, but required for compatibility
  end
  return nt
end

--- hs.fnutils.ieach(list, fn)
--- Function
--- Execute a function across a list-like table in order, and discard the results
---
--- Parameters:
---  * list - A list-like table, i.e. one whose keys are sequential integers starting from 1
---  * fn - A function that accepts a single parameter (a table element)
---
--- Returns:
---  * None
function fnutils.ieach(t, fn)
  for _, v in ipairs(t) do fn(v) end
end

--- hs.fnutils.each(table, fn)
--- Function
--- Execute a function across a table (in arbitrary order), and discard the results
---
--- Parameters:
---  * table - A table; it can have both a list (or array) part and a hash (or dict) part
---  * fn - A function that accepts a single parameter (a table element)
---
--- Returns:
---  * None
function fnutils.each(t, fn)
  for _, v in pairs(t) do fn(v) end
end


--- hs.fnutils.ifilter(list, fn) -> list
--- Function
--- Filter a list-like table by running a predicate function on its elements in order
---
--- Parameters:
---  * list - A list-like table, i.e. one whose keys are sequential integers starting from 1
---  * fn - A function that accepts a single parameter (a table element) and returns a boolean
---    value: true if the parameter should be kept, false if it should be discarded
---
--- Returns:
---  * A list-like table containing the elements of the table for which fn(element) returns true
---
--- Notes:
---  * If `list` has "holes", all elements after the first hole will be lost, as the table is iterated over with `ipairs`;
---    use `hs.fnutils.map()` if your table has holes
function fnutils.ifilter(t, fn)
  local nt = {}
  for _, v in ipairs(t) do if fn(v) then nt[#nt+1] = v end end
  return nt
end

--- hs.fnutils.filter(table, fn) -> table
--- Function
--- Filter a table by running a predicate function on its elements (in arbitrary order)
---
--- Parameters:
---  * table - A table; it can have both a list (or array) part and a hash (or dict) part
---  * fn - A function that accepts a single parameter (a table element) and returns a boolean
---    value: true if the parameter should be kept, false if it should be discarded
---
--- Returns:
---  * A table containing the elements of the table for which fn(element) returns true
---
--- Notes:
---  * If `table` is a pure array table (list-like) without "holes", use `hs.fnutils.ifilter()` if you need guaranteed in-order
---  processing and for better performance.
function fnutils.filter(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    if fn(v) then nt[isListIndex(k) and (#nt+1) or k] = v end -- meh etc.
  end
  return nt
end

--- hs.fnutils.copy(table) -> table
--- Function
--- Copy a table using `pairs()`
---
--- Parameters:
---  * table - A table containing some sort of data
---
--- Returns:
---  * A new table containing the same data as the input table
function fnutils.copy(t)
  local nt = {}
  for k, v in pairs(t) do
    nt[k] = v
  end
  return nt
end

--- hs.fnutils.contains(table, element) -> bool
--- Function
--- Determine if a table contains a given object
---
--- Parameters:
---  * table - A table containing some sort of data
---  * element - An object to search the table for
---
--- Returns:
---  * A boolean, true if the element could be found in the table, otherwise false
function fnutils.contains(t, el)
  for _, v in pairs(t) do
    if v == el then
      return true
    end
  end
  return false
end

--- hs.fnutils.indexOf(table, element) -> number or nil
--- Function
--- Determine the location in a table of a given object
---
--- Parameters:
---  * table - A table containing some sort of data
---  * element - An object to search the table for
---
--- Returns:
---  * A number containing the index of the element in the table, or nil if it could not be found
function fnutils.indexOf(t, el)
  for k, v in pairs(t) do
    if v == el then
      return k
    end
  end
  return nil
end

--- hs.fnutils.concat(table1, table2)
--- Function
--- Join two tables together
---
--- Parameters:
---  * table1 - A table containing some sort of data
---  * table2 - A table containing some sort of data
---
--- Returns:
---  * table1, with all of table2's elements added to the end of it
---
--- Notes:
---  * table2 cannot be a sparse table, see [http://www.luafaq.org/gotchas.html#T6.4](http://www.luafaq.org/gotchas.html#T6.4)
function fnutils.concat(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

--- hs.fnutils.mapCat(table, fn) -> table
--- Function
--- Execute, across a table, a function that outputs tables, and concatenate all of those tables together
---
--- Parameters:
---  * table - A table containing some sort of data
---  * fn - A function that takes a single parameter and returns a table
---
--- Returns:
---  * A table containing the concatenated results of calling fn(element) for every element in the supplied table
function fnutils.mapCat(t, fn)
  local nt = {}
  for _, v in pairs(t) do
    fnutils.concat(nt, fn(v))
  end
  return nt
end

--- hs.fnutils.reduce(table, fn) -> table
--- Function
--- Reduce a table to a single element, using a function
---
--- Parameters:
---  * table - A table containing some sort of data
---  * fn - A function that takes two parameters, which will be elements of the supplied table. It should choose one of these elements and return it
---
--- Returns:
---  * The element of the supplied table that was chosen by the iterative reducer function
---
--- Notes:
---  * table cannot be a sparse table, see [http://www.luafaq.org/gotchas.html#T6.4](http://www.luafaq.org/gotchas.html#T6.4)
---  * The first iteration of the reducer will call fn with the first and second elements of the table. The second iteration will call fn with the result of the first iteration, and the third element. This repeats until there is only one element left
function fnutils.reduce(t, fn)
  local len = #t
  if len == 0 then return nil end
  if len == 1 then return t[1] end

  local result = t[1]
  for i = 2, #t do
    result = fn(result, t[i])
  end
  return result
end

--- hs.fnutils.find(table, fn) -> element
--- Function
--- Execute a function across a table and return the first element where that function returns true
---
--- Parameters:
---  * table - A table containing some sort of data
---  * fn - A function that takes one parameter and returns a boolean value
---
--- Returns:
---  * The element of the supplied table that first caused fn to return true
function fnutils.find(t, fn)
  for _, v in pairs(t) do
    if fn(v) then return v end
  end
  return nil
end

--- hs.fnutils.sequence(...) -> fn
--- Constructor
--- Creates a function that will collect the result of a series of functions into a table
---
--- Parameters:
---  * ... - A number of functions, passed as different arguments. They should accept zero parameters, and return something
---
--- Returns:
---  * A function that, when called, will call all of the functions passed to this constructor. The output of these functions will be collected together and returned.
function fnutils.sequence(...)
  local arg = table.pack(...)
  return function()
    local results = {}
    for _, fn in ipairs(arg) do
      table.insert(results, fn())
    end
    return results
  end
end

--- hs.fnutils.partial(fn, ...) -> fn'
--- Constructor
--- Returns a new function which takes the provided arguments and pre-applies them as the initial arguments to the provided function.  When the new function is later invoked with additional arguments, they are appended to the end of the initial list given and the complete list of arguments is finally passed into the provided function and its result returned.
---
--- Parameters:
---  * fn - The function which will act on all of the arguments provided now and when the result is invoked later.
---  * ... - The initial arguments to pre-apply to the resulting new function.
---
--- Returns:
---  * A function
---
--- Notes:
---  * This is best understood with an example which you can test in the Hammerspoon console:
---
---    Create the function `a` which has it's initial arguments set to `1,2,3`:
---       a = hs.fnutils.partial(function(...) return table.pack(...) end, 1, 2, 3)
---
---    Now some examples of using the new function, `a(...)`:
---       hs.inspect(a("a","b","c")) will return: { 1, 2, 3, "a", "b", "c", n = 6 }
---       hs.inspect(a(4,5,6,7))     will return: { 1, 2, 3, 4, 5, 6, 7, n = 7 }
---       hs.inspect(a(1))           will return: { 1, 2, 3, 1, n = 4 }
function fnutils.partial(fn, ...)
  local args = table.pack(...)
  return function(...)
    for idx = args.n+1,#args do args[idx] = nil end -- clear previous values
    for idx, val in ipairs(table.pack(...)) do
      args[args.n + idx] = val
    end
    return fn(table.unpack(args))
  end
end

--- hs.fnutils.cycle(table) -> fn()
--- Constructor
--- Creates a function that repeatedly iterates a table
---
--- Parameters:
---  * table - A table containing some sort of data
---
--- Returns:
---  * A function that, when called repeatedly, will return all of the elements of the supplied table, repeating indefinitely
---
--- Notes:
---  * table cannot be a sparse table, see [http://www.luafaq.org/gotchas.html#T6.4](http://www.luafaq.org/gotchas.html#T6.4)
---  * An example usage:
---     ```lua
---     f = cycle({4, 5, 6})
---     {f(), f(), f(), f(), f(), f(), f()} == {4, 5, 6, 4, 5, 6, 4}
---     ```
function fnutils.cycle(t)
  local i = 1
  return function()
    local x = t[i]
    i = i % #t + 1
    return x
  end
end

--- hs.fnutils.every(table, fn) -> bool
--- Function
--- Returns true if the application of fn on every entry in table is true.
---
--- Parameters:
---  * table - A table containing some sort of data
---  * fn - A function that accepts a single parameter and returns a "true" value (any value except the boolean `false` or nil) if the parameter was accepted, or a "false" value (the boolean false or nil) if the parameter was rejected.
---
--- Returns:
---  * True if the application of fn on every element of the table is true
---  * False if the function returns `false` for any element of the table.  Note that testing stops when the first false return is detected.
function fnutils.every(table, fn)
  for k, v in pairs(table) do
    if not fn(v, k) then return false end
  end
  return true
end

--- hs.fnutils.some(table, fn) -> bool
--- Function
--- Returns true if the application of fn on entries in table are true for at least one of the members.
---
--- Parameters:
---  * table - A table containing some sort of data
---  * fn - A function that accepts a single parameter and returns a "true" value (any value except the boolean `false` or nil) if the parameter was accepted, or a "false" value (the boolean false or nil) if the parameter was rejected.
---
--- Returns:
---  * True if the application of fn on any element of the table is true.  Note that testing stops when the first true return is detected.
---  * False if the function returns `false` for all elements of the table.
function fnutils.some(table, fn)
  local function is_invalid(v, k)
    return not fn(v, k)
  end
  return not fnutils.every(table, is_invalid)
end

--- hs.fnutils.sortByKeys(table[ , function]) -> function
--- Constructor
--- Iterator for retrieving elements from a table of key-value pairs in the order of the keys.
---
--- Parameters:
---  * table - the table of key-value pairs to be iterated through
---  * fn - an optional function which will be passed to `table.sort` to determine how the keys are sorted.  If it is not present, then keys will be sorted numerically/alphabetically.
---
--- Returns:
---  * function to be used as an iterator
---
--- Notes:
---  * Similar to Perl's `sort(keys %hash)`
---  * Iterators are used in looping constructs like `for`:
---    * `for i,v in hs.fnutils.sortByKeys(t[, f]) do ... end`
---  * A sort function should accept two arguments and return true if the first argument should appear before the second, or false otherwise.
---    * e.g. `function(m,n) return not (m < n) end` would result in reverse alphabetic order.
---    * See _Programming_In_Lua,_3rd_ed_, page 52 for a more complete discussion.
---    * The default sort is to compare keys directly, if they are of the same type, or as their tostring() versions, if the key types differ:
---      * function(m,n) if type(m) ~= type(n) then return tostring(m) < tostring(n) else return m < n end
fnutils.sortByKeys = function(t, f)
  -- a default, simple comparison that treats keys as strings only if their types differ
  f = f or function(m,n) if type(m) ~= type(n) then return tostring(m) < tostring(n) else return m < n end end
  if t then
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
      i = i + 1
      if a[i] == nil then return nil
      else return a[i], t[a[i]]
      end
    end
    return iter
  else
    return function() return nil end
  end
end

--- hs.fnutils.sortByKeyValues(table[ , function]) -> function
--- Constructor
--- Iterator for retrieving elements from a table of key-value pairs in the order of the values.
---
--- Parameters:
---  * table - the table of key-value pairs to be iterated through
---  * fn - an optional function which will be passed to `table.sort` to determine how the values are sorted.  If it is not present, then values will be sorted numerically/alphabetically.
---
--- Returns:
---  * function to be used as an iterator
---
--- Notes:
---  * Similar to Perl's `sort { $hash{$a} <=> $hash{$b} } keys %hash`
---  * Iterators are used in looping constructs like `for`:
---    * `for i,v in hs.fnutils.sortByKeyValues(t[, f]) do ... end`
---  * A sort function should accept two arguments and return true if the first argument should appear before the second, or false otherwise.
---    * e.g. `function(m,n) return not (m < n) end` would result in reverse alphabetic order.
---    * See _Programming_In_Lua,_3rd_ed_, page 52 for a more complete discussion.
---    * The default sort is to compare values directly, if they are of the same type, or as their tostring() versions, if the value types differ:
---      * function(m,n) if type(m) ~= type(n) then return tostring(m) < tostring(n) else return m < n end
fnutils.sortByKeyValues = function(t, f)
  -- a default, simple comparison that treats keys as strings only if their types differ
  f = f or function(m,n) if type(m) ~= type(n) then return tostring(m) < tostring(n) else return m < n end end
  if t then
    local a = {}
    for n in pairs(t) do table.insert(a, {n, t[n]}) end
    table.sort(a, function(m,n) return f(m[2], n[2]) end)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
      i = i + 1
      if a[i] == nil then return nil
      else return a[i][1], a[i][2]
      end
    end
    return iter
  else
    return function() return nil end
  end
end

--- hs.fnutils.split(sString, sSeparator [, nMax] [, bPlain]) -> { array }
--- Function
--- Convert string to an array of strings, breaking at the specified separator.
---
--- Parameters:
---  * sString    -- the string to split into substrings
---  * sSeparator -- the separator.  If `bPlain` is false or not provided, this is treated as a Lua pattern.
---  * nMax       -- optional parameter specifying the maximum number (or all if `nMax` is nil) of substrings to split from `sString`.
---  * bPlain     -- optional boolean parameter, defaulting to false, specifying if `sSeparator` should be treated as plain text (true) or a Lua pattern (false)
---
--- Returns:
---  * An array of substrings.  The last element of the array will be the remaining portion of `sString` that remains after `nMax` (or all, if `nMax` is not provided or is nil) substrings have been identified.
---
--- Notes:
---  * Similar to "split" in Perl or "string.split" in Python.
---  * Optional parameters `nMax` and `bPlain` are identified by their type -- if parameter 3 or 4 is a number or nil, it will be considered a value for `nMax`; if parameter 3 or 4 is a boolean value, it will be considered a value for `bPlain`.
---  * Lua patterns are more flexible for pattern matching, but can also be slower if the split point is simple. See §6.4.1 of the _Lua_Reference_Manual_ at http://www.lua.org/manual/5.3/manual.html#6.4.1 for more information on Lua patterns.
function fnutils.split(sString, sSeparator, nMax, bPlain)
  if type(nMax) == "boolean" then
    nMax, bPlain = bPlain, nMax
  end

  sSeparator = sSeparator or ""

  if type(sString) ~= "string" then
    error("sString parameter to hs.fnutils.split must be a string", 2) end
  if type(sSeparator) ~= "string" then
    error("sSeparator parameter to hs.fnutils.split must be a string", 2) end
  if type(nMax) ~= "number" and type(nMax) ~= "nil" then
    error("nMax parameter to hs.fnutils.split must be a number, if it is provided", 2) end
  if type(bPlain) ~= "boolean" and type(bPlain) ~= "nil" then
    error("bPlain parameter to hs.fnutils.split must be a boolean, if it is provided", 2) end

  if sSeparator == "" or nMax == 0 then return { sString } end -- degenerate cases

  local aRecord = {}

  if sString:len() > 0 then
    nMax = nMax or -1

    local nField, nStart = 1, 1
    local nFirst,nLast = sString:find(sSeparator, nStart, bPlain)
    while nFirst and nMax ~= 0 do
      aRecord[nField] = sString:sub(nStart, nFirst-1)
      nField = nField+1
      nStart = nLast+1
      nFirst,nLast = sString:find(sSeparator, nStart, bPlain)
      nMax = nMax-1
    end
    aRecord[nField] = sString:sub(nStart)
  end

  return aRecord
end

return fnutils
