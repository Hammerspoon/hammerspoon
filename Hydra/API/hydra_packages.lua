--- === hydra.packages ===
---
--- Package management for third party Hydra libraries.
---
--- Put `hydra.packages.setup()` at the top of your initfile; it does nothing if it's already been setup.
---
--- See `hydra.packages.list` and `hydra.packages.install` to get started.

hydra.packages = {}

local function readpackages()
  local f = io.open(os.getenv('HOME')..'/.hydra-ext/packages.json')
  local contents = f:read("*a")
  f:close()
  return json.decode(contents)
end

--- hydra.packages.setup()
--- Clones https://github.com/sdegutis/hydra-ext into ~/.hydra-ext if it's not already there.
function hydra.packages.setup()
  os.execute('git clone https://github.com/sdegutis/hydra-ext.git ~/.hydra-ext')
end

function hydra.packages.update()
  os.execute('cd ~/.hydra-ext && git pull')
end

--- hydra.packages.list()
--- Lists available and installed packages.
function hydra.packages.list()
  return readpackages()
end

--- hydra.packages.listinstalled()
--- Lists only installed packages.
function hydra.packages.listinstalled()
  -- TODO
end

--- hydra.packages.install(name[, version])
--- Installs the given package.
--- If version is omitted, defaults to the latest version.
--- Changes take effect immediately, so that you may use `require "packagename"` without restarting Hydra.
--- Multiple versions cannot be installed simultaneously; if another version of the same package is installed, this implies uninstalling it.
function hydra.packages.install(name, version)
  local matches = fnutils.filter(readpackages(), function(pkg) return pkg.name == name end)
  table.sort(matches, function(a, b) return a.version < b.version end)

  if version then
    matches = fnutils.filter(matches, function(pkg) return pkg.version == version end)
  end

  if #matches == 0 then
    print "No matching packages found"
    return
  end

  local match = matches[#matches]

  print(string.format("Installing:", inspect(match)))

  -- TODO
end
