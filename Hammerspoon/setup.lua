local modpath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...

package.path=configdir.."/?.lua"..";"..configdir.."/?/init.lua"..";"..configdir.."/Spoons/?.spoon/init.lua"..";"..package.path..";"..modpath.."/?.lua"..";"..modpath.."/?/init.lua"
package.cpath=configdir.."/?.so"..";"..package.cpath..";"..modpath.."/?.so"

local ppath = ""
for part in string.gmatch(package.path, "([^;]+)") do
  ppath = ppath..":"..part
end
print("-- package.path: "..ppath)

local cpath = ""
for part in string.gmatch(package.cpath, "([^;]+)") do
  cpath = cpath..":"..part
end
print("-- package.cpath: "..cpath)

return require'hs._coresetup'.setup(...)
