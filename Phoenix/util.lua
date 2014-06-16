local util = {}

function util.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    table.insert(nt, fn(v))
  end
  return nt
end

function util.filter(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    if fn(v) then table.insert(nt, v) end
  end
  return nt
end

function util.contains(t, el)
  for k, v in pairs(t) do
    if v == el then
      return true
    end
  end
  return false
end

function util.indexof(t, el)
  for k, v in pairs(t) do
    if v == el then
      return k
    end
  end
  return nil
end

function util.concat(t1, t2)
  -- NOTE: mutates t1!
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

function util.mapcat(t, fn)
  -- TODO
end

return util
