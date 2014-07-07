--- pprint
---
--- Simple table printing module. pprint itself is callable on tables to pretty-print them.

pprint = {}


function fmt_val(val)
  if type(val) == type('') then
    return "'" .. val .. "'"
  else
    return val
  end
end

function drop_trailing(s)
  return string.sub(s, 1, -3)
end

--- pprint.pairs(tbl)
--- Pretty-prints the table.
function pprint.pairs(tbl)
  res= '{'
  for key, val in pairs(tbl) do
    res = res .. key .. '=' ..  fmt_val(val) .. ', '
  end
  return drop_trailing(res) .. '}'
end

--- pprint.ipairs(tbl)
--- Pretty-prints the table as an array.
function pprint.ipairs(tbl)
  local res = '['
  for _, val in ipairs(tbl) do
    res = res .. fmt_val(val) .. ', '
  end
  return drop_trailing(res) .. ']'
end

--- pprint.keys(tbl)
--- Pretty-prints comma-separated list of keys.
function pprint.keys(tbl)
  local res = ''
  for key, _ in pairs(tbl) do
    res = res .. key .. ', '
  end
  return drop_trailing(res)
end

--- pprint.values(tbl)
--- Pretty-prints comma-separated list of values.
function pprint.values(tbl)
  local res = ''
  for _, val in pairs(tbl) do
    res = res .. fmt_val(val) .. ', '
  end
  return drop_trailing(res)
end

function _pprint(_, tbl)
  print(pprint.pairs(tbl))
end

setmetatable(pprint, {__call = _pprint})
