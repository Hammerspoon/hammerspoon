local modpath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...

print("-- Augmenting require paths")

package.path="~/Library/Application Support/CommandPost/Plugins/?.lua;~/Library/Application Support/CommandPost/Plugins/?/init.lua;" .. configdir.."/extensions/?.lua"..";"..configdir.."/extensions/?/init.lua"..";"..configdir.."/plugins/?.lua"..";"..configdir.."/plugins/?/init.lua"..";"..modpath.."/?.lua"..";"..modpath.."/?/init.lua"
package.cpath="~/Library/Application Support/CommandPost/Plugins/?.so;" .. configdir.."/extensions/?.so"..";"..configdir.."/plugins/?.so"..";"..modpath.."/?.so"

print("-- package.path:")
for part in string.gmatch(package.path, "([^;]+)") do
  print("      "..part)
end

print("-- package.cpath:")
for part in string.gmatch(package.cpath, "([^;]+)") do
  print("      "..part)
end

return require'hs._coresetup'.setup(...)