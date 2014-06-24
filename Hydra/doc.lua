local function help_string()
  return
    "print(doc)                     print this help string\n" ..
    "print(doc.api)                 print only group names\n" ..
    "print(doc.api.window)          print window function definitions\n" ..
    "print(doc.api.window.title)    print window.title function doc in full\n"
end

local function item_tostring(item)
  return
    item[1] .. "\n" ..
    item[2] .. "\n"
end

local function isitem(thing)
  return type(thing) == "table" and # thing == 2 and
    type(thing[1]) == "string" and
    type(thing[2]) == "string"
end

local function isgroup(thing)
  return type(thing) == "table" and type(thing.__doc) == "string"
end

local function group_tostring(group)
  local items = {}
  local submodules = {}

  for name, subitem in pairs(group) do
    if isitem(subitem) then table.insert(items, subitem[1]) end
  end

  for name, subgroup in pairs(group) do
    if isgroup(subgroup) then table.insert(submodules, name) end
  end

  local str = ""

  if # items > 0 then
    str = str .. "[items]\n" .. table.concat(items, "\n") .. "\n\n"
  end

  if # submodules > 0 then
    str = str .. "[submodules]\n" .. table.concat(submodules, "\n") .. "\n\n"
  end

  return str
end

local function hackitem(item)
  return setmetatable(item, {__tostring = item_tostring})
end

local function hackgroup(group)
  for name, thing in pairs(group) do
    if isitem(thing) then
      doc[name] = hackitem(thing)
    elseif isgroup(thing) then
      doc[name] = hackgroup(thing)
    end
  end
  return setmetatable(group, {__tostring = group_tostring})
end

function api._initiate_documentation_system()
  doc = setmetatable(doc, {__tostring = help_string})
  doc.api = hackgroup(doc.api)
end

local function sortedtablekeys(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end

function api.generatedocs(path)
  local file = io.open(path, "w")
  for _, groupname in pairs(sortedtablekeys(doc.api)) do
    local group = doc.api[groupname]
    for _, itemname in pairs(sortedtablekeys(group)) do
      local item = group[itemname]
      local def, docstring = item[1], item[2]
      if def and docstring then
        file:write(def .. " -- " .. docstring .. "\n")
      end
    end
    file:write("\n")
  end
  file:close()
end
