api.fn = {}

doc.api.fn = {__doc = "Super-helpful functional programming utilities."}

doc.api.fn.map = {"api.fn.map(t, fn) -> t", "Returns a table of the results of t(el) on every el in t."}
function api.fn.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    table.insert(nt, fn(v) or nil)
  end
  return nt
end

doc.api.fn.filter = {"api.fn.filter(t, fn) -> t", "Returns a table of the elements in t in which t(el) is truthy."}
function api.fn.filter(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    if fn(v) then table.insert(nt, v) end
  end
  return nt
end

doc.api.fn.contains = {"api.fn.contains(t, el) -> bool", "Returns whether a table contains a given element."}
function api.fn.contains(t, el)
  for k, v in pairs(t) do
    if v == el then
      return true
    end
  end
  return false
end

doc.api.fn.indexof = {"api.fn.indexof(t, el) -> int or nil", "Returns the index of a given element in a table, or nil if not found."}
function api.fn.indexof(t, el)
  for k, v in pairs(t) do
    if v == el then
      return k
    end
  end
  return nil
end

doc.api.fn.concat = {"api.fn.concat(t1, t2)", "Adds all elements of t2 to the end of t1."}
function api.fn.concat(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

doc.api.fn.mapcat = {"api.fn.mapcat(t, fn) -> t2", "Runs fn(el) for every el in t, and assuming the results are tables, combines them into a new table."}
function api.fn.mapcat(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    api.fn.concat(nt, fn(v))
  end
  return nt
end

doc.api.fn.reduce = {"api.fn.reduce(t, fn) -> t2", "Runs fn(el1, el2) for every el in t, then fn(result, el3), etc, until there's only one left."}
function api.fn.reduce(t, fn)
  local len = #t
  if len == 0 then return nil end
  if len == 1 then return t[1] end

  local result = t[1]
  for i = 2, #t do
    result = fn(result, t[i])
  end
  return result
end
