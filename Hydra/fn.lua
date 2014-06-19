hydra.fn = {}

function hydra.fn.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    table.insert(nt, fn(v))
  end
  return nt
end

function hydra.fn.filter(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    if fn(v) then table.insert(nt, v) end
  end
  return nt
end

function hydra.fn.contains(t, el)
  for k, v in pairs(t) do
    if v == el then
      return true
    end
  end
  return false
end

function hydra.fn.indexof(t, el)
  for k, v in pairs(t) do
    if v == el then
      return k
    end
  end
  return nil
end

function hydra.fn.concat(t1, t2)
  -- NOTE: mutates t1!
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

function hydra.fn.mapcat(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    hydra.fn.concat(nt, fn(v))
  end
  return nt
end

function hydra.fn.reduce(t, fn)
  local len = #t
  if len == 0 then return nil end
  if len == 1 then return t[1] end

  local result = t[1]
  for i = 2, #t do
    result = fn(result, t[i])
  end
  return result
end
