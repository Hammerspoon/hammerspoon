local modpath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...

print("-- Augmenting require paths")

package.path=configdir.."/?.lua"..";"..configdir.."/?/init.lua"..";"..modpath.."/?.lua"..";"..modpath.."/?/init.lua"
package.cpath=configdir.."/?.so"..";"..modpath.."/?.so"

print("-- package.path:")
for part in string.gmatch(package.path, "([^;]+)") do
  print("      "..part)
end

print("-- package.cpath:")
for part in string.gmatch(package.cpath, "([^;]+)") do
  print("      "..part)
end

return require'hs._coresetup'.setup(...)