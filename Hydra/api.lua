function api.require(path)
  local userfile = os.getenv("HOME") .. "/.hydra/" .. path .. ".lua"
  local exists, isdir = api.fileexists(userfile)
  if exists and not isdir then
    dofile(userfile)
  else
    api.alert("Cannot find file: " .. path)
  end
end

function api.reload()
  local userfile = os.getenv("HOME") .. "/.hydra/init.lua"
  local exists, isdir = api.fileexists(userfile)

  if exists and not isdir then
    local ok, err = pcall(function()
        dofile(userfile)
    end)
    if not ok then
      api.alert(err, 5)
    end
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
