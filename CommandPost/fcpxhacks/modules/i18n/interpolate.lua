local unpack = unpack or table.unpack -- lua 5.2 compat

-- matches a string of type %{age}
local function interpolateValue(string, variables)
  return string:gsub("(.?)%%{%s*(.-)%s*}",
    function (previous, key)
      if previous == "%" then
        return
      else
        return previous .. tostring(variables [key])
      end
    end)
end

-- matches a string of type %<age>.d
local function interpolateField(string, variables)
  return string:gsub("(.?)%%<%s*(.-)%s*>%.([cdEefgGiouXxsq])",
    function (previous, key, format)
      if previous == "%" then
        return
      else
        return previous .. string.format("%" .. format, variables[key] or "nil")
      end
    end)
end

local function interpolate(pattern, variables)
  variables = variables or {}
  local result = pattern
  result = interpolateValue(result, variables)
  result = interpolateField(result, variables)
  result = string.format(result, unpack(variables))
  return result
end

return interpolate
