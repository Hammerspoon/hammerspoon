--- === hs.func ===
---
--- Some functional programming constructs for collections in Lua tables
---
--- You can call the methods in this module as functions on "plain" tables, via the syntax
--- `new_table=hs.func.filter(hs.func.map(my_table, map_fn),filter_fn)`.
--- Alternatively, you can use the `collection` constructor and then call methods directly on the table, like this:
--- `new_table=hs.func.collection(my_table):map(map_fn):filter(filter_fn)`.
--- All tables or lists returned by hs.func methods, unless otherwise noted, will accept further hs.func methods.
---
--- The methods in this module can be used on these types of collections:
---   - *lists*: ordered collections (also known as linear arrays) where the (non-unique) elements are stored as *values* for sequential integer keys starting from 1
---   - *sets*: unordered sets where the (unique) elements are stored as *keys* whose value is the boolean `true` (or another constant)
---   - *maps*: associative tables (also known as dictionaries) where both keys and their values are arbitrary; they can have a list part as well
---   - *trees*, tables with multiple levels of nesting

local getmetatable,setmetatable=getmetatable,setmetatable
local pairs,ipairs,next,type=pairs,ipairs,next,type
local tpack,tunpack=table.pack,table.unpack

local f={} -- module/class

--- hs.func.collection([table]) -> collection
--- Constructor
--- Makes a collection in a Lua table functional programming friendly
---
--- Parameters:
---  * table - (optional) a Lua table holding a collection of elements, if omitted a new empty table will be created
---
--- Returns:
---  * the table, that will now accept the `hs.func` methods
---
--- Notes:
---  * you can also use the shortcut `hs.func(my_table)`
---  * if the table already has a metatable, the metatable for hs.func will be appended at the end of the `__index` chain, to ensure
---    that hs.func methods don't shadow your table object methods
---  * for the same reason, if you need to set the metatable to an already existing hs.func table, you can use
---    the `hs.func:setmetatable()` method, it will *insert* the new metatable at the top of the chain
f._isFuncTable = true
local function new(t)
  if not t then t={} end
  local mt,nt=t,t
  while mt do
    if mt._isFuncTable then return t end
    nt,mt=mt,getmetatable(mt)
  end
  setmetatable(nt,{__index=f}) -- at the end of the metatable chain
  return t
end
f.collection=new


