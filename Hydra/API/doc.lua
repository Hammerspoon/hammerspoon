help =
  "doc                -- print module names\n" ..
  "doc.window         -- print window subitems\n" ..
  "doc.window.title   -- print window.title function doc in full\n"

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

hydra.jsondocs = {"hydra.jsondocs() -> string", "Returns the documentation as a JSON string for you to generate pretty docs with. The top-level is a list of groups. Groups have keys: name (string), doc (string), items (list of items); Items have keys: name (string), def (string), doc (string)."}
function hydra.jsondocs()
  local groups = {}

  for groupname, group in pairs(doc) do
    local g = {}
    g.name = groupname
    g.doc = group.__doc
    g.items = {}

    for itemname, item in pairs(group) do
      if itemname ~= '__doc' and itemname ~= '__name' then
        local i = {}
        i.name = itemname
        i.def = item[1]
        i.doc = item[2]
        table.insert(g.items, i)
      end
    end
    table.insert(groups, g)
  end

  return json.encode(groups)
end

function hydra._initiate_documentation_system()
  local docsfile = hydra.resourcesdir .. '/docs.json'

  local f = io.open(docsfile)
  local content = f:read("*a")
  f:close()

  local rawdocs = json.decode(content)

  doc = setmetatable({}, {__tostring = doc_tostring})
  for _, mod in pairs(rawdocs) do
    doc[mod.name] = setmetatable({__doc = mod.doc, __name = mod.name}, {__tostring = group_tostring})
    for _, item in pairs(mod.items) do
      doc[mod.name][item.name] = setmetatable({__name = item.name, item.def, item.doc}, {__tostring = item_tostring})
    end
  end
end
