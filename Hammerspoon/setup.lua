local modpath, frameworkspath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...

package.path=configdir.."/?.lua"..";"..configdir.."/?/init.lua"..";"..configdir.."/Spoons/?.spoon/init.lua"..";"..package.path..";"..modpath.."/?.lua"..";"..modpath.."/?/init.lua"
package.cpath=configdir.."/?.so"..";"..package.cpath..";"..frameworkspath.."/?.dylib"

print("-- package.path: "..package.path)
print("-- package.cpath: "..package.cpath)

return require'hs._coresetup'.setup(...)
