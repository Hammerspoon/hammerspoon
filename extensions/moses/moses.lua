
local _MODULEVERSION = '1.4.0'

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

local unique_id_counter = -1


function _.each(t, f, ...)
  for index,value in pairs(t) do
    f(index,value,...)
  end
end

function _.eachi(t, f, ...)
  local lkeys = _.sort(_.select(_.keys(t), function(k,v)
    return _.isInteger(v)
  end))
  for k, key in ipairs(lkeys) do
    f(key, t[key],...)
  end
end

function _.at(t, ...)
  local values = {}
  for i, key in ipairs({...}) do
    if _.has(t, key) then values[#values+1] = t[key] end
  end
  return values
end

function _.count(t, value)
  if _.isNil(value) then return _.size(t) end
  local count = 0
  _.each(t, function(k,v)
    if _.isEqual(v, value) then count = count + 1 end
  end)
  return count
end

function _.countf(t, f, ...)
  return _.count(_.map(t, f, ...), true)
end

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

function _.map(t, f, ...)
  local _t = {}
  for index,value in pairs(t) do
    _t[index] = f(index,value,...)
  end
  return _t
end

function _.reduce(t, f, state)
  for __,value in pairs(t) do
    if state == nil then state = value
    else state = f(state,value)
    end
  end
  return state
end

function _.reduceRight(t, f, state)
  return _.reduce(_.reverse(t),f,state)
end

function _.mapReduce(t, f, state)
  local _t = {}
  for i,value in pairs(t) do
    _t[i] = not state and value or f(state,value)
    state = _t[i]
  end
  return _t
end

function _.mapReduceRight(t, f, state)
  return _.mapReduce(_.reverse(t),f,state)
end

function _.include(t,value)
  local _iter = _.isFunction(value) and value or _.isEqual
  for __,v in pairs(t) do
    if _iter(v,value) then return true end
  end
  return false
end

function _.detect(t, value)
  local _iter = _.isFunction(value) and value or _.isEqual
  for key,arg in pairs(t) do
    if _iter(arg,value) then return key end
  end
end

function _.contains(t, value)
  return _.toBoolean(_.detect(t, value))
end

function _.findWhere(t, props)
  local index = _.detect(t, function(v)
    for key in pairs(props) do
      if props[key] ~= v[key] then return false end
    end
    return true
  end)
  return index and t[index]
end

function _.select(t, f, ...)
  local _mapped = _.map(t, f, ...)
  local _t = {}
  for index,value in pairs(_mapped) do
    if value then _t[#_t+1] = t[index] end
  end
  return _t
end

function _.reject(t, f, ...)
  local _mapped = _.map(t,f,...)
  local _t = {}
  for index,value in pairs (_mapped) do
    if not value then _t[#_t+1] = t[index] end
  end
  return _t
end

function _.all(t, f, ...)
  return ((#_.select(_.map(t,f,...), isTrue)) == (#t))
end

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

function _.pluck(t, property)
  return _.reject(_.map(t,function(__,value)
      return value[property]
    end), iNot)
end

function _.max(t, transform, ...)
  return extract(t, f_max, transform, ...)
end

function _.min(t, transform, ...)
  return extract(t, f_min, transform, ...)
end

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

function _.same(a, b)
  return _.all(a, function (i,v) return _.include(b,v) end)
     and _.all(b, function (i,v) return _.include(a,v) end)
end

function _.sort(t, comp)
  t_sort(t, comp)
  return t
end

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

function _.countBy(t, iter, ...)
  local vararg = {...}
  local stats = {}
  _.each(t,function(i,v)
      local key = iter(i,v,unpack(vararg))
      stats[key] = (stats[key] or 0) +1
    end)
  return stats
end

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

function _.containsKeys(t, other)
  for key in pairs(other) do
    if not t[key] then return false end
  end
  return true
end

function _.sameKeys(tA, tB)
  for key in pairs(tA) do
    if not tB[key] then return false end
  end
  for key in pairs(tB) do
    if not tA[key] then return false end
  end
  return true
end



function _.toArray(...) return {...} end

function _.find(array, value, from)
  for i = from or 1, #array do
    if _.isEqual(array[i], value) then return i end
  end
end

function _.reverse(array)
  local _array = {}
  for i = #array,1,-1 do
    _array[#_array+1] = array[i]
  end
  return _array
end

function _.selectWhile(array, f, ...)
  local t = {}
  for i,v in ipairs(array) do
    if f(i,v,...) then t[i] = v else break end
  end
  return t
end

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

function _.sortedIndex(array, value, comp, sort)
  local _comp = comp or f_min
  if sort then _.sort(array,_comp) end
  for i = 1,#array do
    if not _comp(array[i],value) then return i end
  end
  return #array+1
end

function _.indexOf(array, value)
  for k = 1,#array do
    if array[k] == value then return k end
  end
end

function _.lastIndexOf(array, value)
  local key = _.indexOf(_.reverse(array),value)
  if key then return #array-key+1 end
end

function _.addTop(array, ...)
  _.each({...},function(i,v) t_insert(array,1,v) end)
  return array
end

function _.push(array, ...)
  _.each({...}, function(i,v) array[#array+1] = v end)
  return array
end

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

function _.slice(array, start, finish)
  return _.select(array, function(index)
      return (index >= (start or next(array)) and index <= (finish or #array))
    end)
end

function _.first(array, n)
  local n = n or 1
  return _.slice(array,1, min(n,#array))
end

function _.initial(array, n)
  if n and n < 0 then return end
  return _.slice(array,1, n and #array-(min(n,#array)) or #array-1)
end

function _.last(array,n)
  if n and n <= 0 then return end
  return _.slice(array,n and #array-min(n-1,#array-1) or 2,#array)
end

function _.rest(array,index)
  if index and index > #array then return {} end
  return _.slice(array,index and max(1,min(index,#array)) or 1,#array)
end

function _.compact(array)
  return _.reject(array, function (_,value)
    return not value
  end)
end

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

function _.difference(array, array2)
  if not array2 then return _.clone(array) end
  return _.select(array,function(i,value)
      return not _.include(array2,value)
    end)
end

function _.union(...)
  return _.uniq(_.flatten({...}))
end

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

function _.symmetricDifference(array, array2)
  return _.difference(
    _.union(array, array2),
    _.intersection(array,array2)
  )
end

function _.unique(array)
  local ret = {}
  for i = 1, #array do
    if not _.find(ret, array[i]) then
      ret[#ret+1] = array[i]
    end
  end
  return ret
end

function _.isunique(array)
  return _.isEqual(array, _.unique(array))
end

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

function _.append(array, other)
  local t = {}
  for i,v in ipairs(array) do t[i] = v end
  for i,v in ipairs(other) do t[#t+1] = v end
  return t
end

function _.interleave(...) return _.flatten(_.zip(...)) end

function _.interpose(value, array)
  return _.flatten(_.zip(array, _.rep(value, #array-1)))
end

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

function _.rep(value, n)
  local ret = {}
  for i = 1, n do ret[#ret+1] = value end
  return ret
end

function _.partition(array, n)
  return coroutine.wrap(function()
    partgen(array, n or 1, coroutine.yield)
  end)
end

function _.permutation(array)
  return coroutine.wrap(function()
    permgen(array, #array, coroutine.yield)
  end)
end

function _.invert(array)
  local _ret = {}
  _.each(array,function(i,v) _ret[v] = i end)
  return _ret
end

function _.concat(array, sep, i, j)
  local _array = _.map(array,function(i,v)
    return tostring(v)
  end)
  return t_concat(_array,sep,i or 1,j or #array)

end



function _.identity(value) return value end

function _.once(f)
  local _internal = 0
  local _args = {}
  return function(...)
      _internal = _internal+1
      if _internal<=1 then _args = {...} end
      return f(unpack(_args))
    end
end

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

function _.after(f, count)
  local _limit,_internal = count, 0
  return function(...)
      _internal = _internal+1
      if _internal >= _limit then return f(...) end
    end
end

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

function _.pipe(value, ...)
  return _.compose(...)(value)
end

function _.complement(f)
  return function(...) return not f(...) end
end

function _.juxtapose(value, ...)
  local res = {}
  _.each({...}, function(_,f) res[#res+1] = f(value) end)
  return unpack(res)
end

function _.wrap(f, wrapper)
  return function (...) return  wrapper(f,...) end
end

function _.times(n, iter, ...)
  local results = {}
  for i = 1,n do
    results[i] = iter(i,...)
  end
  return results
end

function _.bind(f, v)
  return function (...)
      return f(v,...)
    end
end

function _.bindn(f, ...)
  local iArg = {...}
  return function (...)
      return f(unpack(_.append(iArg,{...})))
    end
end

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


function _.keys(obj)
  local _oKeys = {}
  _.each(obj,function(key) _oKeys[#_oKeys+1]=key end)
  return _oKeys
end

function _.values(obj)
  local _oValues = {}
  _.each(obj,function(_,value) _oValues[#_oValues+1]=value end)
  return _oValues
end

function _.toBoolean(value)
  return not not value
end

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

function _.tap(obj, f, ...)
  f(obj,...)
  return obj
end

function _.has(obj, key)
  return obj[key]~=nil
end

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

function _.template(obj, template)
  _.each(template or {},function(i,v)
  if not obj[i] then obj[i] = v end
  end)
  return obj
end

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

function _.isTable(t)
  return type(t) == 'table'
end

function _.isCallable(obj)
  return (_.isFunction(obj) or
     (_.isTable(obj) and getmetatable(obj)
                   and getmetatable(obj).__call~=nil) or false)
end

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

function _.isIterable(obj)
  return _.toBoolean((pcall(pairs, obj)))
end

function _.isEmpty(obj)
  if _.isNil(obj) then return true end
  if _.isString(obj) then return #obj==0 end
  if _.isTable(obj) then return next(obj)==nil end
  return true
end

function _.isString(obj)
  return type(obj) == 'string'
end

function _.isFunction(obj)
   return type(obj) == 'function'
end

function _.isNil(obj)
  return obj==nil
end

function _.isNumber(obj)
  return type(obj) == 'number'
end

function _.isNaN(obj)
  return _.isNumber(obj) and obj~=obj
end

function _.isFinite(obj)
  if not _.isNumber(obj) then return false end
  return obj > -huge and obj < huge
end

function _.isBoolean(obj)
  return type(obj) == 'boolean'
end

function _.isInteger(obj)
  return _.isNumber(obj) and floor(obj)==obj
end


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

  --- Returns a wrapped object. Calling library functions as methods on this object
  -- will continue to return wrapped objects until @{obj:value} is used. Can be aliased as `_(value)`.
  -- @class function
  -- @name chain
  -- @tparam value value a value to be wrapped
  -- @treturn object a wrapped object
  function __.chain(value)
    return new(value)
  end

  --- Extracts the value of a wrapped object. Must be called on an chained object (see @{chain}).
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

  --- Imports all library functions into a context.
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