--- hs.func:flatten() -> list
--- Method
--- Creates a list from a map or from a list with holes
---
--- Parameters:
---  * None
---
--- Returns:
---  * a list containing the all the *values* in this collection in arbitrary order (you can sort it afterward if necessary);
---   the keys are assumed to be uninteresting and discarded
---
--- Notes:
---  * you can use this method to remove "holes" from lists; however the result list isn't guaranteed to be
---    in order
function f.flatten(t)
  local nt=new()
  for _,v in pairs(t) do nt[#nt+1]=v end
  return nt
end

--- hs.func:toList() -> list
--- Method
--- Creates a list from a set (i.e. from the keys of a table)
---
--- Parameters:
---  * None
---
--- Returns:
---  * a list containing the all the *keys* in this table in arbitrary order (you can sort it afterward if necessary);
---    the values are assumed to be uninteresting and discarded
function f.toList(t)
  local nt=new()
  for k in pairs(t) do nt[#nt+1]=k end
  return nt
end

--- hs.func:toSet([value]) -> set
--- Method
--- Creates a set from a list
---
--- Parameters:
---  * value - the constant value to assign to every key in the result table; if omitted, defaults to `true`
---
--- Returns:
---  * a table whose keys are all the (unique) elements from this list
---
--- Notes:
---  * any duplicates among the elements in this list will be discarded, as the keys in a Lua table are unique
function f.toSet(t,c)
  if c==nil then c=true end
  local nt=new()
  for _,v in ipairs(t) do nt[v]=c end
  return nt
end

--- hs.func:imap(fn) -> list
--- Method
--- Executes a function across a list in order, and collects the results
---
--- Parameters:
---  * fn - a function that accepts two parameters, a list element and its index, and returns a value.
---    The values returned from this function will be collected, in order, into the result list; when `nil` is
---    returned the relevant element is discarded - the result list will *not* have "holes".
---
--- Returns:
---  * a list containing the results of calling the function on every element in this list
---
--- Notes:
---  * if this table has "holes", all elements after the first hole will be lost, as the table is iterated over with `ipairs`;
---    you can use `hs.func:map()` if necessary.
function f.imap(t,fn)
  local nt=new()
  for k,v in ipairs(t) do nt[#nt+1]=fn(v,k) end
  return nt
end

--- hs.func:map(fn) -> map
--- Method
--- Executes a function across a map (in arbitrary order) and collects the results
---
--- Parameters:
---  * fn - a function that accepts two parameters, a map value and its key, and returns
---    a new value for the element and, optionally, a new key. The key/value pair returned from
---    this function will be added to the result map.
---
--- Returns:
---  * a map containing the results of calling the function on every element in this map
---
--- Notes:
---  * you must use `hs.func:imap()` if this table is a list (without holes) and you need guaranteed in-order
---  processing
---  * if `fn` doesn't return keys, the transformed values returned by it will be assigned to the respective original keys
---  * if `fn` does returns keys, and they are not unique, the previous element with the same key will be overwritten;
---    keep in mind that the iteration order, and therefore which value will ultimately be associated to a
---    conflicted key, is arbitrary
---  * if `fn` returns `nil`, the respective key in the result map won't have any associated element
function f.map(t,fn)
  local nt=new()
  for k,v in pairs(t) do
    local nv,nk=fn(v,k)
    nt[nk~=nil and nk or k]=nv
  end
  return nt
end

--- hs.func:ieach(fn)
--- Method
--- Executes a function with side effects across a list in order, discarding any results
---
--- Parameters:
---  * fn - a function that accepts two parameters, a list element and its index
---
--- Returns:
---  * None
function f.ieach(t,fn)
  for k,v in ipairs(t) do fn(v,k) end
end

--- hs.func:each(fn)
--- Method
--- Executes a function with side effects across a map, in arbitrary order, discarding any results
---
--- Parameters:
---  * fn - a function that accepts two parameters, a map value and its key
---
--- Returns:
---  * None
function f.each(t,fn)
  for k,v in pairs(t) do fn(v,k) end
end

--- hs.func:ipairs(fn)
--- Method
--- Executes a function with side effects across a list in order, discarding any results
---
--- Parameters:
---  * fn - a function that accepts two parameters, a list index and its associated value
---
--- Returns:
---  * None
---
--- Notes:
---  * this method is like `hs.func:ieach`, but `fn` is passed `key,value` instead of `value,key` to mirror
---    the Lua global `ipairs`
function f.ipairs(t,fn)
  for k,v in ipairs(t) do fn(k,v) end
end
--- hs.func:pairs(fn)
--- Method
--- Executes a function with side effects across a map, in arbitrary order, discarding any results
---
--- Parameters:
---  * fn - a function that accepts two parameters, a map key and its associated value
---
--- Returns:
---  * None
---
--- Notes:
---  * this method is like `hs.func:each`, but `fn` is passed `key,value` instead of `value,key` to mirror
---    the Lua global `pairs`
function f.pairs(t,fn)
  for k,v in pairs(t) do fn(k,v) end
end

--- hs.func:ifilter(fn) -> list
--- Method
--- Filters a list by running a predicate function on its elements in order
---
--- Parameters:
---  * fn - a function that accepts two parameters, a list element and its index, and returns a boolean
---    value: `true` if the element should be kept, `false` if it should be discarded
---
--- Returns:
---  * a list containing the elements for which `fn(element,index)` returns true
function f.ifilter(t,fn)
  local nt=new()
  for k,v in ipairs(t) do if fn(v,k) then nt[#nt+1]=v end end
  return nt
end

--- hs.func:filter(fn) -> map
--- Method
--- Filters a map by running a predicate function on its elements, in arbitrary order
---
--- Parameters:
---  * fn - a function that accepts two parameters, a map value and its key, and returns a boolean
---    value: `true` if the element should be kept, `false` if it should be discarded
---
--- Returns:
---  * a map containing the elements for which `fn(value,key)` returns true
function f.filter(t,fn)
  local nt=new()
  for k,v in pairs(t) do if fn(v,k) then nt[k]=v end end
  return nt
end

--- hs.func:copy([maxDepth]) -> collection
--- Method
--- Returns a copy of the collection
---
--- Parameters:
---  * maxDepth - (optional) on a tree, create a copy of every node until this nesting level is reached; if omitted, defaults
---    to 1; if 0, returns the input table (no copy will be performed)
---
--- Returns:
---  * a new collection containing the same data as this collection
---
--- Notes:
---  * this function does *not* handle cycles; use the `maxDepth` parameter with care
local function copy(t,l)
  l=l or 1
  if l<=0 then return t end
  local nt=new()
  for k,v in pairs(t) do nt[k]=type(v)=='table' and copy(v,l-1) or v end
  return nt
end
f.copy=copy

--- hs.func:contains(element[, maxDepth]) -> boolean, depth
--- Method
--- Determines if a list, map or tree contains a given object
---
--- Parameters:
---  * element - a value or object to search the collection for
---  * maxDepth - (optional) on a tree, look for the element until this nesting level is reached; if omitted, defaults
---    to 1
---
--- Returns:
---  * if the element could be found in the collection, `true, depth`, where depth is the nesting level
---    where the element was found; otherwise `false`
---
--- Notes:
---  * this function does *not* handle cycles; use the `maxDepth` parameter with care
---  * when maxDepth>1, the tree is traversed depth-first
local function contains(t,el,l)
  if l<=0 then return t==el,0 end
  for _,v in pairs(t) do
    if v==el then return true,l
    elseif type(v)=='table' then
      if contains(v,el,l-1) then return true,l-1 end
    end
  end
  return false
end
function f.contains(t,el,l)
  l=l or 1
  local maxDepth,res=l
  res,l=contains(t,el,l)
  return res,res and maxDepth-l+1 or nil
end

--- hs.func:key(element) -> key
--- Method
--- Finds the key of a given element in a map
---
--- Parameters:
---  * element - an object or value to search the table for
---
--- Returns:
---  * the first key in the map (in arbitrary order) whose associated value is `element`; `nil` if the element is not found
---
--- Notes:
---  * The table is traversed via `pairs` in arbitrary order; if `element` is associated to multiple keys
---    in the table, the first key found will be returned; subsequent calls to this method from the same
---    table *might* return a different key.
function f.key(t,el)
  for k,v in pairs(t) do if v==el then return k end end
end

--- hs.func:index(element) -> integer
--- Method
--- Finds the index of a given element in a list
---
--- Parameters:
---  * element - an object or value to search the list for
---
--- Returns:
---  * a positive integer, the index of the first occurence of `element` in the list; `nil` if the element is not found
---
--- Notes:
---  * The table is traversed via `ipairs` in order; if `element` is associated to multiple indices
---    in the list, this funciton will always return the lowest one.
function f.index(t,el)
  for k,v in ipairs(t) do if v==el then return k end end
end

--- hs.func:concat(otherList[, inPlace]) -> list
--- Method
--- Concatenates two lists into one
---
--- Parameters:
---  * otherList - a list
---  * inPlace - (optional) if `true`, this list will be modified in-place, appending all the elements from `otherList`,
---    and returned; otherwise a new list will be created and returned
---
--- Returns:
---  * a list with all the elements from this list followed by all the elements from `otherList`
function f.concat(t1,t2,pl)
  local nt=new(pl and t1 or {})
  if not pl then for _,v in ipairs(t1) do nt[#nt+1]=v end end
  for _,v in ipairs(t2) do nt[#nt+1]=v end
  return nt
end

--- hs.func:merge(otherMap[, inPlace]) -> map
--- Method
--- Merges elements from two maps into one
---
--- Parameters:
---  * otherMap - a map
---  * inPlace - (optional) if `true`, this map will be modified in-place, merging all the elements from `otherMap`,
---    and returned; otherwise a new map will be created and returned
---
--- Returns:
---  * a map containing both the key/value pairs in this map and those in `otherMap`
---
--- Notes:
---  * if `otherMap` has keys that are also present in this map, the corresponding key/value pairs from this map
---    will be *overwritten* in the result map; *this is also true for the list parts of the tables*, if present
function f.merge(t1,t2, pl)
  local nt=new(pl and t1 or {})
  if not pl then for k,v in pairs(t1) do nt[k]=v end end
  for k,v in pairs(t2) do nt[k]=v end
  return nt
end

--- hs.func:mapcat(fn) -> list
--- Method
--- Executes, in order across a list, a function that returns lists, and concatenates all of those lists together
---
--- Parameters:
---  * fn - a function that accepts two parameters, a list element and its index, and returns a list
---
--- Returns:
---  * a list containing the concatenated results of calling `fn(element,index)` for every element in this list
function f.mapcat(t,fn)
  local nt=new()
  for k,v in ipairs(t) do f.concat(nt,fn(v,k),true) end
  return nt
end

--- hs.func:mapmerge(fn) -> map
--- Method
--- Executes, in arbitrary order across a map, a function that returns maps, and merges all of those maps together
---
--- Parameters:
---  * fn - a function that accepts two parameters, a map value and its key, and returns a map
---
--- Returns:
---  * a map containing the merged results of calling `fn(value,key)` for every element in this map
---
--- Notes:
---  * exercise caution if the tables returned by `fn` can contain the same keys: see the caveat in `hs.func:merge()`
function f.mapmerge(t,fn)
  local nt=new()
  for k,v in pairs(t) do f.merge(nt,fn(v,k),true) end
  return nt
end

--- hs.func:ireduce(fn[, initialValue,...]) -> value,...
--- Method
--- Reduces a list to a value (or tuple), using a function
---
--- Parameters:
---  * fn - A function that takes three or more parameters:
---    - the result(s) emitted from the previous iteration, or `initialValue`(s) for the first iteration
---    - an element from this list, iterating in order
---    - the element index
---  * initialValue - (optional) the value(s) to pass to `fn` for the first iteration; if omitted, `fn` will
---    be passed `elem1,elem2,2` (then `result,elem3,3` on the second iteration, and so on)
---
--- Returns:
---  * the result emitted by `fn` after the last iteration
---
--- Notes:
---  * `fn` can simply return one of the two elements passed (e.g. a "max" function) or calculate a wholly new
---    value from them (e.g. a "sum" function)
function f.ireduce(t,fn,...)
  local r,i=tpack(...),1
  if r.n==0 then i,r=2,{t[1]} end
  for k=i,#t do r=tpack(fn(tunpack(r),t[k],k)) end
  return tunpack(r)
end

--- hs.func:reduce(fn[, initialValue,...]) -> value,...
--- Method
--- Reduces a map to a value (or tuple), using a function
---
--- Parameters:
---  * fn - a function that takes three or more parameters:
---    - the result(s) emitted from the previous iteration, or `initialValue`(s) for the first iteration
---    - an element value from this map, in arbitrary order
---    - the element key
---  * initialValue - (optional) the value(s) to pass to `fn` for the first iteration; if omitted, `fn` will
---    be passed `value1,value2,key2` (then `result,value3,value3` on the second iteration, and so on)
---
--- Returns:
---  * the result(s) emitted by `fn` after the last iteration
---
--- Notes:
---  * `fn` can simply return one of the two values passed (e.g. a custom "max" function) or calculate a wholly new
---    value from them (e.g. a custom "sum" function)
function f.reduce(t,fn,...)
  local r,k,v=tpack(...)
  if r.n==0 then k,r=next(t,k) r={r} end
  k,v=next(t,k)
  while k~=nil do r=tpack(fn(tunpack(r),v,k)) k,v=next(t,k) end
  return tunpack(r)
end

--- hs.func:ifind(fn) -> element, index
--- Method
--- Execute a predicate function across a list, in order, and returns the first element where that function returns true
---
--- Parameters:
---  * fn - a function that accepts two parameters, a list element and its index, and returns a boolean
---
--- Returns:
---  * The first element of this list that caused `fn` to return `true`, amd its index; `nil` if not found
function f.ifind(t,fn)
  for k,v in ipairs(t) do if fn(v,k) then return v,k end end
end

--- hs.func:find(fn) -> value, key
--- Method
--- Executes a predicate function across a map, in arbitrary order, and returns the first element where that function returns true
---
--- Parameters:
---  * fn - a function that accepts two parameters, a map value and its key, and returns a boolean
---
--- Returns:
---  * the value of the first element of this table that caused `fn` to return `true`, and its key; `nil` if not found
function f.find(t,fn)
  for k,v in pairs(t) do if fn(v,k) then return v,k end end
end

return setmetatable(f,{__call=new})

