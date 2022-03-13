local modpath, frameworkspath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...

local userruntime = "~/.local/share/hammerspoon/site"

local paths = {
  configdir .. "/?.lua",
  configdir .. "/?/init.lua",
  configdir .. "/Spoons/?.spoon/init.lua",
  package.path,
  modpath .. "/?.lua",
  modpath .. "/?/init.lua",
  userruntime .. "/?.lua",
  userruntime .. "/?/init.lua",
  userruntime .. "/Spoons/?.spoon/init.lua",
}

local cpaths = {
  configdir .. "/?.dylib",
  configdir .. "/?.so",
  package.cpath,
  frameworkspath .. "/?.dylib",
  userruntime .. "/lib/?.dylib",
  userruntime .. "/lib/?.so",
}

package.path = table.concat(paths, ";")
package.cpath = table.concat(cpaths, ";")

print("-- package.path: " .. package.path)
print("-- package.cpath: " .. package.cpath)

local preload = function(m) return require(m) end
package.preload['hs.application.watcher']   = preload 'hs.libapplicationwatcher'
package.preload['hs.audiodevice.watcher']   = preload 'hs.libaudiodevicewatcher'
package.preload['hs.battery.watcher']       = preload 'hs.libbatterywatcher'
package.preload['hs.bonjour.service']       = preload 'hs.libbonjourservice'
package.preload['hs.caffeinate.watcher']    = preload 'hs.libcaffeinatewatcher'
package.preload['hs.canvas.matrix']         = preload 'hs.canvas_maxtrix'
package.preload['hs.drawing.color']         = preload 'hs.drawing_color'
package.preload['hs.doc.hsdocs']            = preload 'hs.hsdocs'
package.preload['hs.doc.markdown']          = preload 'hs.libmarkdown'
package.preload['hs.doc.builder']           = preload 'hs.doc_builder'
package.preload['hs.fs.volume']             = preload 'hs.libfsvolume'
package.preload['hs.fs.xattr']              = preload 'hs.libfsxattr'
package.preload['hs.host.locale']           = preload 'hs.host_locale'
package.preload['hs.httpserver.hsminweb']   = preload 'hs.httpserver_hsminweb'
package.preload['hs.location.geocoder']     = preload 'hs.location_geocoder'
package.preload['hs.network.configuration'] = preload 'hs.network_configuration'
package.preload['hs.network.host']          = preload 'hs.network_host'
package.preload['hs.network.ping']          = preload 'hs.network_ping'
package.preload['hs.pasteboard.watcher']    = preload 'hs.libpasteboardwatcher'
package.preload['hs.screen.watcher']        = preload 'hs.libscreenwatcher'
package.preload['hs.socket.udp']            = preload 'hs.libsocketudp'
package.preload['hs.spaces.watcher']        = preload 'hs.libspaceswatcher'
package.preload['hs.uielement.watcher']     = preload 'hs.libuielementwatcher'
package.preload['hs.usb.watcher']           = preload 'hs.libusbwatcher'
package.preload['hs.webview.datastore']     = preload 'hs.libwebviewdatastore'
package.preload['hs.webview.usercontent']   = preload 'hs.libwebviewusercontent'
package.preload['hs.webview.toolbar']       = preload 'hs.webview_toolbar'
package.preload['hs.wifi.watcher']          = preload 'hs.libwifiwatcher'
package.preload['hs.window.filter']         = preload 'hs.window_filter'
package.preload['hs.window.highlight']      = preload 'hs.window_highlight'
package.preload['hs.window.layout']         = preload 'hs.window_layout'
package.preload['hs.window.switcher']       = preload 'hs.window_switcher'
package.preload['hs.window.tiling']         = preload 'hs.window_tiling'

return require'hs._coresetup'.setup(...)
