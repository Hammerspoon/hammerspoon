doc.api.__doc = "The Hydra namespace."

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
  local subitems = {}
  local submodules = {}

  for name, subitem in pairs(group) do
    if isitem(subitem) then table.insert(subitems, subitem[1]) end
  end

  for name, subgroup in pairs(group) do
    if isgroup(subgroup) then table.insert(submodules, name) end
  end

  local str = group.__doc .. "\n\n"

  if # subitems > 0 then
    str = str .. "[subitems]\n" .. table.concat(subitems, "\n") .. "\n\n"
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

local function jsonify_group(groupname, group)
  local subitems = {}
  local subgroups = {}

  for name, thing in pairs(group) do
    if isitem(thing) then
      table.insert(subitems, {name = name, def = thing[1], doc = thing[2]})
    elseif isgroup(thing) then
      table.insert(subgroups, {name = name, group = thing})
    end
  end

  table.sort(subitems, function(a, b) return a.def < b.def end)
  table.sort(subgroups, function(a, b) return a.name < b.name end)

  local str = '{"type": "group", "name": "'..groupname..'", "doc": "'..group.__doc..'", "subitems": ['

  for i, item in pairs(subitems) do
    if i > 1 then str = str .. "," end
    str = str .. '{"type": "item", "name": "'..item.name..'", "def": "'..item.def..'", "doc": "'..item.doc..'"}'
  end

  str = str .. '], "subgroups": ['

  for i, group in pairs(subgroups) do
    if i > 1 then str = str .. "," end
    str = str .. jsonify_group(group.name, group.group)
  end

  str = str .. ']}'
  return str
end

doc.api.jsondocs = {"api.jsondocs() -> string", "Returns the documentation as a JSON string for you to generate pretty docs with. The top-level is a group. Groups have keys: type ('group'), name (string), doc (string), subitems (list of items), subgroups (list of groups); Items have keys: type ('item'), name (string), def (string), doc (string)."}
function api.jsondocs()
  return jsonify_group("doc.api", doc.api)
end

function api._initiate_documentation_system()
  doc = setmetatable(doc, {__tostring = help_string})
  doc.api = hackgroup(doc.api)
end
