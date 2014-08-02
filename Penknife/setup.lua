package.path = os.getenv("HOME") .. "/.penknife/ext/?.lua" .. ';' .. package.path

os.exit = core.exit

-- put this in ObjC maybe?
-- core.pcall(core.reload)

function core.runstring(s)
  local fn, err = load("return " .. s)
  if not fn then fn, err = load(s) end
  if not fn then return tostring(err) end

  local str = ""
  local results = table.pack(pcall(fn))
  for i = 2,results.n do
    if i > 2 then str = str .. "\t" end
    str = str .. tostring(results[i])
  end
  return str
end
