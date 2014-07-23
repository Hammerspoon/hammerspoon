--- === hydra.packages ===
---
--- Package management for third party Hydra libraries.
---
--- Put `hydra.packages.setup()` at the top of your initfile; it does nothing if it's already been setup.
---
--- See `hydra.packages.list` and `hydra.packages.install` to get started.

hydra.packages = {}

--- hydra.packages.cachedirectory -> string
--- Absolute path of packages cache, unquoted; defaults to ~/.hydra-ext
hydra.packages.cachedirectory = os.getenv('HOME')..'/.hydra-ext'

local function readpackages()
  local f = io.open(hydra.packages.cachedirectory..'/packages.json')
  local contents = f:read("*a")
  f:close()
  return json.decode(contents)
end

--- hydra.packages.setup()
--- Clones https://github.com/sdegutis/hydra-ext into hydra.packages.cachedirectory if it's not already there.
function hydra.packages.setup()
  os.execute('git clone https://github.com/sdegutis/hydra-ext.git "' .. hydra.packages.cachedirectory .. '"')
end

function hydra.packages.update()
  os.execute('cd "' .. hydra.packages.cachedirectory .. '" && git pull')
end

--- hydra.packages.list()
--- Lists available and installed packages.
function hydra.packages.list()
  local t = readpackages()
  for k, pkg in ipairs(t) do
    print(pkg.name, pkg.version, pkg.desc)
  end
end

local function findpackage(name, version)
  local matches = fnutils.filter(readpackages(), function(pkg) return pkg.name == name end)
  table.sort(matches, function(a, b) return a.version < b.version end)

  if version then
    matches = fnutils.filter(matches, function(pkg) return pkg.version == version end)
  end

  if #matches == 0 then
    return nil
  elseif #matches > 1 then
    print "oops. somehow we have more than one matching package for this name and version. please report this as a bug."
  end

  return matches[#matches]
end

--- hydra.packages.list(name[, version])
--- Shows information about a given package.
function hydra.packages.info(name)
  local pkg = findpackage(name, version)
  if not pkg then
    print "No matching packages found"
    return
  end

  print(pkg.name)
  print(pkg.version)
  print(pkg.desc)
  print(pkg.license)
  print(pkg.author)
  print(pkg.homepage)
  print(pkg.docspage)
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
  local match = findpackage(name, version)
  if not match then
    print "No matching packages found"
    return
  end

  print(string.format("Installing:", inspect(match)))

  -- TODO
end
