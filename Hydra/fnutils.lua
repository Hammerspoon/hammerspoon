fnutils = {}

doc.fnutils = {__doc = "Super-helpful functional programming utilities."}

doc.fnutils.map = {"fnutils.map(t, fn) -> t", "Returns a table of the results of fn(el) on every el in t."}
function fnutils.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    table.insert(nt, fn(v) or nil)
  end
  return nt
end

doc.fnutils.each = {"fnutils.each(t, fn) -> t", "Runs fn(el) for every el in t."}
function fnutils.each(t, fn)
  for k, v in pairs(t) do
    fn(v)
  end
end

doc.fnutils.filter = {"fnutils.filter(t, fn) -> t", "Returns a table of the elements in t in which fn(el) is truthy."}
function fnutils.filter(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    if fn(v) then table.insert(nt, v) end
  end
  return nt
end

doc.fnutils.contains = {"fnutils.contains(t, el) -> bool", "Returns whether the table contains the given element."}
function fnutils.contains(t, el)
  for k, v in pairs(t) do
    if v == el then
      return true
    end
  end
  return false
end

doc.fnutils.indexof = {"fnutils.indexof(t, el) -> int or nil", "Returns the index of a given element in a table, or nil if not found."}
function fnutils.indexof(t, el)
  for k, v in pairs(t) do
    if v == el then
      return k
    end
  end
  return nil
end

doc.fnutils.concat = {"fnutils.concat(t1, t2)", "Adds all elements of t2 to the end of t1."}
function fnutils.concat(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

doc.fnutils.mapcat = {"fnutils.mapcat(t, fn) -> t2", "Runs fn(el) for every el in t, and assuming the results are tables, combines them into a new table."}
function fnutils.mapcat(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    fnutils.concat(nt, fn(v))
  end
  return nt
end

doc.fnutils.reduce = {"fnutils.reduce(t, fn) -> t2", "Runs fn(el1, el2) for every el in t, then fn(result, el3), etc, until there's only one left."}
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

doc.fnutils.find = {"fnutils.find(t, fn) -> el", "Returns the first element where fn(el) is truthy."}
function fnutils.find(t, fn)
  for _, v in pairs(t) do
    if fn(v) then return v end
  end
  return nil
end
