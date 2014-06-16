local fp = {}

function fp.map(t, fn)
  local nt = {}
  for k, v in pairs(t) do
    table.insert(nt, fn(v))
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

return fp
