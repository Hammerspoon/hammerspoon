local fp = {}

function fp.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    table.insert(nt, fn(v))
  end
  return nt
end

function fp.filter(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    if fn(v) then table.insert(nt, v) end
  end
  return nt
end

function fp.contains(t, el)
  for k, v in pairs(t) do
    if v == el then
      return true
    end
  end
  return false
end

function fp.indexof(t, el)
  for k, v in pairs(t) do
    if v == el then
      return k
    end
  end
  return nil
end

return fp
