--- === hs.fnutils ===
---
--- Functional programming utility functions

local fnutils = {}


--- hs.fnutils.map(table, fn) -> table
--- Function
--- Execute a function across a table and collect the results
---
--- Parameters:
---  * table - A table containing some sort of data
---  * fn - A function that accepts a single parameter. Whatever this function returns, will be collected and returned
---
--- Returns:
---  * A table containing the results of calling the function on every element in the table
function fnutils.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    table.insert(nt, fn(v) or nil)
  end
  return nt
end

--- hs.fnutils.each(table, fn)
--- Function
--- Execute a function across a table and discard the results
---
--- Parameters:
---  * table - A table containing some sort of data
---  * fn - A function taht accepts a single parameter
---
--- Returns:
---  * None
function fnutils.each(t, fn)
  for k, v in pairs(t) do
    fn(v)
  end
end

--- hs.fnutils.filter(table, fn) -> table
--- Function
--- Filter a table using a function
---
--- Parameters:
---  * table - A table containing some sort of data
---  * fn - A function that accepts a single parameter and returns a boolean value, true if the parameter should be kept, false if it should be discarded
---
--- Returns:
---  * A table containing the elements of the table for which fn(element) returns true
function fnutils.filter(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    if fn(v) then table.insert(nt, v) end
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
  for k, v in pairs(t) do
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
  for k, v in pairs(t) do
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
--- Returns fn partially applied to arg (...)
---
--- Parameters:
---  * fn - A function
---  * ... - A number of things
---
--- Returns:
---  * A function
---
--- Notes:
---  * The documentation for this function is currently insufficient. Please submit an improvement if you can!
function fnutils.partial(fn, ...)
  local args = table.pack(...)
  return function(...)
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

return fnutils
