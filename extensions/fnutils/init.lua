--- === hs.fnutils ===
---
--- Super-helpful functional programming utilities.

local fnutils = {}


--- hs.fnutils.map(t, fn) -> t
--- Function
--- Returns a table of the results of fn(el) on every el in t.
function fnutils.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    table.insert(nt, fn(v) or nil)
  end
  return nt
end

--- hs.fnutils.each(t, fn) -> t
--- Function
--- Runs fn(el) for every el in t.
function fnutils.each(t, fn)
  for k, v in pairs(t) do
    fn(v)
  end
end

--- hs.fnutils.filter(t, fn) -> t
--- Function
--- Returns a table of the elements in t in which fn(el) is truthy.
function fnutils.filter(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    if fn(v) then table.insert(nt, v) end
  end
  return nt
end

--- hs.fnutils.copy(t) -> t2
--- Function
--- Returns a new copy of t using pairs(t).
function fnutils.copy(t)
  local nt = {}
  for k, v in pairs(t) do
    nt[k] = v
  end
  return nt
end

--- hs.fnutils.contains(t, el) -> bool
--- Function
--- Returns whether the table contains the given element.
function fnutils.contains(t, el)
  for k, v in pairs(t) do
    if v == el then
      return true
    end
  end
  return false
end

--- hs.fnutils.indexOf(t, el) -> int or nil
--- Function
--- Returns the index of a given element in a table, or nil if not found.
function fnutils.indexOf(t, el)
  for k, v in pairs(t) do
    if v == el then
      return k
    end
  end
  return nil
end

--- hs.fnutils.concat(t1, t2)
--- Function
--- Adds all elements of t2 to the end of t1.
function fnutils.concat(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

--- hs.fnutils.mapCat(t, fn) -> t2
--- Function
--- Runs fn(el) for every el in t, and assuming the results are tables, combines them into a new table.
function fnutils.mapCat(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    fnutils.concat(nt, fn(v))
  end
  return nt
end

--- hs.fnutils.reduce(t, fn) -> t2
--- Function
--- Runs fn(el1, el2) for every el in t, then fn(result, el3), etc, until there's only one left.
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

--- hs.fnutils.find(t, fn) -> el
--- Function
--- Returns the first element where fn(el) is truthy.
function fnutils.find(t, fn)
  for _, v in pairs(t) do
    if fn(v) then return v end
  end
  return nil
end

--- hs.fnutils.sequence(...) -> fn
--- Function
--- Returns a list of the results of the passed functions.
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
--- Function
--- Returns fn partially applied to arg (...).
function fnutils.partial(fn, ...)
  local args = table.pack(...)
  return function(...)
    for idx, val in ipairs(table.pack(...)) do
      args[args.n + idx] = val
    end
    return fn(table.unpack(args))
  end
end

--- hs.fnutils.cycle(t) -> fn() -> t[n]
--- Function
--- Returns a function that returns t[1], t[2], ... t[#t], t[1], ... on successive calls.
--- Example:
---     f = cycle({4, 5, 6})
---     {f(), f(), f(), f(), f(), f(), f()} == {4, 5, 6, 4, 5, 6, 4}
function fnutils.cycle(t)
  local i = 1
  return function()
    local x = t[i]
    i = i % #t + 1
    return x
  end
end

return fnutils
