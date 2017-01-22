local modpath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...

--[[
2017-01-22 23:00:37: modpath: /Users/latenitechris/Documents/Github/hammerspoon/build/FCPX Hacks.app/Contents/Resources/extensions
2017-01-22 23:00:37: fullpath: /Users/latenitechris/.hammerspoon/init.lua
2017-01-22 23:00:37: configdir: /Users/latenitechris/.hammerspoon
2017-01-22 23:00:37: docstringspath: /Users/latenitechris/Documents/Github/hammerspoon/build/FCPX Hacks.app/Contents/Resources/docs.json
2017-01-22 23:00:37: hasinitfile: true
2017-01-22 23:00:37: autoload_extensions: true
--]]

configdir = modpath

--print("-- Augmenting require paths")
--package.path=configdir.."/?.lua"..";"..configdir.."/?/init.lua"..";"..package.path..";"..modpath.."/?.lua"..";"..modpath.."/?/init.lua"
--package.cpath=configdir.."/?.so"..";"..package.cpath..";"..modpath.."/?.so"
package.path=modpath.."/?.lua"..";"..modpath.."/?/init.lua"
package.cpath=modpath.."/?.so"

print("-- package.path:")
for part in string.gmatch(package.path, "([^;]+)") do
  print("      "..part)
end

print("-- package.cpath:")
for part in string.gmatch(package.cpath, "([^;]+)") do
  print("      "..part)
end

return require'hs._coresetup'.setup(...)
