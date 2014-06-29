help =
  "print(doc)                 print module names\n" ..
  "print(doc.window)          print window subitems\n" ..
  "print(doc.window.title)    print window.title function doc in full\n"

local function item_tostring(item)
  return
    item[1] .. "\n" ..
    item[2] .. "\n"
end

local function group_tostring(group)
  local str = group.__doc .. "\n\n"

  str = str .. "[subitems]\n"
  for name, item in pairs(group) do
    if name ~= '__doc' and name ~= '__name' then
      str = str .. item[1] .. "\n"
    end
  end

  return str .. "\n"
end

local function doc_tostring(doc)
  local str = '[modules]\n'

  for name, group in pairs(doc) do
    str = str .. group.__name .. '\n'
  end

  return str
end

local function hackitem(item)
  return setmetatable(item, {__tostring = item_tostring})
end

local function hackgroup(group)
  for name, item in pairs(group) do
    if name ~= '__doc' then
      group[name] = hackitem(item)
      item.__name = name
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
  for name, t in pairs(doc) do
    doc[name] = hackgroup(t)
    doc[name].__name = name
  end
  doc = setmetatable(doc, {__tostring = doc_tostring})
end
