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

--- hydra.docsfile() -> string
--- Returns the path of a JSON file containing the docs, for you to generate pretty docs with. The top-level is a list of groups. Groups have keys: name (string), doc (string), items (list of items); Items have keys: name (string), def (string), doc (string).
function hydra.docsfile()
  return hydra.resourcesdir .. '/docs.json'
end

function hydra._initiate_documentation_system()
  local docsfile = hydra.docsfile()

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
