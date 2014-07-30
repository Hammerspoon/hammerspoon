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

  str = str .. "[submodules]\n"
  for name, item in pairs(group) do
    if name ~= '__doc' and name ~= '__name' and getmetatable(item) == getmetatable(group) then
      str = str .. item.__name .. "\n"
    end
  end

  str = str .. "\n" .. "[subitems]\n"
  for name, item in pairs(group) do
    if name ~= '__doc' and name ~= '__name' and getmetatable(item) ~= getmetatable(group) then
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

local group_metatable = {__tostring = group_tostring}
local item_metatable = {__tostring = item_tostring}

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
    local parts = {}
    for s in string.gmatch(mod.name, "%w+") do
      table.insert(parts, s)
    end

    local parent = doc
    local keyname = parts[#parts]
    parts[#parts] = nil

    for _, s in ipairs(parts) do
      parent = parent[s]
    end

    m = setmetatable({__doc = mod.doc, __name = mod.name}, group_metatable)
    parent[keyname] = m

    for _, item in pairs(mod.items) do
      m[item.name] = setmetatable({__name = item.name, item.def, item.doc}, item_metatable)
    end
  end
end
