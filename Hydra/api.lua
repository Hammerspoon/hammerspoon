api.doc.api.resourcesdir = {"api.doc.api.resourcesdir -> string", "The location of the built-in lua source files."}

api.doc.api.userfile = {"api.userfile(name)", "Returns the full path to the file ~/.hydra/{name}.lua"}
function api.userfile(name)
  return os.getenv("HOME") .. "/.hydra/" .. name .. ".lua"
end

api.doc.api.douserfile = {"api.douserfile(name)", "Convenience wrapper around dofile() and api.userfile(name)"}
function api.douserfile(name)
  local userfile = api.userfile(name)
  local exists, isdir = api.fileexists(userfile)
  if exists and not isdir then
    dofile(userfile)
  else
    api.alert("Can't find file: " .. name)
  end
end

local function load_default_config()
  local defaultinit = dofile(api.resourcesdir .. "/defaultinit.lua")
  defaultinit.run()
end

local function clear_old_state()
  api.hotkey.disableall()
  api.menu.hide()
  api.pathwatcher.stopall()
  api.timer.stopall()
  api.textgrid.closeall()
  api.notify.unregisterall()
end

api.doc.api.reload = {"api.reload()", "Reloads your init-file. Makes sure to clear any state that makes sense to clear (hotkeys, pathwatchers, etc)."}
function api.reload()
  clear_old_state()

  local userfile = os.getenv("HOME") .. "/.hydra/init.lua"
  local exists, isdir = api.fileexists(userfile)

  if exists and not isdir then
    local ok, err = pcall(function() dofile(userfile) end)
    if not ok then
      api.alert("Error loading your config:\n" .. err .. "\nFalling back to sample config.", 10)
      load_default_config()
    end
  else
    -- don't say (via alert) anything more than what the default config already says
    load_default_config()
  end
end

api.doc.api.errorhandler = {"api.errorhandler = function(err)", "Error handler for api.call; intended for you to set, not for third party libs"}
function api.errorhandler(err)
  print("Error: " .. err)
  api.alert("Error: " .. err, 5)
end

function api.tryhandlingerror(firsterr)
  local ok, seconderr = pcall(function()
      api.errorhandler(firsterr)
  end)

  if not ok then
    api.alert("Error while handling error: " .. seconderr, 10)
    api.alert("Original error: " .. firsterr, 10)
  end
end

api.doc.api.call = {"api.call(fn, ...) -> ...", "Just like pcall, except that failures are handled using api.errorhandler"}
function api.call(fn, ...)
  local results = table.pack(pcall(fn, ...))
  if not results[1] then
    -- print(debug.traceback())
    api.tryhandlingerror(results[2])
  end
  return table.unpack(results)
end

api.doc.api.uuid = {"api.uuid() -> string", "Returns a UUID as a string"}
function api.uuid()
  return io.popen("uuidgen"):read()
end
