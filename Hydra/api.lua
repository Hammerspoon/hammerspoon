function api.require(path)
  local userfile = os.getenv("HOME") .. "/.hydra/" .. path .. ".lua"
  local exists, isdir = api.fileexists(userfile)
  if exists and not isdir then
    dofile(userfile)
  else
    api.alert("Can't find file: " .. path)
  end
end

function api.reload()
  local userfile = os.getenv("HOME") .. "/.hydra/init.lua"
  local exists, isdir = api.fileexists(userfile)

  if exists and not isdir then
    api.call(function() dofile(userfile) end)
  else
    local defaultinit = dofile(api.resourcesdir .. "/defaultinit.lua")
    defaultinit.run()
  end
end

local t = getmetatable(api.alert) or {}
t.__call = function(self, msg, dur)
  api.alert.show(msg, dur)
end
setmetatable(api.alert, t)


function api.errorhandler(err)
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

function api.call(fn, ...)
  local results = table.pack(pcall(fn, ...))
  if not results[1] then
    api.tryhandlingerror(results[2])
  end
  return table.unpack(results)
end
