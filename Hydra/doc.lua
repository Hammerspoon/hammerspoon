local function help_string()
  return
    "print(doc)                 print only group names\n" ..
    "print(doc.window)          print window function definitions\n" ..
    "print(doc.window.title)    print window.title function doc in full\n"
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
  local obj = {}

  obj.name = groupname
  obj.doc = group.__doc
  obj.subitems = {}
  obj.subgroups = {}

  for name, thing in pairs(group) do
    if isitem(thing) then
      table.insert(obj.subitems, {name = name, def = thing[1], doc = thing[2]})
    elseif isgroup(thing) then
      table.insert(obj.subgroups, jsonify_group(name, thing))
    end
  end

  table.sort(obj.subitems, function(a, b) return a.def < b.def end)
  table.sort(obj.subgroups, function(a, b) return a.name < b.name end)

  return obj
end

hydra.jsondocs = {"hydra.jsondocs() -> string", "Returns the documentation as a JSON string for you to generate pretty docs with. The top-level is a group. Groups have keys: name (string), doc (string), subitems (list of items), subgroups (list of groups); Items have keys: name (string), def (string), doc (string)."}
function hydra.jsondocs()
  return json.encode(jsonify_group("doc", doc))
end

function hydra._initiate_documentation_system()
  -- doc = setmetatable(doc, {__tostring = help_string})
  -- doc.api = hackgroup(doc.api)
end
